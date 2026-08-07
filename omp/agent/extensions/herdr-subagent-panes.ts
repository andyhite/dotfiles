/**
 * Herdr subagent pane extension for omp.
 *
 * Every time omp spawns a subagent (the `task` tool, or any other caller of
 * the internal task-runner), it emits a `task:subagent:lifecycle` event on
 * the extension host's shared event bus with `status: "started"` and the
 * absolute path to that subagent's live session JSONL. This extension reacts
 * by asking Herdr to open a read-only viewer pane next to this omp pane, so
 * a subagent's progress is visible the instant it starts instead of only
 * after it reports back through the `task` tool result.
 *
 * `task:subagent:lifecycle` is not part of the documented, stable extension
 * hook surface the way `session_start` or `tool_call` are (see `pi.on()` in
 * atuin.ts) — it was found by listening on `pi.events`, the raw bus every
 * `ExtensionAPI` exposes for cross-extension wiring. That bus can go away or
 * rename its channels in a future omp release without notice, so every touch
 * of it here is defensively optional-chained, and every payload that comes
 * off it is treated as `unknown` and narrowed with a real type guard rather
 * than cast. `pi.logger` gets the same defensive treatment for the same
 * reason: a log call is not something this extension is allowed to die on.
 *
 * The viewer pane is a *separate, already-running process* by the time a
 * subagent finishes, so we can't hand it a finished status through argv or
 * env — those are fixed at spawn time. Sending it over would need a socket
 * or some other IPC channel this extension has no business owning. Instead
 * we write a small per-agent JSON file to a state directory (contract with
 * the `omp.subagents` Herdr plugin) and let the viewer watch it; the file is
 * written *before* the pane is opened so the viewer's first read never races
 * a file that doesn't exist yet, and every rewrite goes through a temp file
 * + rename so a reader can never observe a half-written JSON body.
 *
 * Concurrently-open panes are capped (`OMP_SUBAGENT_PANES_MAX`, default 4)
 * because Herdr screen space is finite and a wide `task` fan-out can spawn
 * dozens of subagents in one turn. Hitting the cap skips the pane and logs
 * it rather than queuing — a queue would need its own timeout/cleanup logic
 * to avoid popping a pane open for a subagent that already finished minutes
 * ago, which is exactly the kind of stale-state bug this extension exists to
 * avoid causing elsewhere. The operator can raise the cap or close panes
 * manually if they want more open at once.
 *
 * Panes close themselves once their subagent settles
 * (`OMP_SUBAGENT_PANES_AUTOCLOSE=1`, the default) — but never while the
 * operator is focused on them. A fan-out of subagents otherwise leaves a
 * column of dead panes behind that has to be cleared by hand, and the whole
 * point of the column is watching work in flight. The focus exception is what
 * makes that safe: a pane you are actually reading when its subagent finishes
 * is left alone, then closed once focus moves elsewhere, so a settled pane is
 * never yanked out from under you mid-read. Set `AUTOCLOSE=0` to keep every
 * pane until it is closed by hand. `--no-focus` is
 * passed unconditionally (not exposed as config) because a subagent can spawn
 * many times per turn — stealing the operator's focus on every one of them
 * would make Herdr unusable while a `task` fan-out is running.
 *
 * Panes are opened into a single column rather than each one splitting the
 * omp pane directly. The first pane of a session (or the first one after
 * that column has fully emptied out — see `anchorPaneId` below) splits
 * *this* omp pane sideways, in `OMP_SUBAGENT_PANES_COLUMN`'s direction
 * (default `right`), which is the only split that changes the omp pane's
 * own width. Every pane after that targets the most recently opened
 * subagent pane and splits *it* in `OMP_SUBAGENT_PANES_DIRECTION`'s
 * direction (default `down`), so a wide `task` fan-out grows a column of
 * stacked panes instead of shrinking the omp pane on every subagent.
 *
 * Each pane is renamed with `herdr pane rename` right after it opens, and
 * again with a check or cross appended once its subagent settles, so the
 * Herdr sidebar shows the subagent's own name instead of the manifest's
 * static "Subagent" title on every pane alike. `herdr pane rename` writes
 * the pane's `label` — the field Herdr actually displays — where `herdr
 * pane report-metadata --title` writes a different `title` field that
 * isn't shown anywhere the operator looks (confirmed against a live
 * plugin pane).
 *
 * Extensions run in-process with no sandboxing: an unhandled throw or
 * rejection inside an event handler is not caught by omp's own dispatch
 * machinery and can take the whole session down. Every path through the
 * lifecycle handler below — filesystem writes and `herdr` invocations alike
 * — is therefore wrapped in an awaited try/catch, matching the "never let
 * bookkeeping break the real work" posture atuin.ts uses for its own
 * best-effort shell-outs.
 */

import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

import { accessSync, constants as fsConstants } from "node:fs";
import { mkdir, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { delimiter, join } from "node:path";

const HERDR_PLUGIN_ID = "omp.subagents";
const HERDR_PANE_ENTRYPOINT = "viewer";
const HERDR_EXEC_TIMEOUT_MS = 10_000;
const DEFAULT_PANES_MAX = 4;
const DEFAULT_PLACEMENT = "split";
const DEFAULT_DIRECTION = "down";
const DEFAULT_COLUMN = "right";

// The lifecycle payload crosses an untyped bus (see the header comment), so
// it is narrowed through this guard rather than cast. `status` is kept as
// `string`, not a `"started" | "completed" | ...` union: only "started" is
// contractually stable, and hardcoding the terminal set risks silently
// dropping a future status value (an "error" distinct from "failed", say)
// that this extension should still treat as terminal.
interface SubagentLifecycleEvent {
  id: string;
  agent: string;
  description: string;
  status: string;
  sessionFile: string;
  parentToolCallId?: string;
  detached?: boolean;
  agentSource?: string;
  index?: number;
}

function isSubagentLifecycleEvent(value: unknown): value is SubagentLifecycleEvent {
  if (typeof value !== "object" || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    typeof v.id === "string" &&
    typeof v.agent === "string" &&
    typeof v.description === "string" &&
    typeof v.status === "string" &&
    typeof v.sessionFile === "string"
  );
}

// Mirrors the per-agent status JSON contract shared with the `omp.subagents`
// Herdr plugin's viewer pane. `status` is left as `string` for the same
// reason as `SubagentLifecycleEvent.status` above — it is written verbatim
// from the lifecycle event.
interface AgentPaneStatus {
  id: string;
  agent: string;
  description: string;
  status: string;
  sessionFile: string;
  paneId?: string;
  startedAt: number;
  endedAt?: number;
}

// Bookkeeping kept in memory for panes this session opened. `paneId` starts
// `null` because the status file has to exist (for the viewer to watch)
// before `herdr plugin pane open` has even run, let alone returned an id.
interface OpenPane {
  paneId: string | null;
  statusFile: string;
  startedAt: number;
  // Carried so `session_shutdown` can write a complete terminal status for a
  // subagent that never settled. The lifecycle event that supplied them is
  // long gone by then, and a status file missing its identity fields would
  // leave the viewer rendering a settled pane it can no longer label.
  agent: string;
  description: string;
  sessionFile: string;
}

// `command -v herdr` would work too, but shells out for something this file
// can check itself with a handful of `accessSync` calls — cheaper, and it
// runs once at extension load rather than needing its own `pi.exec` guard.
function isExecutableOnPath(bin: string): boolean {
  const pathEnv = process.env.PATH;
  if (!pathEnv) return false;
  for (const dir of pathEnv.split(delimiter)) {
    if (!dir) continue;
    try {
      accessSync(join(dir, bin), fsConstants.X_OK);
      return true;
    } catch {
      // Not in this directory — keep scanning the rest of PATH.
    }
  }
  return false;
}

// Agent ids come off the same untrusted bus as everything else. They are
// short CamelCase names in every observed payload, but nothing stops a
// future agent type — or a hostile MCP-provided one — from using a slash.
// Replacing anything outside a safe charset (inlined at its one call site
// below) keeps every status file inside stateDir no matter what the bus
// hands us.

// Write-temp-then-rename: `rename` is atomic on the same filesystem, so the
// viewer's file watcher can never observe a partially-written JSON body,
// whether it reads at the exact moment of the initial write or a later
// rewrite when the subagent settles.
async function writeStatusFileAtomically(filePath: string, status: AgentPaneStatus): Promise<void> {
  const tmpPath = `${filePath}.${process.pid}.${Math.random().toString(36).slice(2)}.tmp`;
  await writeFile(tmpPath, JSON.stringify(status), "utf8");
  await rename(tmpPath, filePath);
}

function safeJsonParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

// `herdr plugin pane open`'s success envelope, confirmed empirically:
//   {"id":"cli:plugin","result":{"plugin_pane":{"pane":{"pane_id":"w8:pZ",...},...},"type":"plugin_pane_opened"}}
// Navigated defensively rather than cast, since that shape isn't a published
// contract either — just what the installed Herdr build returns today.
function extractPaneId(value: unknown): string | null {
  if (typeof value !== "object" || value === null) return null;
  const result = (value as Record<string, unknown>).result;
  if (typeof result !== "object" || result === null) return null;
  const pluginPane = (result as Record<string, unknown>).plugin_pane;
  if (typeof pluginPane !== "object" || pluginPane === null) return null;
  const pane = (pluginPane as Record<string, unknown>).pane;
  if (typeof pane !== "object" || pane === null) return null;
  const paneId = (pane as Record<string, unknown>).pane_id;
  return typeof paneId === "string" ? paneId : null;
}

export default function herdrSubagentPanesExtension(pi: ExtensionAPI): void {
  // Three independent ways for this extension to be inert, each silent on
  // failure: a session running outside Herdr, or one that opted out, or one
  // where `herdr` isn't actually reachable, must behave exactly as if this
  // file didn't exist. Checked once here rather than per-event since none of
  // PATH, HERDR_ENV or the opt-out env var change over a session's lifetime,
  // and it means zero listener overhead for the common case of no Herdr.
  if (process.env.HERDR_ENV !== "1") return;
  if (process.env.OMP_SUBAGENT_PANES === "0") return;
  if (!isExecutableOnPath("herdr")) return;

  const panesMax = (() => {
    const raw = Number(process.env.OMP_SUBAGENT_PANES_MAX);
    return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : DEFAULT_PANES_MAX;
  })();
  const placement = process.env.OMP_SUBAGENT_PANES_PLACEMENT || DEFAULT_PLACEMENT;
  // `column` is the direction of the *one* split off the parent omp pane
  // that creates the column; `direction` is how every pane after that
  // stacks within it. Separate knobs because they answer different
  // questions — which side of the omp pane the column lives on, versus how
  // panes pile up inside it — and the (right, down) defaults reproduce the
  // layout described in the header comment with no operator config at all.
  const column = process.env.OMP_SUBAGENT_PANES_COLUMN || DEFAULT_COLUMN;
  const direction = process.env.OMP_SUBAGENT_PANES_DIRECTION || DEFAULT_DIRECTION;
  // Opt *out* rather than in: only an explicit "0" keeps settled panes around
  // (an unset variable means the default, which is now to close them). Tested
  // against the literal string so a stray "false" or "no" doesn't silently
  // read as enabled the way a truthiness check would.
  const autoclose = process.env.OMP_SUBAGENT_PANES_AUTOCLOSE !== "0";
  const stateDir = join(
    process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"),
    "omp-subagent-panes",
  );

  // Agent id -> bookkeeping for panes this session currently owns. Its size
  // *is* the cap counter, so every exit path below either deletes an entry
  // or never added one — there is no separate counter to drift out of sync.
  const openPanes = new Map<string, OpenPane>();

  // The pane id of the most recently opened subagent pane still believed to
  // be open, or `null` when the column doesn't exist yet — start of
  // session, or every pane that was in it has since closed (autoclose
  // closing the last one, or the retry fallback in `openPaneFor` discovering
  // the operator closed it by hand). The next pane to open targets this one
  // and stacks below it in `direction`; `null` means the next pane instead
  // splits the parent omp pane in `column` and starts a fresh column. Kept
  // separate from `openPanes` on purpose: a pane can outlive its subagent's
  // entry there (autoclose off is the default), so which pane is "last in
  // the column" cannot be derived from map contents alone.
  let anchorPaneId: string | null = null;

  // Pane opens are serialized through this promise chain rather than each
  // running as soon as its lifecycle event fires. A `tasks[]` batch spawns
  // every subagent at once, so the bus delivers several "started" events in
  // the same tick — and `anchorPaneId` is only assigned after `herdr plugin
  // pane open` returns a pane id. Run them concurrently and every event in
  // the batch reads `anchorPaneId` while it is still `null`, so all of them
  // take the "start a fresh column" branch and split the parent side by side
  // instead of stacking. Observed exactly that with a two-subagent batch:
  // both panes landed in a row to the right of the omp pane, the second
  // beside the first rather than under it. Chaining keeps the reads and
  // writes ordered without a lock, and a rejected link can't break the chain
  // because the handler below already swallows its own errors.
  let paneOpenQueue: Promise<void> = Promise.resolve();

  async function openPaneFor(evt: SubagentLifecycleEvent): Promise<void> {
    // Dedupe: a repeat "started" for an id already open is a no-op, not a
    // second pane. Nothing observed emits this today, but nothing about the
    // bus contract rules it out either.
    if (openPanes.has(evt.id)) return;

    if (openPanes.size >= panesMax) {
      pi.logger?.warn?.(
        `herdr-subagent-panes: at cap (${panesMax} panes open), skipping pane for subagent "${evt.id}"`,
      );
      return;
    }

    // Reserved synchronously, before the first `await`, so a burst of
    // "started" events processed back-to-back can't all pass the cap check
    // above before any of them finishes opening its pane.
    const statusFile = join(stateDir, `${evt.id.replace(/[^A-Za-z0-9_.-]/g, "_")}.json`);
    const startedAt = Date.now();
    openPanes.set(evt.id, {
      paneId: null,
      statusFile,
      startedAt,
      agent: evt.agent,
      description: evt.description,
      sessionFile: evt.sessionFile,
    });

    const baseStatus: AgentPaneStatus = {
      id: evt.id,
      agent: evt.agent,
      description: evt.description,
      status: "started",
      sessionFile: evt.sessionFile,
      startedAt,
    };

    try {
      // The status file must exist before the pane opens, or the viewer's
      // very first read races a file that isn't there yet.
      await mkdir(stateDir, { recursive: true });
      await writeStatusFileAtomically(statusFile, baseStatus);
    } catch (err) {
      // A missing status file only makes the viewer wait longer for its
      // first successful read (it already has to tolerate that); not worth
      // abandoning the pane over.
      pi.logger?.warn?.(`herdr-subagent-panes: failed to write status file for "${evt.id}"`, {
        error: String(err),
      });
    }

    // Column-then-stack: the first pane in a fresh column (`anchorPaneId`
    // still `null`) splits the parent omp pane sideways in `column`; every
    // pane after that targets the column's own most recent pane and splits
    // *it* in `direction`, so the stack grows without the omp pane ever
    // getting narrower. `usingAnchor` records which case this attempt is,
    // since the retry below needs to know whether a fallback already ran.
    const usingAnchor = anchorPaneId !== null;
    let targetPaneId: string | undefined = anchorPaneId ?? process.env.HERDR_PANE_ID;
    let splitDirection = usingAnchor ? direction : column;

    function buildOpenArgs(): string[] {
      return [
        "plugin",
        "pane",
        "open",
        "--plugin",
        HERDR_PLUGIN_ID,
        "--entrypoint",
        HERDR_PANE_ENTRYPOINT,
        "--placement",
        placement,
        "--direction",
        splitDirection,
        // Guarded read, not the bare `$HERDR_PANE_ID` shell substitution the
        // spec text shows — `pi.exec` never goes through a shell, and the
        // guards above only checked HERDR_ENV, not that Herdr populated
        // every env var it promises to. `targetPaneId` folds in the anchor
        // case, so this guard also covers "no anchor and no env var either".
        ...(targetPaneId ? ["--target-pane", targetPaneId] : []),
        "--no-focus",
        // Deliberately no `--cwd`: the manifest's pane command is the *relative*
        // path `src/viewer.ts`, which Herdr resolves against the pane's working
        // directory. Passing the omp session's cwd here made `bun run
        // src/viewer.ts` resolve to a file that does not exist there, so the
        // pane process died the instant it opened and Herdr tore the pane down
        // (observed: `pane open` returns a pane_id, and a `pane read` a moment
        // later fails `pane_not_found`). Omitting the flag lets Herdr default
        // the pane to the plugin root, which is the only directory that relative
        // command resolves in. The viewer needs nothing from the session cwd —
        // every path it reads arrives absolute in the OMP_SUBAGENT_* env below.
        "--env",
        `OMP_SUBAGENT_ID=${evt.id}`,
        "--env",
        `OMP_SUBAGENT_FILE=${evt.sessionFile}`,
        "--env",
        `OMP_SUBAGENT_TYPE=${evt.agent}`,
        "--env",
        `OMP_SUBAGENT_DESC=${evt.description}`,
        "--env",
        `OMP_SUBAGENT_STATE=${statusFile}`,
        // Forwarded rather than re-read from the environment by the viewer:
        // the pane process is a child of the Herdr server, not of omp, so it
        // never inherits the operator's `OMP_SUBAGENT_PANES_AUTOCLOSE`. Sent
        // as the already-resolved boolean so both halves cannot disagree about
        // what the default is.
        "--env",
        `OMP_SUBAGENT_AUTOCLOSE=${autoclose ? "1" : "0"}`,
      ];
    }

    try {
      let result = await pi.exec("herdr", buildOpenArgs(), { timeout: HERDR_EXEC_TIMEOUT_MS });

      // A tracked anchor pane can vanish with no warning to this extension —
      // the operator is free to close any pane by hand. When that happens
      // `--target-pane <anchor>` fails (nonzero exit), and giving up there
      // would silently drop this subagent's pane entirely: the column is
      // gone, not panes in general. Clear the stale anchor and retry exactly
      // once against the parent pane, starting a fresh column — a second
      // failure means something else is wrong (herdr itself unreachable,
      // say) and belongs in the warning below, not another silent retry.
      if (result.code !== 0 && usingAnchor) {
        anchorPaneId = null;
        targetPaneId = process.env.HERDR_PANE_ID;
        splitDirection = column;
        result = await pi.exec("herdr", buildOpenArgs(), { timeout: HERDR_EXEC_TIMEOUT_MS });
      }

      if (result.code !== 0) {
        pi.logger?.warn?.(
          `herdr-subagent-panes: "herdr plugin pane open" exited ${result.code} for "${evt.id}"`,
          { stderr: result.stderr },
        );
        openPanes.delete(evt.id);
        return;
      }

      const paneId = extractPaneId(safeJsonParse(result.stdout));
      if (!paneId) {
        // The pane may well have opened anyway — herdr exited 0 — but
        // without an id there's nothing to close later, record, or target
        // the next pane against. Leave the reservation in place (it still
        // occupies a real pane) with `paneId` null so autoclose and
        // shutdown cleanup simply skip it, and leave `anchorPaneId`
        // untouched so the next subagent falls back to whatever it already
        // was rather than targeting a pane nobody can identify.
        pi.logger?.warn?.(
          `herdr-subagent-panes: could not read a pane id from "herdr plugin pane open" for "${evt.id}"`,
        );
        return;
      }

      const record = openPanes.get(evt.id);
      if (record) record.paneId = paneId;
      anchorPaneId = paneId;

      // The manifest gives every pane the same static title, "Subagent"
      // (see herdr-plugin.toml) — this is what actually distinguishes one
      // subagent's pane from another in the sidebar. `herdr pane rename`
      // writes the pane's `label`, the field Herdr displays to the
      // operator; `herdr pane report-metadata --title` writes a different
      // `title` field that isn't shown anywhere (confirmed empirically
      // against a live plugin pane), so `rename` is the only call that
      // actually changes what the operator sees.
      try {
        await pi.exec("herdr", ["pane", "rename", paneId, evt.id], {
          timeout: HERDR_EXEC_TIMEOUT_MS,
        });
      } catch (err) {
        pi.logger?.warn?.(`herdr-subagent-panes: failed to rename pane for "${evt.id}"`, {
          error: String(err),
        });
      }

      try {
        await writeStatusFileAtomically(statusFile, { ...baseStatus, paneId });
      } catch (err) {
        pi.logger?.warn?.(`herdr-subagent-panes: failed to record pane id for "${evt.id}"`, {
          error: String(err),
        });
      }
    } catch (err) {
      // herdr disappearing mid-session, a killed CLI process, etc. Free the
      // slot so one subagent that never actually got a pane can't starve
      // every subagent spawned after it.
      pi.logger?.warn?.(`herdr-subagent-panes: failed to open a pane for "${evt.id}"`, {
        error: String(err),
      });
      openPanes.delete(evt.id);
    }
  }

  async function settlePaneFor(evt: SubagentLifecycleEvent): Promise<void> {
    const record = openPanes.get(evt.id);
    // Never opened — skipped at the cap, or the open itself failed — so
    // there is no status file or pane to reconcile.
    if (!record) return;
    // Free the slot up front: everything past this point is best-effort
    // logging/cleanup, and the cap counter must not stay wrong if any of it
    // throws.
    openPanes.delete(evt.id);

    const finalStatus: AgentPaneStatus = {
      id: evt.id,
      agent: evt.agent,
      description: evt.description,
      status: evt.status,
      sessionFile: evt.sessionFile,
      paneId: record.paneId ?? undefined,
      startedAt: record.startedAt,
      endedAt: Date.now(),
    };

    try {
      await writeStatusFileAtomically(record.statusFile, finalStatus);
    } catch (err) {
      pi.logger?.warn?.(`herdr-subagent-panes: failed to write terminal status for "${evt.id}"`, {
        error: String(err),
      });
    }

    // Relabel the pane to show it settled — a check for a clean "completed",
    // a cross for anything else terminal ("failed", "aborted", or an
    // unrecognized future status; see the header comment on `status` for why
    // that set is deliberately not enumerated). Done unconditionally now that
    // autoclose is the default: a pane the operator is focused on outlives its
    // subagent for as long as they keep looking at it, so it needs the settled
    // mark. For a pane that closes immediately this is one wasted round trip,
    // which is cheaper than deciding the label after the close race.
    if (record.paneId) {
      const outcomeMark = evt.status === "completed" ? "\u2713" : "\u2717";
      try {
        await pi.exec("herdr", ["pane", "rename", record.paneId, `${evt.id} ${outcomeMark}`], {
          timeout: HERDR_EXEC_TIMEOUT_MS,
        });
      } catch (err) {
        pi.logger?.warn?.(`herdr-subagent-panes: failed to relabel pane for "${evt.id}"`, {
          error: String(err),
        });
      }
    }

    // Closing a settled pane is the *viewer's* job, not this extension's, so
    // there is nothing left to do here.
    //
    // The obvious implementation — poll `herdr pane get` for `focused` here and
    // shell out to `herdr plugin pane close` once it clears — was written,
    // tested, and removed. It cannot work: this extension's lifetime is the omp
    // process's, and a settled-while-focused pane routinely outlives it. A
    // headless `omp -p` run reached its final answer and exited while the wait
    // was still pending, and the pane was still sitting there long after focus
    // moved away, with nothing left alive to close it. The pane's own process
    // is the only thing whose lifetime matches the pane, and Herdr reaps a
    // plugin pane as soon as its command exits (verified by sending `q` to a
    // viewer and watching `pane get` report the pane gone), so the viewer
    // closes itself by exiting. `OMP_SUBAGENT_AUTOCLOSE` is forwarded into the
    // pane's env for exactly that.
    //
    // What does still belong here is the anchor: the pane is about to go away
    // on its own, so a subagent spawning next should start a fresh column
    // rather than target a pane that is mid-exit. Getting this wrong is not
    // fatal either way — `openPaneFor`'s retry already recovers from a dead
    // target-pane — but clearing it saves that round trip in the common case.
    if (autoclose && anchorPaneId === record.paneId) anchorPaneId = null;
  }

  // Subscribing here — synchronously, in the factory body — rather than
  // inside a `pi.on("session_start", ...)` callback: the factory itself only
  // runs once, at session start, so nesting behind that hook would just add
  // a round trip for nothing this extension needs to wait for.
  //
  // The whole handler is one awaited try/catch: `pi.events` almost certainly
  // fires listeners without awaiting them (it's a bus, not a hook chain), so
  // a rejection escaping this function becomes an unhandled promise
  // rejection at the process level — see the header comment on why that is
  // fatal here in a way it wouldn't be for a normal caught exception.
  pi.events?.on?.("task:subagent:lifecycle", async (raw: unknown) => {
    try {
      if (!isSubagentLifecycleEvent(raw)) return;
      if (raw.status === "started") {
        // Queue rather than await directly, so a batch's simultaneous
        // "started" events open their panes one after another and each one
        // sees the previous pane's id as the anchor. Awaiting the chain keeps
        // this handler's own error boundary around the work.
        paneOpenQueue = paneOpenQueue.then(() => openPaneFor(raw));
        await paneOpenQueue;
      } else {
        // Settles are not queued: they only touch this agent's own record and
        // the anchor it may still hold, never the shared "where does the next
        // pane go" decision that made ordering matter above.
        await settlePaneFor(raw);
      }
    } catch (err) {
      pi.logger?.warn?.("herdr-subagent-panes: unhandled error in lifecycle handler", {
        error: String(err),
      });
    }
  });

  // `session_shutdown` *is* a documented stable hook (see atuin.ts's own use
  // of it for the same "don't leak state past the session" reason), so it
  // goes through `pi.on()` rather than the raw bus.
  //
  // Anything still in `openPanes` here is a subagent that never settled: omp
  // is going away and will take its in-process children with it. This does NOT
  // close their panes. It writes each one a terminal status instead, and lets
  // the viewer do exactly what it does for a normal settle — render the
  // outcome, then close itself once the operator isn't focused on it.
  //
  // Closing them here directly was the first implementation and it was wrong
  // in two ways. It ignored the focus exception, so quitting omp yanked a pane
  // mid-read; and it fired on the far more common headless case, where the
  // model answers without waiting for a background subagent and omp exits
  // seconds after the pane opened — the pane vanished while its agent was
  // still listed as running, which looks exactly like a crash. Marking the
  // status is honest about what happened, keeps a single close mechanism in
  // one place, and costs one small file write per pane instead of a
  // subprocess.
  pi.on("session_shutdown", async (_event, _ctx: ExtensionContext) => {
    const panes = [...openPanes.entries()];
    openPanes.clear();

    for (const [id, record] of panes) {
      // No pane ever opened for this reservation, so no viewer is watching the
      // status file and nothing will read what we write.
      if (!record.paneId) continue;
      try {
        await writeStatusFileAtomically(record.statusFile, {
          id,
          agent: record.agent,
          description: record.description,
          // "aborted" rather than "failed": the subagent didn't fail, it was
          // cut short by the session ending. This is the same wording the
          // lifecycle bus uses when a run is torn down.
          status: "aborted",
          sessionFile: record.sessionFile,
          paneId: record.paneId,
          startedAt: record.startedAt,
          endedAt: Date.now(),
        });
      } catch (err) {
        pi.logger?.warn?.(
          `herdr-subagent-panes: failed to mark "${id}" aborted at shutdown`,
          { error: String(err) },
        );
      }
    }
  });
}
