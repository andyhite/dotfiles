#!/usr/bin/env bun
/**
 * Live viewer for one omp subagent, run as a herdr pane entrypoint.
 *
 * This is omp's own transcript renderer, not a lookalike of it. It imports
 * `AgentTranscriptViewer` straight out of the installed @oh-my-pi/pi-coding-agent
 * package — the same component the interactive omp Agent Hub mounts to show a
 * parked subagent / advisor transcript (modes/components/agent-transcript-viewer.ts,
 * mounted by modes/components/agent-hub.ts's `openChat()`) — and drives it inside a
 * real @oh-my-pi/pi-tui `TUI`. A pane running this file looks exactly like omp
 * because it *is* omp, not a hand-tuned palette copy. See `../package.json` for the
 * version pin (kept in lockstep with the installed `omp` binary by
 * `../scripts/install.sh`, run from this plugin's `[[build]]` step — see
 * `../herdr-plugin.toml`) and `../src/viewer-fallback.ts` for the ANSI-art renderer
 * this file defers to on any failure.
 *
 * Read-only is structural, not policed by this file. `AgentTranscriptViewerDeps`
 * (agent-transcript-viewer.ts:35-58) takes optional `remote` (collab-guest chat) and
 * `lifecycle` (revive/steer a local agent) deps; its private `#sendable` getter
 * (agent-transcript-viewer.ts:186-190) is `Boolean(deps.remote || deps.lifecycle)` —
 * with neither wired below, the component itself never constructs its message editor
 * and every send/revive code path inside it is dead. There is nothing here to bypass
 * because there is no code path capable of sending anything.
 *
 * Failure handling — "resolve env, try the native viewer, hand off to the fallback
 * renderer on any failure" — has one honest gap worth naming up front: every import
 * below is `import`, not `await import()` (author-time-known specifiers use static
 * imports, full stop — no exception for this file). Bun resolves static imports
 * before a single line of this module's own code runs, so if this plugin's
 * `node_modules` is entirely absent (the `[[build]]` step never ran, or ran against
 * the wrong platform), `bun run src/viewer.ts` fails at module load, before the
 * try/catch below ever gets a chance to run — there is no way to catch a failed
 * static import without making it dynamic. That gap is exactly what the
 * `[[build]]` step exists to prevent, not something this file can paper over.
 * What this file *does* catch — synchronously during setup, or later via the
 * `uncaughtException`/`unhandledRejection` handlers below, which cover the
 * component's own internal 250ms poll timer (agent-transcript-viewer.ts `POLL_MS`)
 * running detached from any promise this file awaits — is the realistic failure
 * mode: `node_modules` present but stale (omp itself got upgraded without this
 * plugin's `[[build]]` step re-running), so the installed package's session-JSONL
 * parser chokes on a shape a newer omp actually writes. Imports resolve fine;
 * construction or a later poll tick throws instead.
 *
 * `Settings.init()` is a discovered requirement, not an obvious one: constructing
 * `AgentTranscriptViewer` throws synchronously — "Settings not initialized. Call
 * Settings.init() first." out of chat-transcript-builder.ts's `#appendAssistantMessage`
 * — unless the module-global `settings` singleton (config/settings.ts) has been
 * populated first. `{ inMemory: true }` is the lightest init path available: per
 * `Settings#load()`, `inMemory` forces `#persist` false, which skips opening
 * `agent.db`, legacy-config migration, and marker-file writes entirely (all gated
 * behind `#persist`) and just resolves project settings + defaults — enough for the
 * handful of display flags `ChatTranscriptBuilder` reads (`terminal.showImages`,
 * `display.hideToolActivity`, ...), with no risk of this throwaway process
 * contending with the real omp process's already-open `agent.db`. `theme` (the
 * module-global powering every `theme.fg`/`theme.bold` call inside the component,
 * config/theme/theme.ts) has the same shape: a bare `let`, undefined until
 * `initTheme()` resolves, with no undefined-guard in the component's own render path.
 * Both are awaited before `AgentTranscriptViewer` is ever constructed.
 *
 * Width and resize: this file never computes or passes a width or height anywhere.
 * `AgentTranscriptViewer.render(width)` (agent-transcript-viewer.ts:548) already owns
 * that math (`contentWidth = width - 1` for its own ScrollView's scrollbar column,
 * `termHeight = process.stdout.rows`), and `ProcessTerminal.columns`/`.rows`
 * (pi-tui terminal.ts) already read `process.stdout.columns`/`.rows` live on every
 * frame — `TUI`'s own compose loop feeds the child that exact number every render,
 * with zero gutter added on either side. Mounting the component as a plain
 * `ui.addChild(viewer)` root child (not wrapped in any manual indent or box of this
 * file's own) is what keeps that arithmetic honest: verified live at a real 91-column
 * herdr pane width and again at 60 columns (see the plugin README's acceptance
 * notes) — every content row lands at exactly the pane width, nothing wraps, and
 * `ProcessTerminal`'s own `process.stdout.on("resize", ...)` listener means a herdr
 * column-stack resize is picked up on the very next frame with no polling of our own.
 */

import { readFileSync, statSync } from "node:fs";
import { AgentTranscriptViewer } from "@oh-my-pi/pi-coding-agent/modes/components/agent-transcript-viewer";
import { initTheme } from "@oh-my-pi/pi-coding-agent/modes/theme/theme";
import { AgentRegistry } from "@oh-my-pi/pi-coding-agent/registry/agent-registry";
import type { AgentStatus } from "@oh-my-pi/pi-coding-agent/registry/agent-registry";
import { Settings } from "@oh-my-pi/pi-coding-agent/config/settings";
import { matchesKey, ProcessTerminal, TUI } from "@oh-my-pi/pi-tui";
import type { KeyId } from "@oh-my-pi/pi-tui";

// ---------------------------------------------------------------------------
// env contract — same names/meanings as viewer-fallback.ts; OMP_SUBAGENT_TYPE
// and OMP_SUBAGENT_DESC are read there but not here, since the native header
// (AgentTranscriptViewer's own `#headerLines`) draws its identity from the
// `AgentRegistry` ref (id, kind, status) instead of free-text env values.
// ---------------------------------------------------------------------------

const subagentId = process.env.OMP_SUBAGENT_ID ?? "subagent";
const subagentState = process.env.OMP_SUBAGENT_STATE;
// See viewer-fallback.ts for why unset defaults to "on".
const subagentAutoclose = process.env.OMP_SUBAGENT_AUTOCLOSE !== "0";

function sleep(ms: number): Promise<void> {
  const { promise, resolve } = Promise.withResolvers<void>();
  setTimeout(resolve, ms);
  return promise;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

// ---------------------------------------------------------------------------
// fallback handoff — see the header comment for exactly which failures land
// here and which ones can't (static-import resolution).
// ---------------------------------------------------------------------------

// stdout-isTTY/NO_COLOR-aware dim, independent of the `theme` module on
// purpose: this is the one line that must still print correctly even when
// `initTheme()` itself is what failed.
function dimLine(text: string): string {
  return process.stdout.isTTY && !process.env.NO_COLOR ? `\u001b[38;5;242m${text}\u001b[0m` : text;
}

let fellBack = false;

// Spawns viewer-fallback.ts with this pane's own stdio and mirrors its exit
// code. Guarded to run at most once: an uncaughtException and an
// unhandledRejection can both fire off the same underlying failure (a
// rejected promise settling asynchronously after its throw already tripped
// the exception handler), and the fallback must never be spawned twice onto
// the same terminal.
function fallBackTo(reason: string): never {
  if (fellBack) process.exit(1);
  fellBack = true;
  console.error(
    dimLine(`omp-subagents viewer: native renderer unavailable (${reason}) — using the bundled fallback`),
  );
  const result = Bun.spawnSync(["bun", "run", `${import.meta.dir}/viewer-fallback.ts`], {
    stdio: ["inherit", "inherit", "inherit"],
  });
  process.exit(result.exitCode ?? 1);
}

// Covers everything after the synchronous setup phase in `mountNative` below
// — most importantly, AgentTranscriptViewer's own internal 250ms poll timer
// (POLL_MS in agent-transcript-viewer.ts), which runs detached from any
// promise this file awaits and would otherwise crash the process with no
// chance to fall back.
process.on("uncaughtException", err => fallBackTo(err instanceof Error ? err.message : String(err)));
process.on("unhandledRejection", err => fallBackTo(err instanceof Error ? err.message : String(err)));

// ---------------------------------------------------------------------------
// autoclose — ported from viewer-fallback.ts verbatim (same herdr contract:
// read-only `herdr pane get` focus probe, every failure mode collapses to
// "not focused" so a broken probe closes rather than orphans the pane); see
// that file's comments for the full rationale. Routed through `closeAndExit`
// here instead of a bare `process.exit` so the TUI/component get torn down
// first either way.
// ---------------------------------------------------------------------------

const FOCUS_POLL_INTERVAL_MS = 2000;
const FOCUS_POLL_TIMEOUT_MS = 10 * 60 * 1000;

function isPaneFocused(paneId: string): boolean {
  let exitCode: number;
  let stdout: string;
  try {
    const probe = Bun.spawnSync([process.env.HERDR_BIN_PATH ?? "herdr", "pane", "get", paneId], {
      stdout: "pipe",
      stderr: "ignore",
    });
    exitCode = probe.exitCode;
    stdout = probe.stdout.toString("utf8");
  } catch {
    return false;
  }
  if (exitCode !== 0) return false;
  let parsed: unknown;
  try {
    parsed = JSON.parse(stdout);
  } catch {
    return false;
  }
  if (!isRecord(parsed)) return false;
  const result = parsed.result;
  if (!isRecord(result)) return false;
  const pane = result.pane;
  if (!isRecord(pane)) return false;
  return pane.focused === true;
}

async function autocloseAfterSettle(ui: TUI, closeAndExit: (code: number) => void): Promise<void> {
  const paneId = process.env.HERDR_PANE_ID;
  if (!paneId || !isPaneFocused(paneId)) {
    closeAndExit(0);
    return;
  }
  const deadline = Date.now() + FOCUS_POLL_TIMEOUT_MS;
  while (Date.now() < deadline) {
    await sleep(FOCUS_POLL_INTERVAL_MS);
    if (!isPaneFocused(paneId)) {
      closeAndExit(0);
      return;
    }
  }
  // Focused for the entire cap: leave the pane open. Esc (the component's own
  // `onClose`) and the global q/ctrl+c listener wired in `mountNative` are
  // both already live at this point, so there is nothing further to arm here
  // — unlike the fallback renderer, which has no such listener until this
  // exact moment and has to start one.
  console.log(dimLine("still focused after 10m — press q, ctrl+c, or Esc to close"));
  ui.requestRender();
}

// ---------------------------------------------------------------------------
// settle watch — maps OMP_SUBAGENT_STATE's terminal status onto the
// AgentRegistry ref so the component's own header badge (`statusBadge` in
// agent-transcript-viewer.ts) reflects reality, then runs autoclose. Falls
// back to idle-detection on the session file itself when no state file was
// given at all (a manual `bun run` against an already-finished transcript,
// this plugin's own acceptance check included) — a real pane opened by the
// extension always has OMP_SUBAGENT_STATE and settles from an actual status.
// ---------------------------------------------------------------------------

const POLL_INTERVAL_MS = 200;
const FALLBACK_IDLE_TICKS = 5;

function readTerminalStatus(path: string): string | undefined {
  let raw: string;
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    return undefined; // not written yet, or briefly absent mid atomic-rewrite
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return undefined; // caught the file mid-write; the next poll retries
  }
  if (!isRecord(parsed)) return undefined;
  const status = asString(parsed.status);
  return status && status !== "started" ? status : undefined;
}

function fileSizeOrUndefined(path: string): number | undefined {
  try {
    return statSync(path).size;
  } catch {
    return undefined; // file briefly missing mid-rotation, or not created yet
  }
}

// `completed` is the only success status the lifecycle contract writes;
// everything else (`failed`, `aborted`, and — for the no-state fallback path
// below — "unknown") reads as `aborted` on the badge. AgentStatus has no
// third, neutral option, and erring toward the visible-attention colour on
// an ambiguous outcome beats a falsely reassuring "idle".
function mapTerminalStatus(rawStatus: string): AgentStatus {
  return rawStatus === "completed" ? "idle" : "aborted";
}

async function watchForSettle(
  sessionFile: string,
  registry: AgentRegistry,
  ui: TUI,
  closeAndExit: (code: number) => void,
): Promise<void> {
  let settledStatus: string | undefined;
  let lastSize: number | undefined;
  let idleTicks = 0;

  while (settledStatus === undefined) {
    await sleep(POLL_INTERVAL_MS);
    if (subagentState) {
      settledStatus = readTerminalStatus(subagentState);
    } else {
      const size = fileSizeOrUndefined(sessionFile);
      idleTicks = size !== undefined && size === lastSize ? idleTicks + 1 : 0;
      lastSize = size;
      if (idleTicks >= FALLBACK_IDLE_TICKS) settledStatus = "unknown";
    }
  }

  registry.setStatus(subagentId, mapTerminalStatus(settledStatus));
  ui.requestRender();

  if (!subagentAutoclose) return; // stays open for manual q/ctrl+c/Esc
  await autocloseAfterSettle(ui, closeAndExit);
}

// ---------------------------------------------------------------------------
// mount
// ---------------------------------------------------------------------------

async function mountNative(sessionFile: string): Promise<void> {
  await Settings.init({ inMemory: true });
  await initTheme();

  const registry = new AgentRegistry();
  registry.register({
    id: subagentId,
    displayName: subagentId,
    kind: "sub",
    session: null,
    sessionFile,
    status: "running",
  });

  const terminal = new ProcessTerminal();
  const ui = new TUI(terminal);

  // omp's shipped defaults (config/keybindings.ts: app.tools.expand,
  // app.agents.hub, app.session.observe) — not read from the user's real omp
  // config, since this standalone process has none of omp's config plumbing
  // wired up and the component only needs *a* key list to match input
  // against, not the operator's actual customized bindings.
  const expandKeys: KeyId[] = ["ctrl+o"];
  const hubKeys: KeyId[] = ["alt+a", "ctrl+s"];

  let viewer: AgentTranscriptViewer;
  let closed = false;
  const closeAndExit = (code: number): void => {
    if (closed) return;
    closed = true;
    viewer.dispose();
    ui.stop();
    process.exit(code);
  };

  viewer = new AgentTranscriptViewer({
    agentId: subagentId,
    registry,
    ui,
    cwd: process.cwd(),
    expandKeys,
    hubKeys,
    requestRender: () => ui.requestRender(),
    onClose: () => closeAndExit(0),
    onHubClose: () => closeAndExit(0),
    // `remote` and `lifecycle` are deliberately omitted — see the header
    // comment for why that is the actual read-only enforcement.
  });

  ui.addChild(viewer);
  ui.setFocus(viewer);
  ui.addInputListener(data => {
    if (matchesKey(data, "q") || matchesKey(data, "ctrl+c")) {
      closeAndExit(0);
      return { consume: true };
    }
    return undefined;
  });
  ui.start();

  // Detached on purpose: `mountNative` resolving is "setup succeeded", not
  // "the pane is done". The pane's actual lifetime runs until `closeAndExit`
  // calls `process.exit`, driven by this loop, the component's own input
  // handling, or the global q/ctrl+c listener above.
  void watchForSettle(sessionFile, registry, ui, closeAndExit);
}

async function main(): Promise<void> {
  const sessionFile = process.env.OMP_SUBAGENT_FILE;
  if (!sessionFile) {
    console.error(
      "omp-subagents viewer: OMP_SUBAGENT_FILE is not set. This pane is meant to be " +
        "opened by the herdr-subagent-panes omp extension, which sets it to the " +
        "subagent's session JSONL path; it is not meant to be launched by hand " +
        "without that variable.",
    );
    process.exit(1);
  }
  try {
    await mountNative(sessionFile);
  } catch (err) {
    fallBackTo(err instanceof Error ? err.message : String(err));
  }
}

await main();
