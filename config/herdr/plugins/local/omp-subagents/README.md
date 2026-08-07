# omp.subagents

A herdr plugin that gives every omp subagent its own read-only live-transcript
pane. It exposes exactly one thing — the `viewer` pane — and has no actions,
no keybindings, and no events of its own.

## What it is

`src/viewer.ts` mounts omp's own `AgentTranscriptViewer` component — imported
straight out of the installed `@oh-my-pi/pi-coding-agent` package, the same
component omp's own Agent Hub uses to show a parked subagent/advisor
transcript — inside a real `@oh-my-pi/pi-tui` `TUI`. A pane running this file
looks exactly like omp because it *is* omp's renderer, not a lookalike of it.
Width and resize are handled entirely by `TUI`/`ProcessTerminal` reading the
pane's real terminal size on every frame; this plugin does no width math of
its own (verified live at both a 91- and a 60-column pane — every row lands
exactly at the pane width, nothing wraps).

Read-only is structural, not policed here: the component takes optional
`remote`/`lifecycle` deps that gate its own message editor and revive/steer
path, and this file wires neither. There is no code path capable of sending
anything to the subagent, even by accident.

**Version coupling.** These are internal, unstable omp APIs with no semver
contract — `package.json` pins `@oh-my-pi/pi-coding-agent` and
`@oh-my-pi/pi-tui` to the *exact* version of the `omp` binary this plugin was
last built against, and `scripts/install.sh` (run by the `[[build]]` step
below) re-pins and reinstalls against whatever `omp --version` reports every
time it runs, so the two stay in lockstep instead of silently drifting apart
across an omp upgrade.

**Fallback.** `src/viewer-fallback.ts` is this plugin's original renderer —
a dependency-free, hand-rolled ANSI approximation of omp's palette, kept
verbatim. `src/viewer.ts` tries the native path first and falls back to it,
with one dim log line naming the reason, on *any* failure: a synchronous
construction error, or an `uncaughtException`/`unhandledRejection` from the
native component's own internal 250ms poll timer later on (covers the
realistic failure mode — `node_modules` present but stale after an omp
upgrade the `[[build]]` step hasn't re-run against, so the installed
package's session-JSONL parser chokes on a shape a newer omp actually
writes). One gap is structural and undocumented nowhere else: every import in
`viewer.ts` is a static `import`, which Bun resolves before any of this
file's own code runs, so a *completely absent* `node_modules` (the
`[[build]]` step never ran at all) crashes before the fallback logic gets a
chance — see "Dependencies & build" below for why that should never happen
in practice.

When the subagent settles, `viewer.ts` maps the terminal status onto the
component's own `AgentRegistry` ref (`idle` for `completed`, `aborted`
otherwise) so the header badge reflects reality, then runs the same
autoclose behaviour as always: exits once the pane is not focused, waiting
out any stretch the operator is actually looking at it, or — with autoclose
off, or once its 10-minute focused-wait cap is hit — waits for `q`, ctrl+c,
or Esc so you can scroll back before closing it by hand. Both renderers
implement this the same way (a read-only `herdr pane get` focus probe, never
anything that mutates herdr state) and only run it as a live herdr pane; a
bare `bun run` (this plugin's own acceptance check included) still exits on
its own, from an idle-detection fallback when no `OMP_SUBAGENT_STATE` was
given at all.

## How it is wired

Both renderers only render, and — per `OMP_SUBAGENT_AUTOCLOSE` — close
themselves. Deciding *when* a pane opens is still the omp extension's job:
`omp/agent/extensions/herdr-subagent-panes.ts` listens for
`task:subagent:lifecycle`, and for each subagent it spawns runs

```
herdr plugin pane open --plugin omp.subagents --entrypoint viewer \
  --env OMP_SUBAGENT_ID=... --env OMP_SUBAGENT_FILE=... \
  --env OMP_SUBAGENT_TYPE=... --env OMP_SUBAGENT_DESC=... \
  --env OMP_SUBAGENT_STATE=... --env OMP_SUBAGENT_AUTOCLOSE=...
```

`OMP_SUBAGENT_STATE` points at a small JSON file the extension keeps
rewriting (atomically) as the subagent's status changes; both renderers poll
it for the terminal status rather than trying to talk to the extension
directly (`viewer.ts` on a 200ms timer of its own, independent of the native
component's own 250ms transcript-tailing poll — see its header comment).

`OMP_SUBAGENT_AUTOCLOSE` is the already-resolved boolean (`1` or `0`, always
set explicitly) for whether *this* pane should close itself once its
subagent settles — forwarded rather than left for either renderer to read
`OMP_SUBAGENT_PANES_AUTOCLOSE` itself, since the pane process is a child of
the Herdr server, not of omp, and never inherits the operator's environment.
Closing is entirely the renderer's own job from there: it exits (status 0)
once the pane isn't focused, and that exit is what closes the pane — Herdr
reaps a plugin pane the instant its entrypoint process ends. The extension
used to run this same "wait for unfocus, then close" loop itself, but its
poll timer lives inside the omp process and can't outlive an `omp -p` run
that exits before the operator looks away, which orphaned the pane; see the
header comment in `viewer-fallback.ts` for the live repro. The read-only
`herdr pane get` used for the focus probe is the only herdr call either
renderer ever makes — neither calls `pane close` or `pane rename`.

`HERDR_PLUGIN_ENTRYPOINT_ID` (herdr-injected, not omp-injected — see the same
comment block) gates `viewer-fallback.ts`'s raw-mode keypress wait used when
autoclose is off, or once its 10-minute focused-wait cap is hit: it only
activates when herdr itself launched this as the `viewer` entrypoint, so a
plain `bun run src/viewer-fallback.ts` from a shell degrades to plain
streaming output that exits on its own. `viewer.ts`'s native path doesn't
need this gate — `ProcessTerminal`'s own raw-mode setup already no-ops
safely outside a real TTY (see pi-tui's `ProcessTerminal.start`), so it
behaves the same way without a flag of its own.

## Dependencies & build

`package.json` depends on `@oh-my-pi/pi-coding-agent` and `@oh-my-pi/pi-tui`,
committed pinned to `17.2.10`. The `[[build]]` step in `herdr-plugin.toml`
runs `scripts/install.sh`, which reads `omp --version`, rewrites both pins to
match it, and runs `bun install` — falling back to the committed pin
unchanged when `omp` isn't on PATH at all.

**`herdr plugin link` does not run `[[build]]`** — verified empirically: a
fresh `herdr plugin link` against this directory with no `node_modules`
reports `plugin_linked` (its JSON response even echoes this manifest's
`[[build]]` entry back) but leaves `node_modules` absent; the manifest is
read, the step just never executes. The repo-root `install.sh`'s local-plugin
loop compensates by running `scripts/install.sh` itself, directly, right
after linking. A bare `herdr plugin link path/to/this/dir` run by hand (not
through `install.sh`) needs `bun install` (or `scripts/install.sh`) run
afterward, same as any other fresh checkout.

**`bun build --target=bun src/viewer.ts` alone is not a meaningful
standalone-bundle check for this file**, and does not succeed: without
`--external`, Bun tries to inline the *entire* `@oh-my-pi/pi-coding-agent`
source tree, which reaches a conditional `import("omp-legacy-pi-modules")`
(a virtual module omp's own compiled-binary build supplies through a custom
bundler plugin, gated behind an `IS_COMPILED_BINARY` check that is always
false here) that Bun's bundler still tries to resolve statically regardless
of the runtime guard around it, and separately reaches enough real static
assets (generated tool-view JS, HTML/CSS templates, `CHANGELOG.md`) that even
past that it can't be piped through stdout without an `--outdir`. This file
is never bundled in production — the pane entrypoint is `bun run
src/viewer.ts`, which resolves `node_modules` normally with no bundling — so
the correct sanity check for "this file's own syntax and import specifiers
are sound" externalizes both SDK packages instead:

```
bun build --target=bun \
  --external '@oh-my-pi/pi-coding-agent' --external '@oh-my-pi/pi-coding-agent/*' \
  --external '@oh-my-pi/pi-tui' --external '@oh-my-pi/pi-tui/*' \
  src/viewer.ts >/dev/null
```

`bunx tsc --noEmit --strict` (with `@types/bun` installed, `bun`'s own
devDependency) is a stricter and equally fast type-soundness check, and
passes clean against both `src/viewer.ts` and `src/viewer-fallback.ts`.

## Config knobs

None live in this plugin. The user-facing switches are read by the extension
that opens these panes, not by the pane itself:

| Env var (read by the extension) | Default | Effect |
| --- | --- | --- |
| `OMP_SUBAGENT_PANES` | unset (on) | `0` disables auto-opening panes entirely |
| `OMP_SUBAGENT_PANES_MAX` | `4` | caps concurrently open subagent panes |
| `OMP_SUBAGENT_PANES_PLACEMENT` | `split` | passed through to `herdr plugin pane open --placement` |
| `OMP_SUBAGENT_PANES_DIRECTION` | `down` | passed through to `herdr plugin pane open --direction` |
| `OMP_SUBAGENT_PANES_AUTOCLOSE` | unset (on) | `0` keeps every pane open instead of closing it when its subagent settles; the resolved value is forwarded into the pane as `OMP_SUBAGENT_AUTOCLOSE` for the viewer to act on |

See `herdr-subagent-panes.ts` for how those are applied.
