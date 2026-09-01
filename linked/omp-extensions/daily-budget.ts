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
 *   Codex — anything `omp usage --json` reports a rolling window for).
 *   Which providers get paced is discovered fresh from that report every
 *   check, never a static list — an unauthenticated/unconfigured provider
 *   simply never appears and is never paced. `usage.allocationPct` is the
 *   default schedule for any reported provider. `usage.providers[key]`
 *   defines a *track* — not necessarily one per provider id: `provider`
 *   picks which report to read (default: the key itself), `limitId`/
 *   `windowId` pick which of that report's limits to pace when the default
 *   match (`window.id === windowId && scope.shared === true`) doesn't fit
 *   (Cursor's own-model bundle reports a `monthly`, non-`shared` limit),
 *   and `deriveDailyFromWindow` synthesizes an even weekday split from the
 *   matched limit's own window length instead of requiring a hand-authored
 *   one (Cursor's monthly reset has no natural workweek shape the way
 *   Claude/Codex's 7-day windows do).
 * - `cost`: a $ cap for pay-per-token providers (no quota window at all).
 *   Every provider *not* covered by `usage`'s discovered set is a cost
 *   provider by construction — nothing needs listing for its spend to count.
 *   By default every such provider's spend is pooled against one shared
 *   `cost.dailyCapUsd` (matching the "should all contribute to the spend the
 *   budget is evaluated against" requirement); `cost.providers[id]` pulls
 *   that one provider out of the pool and gives it its own separate cap.
 *   `cost.reportSources[key]` is the third case: real $ spend that a usage
 *   report already tallies directly (`amount.used`, unit "usd") but that
 *   the session-log scan can't isolate — Cursor's pay-per-token overage
 *   shares its provider id with its own-model bundle, so the log's bare
 *   `provider` field can't tell them apart. It always pools into
 *   `cost:combined` at full weight, with no cap of its own — monitoring,
 *   not pacing: the wall it eventually hits (Cursor's own $20/mo cap) isn't
 *   one this extension enforces.
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
 * the CLI and the statusline `usage` segment already show. It refreshes on
 * `turn_end` (so the widget reflects what an agent turn just spent) and
 * falls back to a self-rescheduling `checkIntervalMs` idle timer — reset
 * after every refresh, turn-triggered or not — so a session sitting idle
 * still catches usage from `omp usage --json` itself moving (rolling
 * window resets, spend from another concurrent session) without polling
 * on a fixed wall-clock grid while turns are active.
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
// default. For `usage` this changes which allocationPct paces the track and,
// optionally, which of the provider's several reported limits it paces
// against — it is always tracked individually regardless. For `cost` it
// additionally pulls the provider out of the shared pool: its spend counts
// against `dailyCapUsd` here instead of the pooled default.
//
// The default match (`window.id === config.windowId && scope.shared ===
// true`) fits Anthropic/Codex-style rolling quota windows, but Cursor's
// own-model bundle reports a `monthly`-scoped limit with no `shared` flag
// at all — `limitId` pins it explicitly, and `windowId` widens the match
// to a different window id than the global default when `limitId` isn't
// precise enough on its own. A config key need not equal the provider id:
// `provider` names which report to read, so a provider could in principle
// be split into several independently paced tracks, though today only
// Cursor needs even one (its pay-per-token overage is tracked separately,
// via `cost.reportSources` below, not as a second usage track).
interface UsageProviderOverride {
  provider?: string;
  limitId?: string;
  windowId?: string;
  // Skips `allocationPct` and instead synthesizes a schedule from the
  // matched limit's own reported window: `100 / <days in the window>` per
  // day, or — with `deriveWeekdaysOnly` — `100 / <weekdays in the
  // window>` on Mon-Fri only and 0 on Sat/Sun, so a monthly cap doesn't
  // need a hand-authored weekday split, and can still sit idle on
  // weekends the same way the workweek-shaped Anthropic/Codex schedules
  // do below.
  deriveDailyFromWindow?: boolean;
  deriveWeekdaysOnly?: boolean;
  allocationPct?: WeekdayMap;
}

interface CostProviderOverride {
  dailyCapUsd: WeekdayMap;
}

// A provider limit that already reports its own cumulative $ figure
// (`amount.used`/`amount.limit`, unit "usd") rather than something
// reconstructable from local session logs — Cursor's per-token overage is
// account-wide and split across sibling limits (own-model bundle vs API
// overage) that the session log's bare `provider` field can't tell apart.
// Its today's-delta gets added straight into the pooled `cost:combined`
// total alongside session-log-derived spend, at full weight, with no cap
// of its own — it is monitoring, not pacing: the $20/mo wall it eventually
// hits is Cursor's own, not one this extension enforces.
interface CostReportSource {
  provider?: string; // defaults to the config key
  limitId: string;
}

// A rendered widget segment, kept alongside its sort key (the provider id
// or cost-bucket label) so the final line can be sorted alphabetically —
// with "API" pinned last — without re-parsing the ANSI-colored text.
interface BudgetSegment {
  label: string;
  text: string;
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
    reportSources?: Record<string, CostReportSource>;
  };
}

interface UsageLimit {
  id?: string;
  scope?: { provider?: string; shared?: boolean };
  window?: { id?: string; resetsAt?: number; durationMs?: number };
  amount?: { usedFraction?: number; used?: number; limit?: number; unit?: string };
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
  dayBaselineUsedUsd?: number;
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

// One calendar month before `ms`, same day-of-month (clamped into a
// shorter target month, e.g. Mar 31 -> Feb 28). Cursor's `monthly` limits
// report only `resetsAt`, no `durationMs` the way Anthropic/Codex's rolling
// windows do, so there is no arithmetic window length to subtract; the
// billing cycle is a real calendar month, so date-arithmetic is the only
// way to recover its start.
function monthBeforeMs(ms: number): number {
  const d = new Date(ms);
  const day = d.getDate();
  d.setDate(1);
  d.setMonth(d.getMonth() - 1);
  const daysInTargetMonth = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  d.setDate(Math.min(day, daysInTargetMonth));
  return d.getTime();
}

// A schedule derived from the matched limit's own reported window — every
// day an equal share of 100%, or (`weekdaysOnly`) every Mon-Fri an equal
// share and 0 on Sat/Sun — for `deriveDailyFromWindow` tracks, so a $ or
// request cap that only resets monthly doesn't need a hand-authored
// weekday split, and can still sit idle on weekends the same way the
// workweek-shaped Anthropic/Codex schedules do.
function deriveFlatDailyAllocation(windowStartMs: number, resetsAtMs: number, weekdaysOnly: boolean): WeekdayMap {
  const dayMs = 24 * 60 * 60 * 1000;
  const totalDays = Math.max(1, Math.round((resetsAtMs - windowStartMs) / dayMs));
  if (!weekdaysOnly) {
    const pct = 100 / totalDays;
    return { sun: pct, mon: pct, tue: pct, wed: pct, thu: pct, fri: pct, sat: pct };
  }
  let weekdayCount = 0;
  for (let i = 0; i < totalDays; i++) {
    const wd = weekdayOf(windowStartMs + i * dayMs);
    if (wd !== "sat" && wd !== "sun") weekdayCount++;
  }
  const pct = 100 / Math.max(1, weekdayCount);
  return { sun: 0, mon: pct, tue: pct, wed: pct, thu: pct, fri: pct, sat: 0 };
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

// Today's $ delta for each `cost.reportSources` entry, keyed by config key
// (e.g. "cursor-api") — for the pooled cost total to add alongside
// session-log-derived spend. Baseline-delta, the same technique the usage
// tracks above use for their %, because a report only ever gives a live
// cumulative snapshot (`amount.used`), never an arbitrary-range query the
// way the session-log scan can: there is no way to ask "how much did this
// specific Cursor sub-limit spend between last Tuesday and Thursday",
// only "how much more has `used` grown since the last time this ran". A
// day boundary or the underlying window rolling both reset the baseline to
// the live value (delta 0 for that day) the same way the usage loop does.
// State is kept under `cost-report:<key>` so it can't collide with a
// same-named usage track or cost bucket.
function reportSourceSpendToday(
  reports: UsageReport[],
  sources: Record<string, CostReportSource>,
  state: DailyState,
  now: number,
  todayStartMs: number,
): Record<string, number> {
  const spend: Record<string, number> = {};
  for (const [key, source] of Object.entries(sources)) {
    const report = reports.find((r) => r.provider === (source.provider ?? key));
    const limit = report?.limits?.find((l) => l.id === source.limitId);
    const usedUsd = limit?.amount?.used;
    const resetsAt = limit?.window?.resetsAt;
    if (usedUsd === undefined || resetsAt === undefined) continue; // not authenticated/reporting right now
    const windowStartMs =
      limit?.window?.durationMs !== undefined ? resetsAt - limit.window.durationMs : monthBeforeMs(resetsAt);

    const stateKey = `cost-report:${key}`;
    const entry = state[stateKey] ?? {};
    if (entry.windowStartMs !== windowStartMs || entry.dayBaselineStartMs !== todayStartMs) {
      entry.windowStartMs = windowStartMs;
      entry.dayBaselineStartMs = todayStartMs;
      entry.dayBaselineUsedUsd = usedUsd;
    }
    spend[key] = Math.max(0, usedUsd - (entry.dayBaselineUsedUsd ?? usedUsd));
    state[stateKey] = entry;
  }
  return spend;
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
  yellow: "\x1b[33m",
  red: "\x1b[31m",
} as const;

function colorize(code: string, text: string): string {
  return `${code}${text}${ANSI.reset}`;
}

// Red/yellow/green tiering shared by every rendered status number. A track
// can be over pace today (spending faster than its allocation) or simply
// running low on the underlying window regardless of today's pace — e.g.
// 95% of a 7d quota already burned shows "0/0%" today (nothing left to
// allocate, so today's own pace check trivially passes) which would read as
// healthy if colored on pace alone, without also checking how much of the
// window remains. `red` covers the "act now" cases (over pace, or the
// window itself is nearly exhausted); `yellow` is "watch this" headroom
// below that; anything else is healthy — callers colorize their own
// numbers with the returned code rather than render a separate icon.
function statusColor(remainingPct: number, forceCritical: boolean): string {
  if (forceCritical || remainingPct <= 10) return ANSI.red;
  if (remainingPct <= 25) return ANSI.yellow;
  return ANSI.green;
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
  segments: BudgetSegment[],
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

  const remainingCapPct = effectiveCapToday > 0 ? ((effectiveCapToday - spentToday) / effectiveCapToday) * 100 : 100;
  const color = statusColor(remainingCapPct, overCap);
  segments.push({ label, text: `${label} ${colorize(color, `$${spentToday.toFixed(2)}/$${effectiveCapToday.toFixed(2)}`)}` });
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
  const segments: BudgetSegment[] = [];

  // Quota-window providers are whichever ones `omp usage --json` actually
  // reports right now — never a static list — so an unauthenticated or
  // unconfigured provider is never paced and never shown. Each entry in
  // `config.usage.providers` is a *track*, not necessarily a provider id: it
  // names which provider report to read (`provider`, defaulting to the key
  // itself) and, optionally, which specific limit within that report
  // (`limitId`/`windowId`) — that split is what lets one provider like
  // Cursor pace two independent limits (its own-model bundle and its
  // pay-per-token overage) as two separate lines. Any reporting provider
  // not claimed by a track this way still gets auto-discovered below under
  // the default match, unchanged from before this split existed.
  const overrides = config.usage.providers ?? {};
  const claimedProviderIds = new Set(Object.entries(overrides).map(([key, o]) => o.provider ?? key));
  const tracks: Array<{ key: string; report: UsageReport | undefined; override: UsageProviderOverride | undefined }> =
    [
      ...Object.entries(overrides).map(([key, override]) => ({
        key,
        report: reports.find((r) => r.provider === (override.provider ?? key)),
        override,
      })),
      ...reports
        .filter((r) => !claimedProviderIds.has(r.provider))
        .map((report) => ({ key: report.provider, report, override: undefined })),
    ];

  for (const { key, report, override } of tracks) {
    if (!report) continue; // track configured for a provider that isn't authenticated/reporting right now

    const limit = override?.limitId
      ? report.limits?.find((l) => l.id === override.limitId)
      : override?.windowId
        ? report.limits?.find((l) => l.window?.id === override.windowId)
        : report.limits?.find((l) => l.window?.id === config.windowId && l.scope?.shared === true);
    const usedFraction = limit?.amount?.usedFraction;
    const resetsAt = limit?.window?.resetsAt;
    // Anthropic/Codex-style rolling windows report their own length; Cursor's
    // `monthly` limits report only `resetsAt`, so fall back to one calendar
    // month before it.
    const windowStartMs =
      resetsAt === undefined
        ? undefined
        : (limit?.window?.durationMs !== undefined ? resetsAt - limit.window.durationMs : monthBeforeMs(resetsAt));
    // Authenticated, but the matched limit doesn't exist or carries no
    // usable window (e.g. the default match found nothing because this
    // provider only exposes a 5h window) — nothing to pace.
    if (usedFraction === undefined || resetsAt === undefined || windowStartMs === undefined) continue;

    const allocationPct = override?.deriveDailyFromWindow
      ? deriveFlatDailyAllocation(windowStartMs, resetsAt, override.deriveWeekdaysOnly ?? false)
      : (override?.allocationPct ?? config.usage.allocationPct);
    const usedPct = usedFraction * 100;

    // Reset the day's usage baseline whenever the window rolls (the
    // provider's own cumulative usedFraction jumps back near 0, so a stale
    // baseline would show a false "today" spike) or a new calendar day
    // starts. cumulativeAllocationPct(now) minus that baseline is exactly
    // "today's base allocation +/- whatever rolled forward": an under-pace
    // day leaves usedPct behind the cumulative target, which shows up as
    // extra headroom today; an over-pace day does the opposite.
    const entry = state[key] ?? {};
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
          `${key}: ${todaysUsedPct.toFixed(0)}% used today, ` +
            `${todaysAllocatedPct.toFixed(0)}% allocated (incl. carryover)`,
          "warning",
        );
        entry.warnedDayStartMs = todayStartMs;
      }
    } else {
      delete entry.warnedDayStartMs;
    }
    state[key] = entry;

    const color = statusColor(100 - usedPct, overPace);
    segments.push({
      label: key,
      text: `${key} ${colorize(ANSI.dim, `(${usedPct.toFixed(0)}%)`)} ${colorize(color, `${todaysUsedPct.toFixed(0)}/${todaysAllocatedPct.toFixed(0)}%`)}`,
    });
  }

  if (config.cost) {
    const { dailyCapUsd, providers: overrides = {}, reportSources = {} } = config.cost;
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
    // pooled default and each override just read different keys/sums out
    // of it rather than each re-scanning independently. `reportSources`
    // (e.g. Cursor's API-overage sub-limit) adds today's $ delta on top —
    // its config key is never a real provider id, so it can't collide with
    // `quotaProviderIds`/`overrideIds` and always pools in — but it can
    // only ever contribute *today's* number, never the carryover math
    // below, which needs an arbitrary-range query a live report snapshot
    // can't answer (see `reportSourceSpendToday`).
    const todaysTotals = sumCostByProviderInRange(todayStartMs, now + 1);
    const todaysReportSpend = reportSourceSpendToday(reports, reportSources, state, now, todayStartMs);
    const reportSpendTotal = Object.values(todaysReportSpend).reduce((sum, v) => sum + v, 0);

    evaluateCostBucket(
      "cost:combined",
      "API",
      dailyCapUsd,
      poolSpend(todaysTotals) + reportSpendTotal,
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
    // nothing to pace, so show an empty widget rather than an empty bar.
    ui.setWidget("daily-budget", [], { placement: "aboveEditor" });
    return;
  }
  // Alphabetical by provider label reads faster than insertion order (usage
  // tracks first, then cost buckets) once there are several — except the
  // pooled "API" cost bucket, which stays last since it summarizes every
  // other pay-per-token provider rather than naming one of its own.
  const ordered = [...segments].sort((a, b) => {
    if (a.label === "API") return 1;
    if (b.label === "API") return -1;
    return a.label.localeCompare(b.label);
  });
  const line = ordered.map((s) => s.text).join(` ${colorize(ANSI.dim, "/")} `);
  ui.setWidget("daily-budget", [rightAlign(line)], { placement: "aboveEditor" });
}

export default function dailyBudgetExtension(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx: ExtensionContext) => {
    const config = loadConfig();
    if (!config) return;

    // `idleTimer` is a self-rescheduling `setTimeout`, not `setInterval`: every
    // refresh — whether triggered by `turn_end` or by the idle timer itself —
    // clears and re-arms it, so the fallback interval always measures time
    // since the *last* refresh rather than firing on a fixed wall-clock grid
    // that could double up right after a turn-triggered check. Primed with an
    // immediately-cleared timer (rather than a `ReturnType<typeof ...>`
    // annotation) so `idleTimer`'s type is inferred from `ctx.setTimeout`
    // itself.
    let idleTimer = ctx.setTimeout(() => {}, 0);
    ctx.clearTimer(idleTimer);
    const refresh = () => {
      checkBudgets(config, ctx.ui);
      ctx.clearTimer(idleTimer);
      idleTimer = ctx.setTimeout(refresh, config.checkIntervalMs);
    };

    refresh();
    pi.on("turn_end", () => refresh());
    pi.on("session_shutdown", () => {
      if (idleTimer) ctx.clearTimer(idleTimer);
    });
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
