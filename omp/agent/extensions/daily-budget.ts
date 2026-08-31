/**
 * Daily-budget pacing on top of omp's built-in `retry.usageAwareFallback`.
 *
 * `usageAwareFallback` (config.yml) already falls back off the primary model
 * once a provider's own rolling quota window (Claude's 5h/7d, Codex's 5h/7d)
 * gets low — see docs/non-compaction-retry-policy.md. What it has no notion
 * of is *how* that week should be spent day to day: it is silent right up
 * until the reserve threshold, so a heavy Monday can quietly burn the whole
 * 7-day window before Friday.
 *
 * `daily-budget.json` allocates a percentage of that 7-day window to each
 * weekday, and a $ cap to each weekday for the pay-per-token providers that
 * have no quota window at all. Both track a same-day carryover: an
 * under-spent day banks its leftover allowance forward, an over-spent day
 * borrows against tomorrow's, so the displayed "today" number is the day's
 * own budget plus whatever rolled forward from prior days. This extension
 * does not fall back or block anything — that stays `usageAwareFallback`'s
 * job — it only warns once actual usage overruns today's effective
 * allowance, so the fallback/quota wall stops being a surprise.
 *
 * There is no documented extension API to read a provider's live usage
 * report in-process (`pi.registerProvider`'s `usage.fetchUsage` only lets you
 * *supply* one), so this shells out to `omp usage --json` — the same data
 * the CLI and the statusline `usage` segment already show — on a timer
 * rather than on every turn, to keep it off the network's critical path.
 */

import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const CONFIG_PATH = join(homedir(), ".omp", "agent", "daily-budget.json");
const STATE_PATH = join(homedir(), ".omp", "agent", "daily-budget-state.json");

const WEEKDAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"] as const;
type Weekday = (typeof WEEKDAYS)[number];

interface BudgetConfig {
  providers: string[];
  windowId: string; // must match a reported limit's `window.id` (e.g. "7d")
  checkIntervalMs: number;
  allocationPct: Record<Weekday, number>;
  costCap?: CostCapConfig;
}

// API-billed providers (pay-per-token, no rolling quota window from `omp
// usage --json`) get a per-weekday $ cap instead of a %-of-window
// allocation — there is no window to allocate a percentage of.
interface CostCapConfig {
  providers: string[];
  dailyCapUsd: Record<Weekday, number>;
}

interface UsageLimit {
  scope?: { provider?: string; shared?: boolean };
  window?: { id?: string; resetsAt?: number; durationMs?: number };
  amount?: { usedFraction?: number };
}

interface UsageReport {
  provider: string;
  limits?: UsageLimit[];
}

// Per-provider ledger, keyed by provider id (quota providers) or
// "cost:combined" (the pooled cost cap). Quota providers carry their own
// cumulative-usage report, so their carryover is derived on read (see
// `checkBudgets`) rather than stored — only the day boundary needs
// remembering. Cost has no such report, so its carryover is computed and
// stored explicitly when a day rolls over. `warnedDayStartMs` dedupes the
// overrun notification to once per local calendar day.
interface Ledger {
  windowStartMs?: number;
  dayBaselineStartMs?: number;
  dayBaselineUsedPct?: number;
  weekStartMs?: number;
  carryoverUsd?: number;
  warnedDayStartMs?: number;
}

type DailyState = Record<string, Ledger>;

// Minimal shape shared by ExtensionContext and ExtensionCommandContext so
// this helper doesn't have to pick one.
interface NotifyUI {
  notify(message: string, level: "info" | "warning" | "error"): void;
  setWidget(key: string, lines: string[], options?: { placement?: "aboveEditor" | "belowEditor" }): void;
}

function loadConfig(): BudgetConfig | undefined {
  if (!existsSync(CONFIG_PATH)) return undefined;
  try {
    return JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as BudgetConfig;
  } catch {
    return undefined;
  }
}

function loadState(): DailyState {
  if (!existsSync(STATE_PATH)) return {};
  try {
    return JSON.parse(readFileSync(STATE_PATH, "utf8")) as DailyState;
  } catch {
    return {};
  }
}

function weekdayOf(ms: number): Weekday {
  // Names the Date→weekday-enum mapping so callers read a domain concept,
  // not a raw array index.
  return WEEKDAYS[new Date(ms).getDay()];
}

// Most recent Monday-local-midnight at or before `ms`. The cost cap's
// carryover resets here each week (unlike the quota providers', which
// resets whenever each provider's own rolling window happens to roll) —
// there is no provider-reported window to key a reset off for cost, so a
// fixed calendar week gives it one instead of accumulating forever.
function weekStartMs(ms: number): number {
  const d = new Date(ms);
  d.setHours(0, 0, 0, 0);
  const daysSinceMonday = (d.getDay() + 6) % 7;
  d.setDate(d.getDate() - daysSinceMonday);
  return d.getTime();
}

// Cumulative allocated percentage from the window's own start through today.
// Walking real calendar days rather than assuming a Monday start: the
// provider's window is rolling (it resets N days after it last reset, not on
// a fixed calendar boundary), so "day 1" is whatever weekday the window
// happened to start on.
function cumulativeAllocationPct(config: BudgetConfig, windowStartMs: number, nowMs: number): number {
  const dayMs = 24 * 60 * 60 * 1000;
  const daysElapsed = Math.max(1, Math.floor((nowMs - windowStartMs) / dayMs) + 1);
  let total = 0;
  for (let i = 0; i < daysElapsed; i++) {
    total += config.allocationPct[weekdayOf(windowStartMs + i * dayMs)] ?? 0;
  }
  return total;
}

function fetchUsageReports(): UsageReport[] {
  const raw = execFileSync("omp", ["usage", "--json"], {
    encoding: "utf8",
    timeout: 15_000,
  });
  // Trusted own-CLI output, not raw external input; cast once, then read
  // through the named, typed const rather than chaining member access off
  // the cast itself.
  const parsed = JSON.parse(raw) as { reports?: UsageReport[] };
  return parsed.reports ?? [];
}

const SESSIONS_DIR = join(homedir(), ".omp", "agent", "sessions");

interface SessionMessageEntry {
  type: string;
  message?: {
    role?: string;
    provider?: string;
    timestamp?: number;
    usage?: { cost?: { total?: number } };
  };
}

// Sums $ cost per provider over [startMs, endMs) by scanning every session's
// on-disk JSONL log (`~/.omp/agent/sessions/<encoded-cwd>/*.jsonl`), since
// cost is account-wide, not scoped to the current session, and there is no
// documented extension API that reports historical spend across sessions. A
// file whose mtime predates the range start cannot contain a message
// timestamped inside it, so most files are skipped without being opened.
function sumCostByProviderInRange(providers: string[], startMs: number, endMs: number): Record<string, number> {
  const totals: Record<string, number> = {};
  for (const providerId of providers) totals[providerId] = 0;
  if (!existsSync(SESSIONS_DIR)) return totals;

  let projectDirs: string[];
  try {
    projectDirs = readdirSync(SESSIONS_DIR);
  } catch {
    return totals;
  }

  for (const dir of projectDirs) {
    const dirPath = join(SESSIONS_DIR, dir);
    let files: string[];
    try {
      files = readdirSync(dirPath).filter((f) => f.endsWith(".jsonl"));
    } catch {
      continue;
    }

    for (const file of files) {
      const filePath = join(dirPath, file);
      try {
        if (statSync(filePath).mtimeMs < startMs) continue;

        for (const line of readFileSync(filePath, "utf8").split("\n")) {
          if (!line) continue;
          let entry: SessionMessageEntry;
          try {
            entry = JSON.parse(line) as SessionMessageEntry;
          } catch {
            continue;
          }
          const message = entry.message;
          if (
            entry.type !== "message" ||
            message?.role !== "assistant" ||
            message.provider === undefined ||
            !providers.includes(message.provider) ||
            message.timestamp === undefined ||
            message.timestamp < startMs ||
            message.timestamp >= endMs
          ) {
            continue;
          }
          totals[message.provider] = (totals[message.provider] ?? 0) + (message.usage?.cost?.total ?? 0);
        }
      } catch {
        continue;
      }
    }
  }
  return totals;
}

// Minimal raw ANSI helpers — no documented theme accessor reaches plain
// setWidget strings (that API is untyped for styling), and setStatus's own
// docs note ANSI gets stripped there, so we go straight to escape codes
// rather than reach for a color library for three colors.
const ANSI = {
  reset: "\x1b[0m",
  dim: "\x1b[2m",
  green: "\x1b[32m",
  red: "\x1b[31m",
} as const;

function colorize(code: string, text: string): string {
  return `${code}${text}${ANSI.reset}`;
}

// eslint-disable-next-line no-control-regex
const ANSI_PATTERN = /\x1b\[[0-9;]*m/g;

// Right-aligns against the real terminal width, since setWidget has no
// alignment option of its own; strips ANSI codes first so escape sequences
// (zero visible width) don't get counted as padding.
function rightAlign(line: string): string {
  const width = process.stdout.columns ?? 80;
  const visibleLength = line.replace(ANSI_PATTERN, "").length;
  const pad = Math.max(0, width - 2 - visibleLength);
  return " ".repeat(pad) + line;
}

// Toggled by the `/budget` command; gates rendering only — the pacing
// check, state persistence, and overrun `notify` warnings still run while
// hidden, so muting the widget never silences the thing it's warning about.
let widgetHidden = false;

function checkBudgets(config: BudgetConfig, ui: NotifyUI): void {
  let reports: UsageReport[];
  try {
    reports = fetchUsageReports();
  } catch {
    ui.setWidget("daily-budget", ["Budget: check failed"], { placement: "aboveEditor" });
    return;
  }

  const state = loadState();
  const now = Date.now();
  const todayStartMs = new Date(now).setHours(0, 0, 0, 0);
  const segments: string[] = [];

  for (const providerId of config.providers) {
    const report = reports.find((r) => r.provider === providerId);
    const limit = report?.limits?.find(
      (l) => l.window?.id === config.windowId && l.scope?.shared === true,
    );
    const usedFraction = limit?.amount?.usedFraction;
    const resetsAt = limit?.window?.resetsAt;
    const durationMs = limit?.window?.durationMs;
    if (usedFraction === undefined || resetsAt === undefined || durationMs === undefined) {
      segments.push(`${providerId} n/a`);
      continue;
    }

    const windowStartMs = resetsAt - durationMs;
    const usedPct = usedFraction * 100;

    // Reset the day's usage baseline whenever the window rolls (the
    // provider's own cumulative usedFraction jumps back near 0, so a stale
    // baseline would show a false "today" spike) or a new calendar day
    // starts. cumulativeAllocationPct(now) minus that baseline is exactly
    // "today's base allocation +/- whatever rolled forward": an under-pace
    // day leaves usedPct behind the cumulative target, which shows up as
    // extra headroom today; an over-pace day does the opposite.
    const entry = state[providerId] ?? {};
    if (entry.windowStartMs !== windowStartMs || entry.dayBaselineStartMs !== todayStartMs) {
      entry.windowStartMs = windowStartMs;
      entry.dayBaselineStartMs = todayStartMs;
      entry.dayBaselineUsedPct = usedPct;
    }

    const baseline = entry.dayBaselineUsedPct ?? usedPct;
    const todaysUsedPct = usedPct - baseline;
    const todaysAllocatedPct = cumulativeAllocationPct(config, windowStartMs, now) - baseline;
    const overPace = todaysUsedPct > todaysAllocatedPct;

    if (overPace) {
      if (entry.warnedDayStartMs !== todayStartMs) {
        ui.notify(
          `${providerId}: ${todaysUsedPct.toFixed(0)}% used today, ` +
            `${todaysAllocatedPct.toFixed(0)}% allocated (incl. carryover)`,
          "warning",
        );
        entry.warnedDayStartMs = todayStartMs;
      }
    } else {
      delete entry.warnedDayStartMs;
    }
    state[providerId] = entry;

    const status = overPace ? colorize(ANSI.red, "!") : colorize(ANSI.green, "\u2713");
    segments.push(`${providerId} ${todaysUsedPct.toFixed(0)}/${todaysAllocatedPct.toFixed(0)}% ${status}`);
  }

  if (config.costCap) {
    const { providers, dailyCapUsd } = config.costCap;
    const entry = state["cost:combined"] ?? {};

    // A new calendar week (Monday) zeroes the carryover so a rough week
    // can't keep dragging down the next; otherwise settle the day that
    // just ended — its leftover (or overrun), on top of whatever it
    // started with, becomes today's carryover.
    const currentWeekStartMs = weekStartMs(now);
    if (entry.weekStartMs !== currentWeekStartMs) {
      entry.weekStartMs = currentWeekStartMs;
      entry.carryoverUsd = 0;
    } else if (entry.dayBaselineStartMs !== todayStartMs) {
      const priorCap = (dailyCapUsd[weekdayOf(entry.dayBaselineStartMs)] ?? 0) + (entry.carryoverUsd ?? 0);
      const priorTotals = sumCostByProviderInRange(providers, entry.dayBaselineStartMs, todayStartMs);
      const priorSpend = Object.values(priorTotals).reduce((sum, cost) => sum + cost, 0);
      entry.carryoverUsd = priorCap - priorSpend;
    }
    entry.dayBaselineStartMs = todayStartMs;

    const totals = sumCostByProviderInRange(providers, todayStartMs, now + 1);
    const spentToday = Object.values(totals).reduce((sum, cost) => sum + cost, 0);
    const effectiveCapToday = (dailyCapUsd[weekdayOf(now)] ?? 0) + (entry.carryoverUsd ?? 0);
    const overCap = spentToday > effectiveCapToday;

    if (overCap) {
      if (entry.warnedDayStartMs !== todayStartMs) {
        ui.notify(
          `API cost: $${spentToday.toFixed(2)} of $${effectiveCapToday.toFixed(2)} today's budget used (incl. carryover)`,
          "warning",
        );
        entry.warnedDayStartMs = todayStartMs;
      }
    } else {
      delete entry.warnedDayStartMs;
    }
    state["cost:combined"] = entry;

    const costStatus = overCap ? colorize(ANSI.red, "!") : colorize(ANSI.green, "\u2713");
    segments.push(`API $${spentToday.toFixed(2)}/$${effectiveCapToday.toFixed(2)} ${costStatus}`);
  }

  writeFileSync(STATE_PATH, JSON.stringify(state, null, 2));
  if (widgetHidden) return;
  const line = `${colorize(ANSI.dim, `Budget (${config.windowId})`)}  ${segments.join("   ")}`;
  ui.setWidget("daily-budget", [rightAlign(line)], { placement: "aboveEditor" });
}

export default function dailyBudgetExtension(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx: ExtensionContext) => {
    const config = loadConfig();
    if (!config) return;

    checkBudgets(config, ctx.ui);
    const timer = ctx.setInterval(() => checkBudgets(config, ctx.ui), config.checkIntervalMs);
    pi.on("session_shutdown", () => ctx.clearTimer(timer));
  });

  pi.registerCommand("budget", {
    description: "Toggle the daily-budget pacing widget",
    handler: async (_args, ctx) => {
      const config = loadConfig();
      if (!config) {
        ctx.ui.notify("No ~/.omp/agent/daily-budget.json configured", "warning");
        return;
      }
      widgetHidden = !widgetHidden;
      if (widgetHidden) {
        ctx.ui.setWidget("daily-budget", [], { placement: "aboveEditor" });
      } else {
        checkBudgets(config, ctx.ui);
      }
    },
  });
}
