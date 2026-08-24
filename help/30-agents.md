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
    omp plugin install <src>        # install a plugin at user scope (npm spec or git shorthand)
    omp plugin install --dry-run <src>  # show what an install would do, changing nothing

Installed omp plugins (`omp_plugins.txt`), one line each on what they add:

- `foreman` — the boss half: `/foreman:*` commands, `skill://foreman-boss`, the `foreman_*` tools
- `billion-context-omp` — model-driven context compression; `compress`/`decompress`/`search_context` and the `/acp` report

Gotcha: for omp plugins, install IS the update path — the opposite of the gh
extensions trap. Re-running `omp plugin install` on a git or npm source lets
omp follow its `bun install` with a `bun update`, which moves the dependency
forward; there is no separate update command to pair it with. It's also why
billion-context-omp's own `autoUpdate` is switched off in `omp/acp-omp.json`:
left on, the extension reinstalls itself from npm behind the manifest's back.
`omp update` is deliberately the only upgrade path for omp itself — install.sh
never re-downloads it, so `omp update` (or `--check` first) is how you
actually get a new release. Machine-local model providers (API keys, custom
endpoints) go in `~/.omp/agent/models.yml`, never in the tracked
`omp/agent/config.yml` — CI greps the tracked config and only allows built-in
provider ids there. Global user context lives in `omp/agent/AGENTS.md`
(native discovery, highest priority — `disabledProviders` in `config.yml`
turns off the `claude`/`gemini`/etc. discovery providers so it's the only
user-level file omp reads), and `~/.claude/CLAUDE.md` below is a symlink
straight to it rather than a second copy.

## claude — Claude Code

`install.sh`'s tools step installs it: the native installer at
[claude.ai/install.sh](https://claude.ai/install.sh) on both macOS and Linux
(it auto-detects the platform itself, so there's no per-OS branch the way
omp/herdr need). run_quiet-wrapped, like herdr/atuin/starship — it always
re-runs, and its own install/update chatter is suppressed unless something
fails, same as those. Global config is tracked too: `config/claude/settings.json`
links to `~/.claude/settings.json`. `config/claude/CLAUDE.md` is a symlink
(tracked as one in git) to `omp/agent/AGENTS.md` above, so Claude Code's
global user memory and omp's global context are the same file — everything
else under `~/.claude` is sessions, cache, and machine state, none of it
meant for a repo. zshrc aliases the bare `claude` invocation to always add
`--dangerously-skip-permissions` — this machine is trusted enough that typing
the flag out every time is pure friction.

    claude                          # launch or resume the interactive session
    claude --continue               # resume the most recent conversation
    claude --resume                 # resume a session by picker
    claude update                   # check for and install an update now
    claude mcp list                 # list configured MCP servers

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
inside of. foreman has no terminal or worktree management of its own — its CLI
half is itself a herdr plugin (`andyhite/foreman/herdr` below), and every
worker `foreman spawn` creates is a herdr pane living in a herdr worktree
workspace. The `herdr` agent skill that lets an agent drive its own session
only arms itself when `HERDR_ENV=1` is set — i.e. only when that agent is
actually running inside a herdr-managed pane, not just any terminal. And
plugins like `douglascorrea/herdr-agent-inbox` (the agent inbox split) exist
as panes precisely because herdr is what's already multiplexing the terminal
they share.

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

- `paulbkim-dev/vim-herdr-navigation` — ctrl-h/j/k/l crosses into nvim splits instead of stopping at the pane edge
- `douglascorrea/herdr-agent-inbox` — inbox plus auto tab/session naming for agent panes
- `tdi/herdr-worktree-setup` — on worktree.created: copies .env*, mise trust, direnv allow, installs deps
- `andyhite/foreman/herdr` — foreman's CLI half, installs the `foreman` binary onto PATH

## foreman — the boss

Two halves, both required. The herdr plugin `andyhite/foreman/herdr`
(`herdr_plugins.txt`) is the CLI — its startup hook symlinks the `foreman`
binary onto PATH. The omp plugin `foreman` (`omp_plugins.txt`, a direct git
install of `andyhite/foreman` — no marketplace) is the agent-facing half:
`/foreman:*` commands and the `skill://foreman-boss` / `skill://foreman-dispatch`
/ `skill://foreman-worker` skills. A worker dispatched by foreman is a separate
`omp` process in its own pane, worktree, and branch — never an in-process
`task` subagent sharing the boss's own process.

    foreman boss                    # claim the boss handle for this pane
    foreman spawn <branch>          # create a worktree, start an agent, dispatch work to it
    foreman send <handle> <text>    # dispatch work to a worker, return immediately
    foreman ask <handle> <text>     # dispatch and block until the worker's report is in
    foreman join                    # collect this repo's workers, print their reports
    foreman ls                      # list workers, their kinds, and their states
    foreman dashboard               # inspect and operate foreman interactively
    foreman reap <handle>           # remove a worker's worktree and forget it
    foreman report -f <file>        # (worker side) write the report the boss collects
    foreman doctor                  # check prerequisites are in place

`/foreman:boss` claims the boss handle and adopts the role for the session;
`/foreman:dispatch` sends one piece of work to a worker mid-session. A
dispatched worker's brief names a role or a list of skills to run — literal
skill names it reaches with `foreman skill <name>`, which is how it triggers
a skill marked disable-model-invocation that it couldn't otherwise reach on
its own.

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
