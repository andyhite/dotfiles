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
 * `daily-budget.json` has two independent categories, each a global default
 * plus optional per-provider overrides:
 *
 * - `usage`: a %-of-window allocation for quota-window providers (Claude,
 *   Codex — anything `omp usage --json` reports a rolling window for). Which
 *   providers get paced is discovered fresh from that report every check,
 *   never a static list — an unauthenticated/unconfigured provider simply
 *   never appears and is never paced. `usage.allocationPct` is the default
 *   schedule for any reported provider; `usage.providers[id].allocationPct`
 *   overrides it for one provider.
 * - `cost`: a $ cap for pay-per-token providers (no quota window at all).
 *   Every provider *not* covered by `usage`'s discovered set is a cost
 *   provider by construction — nothing needs listing for its spend to count.
 *   By default every such provider's spend is pooled against one shared
 *   `cost.dailyCapUsd` (matching the "should all contribute to the spend the
 *   budget is evaluated against" requirement); `cost.providers[id]` pulls
 *   that one provider out of the pool and gives it its own separate cap.
 *
 * Both categories track a same-day carryover: an under-spent day banks its
 * leftover allowance forward, an over-spent day borrows against tomorrow's,
 * so the displayed "today" number is the day's own budget plus whatever
 * rolled forward from prior days. This extension does not fall back or
 * block anything — that stays `usageAwareFallback`'s job — it only warns
 * once actual usage overruns today's effective allowance, so the
 * fallback/quota wall stops being a surprise.
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

type WeekdayMap = Record<Weekday, number>;

// A provider-specific schedule that supersedes its category's global
// default. For `usage` this only changes which allocationPct paces that one
// provider — it is always tracked individually regardless. For `cost` it
// additionally pulls the provider out of the shared pool: its spend counts
// against `dailyCapUsd` here instead of the pooled default.
interface UsageProviderOverride {
  allocationPct: WeekdayMap;
}

interface CostProviderOverride {
  dailyCapUsd: WeekdayMap;
}

interface BudgetConfig {
  windowId: string; // must match a reported limit's `window.id` (e.g. "7d")
  checkIntervalMs: number;
  usage: {
    allocationPct: WeekdayMap;
    providers?: Record<string, UsageProviderOverride>;
  };
  // Optional: a machine with no pay-per-token provider authenticated simply
  // never accrues cost, so there is nothing to cap.
  cost?: {
    dailyCapUsd: WeekdayMap;
    providers?: Record<string, CostProviderOverride>;
  };
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

// Per-bucket ledger. Quota providers are keyed by their bare provider id and
// carry their own cumulative-usage report, so their carryover is derived on
// read (see `checkBudgets`) rather than stored — only the day boundary needs
// remembering. Cost buckets ("cost:combined" for the shared pool,
// "cost:<providerId>" for an override) have no such report, so their
// carryover is computed and stored explicitly when a day rolls over.
// `warnedDayStartMs` dedupes the overrun notification to once per local
// calendar day.
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
// happened to start on. Takes the resolved allocationPct map directly
// (global default or a provider's override) rather than the whole config, so
// callers don't re-resolve which one applies.
function cumulativeAllocationPct(allocationPct: WeekdayMap, windowStartMs: number, nowMs: number): number {
  const dayMs = 24 * 60 * 60 * 1000;
  const daysElapsed = Math.max(1, Math.floor((nowMs - windowStartMs) / dayMs) + 1);
  let total = 0;
  for (let i = 0; i < daysElapsed; i++) {
    total += allocationPct[weekdayOf(windowStartMs + i * dayMs)] ?? 0;
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
//
// Unfiltered by design: every provider that ever billed a message shows up
// in the result, keyed by its own id, so the caller — not this scan — draws
// the line between "quota provider whose notional cost doesn't count" and
// "real pay-per-token spend". `omp` logs a notional cost for every message
// including subscription providers' (Claude/Codex), so a naive full sum
// would double-count spend already paced by `usage`; callers must exclude
// each check's discovered quota-provider ids from the total themselves.
function sumCostByProviderInRange(startMs: number, endMs: number): Record<string, number> {
  const totals: Record<string, number> = {};
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

// Settles carryover, checks today's spend against today's effective cap
// (weekday cap + carryover), notifies once per day on overrun, persists the
// ledger entry, and appends the rendered segment. Shared by the pooled
// default cost bucket and every per-provider cost override — the only
// difference between them is which spend function and cap schedule feed in.
function evaluateCostBucket(
  key: string,
  label: string,
  dailyCapUsd: WeekdayMap,
  spentToday: number,
  priorSpend: (startMs: number, endMs: number) => number,
  state: DailyState,
  now: number,
  todayStartMs: number,
  ui: NotifyUI,
  segments: string[],
): void {
  const entry = state[key] ?? {};

  // A new calendar week (Monday) zeroes the carryover so a rough week
  // can't keep dragging down the next; otherwise settle the day that just
  // ended — its leftover (or overrun), on top of whatever it started with,
  // becomes today's carryover.
  const currentWeekStartMs = weekStartMs(now);
  if (entry.weekStartMs !== currentWeekStartMs) {
    entry.weekStartMs = currentWeekStartMs;
    entry.carryoverUsd = 0;
  } else if (entry.dayBaselineStartMs !== todayStartMs) {
    const priorCap = (dailyCapUsd[weekdayOf(entry.dayBaselineStartMs)] ?? 0) + (entry.carryoverUsd ?? 0);
    entry.carryoverUsd = priorCap - priorSpend(entry.dayBaselineStartMs, todayStartMs);
  }
  entry.dayBaselineStartMs = todayStartMs;

  const effectiveCapToday = (dailyCapUsd[weekdayOf(now)] ?? 0) + (entry.carryoverUsd ?? 0);
  const overCap = spentToday > effectiveCapToday;

  if (overCap) {
    if (entry.warnedDayStartMs !== todayStartMs) {
      ui.notify(
        `${label} cost: $${spentToday.toFixed(2)} of $${effectiveCapToday.toFixed(2)} today's budget used (incl. carryover)`,
        "warning",
      );
      entry.warnedDayStartMs = todayStartMs;
    }
  } else {
    delete entry.warnedDayStartMs;
  }
  state[key] = entry;

  const status = overCap ? colorize(ANSI.red, "!") : colorize(ANSI.green, "\u2713");
  segments.push(`${label} $${spentToday.toFixed(2)}/$${effectiveCapToday.toFixed(2)} ${status}`);
}

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

  // Quota-window providers are whichever ones `omp usage --json` actually
  // reports right now — never a static list — so an unauthenticated or
  // unconfigured provider is never paced and never shown.
  for (const report of reports) {
    const providerId = report.provider;
    const limit = report.limits?.find((l) => l.window?.id === config.windowId && l.scope?.shared === true);
    const usedFraction = limit?.amount?.usedFraction;
    const resetsAt = limit?.window?.resetsAt;
    const durationMs = limit?.window?.durationMs;
    // Authenticated, but this provider doesn't report `config.windowId` as a
    // shared window (e.g. it only exposes a 5h window) — nothing to pace.
    if (usedFraction === undefined || resetsAt === undefined || durationMs === undefined) continue;

    const allocationPct = config.usage.providers?.[providerId]?.allocationPct ?? config.usage.allocationPct;
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
    const todaysAllocatedPct = cumulativeAllocationPct(allocationPct, windowStartMs, now) - baseline;
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

  if (config.cost) {
    const { dailyCapUsd, providers: overrides = {} } = config.cost;
    // Every provider `usage` is actively pacing this check reports a
    // notional cost too (subscription plans still log a would-be $ figure),
    // which is not real per-token spend — exclude those ids so the pool
    // isn't double-counting quota-paced usage as cash spend.
    const quotaProviderIds = new Set(reports.map((r) => r.provider));
    const overrideIds = new Set(Object.keys(overrides));

    const poolSpend = (totals: Record<string, number>) => {
      let sum = 0;
      for (const [providerId, cost] of Object.entries(totals)) {
        if (quotaProviderIds.has(providerId) || overrideIds.has(providerId)) continue;
        sum += cost;
      }
      return sum;
    };

    // One sweep of today's session logs covers every bucket below — the
    // pooled default and each override just read different keys/sums out of
    // it rather than each re-scanning independently.
    const todaysTotals = sumCostByProviderInRange(todayStartMs, now + 1);

    evaluateCostBucket(
      "cost:combined",
      "API",
      dailyCapUsd,
      poolSpend(todaysTotals),
      (startMs, endMs) => poolSpend(sumCostByProviderInRange(startMs, endMs)),
      state,
      now,
      todayStartMs,
      ui,
      segments,
    );

    for (const [providerId, override] of Object.entries(overrides)) {
      evaluateCostBucket(
        `cost:${providerId}`,
        providerId,
        override.dailyCapUsd,
        todaysTotals[providerId] ?? 0,
        (startMs, endMs) => sumCostByProviderInRange(startMs, endMs)[providerId] ?? 0,
        state,
        now,
        todayStartMs,
        ui,
        segments,
      );
    }
  }

  writeFileSync(STATE_PATH, JSON.stringify(state, null, 2));
  if (widgetHidden) return;
  if (segments.length === 0) {
    // Nothing discovered from `omp usage --json` and no cost accrued —
    // nothing to pace, so show nothing rather than a bare "Budget (7d)"
    // label.
    ui.setWidget("daily-budget", [], { placement: "aboveEditor" });
    return;
  }
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
