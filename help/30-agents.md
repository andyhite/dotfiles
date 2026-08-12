## omp — the coding agent

This is what you're talking to right now. `omp/agent/config.yml` pins model
routing per role under `modelRoles` (`default`, `plan`, `task`, `smol`,
`commit`, `advisor`, and more), and `retry.fallbackChains` gives each role an
ordered list of alternate models to fall back to on failure, keyed by the
same role names.

    omp                             # launch or resume the interactive session
    omp --model opus                # override the model for this run (fuzzy match)
    omp -c                          # continue the previous session
    omp -r                          # resume a session by picker
    omp update                      # download and install the latest omp release
    omp update --check              # check for an update without installing
    omp plugin list                 # list installed plugins
    omp plugin marketplace update   # refresh a marketplace's catalog before reinstalling from it
    omp plugin install <name>@<mkt> # install a plugin from an already-refreshed marketplace

Gotcha: `omp plugin install --force` reinstalls from whatever marketplace
clone is already on disk — it does NOT refresh the catalog first. Re-running
it without `marketplace update` first just reinstalls the version you
already have and reports success, silently skipping any upstream update.
`omp_plugins.txt` documents this trap and install.sh always does both steps
in order. `omp update` is deliberately the only upgrade path — install.sh
never re-downloads omp itself, so `omp update` (or `--check` first) is how
you actually get a new release. Machine-local model providers (API keys,
custom endpoints) go in `~/.omp/agent/models.yml`, never in the tracked
`omp/agent/config.yml` — CI greps the tracked config and only allows
built-in provider ids there.

## herdr — the terminal multiplexer for coding agents

`install.sh`'s tools step installs it: a real Homebrew core formula on macOS
(`brew "herdr"`), the official `curl -fsSL https://herdr.dev/install.sh | sh`
installer on Linux — see the README's herdr section for the `~/.local/bin`
shadow trap that installer shares with uv's.

herdr is a terminal multiplexer purpose-built for running and supervising
coding agents — not a general-purpose tmux/zellij replacement with agent
support bolted on after the fact. Panes, tabs, and workspaces are the layout
primitives, and a git worktree is a first-class *kind* of workspace
(`herdr worktree create <branch>`) rather than something scripted on top of a
plain shell pane. Every pane recognized as hosting a supported agent (omp,
Claude Code, Codex, ...) is tracked through a small lifecycle state machine —
`idle`, `working`, `blocked`, `done`, `unknown` — that `herdr agent list` and
every plugin below reads from, so tooling can tell "waiting on you" apart
from "finished while you weren't looking" without scraping terminal output.

It's also the terminal layer the rest of this toolchain assumes it's running
inside of. fleet has no terminal or worktree management of its own — its CLI
half is itself a herdr plugin (`andyhite/foreman/herdr` below), and every
worker `fleet spawn` creates is a herdr pane living in a herdr worktree
workspace. The `herdr` agent skill that lets an agent drive its own session
only arms itself when `HERDR_ENV=1` is set — i.e. only when that agent is
actually running inside a herdr-managed pane, not just any terminal. And
plugins like `persiyanov/herdr-reviewr` (a diff-review split) or
`ogulcancelik/herdr-browser` (Chromium over CDP) exist as panes precisely
because herdr is what's already multiplexing the terminal they share.

    herdr                            # launch or attach to the persistent session
    herdr agent start                # start a supported interactive agent in an existing pane
    herdr agent list                 # list agents across panes
    herdr worktree create <branch>   # create a git worktree and open it as a workspace
    herdr worktree list              # list worktree workspaces
    herdr plugin install <owner>/<repo>  # install (or update, re-run) a plugin from GitHub
    herdr plugin action list         # list every action every installed plugin exposes
    herdr plugin action invoke <id> --plugin <plugin_id>  # run one action directly, bypassing the palette

The command palette is bound to `prefix+p` (`config/herdr/palette/palette.sh`)
— fzf over every installed plugin's actions, enumerated live from
`herdr plugin action list`. That's why most plugin actions in this config are
deliberately left unbound to a dedicated key: one fuzzy search away already
covers all of them, and a key binding is only added for the handful used
often enough to be worth memorizing.

Installed plugins (`herdr_plugins.txt`), one line each on what they add:

- `ogulcancelik/herdr-browser` — Chromium in a pane, drivable over CDP
- `persiyanov/herdr-reviewr` — local diff/review TUI split, not an AI reviewer
- `paulbkim-dev/vim-herdr-navigation` — ctrl-h/j/k/l crosses into nvim splits instead of stopping at the pane edge
- `osolmaz/ghzinga/plugins/herdr` — ctrl-click a github.com issue/PR link, opens gzg in a split
- `douglascorrea/herdr-agent-inbox` — inbox plus auto tab/session naming for agent panes
- `Davidcreador/herdr-token-dashboard` — live token spend and cost notifications (omp/OpenCode/Claude sessions)
- `tdi/herdr-worktree-setup` — on worktree.created: copies .env*, mise trust, direnv allow, installs deps
- `andyhite/foreman/herdr` — fleet's CLI half, installs the `fleet` binary onto PATH
- `wyattjoh/herdr-plugin-gh-pr` — focused agent's branch PR state as a sidebar token
- `a2u/herdr-jira` — Jira issues in a pane, with `d` to hand one to any visible agent

## fleet — the orchestrator

Two halves, both required. The herdr plugin `andyhite/foreman/herdr`
(`herdr_plugins.txt`) is the CLI — its startup hook symlinks the `fleet`
binary onto PATH. The omp plugin `fleet@foreman` (`omp_plugins.txt`) is the
agent-facing half: `/fleet:*` commands and the `skill://fleet` /
`skill://fleet-dispatch` skills. A worker dispatched by fleet is a separate
`omp` process in its own pane, worktree, and branch — never an in-process
`task` subagent sharing the boss's own process.

    fleet boss                      # claim the orchestrator handle for this pane
    fleet spawn <branch>            # create a worktree, start an agent, dispatch work to it
    fleet send <handle> <text>      # dispatch work to a worker, return immediately
    fleet ask <handle> <text>       # dispatch and block until the worker's report is in
    fleet join                      # collect this repo's workers, print their reports
    fleet ls                        # list workers, their kinds, and their states
    fleet dashboard                 # inspect and operate the fleet interactively
    fleet reap <handle>             # remove a worker's worktree and forget it
    fleet report -f <file>          # (worker side) write the report the orchestrator collects
    fleet doctor                    # check prerequisites are in place

The `/fleet:*` omp commands (`/fleet:implement`, `/fleet:diagnosing-bugs`,
`/fleet:research`, `/fleet:prototype`, `/fleet:code-review`) are each named
for the skill they delegate to; a dispatched worker's brief opens by telling
it to run `fleet skill <that name>`, which is how it reaches a skill marked
disable-model-invocation that it couldn't otherwise trigger on its own.

## paseo — the agent supervision daemon

Supervises coding agents as a background daemon and exposes them to
desktop/mobile/CLI clients. This setup splits the role across machines: the
Mac runs the GUI desktop client, the Linux box runs the daemon itself.

    paseo onboard                   # first-time setup: start daemon, print pairing instructions
    paseo ls                        # list agents (excludes archived by default)
    paseo run "<prompt>"            # create and start an agent with a task
    paseo attach <id>               # stream a running agent's output
    paseo send <id> "<prompt>"      # send a follow-up message/task to an existing agent
    paseo logs <id>                 # view an agent's activity/timeline
    paseo status                    # local daemon status
    paseo stop <id>                 # interrupt a running agent

`config/paseo/orchestration-preferences.json` decides which provider/model a
delegated role gets (`impl`, `ui`, `research`, `planning`, `audit`) — Opus
for anything artistic or judgment-driven (copy, naming, UX, planning), Codex
for mechanical work against an already-settled design. Its own `preferences`
array also says to prefer asynchronous delegation over polling agent status.
The four orchestration skills installed from `agent_skills.txt`
(`paseo`, `paseo-advisor`, `paseo-committee`, `paseo-handoff`) all come from
the same `getpaseo/paseo` repo the daemon itself is built from, and `paseo`
is the one the other three depend on — it documents the tool surface and the
orchestration-preferences.json contract the rest assume.

## skills — the cross-agent skill CLI

Canonical skill copies live in `~/.agents/skills`, installed from
`agent_skills.txt` (one `<owner>/<repo> --skill <name>` per line). The CLI
then symlinks each configured agent's own skills directory into that shared
tree, which is how every agent — omp included — picks up the same skills
without a separate install per tool.

    npx skills find <keyword>                            # search for skills interactively or by keyword
    npx skills add <owner>/<repo> --skill <name> -g -y    # install one skill globally, unattended
    npx skills list                                       # list installed skills
    npx skills list -g                                    # list skills installed globally, not project-local
    npx skills update                                     # update every installed skill to its latest content
    npx skills update --skill <name>                      # update just one installed skill
    npx skills remove <name>                              # remove an installed skill

`-g` installs globally rather than into a single project; `-y` accepts
prompts unattended, which is what lets `install.sh` run this with no tty.
`~/.agents/.skill-lock.json` stays untracked — it's generated state (content
hashes, install/update timestamps), the same role herdr's own
`plugins.json` plays next to `herdr_plugins.txt`.
