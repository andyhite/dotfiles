/**
 * Atuin extension for omp.
 *
 * Records every command omp runs through its `bash` tool into the same Atuin
 * history as hand-typed commands, tagged `--author pi`:
 *
 *   atuin search --author pi           just this agent
 *   atuin search --author '$all-agent' every known agent
 *   atuin search --author '$all-user'  only me
 *
 * "pi" rather than "omp" because omp is a distribution of pi — and because the
 * name has to be one of Atuin's KNOWN_AGENTS (claude-code, codex, copilot,
 * opencode, pi) to mean anything. That list is what `$all-user` subtracts, and
 * `$all-user` is hardcoded into every interactive search, so under any other
 * name these rows count as hand-typed and pile up in ctrl-r. One gap: the
 * daemon's index has no author column at all, so a *typed* ctrl-r query still
 * surfaces them (search_mode = daemon-fuzzy). The empty list and the whole
 * up-arrow search go through sqlite, which honours the filter.
 *
 * Rows already recorded as "omp" keep that author. history.db is a projection
 * of the record store, so a sqlite UPDATE would be undone by the next
 * `atuin store rebuild history`.
 *
 * `atuin hook install` only knows claude-code, codex, opencode and pi, so this
 * file is maintained here and symlinked into place by install.sh rather than
 * generated. It is deliberately close to Atuin's own pi extension, with two
 * differences that omp's tool surface makes possible — see `exitCodeOf` and
 * the `--intent` argument below.
 */

import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

const ATUIN_AUTHOR = "pi";
const ATUIN_TIMEOUT_MS = 10_000;

// omp's bash tool reports the real exit status in `details`, so unlike the pi
// extension there is no need to scrape "Command exited with code <n>" back out
// of the result text. `timedOut` has no exit code of its own; 124 is what
// timeout(1) reports and keeps these entries greppable.
function exitCodeOf(result: unknown, isError: boolean): number {
  const details = (result as { details?: unknown } | undefined)?.details;
  if (details && typeof details === "object") {
    const { exitCode, timedOut } = details as {
      exitCode?: unknown;
      timedOut?: unknown;
    };
    if (typeof exitCode === "number") return exitCode;
    if (timedOut === true) return 124;
  }
  return isError ? 1 : 0;
}

export default function atuinOmpExtension(pi: ExtensionAPI) {
  // Atuin history ids for in-flight bash calls, keyed by tool call id.
  const pending = new Map<string, string>();

  // Observed through events rather than by registering a `bash` tool: an
  // extension-provided tool would collide with sandboxes or remote runners,
  // while events fire whichever implementation ends up executing.
  pi.on("tool_call", async (event, ctx: ExtensionContext) => {
    if (event.toolName !== "bash") return;

    const input = event.input as { command?: unknown; i?: unknown };
    if (typeof input.command !== "string" || input.command.length === 0) return;

    // Every omp bash call carries an `i` intent string. Atuin stores it, so the
    // history explains *why* a command ran, not just what ran.
    const intent = typeof input.i === "string" && input.i.length > 0 ? input.i : null;

    try {
      const started = await pi.exec(
        "atuin",
        [
          "history",
          "start",
          "--author",
          ATUIN_AUTHOR,
          ...(intent ? ["--intent", intent] : []),
          "--",
          input.command,
        ],
        { cwd: ctx.cwd, timeout: ATUIN_TIMEOUT_MS },
      );
      if (started.code !== 0) return;

      const historyId = started.stdout.trim();
      if (historyId) pending.set(event.toolCallId, historyId);
    } catch {
      // Never let history bookkeeping block a command.
    }
  });

  // tool_execution_end (not tool_result) also fires when another extension
  // blocks the call, so entries opened above are always closed out.
  pi.on("tool_execution_end", async (event, ctx: ExtensionContext) => {
    const historyId = pending.get(event.toolCallId);
    if (!historyId) return;
    pending.delete(event.toolCallId);

    try {
      await pi.exec(
        "atuin",
        [
          "history",
          "end",
          historyId,
          "--exit",
          String(exitCodeOf(event.result, event.isError)),
        ],
        { cwd: ctx.cwd, timeout: ATUIN_TIMEOUT_MS },
      );
    } catch {
      // Same: an Atuin failure must not surface as a tool failure.
    }
  });

  // A session that ends mid-command would otherwise leave rows open forever.
  pi.on("session_shutdown", async (_event, ctx: ExtensionContext) => {
    const open = [...pending.values()];
    pending.clear();
    for (const historyId of open) {
      try {
        await pi.exec("atuin", ["history", "end", historyId, "--exit", "130"], {
          cwd: ctx.cwd,
          timeout: ATUIN_TIMEOUT_MS,
        });
      } catch {
        // Best effort.
      }
    }
  });
}
