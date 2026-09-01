# dotfiles

Shell and terminal config, synced between my Mac (Ghostty) and remote dev VMs. GitHub Dark
Default theme everywhere, zsh with antidote instead of oh-my-zsh, starship for the prompt,
NvChad for editing.

Applied with [chezmoi](https://chezmoi.io) (owns everything that lands under `$HOME`) and
[mise](https://mise.jdx.dev) (owns every CLI tool and language runtime). See `AGENTS.md`
for how to change things here — this file is why each tool is configured the way it is.

## Contents

- [What's in here](#whats-in-here)
- [Bootstrap a new machine](#bootstrap-a-new-machine)
  - [Provisioning scripts](#provisioning-scripts)
  - [Remote installs — `just remote`](#remote-installs----just-remote)
  - [Completions](#completions)
  - [The `create_private_` secrets](#the-create_private_-secrets)
  - [mise](#mise)
  - [`make` on macOS — `gmake`, not `gnumake`](#make-on-macos--gmake-not-gnumake)
  - [Shells with no line editor — `TERM=dumb`, or no tty](#shells-with-no-line-editor--termdumb-or-no-tty)
- [Notes by tool](#notes-by-tool)
  - [Git — rebase-first, with hunk and delta](#git--rebase-first-with-hunk-and-delta)
  - [Shell — carapace, fd, uv, and Linux clipboards](#shell--carapace-fd-uv-and-linux-clipboards)
  - [gh extensions — one manifest entry, install vs. upgrade](#gh-extensions--one-manifest-entry-install-vs-upgrade)
  - [btop — GitHub Dark Default theme, and the config-rewrite trap](#btop--github-dark-default-theme-and-the-config-rewrite-trap)
  - [Docker Desktop](#docker-desktop)
  - [Caddy — local HTTPS for internal-only dev hostnames](#caddy--local-https-for-internal-only-dev-hostnames)
  - [dnsmasq — wildcard local DNS via macOS's per-domain resolver](#dnsmasq--wildcard-local-dns-via-macoss-per-domain-resolver)
  - [omp — one tracked config, two machines, different accounts](#omp--one-tracked-config-two-machines-different-accounts)
  - [omp compaction — a fold is priced in cache, not tokens](#omp-compaction--a-fold-is-priced-in-cache-not-tokens)
  - [Atuin](#atuin)
  - [herdr — mise on both platforms](#herdr--mise-on-both-platforms)
  - [Herdr plugins — one manifest, herdr's registry stays untracked](#herdr-plugins--one-manifest-herdrs-registry-stays-untracked)
  - [Herdr plugin keybindings — `[keys]` only knows herdr's own actions](#herdr-plugin-keybindings--keys-only-knows-herdrs-own-actions)
  - [lin — mise's cargo backend, both platforms](#lin--mises-cargo-backend-both-platforms)
  - [Agent skills — one manifest, the lockfile isn't tracked](#agent-skills--one-manifest-the-lockfile-isnt-tracked)
  - [NvChad — diffview alongside telescope `git_status`](#nvchad--diffview-alongside-telescope-git_status)
  - [NvChad's lockfile — apply restores it, `:Lazy sync` moves it](#nvchads-lockfile--apply-restores-it-lazy-sync-moves-it)
  - [NvChad's Mason/Treesitter setup — do this yourself, on purpose](#nvchads-masontreesitter-setup--do-this-yourself-on-purpose)
  - [Ghostty over SSH — `TERM=xterm-ghostty` doesn't exist on most remotes](#ghostty-over-ssh--termxterm-ghostty-doesnt-exist-on-most-remotes)
  - [Hammerspoon — per-Space Ghostty toggle, Ghostty's own is app-wide](#hammerspoon--per-space-ghostty-toggle-ghosttys-own-is-app-wide)
- [Making changes](#making-changes)
  - [Justfile and CI](#justfile-and-ci)

## What's in here

The inventory tables below list every path chezmoi manages, named in chezmoi's own source
naming (`dot_` → `.`, `private_` → mode 0600, `create_private_` → written once at mode
0600 and never overwritten, `symlink_` → a `$HOME` symlink to a `linked/` tree, `.tmpl` →
rendered per machine). `home/.chezmoiroot` (containing the single line `home`) is what
keeps everything outside `home/` and `linked/` — this README, the `Justfile` — out of the
applied state entirely.

### Shell & prompt

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_zshrc` | `~/.zshrc` | zsh config: completion, antidote plugin load, history, aliases, tool init hooks |
| `home/dot_zshenv` | `~/.zshenv` | `PATH` setup read by every zsh invocation, interactive or not |
| `home/dot_zsh_plugins.txt` | `~/.zsh_plugins.txt` | antidote's plugin list (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, zsh-vi-mode) |
| `home/dot_config/starship.toml` | `~/.config/starship.toml` | prompt — GitHub Dark Default palette, hostname shown only over SSH |
| `home/dot_config/atuin/config.toml` | `~/.config/atuin/config.toml` | Atuin (shell history): overrides only — daemon, fuzzy search, full-style UI, vi keymap, `atuin ai`. Also the answers `atuin setup` would otherwise re-ask on every install |
| `home/dot_config/atuin/themes/github-dark-default.toml` | `~/.config/atuin/themes/github-dark-default.toml` | GitHub Dark Default for Atuin; foreground colors only, background comes from Ghostty |
| `home/create_private_dot_zshrc.local` | `~/.zshrc.local` (created once, mode 0600) | machine-local secrets — never committed |

### Terminal & workspace

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_config/ghostty/config` | `~/.config/ghostty/config` | Ghostty terminal: `GitHub Dark Default` theme, shell integration — same path on macOS and Linux |
| `home/dot_hammerspoon/init.lua` | `~/.hammerspoon/init.lua` (macOS only) | Hammerspoon: binds the per-Space Ghostty show/hide toggle that replaced Ghostty's own app-wide one — see [Hammerspoon](#hammerspoon--per-space-ghostty-toggle-ghosttys-own-is-app-wide) below |
| `home/dot_config/btop/` | `~/.config/btop/` | btop resource monitor: GitHub Dark Default theme, `save_config_on_exit = false` so btop's default full-config-rewrite-on-quit can't overwrite this file — see [btop](#btop--github-dark-default-theme-and-the-config-rewrite-trap) below |
| `home/dot_config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager), native theme resynced to Ghostty's accent blue, no contrast-repair overrides needed |
| `home/dot_config/herdr/palette/` | `~/.config/herdr/palette/` | the `prefix+p` command palette — an fzf script run by a `type = "popup"` keybinding, plus the MIT notice of the plugin it's derived from |
| `home/dot_config/herdr/layout/` | `~/.config/herdr/layout/` | the `prefix+f` fold command — a `type = "shell"` keybinding that folds a row of N side-by-side panes into N/2 columns of two |
| `home/dot_config/herdr/plugins/symlink_config.tmpl` | `~/.config/herdr/plugins/config` → `linked/herdr-plugin-config` | per-plugin Herdr config, one directory per plugin id — herdr writes into this tree as new plugins install, which is why it's `linked/` rather than copied — see [Copy mode vs. `linked/`](./AGENTS.md#copy-mode-vs-linked) in `AGENTS.md` |
| `linked/herdr-plugins/ticket-worktree/` | reached via `herdr plugin link`, driven by its `packages.yaml` entry | the `prefix+t` ticket-to-worktree plugin: a single-screen form popup for a Jira/Linear ticket URL, then creates a `ticket/<key>` branch + worktree and starts an omp agent with the ticket queued as an unsubmitted prompt — see [Herdr plugins](#herdr-plugins--one-manifest-herdrs-registry-stays-untracked) below |
| `home/dot_config/caddy/Caddyfile` | `~/.config/caddy/Caddyfile` (macOS only) | base Caddyfile — `local_certs` only, imports the machine-local one below by a path relative to itself — see [Caddy](#caddy--local-https-for-internal-only-dev-hostnames) below |
| `home/dot_config/caddy/create_private_Caddyfile.local` | `~/.config/caddy/Caddyfile.local` (created once, mode 0600) | machine-local site blocks, never committed |
| `home/dot_config/dnsmasq/dnsmasq.conf.tmpl` | `~/.config/dnsmasq/dnsmasq.conf` (macOS only) | base dnsmasq config — loopback-only, non-privileged port — see [dnsmasq](#dnsmasq--wildcard-local-dns-via-macoss-per-domain-resolver) below |
| `home/dot_config/dnsmasq/create_private_dnsmasq.local.conf` | `~/.config/dnsmasq/dnsmasq.local.conf` (created once, mode 0600) | machine-local wildcard-domain records, never committed |
| `home/Library/LaunchAgents/dev.caddy.plist` | `~/Library/LaunchAgents/dev.caddy.plist` (macOS) | this repo's own LaunchAgent for caddy, replacing `brew services` — not loaded by any provisioning script; `launchctl load -w` it by hand when you want it running |
| `home/Library/LaunchAgents/dev.dnsmasq.plist` | `~/Library/LaunchAgents/dev.dnsmasq.plist` (macOS) | same, for dnsmasq |

### Editor

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_config/symlink_nvim.tmpl` | `~/.config/nvim` → `linked/nvim` | [NvChad](https://nvchad.com) starter — vendored once, `.git` stripped, fully mine to edit from here. Includes `lazy-lock.json`: tracked on purpose, so it's the pinned plugin set every machine restores to rather than per-machine generated state — see [the lockfile section](#nvchads-lockfile--apply-restores-it-lazy-sync-moves-it). It's `linked/` (live-symlinked, not copied) because NvChad rewrites `lazy-lock.json` on `:Lazy sync` |
| `home/dot_config/zed/settings.json` | `~/.config/zed/settings.json` | Zed editor settings — `disable_ai: true` since agents run from the terminal via omp, not inside the editor, so the `agent`/`agent_servers` keys go undefined rather than tracked as dead config. `ssh_connections` is absent because it now lives in Zed's project-local settings, not this user-level file — see the header comment in the file itself |

### Git

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_gitconfig.tmpl` | `~/.gitconfig` | tracked git identity, LFS/xet filter wiring, rebase-first defaults, hunk pager + hunk difftool (delta retained for `add -p`), plus a templated `includeIf "gitdir:…"` block for work identity (see [Work identity](./AGENTS.md#work-identity) in `AGENTS.md`); anything else that varies per machine layers in through `create_private_dot_gitconfig.local` below |
| `home/create_private_dot_gitconfig.local` | `~/.gitconfig.local` (created once, mode 0600) | work identity via `includeIf "gitdir:…"`, private-registry credentials. `dot_gitconfig.tmpl`'s trailing `[include]` applies last, so anything set here wins over every default in the tracked file |
| `home/create_private_dot_gitconfig-work.tmpl` | `~/.gitconfig-work` (created once, mode 0600; skipped entirely when `workGitDir` is blank) | `[user] name`/`email` rendered from the `workName`/`workEmail` prompts — the one machine-local fact that's prompted rather than hand-filled, since it isn't a secret |
| `home/dot_config/git/ignore` | `~/.config/git/ignore` | global gitignore — git's own default `core.excludesFile` location when that setting is unset, so machine-tool droppings (`.DS_Store`, `.idea/`) never have to live in a project's own `.gitignore` |
| `home/dot_config/gh/config.yml` | `~/.config/gh/config.yml` | gh CLI defaults and aliases; `git_protocol: https` is deliberate — `private_dot_ssh/config` maps `github.com` to the work SSH key, so an ssh remote here would silently authenticate as the wrong account |
| `home/dot_config/lazygit/config.yml` | `~/.config/lazygit/config.yml` (Linux) | Lazygit: GitHub Dark Default theme, Nerd Font v3 icons, fuzzy filtering, and nvim integration; `zshrc` exposes it as `lg` |
| `home/Library/Application Support/lazygit/symlink_config.yml.tmpl` | `~/Library/Application Support/lazygit/config.yml` → `home/dot_config/lazygit/config.yml` (macOS) | same file, Lazygit's native macOS location — one real file, one symlink, never two tracked copies |
| `home/dot_config/hunk/config.toml` | `~/.config/hunk/config.toml` | Hunk review-stream viewer: `github-dark-default` theme (an exact built-in Shiki theme id), line numbers, and default-on agent notes for reviewing agent-authored changesets; wired as both `core.pager` and `diff.tool` — see the Git section below |
| `home/private_dot_ssh/config` | `~/.ssh/config` (mode 0600) | portable ssh identity config — per-key `Host` blocks for github.com (`IdentitiesOnly yes` so the agent can't offer the wrong key first), github.com-personal, hf.co, runpod.io, plus dstack's `Include ~/.dstack/ssh/config` (dstack injects that line into `~/.ssh/config` on every provision — a real file chezmoi owns, not a symlink, so tracking it is the only way the tree stays clean; inert where dstack has never run); machine-specific hosts live in `~/.ssh/config.local` instead |
| `home/private_dot_ssh/create_private_config.local` | `~/.ssh/config.local` (created once, mode 0600) | throwaway test hosts, machine-specific aliases. `private_dot_ssh/config`'s first non-dstack line is `Include ~/.ssh/config.local`, because ssh takes the first value it finds for any option and this is the only way the local file can override rather than be shadowed |

### Agents & orchestration

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_omp/agent/config.yml` | `~/.omp/agent/config.yml` | [omp](https://omp.sh) coding agent settings — besides this file, `AGENTS.md`, and `rules/output-style.md` below, the rest of `~/.omp/agent` is databases, sessions, and a secrets key |
| `home/dot_omp/agent/extensions/symlink_atuin.ts.tmpl` | `~/.omp/agent/extensions/atuin.ts` → `linked/omp-extensions/atuin.ts` | records omp's `bash` commands into Atuin history as `--author pi` (a `KNOWN_AGENTS` name, so `$all-user` hides them), with omp's intent string as `--intent`. Hand-maintained: `atuin hook install` has no omp target. `linked/` because it's code developed in place, headed for its own repo eventually |
| `home/dot_omp/agent/extensions/symlink_daily-budget.ts.tmpl` | `~/.omp/agent/extensions/daily-budget.ts` → `linked/omp-extensions/daily-budget.ts` | weekday spend-pacing warnings layered on top of `retry.usageAwareFallback` — shells out to `omp usage --json` on `turn_end` (plus a 5-minute idle fallback timer while a session sits quiet) and warns (never falls back — that stays `usageAwareFallback`'s job) once real usage outruns the cumulative allocation in `daily-budget.json` through today's weekday |
| `home/dot_omp/agent/daily-budget.json` | `~/.omp/agent/daily-budget.json` | two independent budgets, `usage` (%-of-7d-quota, for whichever providers `omp usage --json` actually reports — never a static list) and `cost` (a $ cap pooled across every other, pay-per-token provider by default); each is a global default schedule plus an optional per-provider `providers` override, read by the extension above. The runtime ledger it writes (`daily-budget-state.json`) is untracked state, not this file |
| `home/dot_omp/agent/rules/output-style.md` | `~/.omp/agent/rules/output-style.md` | `alwaysApply: true` rule that shapes every omp response for an ADHD reader — answer first, numbered steps, one next action, no preamble or recap |
| `home/dot_omp/agent/AGENTS.md` | `~/.omp/agent/AGENTS.md` | omp's native global context file (highest-priority discovery provider — shadows every other tool's user-level context). Holds the same ADHD output-style guidance as `rules/output-style.md` above, since it's a personal preference rather than an omp-specific one; `dot_claude/symlink_CLAUDE.md.tmpl` below points straight at this file, so it's the one source of truth |
| `home/dot_omp/agent/create_private_models.yml` | `~/.omp/agent/models.yml` (created once, mode 0600) | credentials and custom provider ids — trial models, self-hosted endpoints, a second identity for an existing account; see [omp model routing](./AGENTS.md#omp-model-routing) in `AGENTS.md` |
| `home/dot_omp/agent/create_private_config.local.yml` | `~/.omp/agent/config.local.yml` (created once, mode 0600) | a `modelRoles`/`retry.fallbackChains` overlay `zshrc` loads via `PI_CONFIG_FILES`, deep-merged on top of the shared `config.yml` |
| `home/dot_claude/settings.json` | `~/.claude/settings.json` | [Claude Code](https://claude.com/product/claude-code) CLI global settings — push/input-needed notifications, `theme: auto`, `skipDangerousModePermissionPrompt`, `tui: fullscreen`, and `PreToolUse`/`PostToolUse`/`PostToolUseFailure` hooks (all matcher `Bash`) that pipe `atuin hook claude-code` the same way `dot_omp/agent/extensions/atuin.ts` does for omp; the rest of `~/.claude` is sessions, an oauth/telemetry cache, a machine ID, backups, and the `skills/` symlinks the cross-agent skill install manages |
| `home/dot_claude/symlink_CLAUDE.md.tmpl` | `~/.claude/CLAUDE.md` → `~/.omp/agent/AGENTS.md` | a symlink to the applied `dot_omp/agent/AGENTS.md` above — Claude Code's global user memory reuses the exact same content rather than carrying a second copy. The `claude` discovery provider is disabled in `dot_omp/agent/config.yml`, so omp itself reads `AGENTS.md` directly and never this path |
| `home/dot_dstack/server/create_private_config.yml` | `~/.dstack/server/config.yml` (created once, mode 0600) | [dstack](https://dstack.ai) GPU-cloud task/dev-environment orchestrator config — `dstack` itself installs via `uv tool install` (see [packages.yaml](#bootstrap-a-new-machine) below) |
| `home/Library/LaunchAgents/ai.dstack.server.plist` | `~/Library/LaunchAgents/ai.dstack.server.plist` (macOS) | `RunAtLoad`+`KeepAlive` LaunchAgent that starts `dstack server` at login and restarts it if it dies; loaded by `run_onchange_after_70-services.sh.tmpl`, never by chezmoi's own file-write step, so a throwaway-destination `just smoke` run never touches the real launchd namespace |
| `home/dot_config/systemd/user/dstack-server.service` | `~/.config/systemd/user/dstack-server.service` (Linux) | the same job as the plist above, as a systemd `--user` unit (`Restart=on-failure`, `WantedBy=default.target`); same split from chezmoi's file-write step into the dedicated services script |
| `home/dot_local/bin/executable_tailscale` | `~/.local/bin/tailscale` | PATH shim for the Mac App Store build of Tailscale — `exec`s the bundled CLI directly, since a plain symlink to it fails at runtime (see the file itself for why). Present only on macOS, and only when the App Store app is actually installed — see `.chezmoiignore`'s `stat` guard |

### Repo scripts, checks & docs

| Path | Target | What it is |
| --- | --- | --- |
| `home/.chezmoidata/packages.yaml` | not applied — read by the templates below | the one manifest for every installable thing: CLI tools, language runtimes, Homebrew casks, apt packages, uv tools, herdr plugins, gh extensions, cross-agent skills — see [Bootstrap a new machine](#bootstrap-a-new-machine) |
| `home/dot_config/mise/config.toml.tmpl` | `~/.config/mise/config.toml` | mise's global tool-version config, rendered from every `via: mise` entry in `packages.yaml` — see [mise](#mise) below |
| `home/.chezmoiscripts/*.sh.tmpl` | not applied — run by `chezmoi apply` in numbered order | thirteen provisioning scripts — see [Provisioning scripts](#provisioning-scripts) below |
| `home/.chezmoitemplates/output.sh.tmpl` | not applied — included by every provisioning script via a `template` action | shared `ok`/`added`/`updated`/`skipped`/`warned`/`failed`/`run_quiet` output helpers — see [Provisioning scripts](#provisioning-scripts) below |
| `home/.chezmoi.toml.tmpl` | `~/.config/chezmoi/chezmoi.toml` | sets `sourceDir` to the repo's own working tree and prompts the three `workName`/`workEmail`/`workGitDir` values once — see [Work identity](./AGENTS.md#work-identity) in `AGENTS.md` |
| `home/.chezmoiignore` | not applied — chezmoi reads it directly | OS-conditional exclusions: `.hammerspoon`/`Library` off Linux, `.config/systemd` off macOS, the Tailscale shim unless the App Store app is installed, `.gitconfig-work` unless `workGitDir` is set |
| `home/.chezmoiexternal.toml` | not applied — chezmoi reads it directly | antidote's git-repo clone (`~/.antidote`) and, Linux only, the Geist Mono Nerd Font release archive (macOS gets the same font from a cask instead) |
| `Justfile` | not applied — invoked by `just` and CI | single source of truth for every check — `.github/workflows/ci.yml` calls its recipes instead of duplicating them; see [Justfile and CI](#justfile-and-ci) |
| `.pre-commit-config.yaml` | not applied — read by `pre-commit` | gitleaks plus the local `just leakguard` hook; `run_once_after_90-repo-hooks.sh.tmpl` runs `pre-commit install` on apply so a fresh clone gets both |
| `.markdownlint.yaml` | not applied — read by nvim's `markdownlint` linter and `just fix-md` | shared markdown lint rules: MD013 (line-length) and MD041 (require a top-level heading) off, since neither matches this repo's own conventions |

## Bootstrap a new machine

```sh
brew install chezmoi                 # macOS, with Homebrew already present
# or, on Linux:
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

chezmoi init --apply https://github.com/andyhite/dotfiles.git
```

The first `chezmoi init` prompts three questions once — work git author name, work git
author email, and a work checkout directory for the `includeIf "gitdir:…"` block — and
persists the answers outside the repo, in `~/.config/chezmoi/chezmoi.toml`. Blank answers
are valid and mean "no work identity on this machine". `chezmoi apply` is safe to re-run
any time: it installs what's missing and updates what's already there, and every script
and `create_private_` entry is idempotent by design (proven by `just smoke`, which applies
the whole tree twice into a throwaway destination and asserts the second run is a no-op).

`home/.chezmoidata/packages.yaml` is the one manifest for every installable thing this
config drives — a CLI, a language runtime, a Homebrew cask, an apt package, a uv tool, a
herdr plugin, a `gh` extension, a cross-agent skill. Each entry names its manager per
platform: `via: mise | brew | cask | apt | uv | installer | herdr | omp | gh | skill`.
There is no second manifest, no Brewfile, no per-OS branch anywhere else — the mise
config, the generated Brewfile, the apt script, the uv-tools script, the upstream-installer
script, the completions script, and the agents script all filter this one list. See
"Adding anything installable" in `AGENTS.md` for how to add an entry.

### Provisioning scripts

Thirteen scripts under `home/.chezmoiscripts/`, each wrapped in an `{{ if eq .chezmoi.os
… }}` guard where it's platform-specific (a guarded-out script renders empty and does
nothing). chezmoi runs every `before_` script first, in ASCII order, before writing a
single file; then writes every file, directory, symlink, and external; then runs every
`after_` script, also in ASCII order. The number prefix is what fixes ordering within each
phase — it exists because later scripts depend on earlier ones having already run
(mise before the tools it installs; the symlinked target files before a script that reads
them). `run_onchange_` scripts re-run whenever their own rendered content changes — which,
because each one filters `packages.yaml` down to just its own `via` subset, means a
manifest edit re-triggers only the scripts whose rendered text actually changed.
`run_once_` scripts run exactly once per machine, ever, regardless of content changes —
used for the two installers that self-update and for the `pre-commit install` call, where
re-running on every apply would be wasted work rather than a correctness fix.

Every script pulls in `home/.chezmoitemplates/output.sh.tmpl` — a `.chezmoitemplates`
partial, not applied on its own — as its first line after `set -euo pipefail`. It defines
`ok`/`added`/`updated`/`skipped`/`warned`/`failed` (colour + glyph, `NO_COLOR`/non-tty
aware) and `run_quiet <label> <cmd…>`, which redirects a noisy installer's own stdout/
stderr to a temp file and only replays it (indented, tail -12) if the command failed.
`CHEZMOI_VERBOSE=1 chezmoi apply` shows every command's raw output instead. This is the
same structured-status/quiet-by-default design the old `install.sh` used, ported into
chezmoi's script model instead of duplicated across all thirteen scripts.

| Script | Platform | What it does |
| --- | --- | --- |
| `run_onchange_before_05-apt.sh.tmpl` | linux | `apt-get update`, then one `apt-get install` per `via: apt` entry — per package, not batched, so one missing from this Ubuntu release's archives skips itself instead of failing the whole list. Runs first so `curl`/`git`/`unzip` exist for everything after |
| `run_onchange_before_06-homebrew.sh.tmpl` | darwin | fails with a one-line install instruction if `brew` isn't on `PATH`. Never auto-installs Homebrew — that needs sudo and is a machine-level decision |
| `run_onchange_before_10-mise.sh.tmpl` | both | reads the single `name: mise` entry directly (mise can't install itself from its own config): `brew install mise` on darwin, the `mise.run` curl installer on linux, only if `mise` isn't already on `PATH` |
| `run_onchange_after_20-brew-bundle.sh.tmpl` | darwin | renders every `via: brew`/`via: cask` entry into a heredoc, writes it to a `mktemp` path, and runs `brew bundle check`/`brew bundle install` against that path — see [Bootstrap a new machine](#bootstrap-a-new-machine) above and `just brewfile` below |
| `run_onchange_after_30-mise-install.sh.tmpl` | both | `mise install --yes node rust` first (load-bearing: the `cargo:lincli` and future `npm:` backends need those two runtimes already present), then `mise install --yes` for everything else |
| `run_onchange_after_35-uv-tools.sh.tmpl` | both | for each `via: uv` entry, `uv tool upgrade` if already installed, else `uv tool install` with the full requirement string (so `dstack[server]`'s extra is preserved); skips cleanly with a note if `uv` itself isn't on `PATH` yet |
| `run_once_after_40-installers.sh.tmpl` | both | for each `via: installer` entry, `curl \| sh`/`curl \| bash` only if the binary is missing — `run_once_`, not `run_onchange_`, because omp and claude both self-update and omp's installer is a ~120MB download |
| `run_onchange_after_45-fontcache.sh.tmpl` | linux | `fc-cache -f` on the Nerd Font directory the external in `.chezmoiexternal.toml` fetched |
| `run_onchange_after_50-completions.sh.tmpl` | both | see [Completions](#completions) below |
| `run_onchange_after_60-agents.sh.tmpl` | both | installs/links `via: herdr` plugins, `via: omp` plugins, upserts `via: gh` extensions, installs `via: skill` cross-agent skills, and re-links `~/.omp/agent/skills` from every installed herdr plugin's own `skills/`/`.agents/skills/` directory |
| `run_onchange_after_70-services.sh.tmpl` | both | darwin: loads the dstack LaunchAgent if not already loaded (caddy's and dnsmasq's own LaunchAgents are deliberately *not* auto-loaded here — see their inventory rows above); linux: `systemctl --user enable --now dstack-server.service` |
| `run_onchange_after_80-nvchad.sh.tmpl` | both | hashes `linked/nvim/lazy-lock.json` at runtime against the last hash it wrote, and runs `nvim --headless "+Lazy! restore" +qa` only when that hash changed — see [NvChad's lockfile](#nvchads-lockfile--apply-restores-it-lazy-sync-moves-it) |
| `run_once_after_90-repo-hooks.sh.tmpl` | both | `pre-commit install` in the repo's own working tree, guarded on the binary and on `.git` existing |

### Remote installs — `just remote`

```sh
just remote andyhite-fab
```

Replaces the old `install.sh --host` driver. `just remote <host>` warns if the local tree
is dirty (the remote installs whatever `origin` has, not this working copy), then ssh's in
and either fast-forwards an existing `~/.dotfiles` clone with `chezmoi update --apply` or
runs `chezmoi init --apply` against a fresh one — installing `chezmoi` itself into
`~/.local/bin` first if it isn't already there. Nothing is piped over the wire: the remote
always ends up in a state some git ref actually describes.

### Completions

`zshrc` puts `~/.local/share/zsh/site-functions` first on `fpath` so a completion
generated from the installed binary beats a distro's stale copy. `run_onchange_after_50-
completions.sh.tmpl` writes one per `packages.yaml` entry that carries a
`postInstall: [{ zshCompletion: [<argv>] }]` step — the argv is run and its stdout becomes
`~/.local/share/zsh/site-functions/_<name>`. Adding a completion for a new tool is that one
line on its manifest entry, never a second file or a hand-maintained table.

`zshrc` also `source`s `<(carapace _carapace)` after antidote loads fzf-tab — carapace
ships built-in specs for roughly a thousand CLIs and feeds them through the same fzf-tab
popup as everything else. It does **not** replace the tools with their own `zshCompletion`
step: carapace has no spec for `omp`, `herdr`, `tree-sitter`, or `mise`, which is exactly
why those entries still carry a generator — the two mechanisms cover disjoint command
sets.

Deliberately absent from `postInstall` because something else already covers them: most
Homebrew-only formulae (git, gh, docker, …) via carapace; `fzf` from the `fzf --zsh` eval
in `zshrc`; `direnv` and `nvim`, which publish no zsh completion at all; and zsh itself
ships `_jq` and `_vim`.

Two details worth knowing, both load-bearing and both in the script itself. Generation
goes through a temp file and only replaces the target when the output is non-empty and
differs from what's already there, so a tool that starts erroring can't blank a working
completion. And because `zshrc` runs `compinit -C` — which trusts a cached dump rather
than rescanning `fpath` on every shell start — the script deletes `~/.zcompdump*` whenever
it actually writes something new, so the next shell rebuilds once.

### The `create_private_` secrets

Nine tracked entries, one convention: `create_private_dot_zshrc.local`,
`create_private_dot_gitconfig.local`, `private_dot_ssh/create_private_config.local`,
`dot_omp/agent/create_private_models.yml`, `dot_omp/agent/create_private_config.local.yml`,
`dot_dstack/server/create_private_config.yml`,
`dot_config/caddy/create_private_Caddyfile.local`, and
`dot_config/dnsmasq/create_private_dnsmasq.local.conf` are written at mode 0600 the first
time `chezmoi apply` runs, and left alone on every run after that — a filled-in file is
never clobbered by a re-apply. Each one holds real secrets or per-machine values that have
no business in a public repo. `create_private_dot_gitconfig-work.tmpl` is the ninth, and
the one exception to "hand-filled": it's rendered from the three `promptStringOnce`
answers (`workName`, `workEmail`) instead, since work identity isn't a secret — see
[Work identity](./AGENTS.md#work-identity) in `AGENTS.md`.

The two config templates among the first six exist because of how their tracked file reads
the copy back, not just as a place to dump overrides:

- `dot_gitconfig.tmpl` ends with `[include]` / `path = ~/.gitconfig.local`. Git applies
  repeated keys in file order, so an include at the very end wins over every default set
  above it — `~/.gitconfig.local` doesn't need to know what it's overriding, it just wins
  by coming last.
- `private_dot_ssh/config` *starts* with `Include ~/.ssh/config.local`, before any `Host`
  block. ssh takes the first value it finds for a given option, so the include has to come
  first or a later `Host github.com` block would shadow it instead of losing to it. A
  missing include target isn't an error in `ssh_config`, so this line is safe on a machine
  that hasn't applied yet.

`create_private_dot_zshrc.local` needs no such trick — `zshrc` just sources
`~/.zshrc.local` near the top, before the tool blocks that read values like `AWS_PROFILE`.

`models.yml` and `config.local.yml` don't land at `~/.*.local` like the first three — they
sit in `~/.omp/agent/`, beside `config.yml`, where omp looks for both. They're also the two
that ship inert rather than empty — `providers: {}` and `{}` respectively — because omp
validates each file's root as an object, and a copy trimmed to pure comments parses as
null: a validation warning for `models.yml`, a hard startup error for `config.local.yml`
(loaded via `PI_CONFIG_FILES`, which `zshrc` exports once the file exists). See
[the omp section](#omp--one-tracked-config-two-machines-different-accounts) for what goes
in each.

`dot_dstack/server/create_private_config.yml` follows the same convention, landing at
`~/.dstack/server/config.yml` — the rest of `~/.dstack` (the sqlite db, server/job/runner
logs, a generated ssh keypair) is state dstack writes itself, so only this one file is
templated. It ships with the `main` project defined but no backend configured — dstack's
docs require the project to exist even with zero backends — plus a commented RunPod block
showing where a real `api_key` goes.

`dot_config/caddy/create_private_Caddyfile.local` and
`dot_config/dnsmasq/create_private_dnsmasq.local.conf` are two more of these — the eighth
and ninth. They didn't use to qualify: caddy and dnsmasq used to run via `brew services`,
which reads config from `/opt/homebrew/etc`, outside chezmoi's destination directory
entirely, so the copy-once-at-0600 guarantee had to be reproduced by hand in
`run_onchange_after_70-services.sh.tmpl`. Now that both run under this repo's own
LaunchAgents instead (see [Caddy](#caddy--local-https-for-internal-only-dev-hostnames) and
[dnsmasq](#dnsmasq--wildcard-local-dns-via-macoss-per-domain-resolver) below), their
configs live under `~/.config` like everything else chezmoi manages, and get the same
`create_private_` treatment as the rest of this section.

### mise

Replaces the old per-language version manager: one binary instead of a plugin per language
(no `plugin add node`/`plugin add golang` to run on every machine), and it activates by
rewriting `PATH` on every prompt instead of installing shims — a version change in
`~/.config/mise/config.toml` is live in the shell you're already sitting in, with no
`reshim` step.

`home/dot_config/mise/config.toml.tmpl` renders one `"tool" = "version"` line per
`via: mise` entry in `packages.yaml`, and pins the five runtimes to exact versions on
purpose — `node = "26.7.0"`, not `"latest"` — so a machine doesn't silently drift to
whatever happened to be current the day someone applied. This lands at mise's **global**
config, `~/.config/mise/config.toml`, which mise resolves by walking up from the current
directory to `$HOME` and beyond — the same "nearest file wins" property `~/.tool-versions`
used to provide, so a project with its own `.tool-versions`/`mise.toml` still wins inside
that project.

A trailing `t` on a python version — `3.14.7t` versus the `3.14.7` pinned here — selects
the free-threaded (no-GIL) build. That's a distinct, opt-in variant, not a typo, so don't
"fix" it if it turns up somewhere else.

### `make` on macOS — `gmake`, not `gnumake`

Apple ships GNU make 3.81, from 2006, as *both* `make` and `gnumake` — so the obvious
`alias make=gnumake` looks like an upgrade but is a silent no-op, still 3.81. Homebrew's
`make` formula installs GNU make 4.x as `gmake` instead, specifically to dodge that name
clash, so `zshrc`'s macOS block aliases `make` to `gmake` once it finds Homebrew's copy —
`gnumake` was never the one worth reaching for.

### Shells with no line editor — `TERM=dumb`, or no tty

A coding agent shelling out, an editor's shell mode, a `zsh -ic` from a script: all
interactive zsh, none of them running zle. `zshrc` sets `_no_zle` when `TERM` is `dumb`,
the shell isn't interactive, or stdin isn't a terminal, and skips the prompt and the fzf
key-binding/completion scripts for the rest of the file.

It's a correctness fix, not a speedup. Both of those write to the caller's stderr before
its command has produced a byte:

```
[ERROR] - (starship::print): Under a 'dumb' terminal (TERM=dumb).
(eval):1: can't change option: zle
(eval):1: can't change option: zle
```

starship refuses to render into a terminal with no capabilities, and fzf's two scripts
snapshot `$options` and restore the array wholesale on the way out — which tries to set
`zle` back on, and zsh won't allow that where it turned it off. Everything that isn't
the interactive layer still runs: `PATH`, mise, `compinit`, aliases, direnv, and atuin
all load exactly as before, so a scripted shell resolves the same commands an interactive
one does.

## Notes by tool

### Git — rebase-first, with hunk and delta

`dot_gitconfig.tmpl` is deliberately rebase-oriented (`pull.rebase`, `rebase.autoStash`,
`rebase.autoSquash`, `rebase.updateRefs`, `rerere.enabled`, `rerere.autoupdate`) so
review fixups belong spread across existing commits rather than piled into one "address
review" commit at the tip. **delta** is the pager that finally renders those settings:
`core.pager = delta || less` and `interactive.diffFilter = delta --color-only || cat`.
The `|| less` / `|| cat` fallbacks are mandatory — git runs both through `sh -c`, so a
missing delta on a fresh machine falls through instead of bricking every `git diff`/`log`/
`show` and `git add -p`. `syntax-theme = none` disables delta's own syntax highlighting:
`delta --list-syntax-themes` ships only a light `GitHub` entry and no dark one, so there is
no bundled delta theme that matches GitHub Dark Default — delta is the one surface in this
repo that cannot match the palette at all, rather than approximating it.
`dot_config/lazygit/config.yml` reuses the same `[delta]` block with `pager: delta --dark
--paging=never` — `--paging=never` is load-bearing because lazygit already scrolls the
diff panel itself; a delta that also spawned `less` would deadlock the panel for input.

**hunk** owns `core.pager` and `diff.tool`. It sniffs stdin: a patch-like diff opens
the full-screen review UI, anything else (a `git log --oneline`, a non-diff `git show`)
falls through to a plain-text pager resolved from `HUNK_TEXT_PAGER`, then `PAGER`,
then `less -R` — a value that resolves back to hunk is skipped so git can't recurse
into its own pager. The `|| less` fallback on `core.pager` is still load-bearing
alongside that sniffing fallback: it covers a machine where the `hunk` binary itself
is missing, which the stdin-based fallback can't help with since hunk has to already
be running to sniff anything. `git review` (`!hunk diff`) reads a whole changeset in
one stream instead of git's per-file difftool pairing.

**delta** keeps exactly two jobs a full-screen TUI can't do: `interactive.diffFilter =
delta --color-only || cat` for `git add -p`, which parses delta's output line-for-line
to know what got staged, and lazygit's `diffRenderers.command = delta --dark
--paging=never`, which renders into a panel lazygit itself owns rather than a
terminal delta would have to take over. `dot_config/hunk/config.toml`
(`~/.config/hunk/config.toml`) sets `theme = "github-dark-default"` — hunk is
Shiki-backed and actually ships a theme with that exact id — plus
`line_numbers = true` to match delta's gutter and `agent_notes = true`, since this
machine's diffs are read almost entirely as agent-authored changesets rather than
opting the notes rail in per session.

**gitleaks** and **pre-commit** are both deliberate. `.pre-commit-config.yaml` runs
gitleaks at commit time for tokens, keys, and credential-shaped strings; the local
`just leakguard` hook is the other half, running the same work-identifier grep CI uses.
Gitleaks has no idea those strings matter — they look like ordinary words — and
leakguard would not catch a real API key. `run_once_after_90-repo-hooks.sh.tmpl` runs
`pre-commit install` so neither hook requires a manual opt-in on a fresh clone.

### Shell — carapace, fd, uv, and Linux clipboards

**carapace** initializes in `zshrc` after antidote loads fzf-tab (`source <(carapace
_carapace)` with `CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'`). It is skipped in
`TERM=dumb` / non-interactive shells for the same reason starship and fzf key bindings
are. See [Completions](#completions) for how it coexists with the generated
`_omp`/`_herdr`/`_tree-sitter`/`_mise` files.

**fd** backs `FZF_DEFAULT_COMMAND` and telescope's `find_files` picker. mise's registry
entry resolves to the real `fd` binary on both platforms, so the old Debian
`fd-find`-installs-as-`fdfind` shim this repo used to carry no longer applies.

**uv** is a mise tool (`aqua:astral-sh/uv`) on both platforms now, resolved through
`~/.local/share/mise/installs/uv`. The old shadowing trap — a standalone Astral install in
`~/.local/bin` silently outranking a Homebrew formula on `PATH`, with `brew upgrade` never
touching the winning copy — can't recur here: mise is the only source `packages.yaml`
names for `uv`, so there's nowhere to write a second one. `which -a uv` should show exactly
one path.

**wl-clipboard** and **xclip** install together on Linux (`apt`) so nvim's `+` register
can paste on either Wayland or X11.

### gh extensions — one manifest entry, install vs. upgrade

`packages.yaml`'s `via: gh` entries are the tracked source of truth, same shape as the
`via: herdr` and `via: skill` entries — one list, read rather than linked.
`run_onchange_after_60-agents.sh.tmpl`'s gh block runs after mise has put `gh` on `PATH`
and is independent of the config-file writes (extensions are per-user, not symlinked
files).

Install is not update: `gh extension install` fails on an already-installed extension, and
`gh extension upgrade` is the only command that moves an existing one forward — the script
checks `gh extension list` first and picks the right one. It checks `gh auth status` once
up front too; an unauthenticated box skips the whole manifest with a note rather than
failing once per entry. The one extension listed today is `seachicken/gh-poi` —
squash-merged branches never look merged to `git branch --merged`, and a worktree per
branch of stacked agent work means merged-branch churn is continuous rather than
occasional.

### btop — GitHub Dark Default theme, and the config-rewrite trap

`dot_config/btop/` is applied whole to `~/.config/btop/`: `btop.conf` sets `color_theme =
"github-dark-default"` and `dot_config/btop/themes/github-dark-default.theme` maps the
same hex values as `dot_config/starship.toml`'s `[palettes.github_dark_default]` and
`dot_config/atuin/themes/github-dark-default.toml` — Ghostty's actual rendered ANSI
colors. btop bundles 41 themes, none of them a GitHub theme, so a custom file is the only
way to run this palette here — there's no bundled candidate to fall back to instead.
`main_bg` in the theme is Ghostty's actual terminal background (`#0d1117`, GitHub Dark
Default) — btop always paints its own background pixels, so matching the real terminal is
what avoids a visible seam around the window, the same distinction
`dot_config/herdr/config.toml`'s contrast-repair block had to make.

`btop.conf` also sets `save_config_on_exit = false`, and that one isn't taste. btop's own
default is `true`, and on quit it rewrites its **entire** config file — every key, not
just the ones this file sets — back to disk. Confirmed by launching btop against a
one-line config and diffing before/after: it came back as a ~280-line dump of every
built-in option. Left at the default, the first `btop` + `q` after applying would
balloon this tracked file into that dump and turn it into a live, constantly-
diffing file the moment two machines quit btop with different terminal sizes or GPU
detection results. `save_config_on_exit = false` is what keeps this file exactly what's
tracked, forever.

### Docker Desktop

`docker-desktop`'s `packages.yaml` entry carries `args: "adopt: true"`, rendered verbatim
into the generated Brewfile's cask line: `/Applications/Docker.app` already exists on the
machine this repo runs on, and a plain `brew bundle` install aborts with "already an App"
unless adopt takes over the existing install. No Linux counterpart — Docker's apt repo is
a host-level decision, not a dotfiles one.

### Caddy — local HTTPS for internal-only dev hostnames

`dot_config/caddy/Caddyfile` is deliberately thin — `local_certs` and one `import` line —
because a real site block always names a real internal hostname and a real IP, neither of
which belongs in a public repo. `local_certs` is what makes that possible at all: it mints
certs from Caddy's own built-in CA instead of asking Let's Encrypt, which could never
issue for a hostname that isn't publicly resolvable. `caddy trust` installs that CA into
your keychain once, and every site the imported file defines is trusted with no browser
warning from then on.

The imported file, `~/.config/caddy/Caddyfile.local`, is created once from
`dot_config/caddy/create_private_Caddyfile.local` — inert until you uncomment a block and
fill in a real hostname and IP, same contract as
`private_dot_ssh/create_private_config.local`. `import Caddyfile.local` (no leading `/`)
resolves relative to the Caddyfile doing the importing, not the process's working
directory, so it always finds the sibling file regardless of who starts caddy or from
where. A single regex-matched wildcard block there can stand in for a whole family of
hostnames — `<service>-<port>` — without a new site block per port; the template shows the
pattern.

Caddy starts via this repo's own `Library/LaunchAgents/dev.caddy.plist`, not
`brew services` — caddy installs from mise (`aqua:caddyserver/caddy`), which ships no
service supervision of its own, so this repo owns that instead. It's deliberately not
loaded by any provisioning script — a machine with nothing to proxy doesn't need it
running — so start it once with
`launchctl load -w ~/Library/LaunchAgents/dev.caddy.plist`. Because it's a normal
user-scoped LaunchAgent (not `brew services`' own, which pins `HOME` to a fixed path for
every service it manages), it runs under your real login `HOME`, so Caddy's default
cert-storage location is wherever that user actually is. After editing the local
Caddyfile, apply it with `caddy reload --config ~/.config/caddy/Caddyfile` (no restart, no
dropped connections) rather than reloading the LaunchAgent.

### dnsmasq — wildcard local DNS via macOS's per-domain resolver

`/etc/hosts` has no wildcard syntax — every hostname needs its own literal line, which
doesn't scale to a naming scheme like `<service>-<port>.example.internal` where new
hostnames show up as often as new local services do. macOS's per-domain resolver
(`/etc/resolver/<domain>`) fixes that: any lookup under that one domain gets sent to a
resolver you name instead of the system default, and dnsmasq answers every hostname under
it — including ones that don't exist yet — with a single `address=/.<domain>/127.0.0.1`
line.

`dot_config/dnsmasq/dnsmasq.conf.tmpl` binds `127.0.0.1` on port `5453`, not the standard
`53`, so the LaunchAgent that starts it never needs root — macOS's own resolver keeps port
53 regardless, since `/etc/resolver` only redirects the one domain named there, not the
whole system. Its final line, `conf-file=~/.config/dnsmasq/dnsmasq.local.conf`, is the
actual domain list, deliberately not this tracked file: real internal hostnames don't
belong in a public repo. Unlike Caddy's `import`, dnsmasq has no notion of "relative to
this file", and the LaunchAgent sets no working directory, so that one line is templated
with `{{ .chezmoi.homeDir }}` rather than tracked as a literal path — the only templated
value in an otherwise-plain config.

`dnsmasq.local.conf` is created once from
`dot_config/dnsmasq/create_private_dnsmasq.local.conf`, same `create_private_` contract as
everything else in this section.

Wiring a new domain in is two steps this repo can't do for you, since the domain name
itself is the machine-local part:

```
# in ~/.config/dnsmasq/dnsmasq.local.conf
address=/.example.internal/127.0.0.1

# /etc/resolver/example.internal
nameserver 127.0.0.1
port 5453
```

dnsmasq starts via `Library/LaunchAgents/dev.dnsmasq.plist`, replacing
`brew services start dnsmasq` (dnsmasq isn't in mise's registry, so it still installs from
Homebrew — only its startup moved). Same reasoning as Caddy's plist: not loaded by any
provisioning script, since a machine with no wildcard domain to resolve doesn't need it
running — `launchctl load -w ~/Library/LaunchAgents/dev.dnsmasq.plist` to start it.
dnsmasq doesn't watch its config for changes, so picking up an edit to `dnsmasq.local.conf`
needs `launchctl kickstart -k gui/$(id -u)/dev.dnsmasq` (or unload/reload the same plist).

### omp — one tracked config, two machines, different accounts

`dot_omp/agent/config.yml` is applied to `~/.omp/agent/config.yml` and shared by every
machine. `modelRoles` and `retry.fallbackChains` in it name only the two built-in
provider ids every machine is expected to authenticate — `anthropic` (subscription
primary, from `modelRoles`) and `cursor` (subscription, employer-billed on both
machines) — as one thin fallback tier:

```yaml
default:
  - anthropic/claude-sonnet-5   # modelRoles primary — subscription
  - cursor/composer-2.5         # fallback chain — subscription, shared by every machine
```

`openai` and `openai-codex` are deliberately absent from the tracked file: not every
machine authenticates them, and unlike an unresolvable built-in id (skipped silently —
omp validates every fallback-chain entry against its model catalog, not against
credentials), a chain that leaned on them for its only real fallback tier would leave a
machine with none at all the moment `cursor` also failed. A machine that wants more tiers
adds them locally instead of thinning the shared default for everyone.

**Which account pays — an auth question, not a routing one.** The provider name doesn't
change: `anthropic` is `anthropic` everywhere, reached with a subscription OAuth token
wherever one is logged in. omp resolves credentials in a fixed order, and a stored OAuth
session beats every environment variable:

```
1  --api-key (runtime)          5  provider env var, incl. .env files
2  models.yml apiKey            6  other stored API key
3  stored OAuth credential      7  models.yml custom-provider resolver
4  login-sourced stored key
```

So exporting `OPENAI_API_KEY` on a box that has ever run `/login openai-codex` does
nothing for the bare `openai-codex` id — the subscription keeps paying, silently, and
nothing warns you. Pinning a built-in id's credential (`providers.openai.apiKey` in
`~/.omp/agent/models.yml`) replaces the one credential that id resolves to; it works when
nothing else on the machine needs that id's other credential at the same time. Two
credit tiers for the same upstream account, both wanted as distinct ordered fallback
tiers, need two distinct provider ids instead — see `dot_omp/agent/create_private_models.yml`
for that pattern (self-hosted or trial providers use it too).

**A machine's own model routing lives in `~/.omp/agent/config.local.yml`, not
`config.yml`.** `zshrc` exports `PI_CONFIG_FILES` pointing at it so omp layers it as a
CLI config overlay on top of the shared `config.yml` — a deep merge of settings objects,
so only the keys a machine actually sets override anything. This is where a machine that
authenticates `openai` adds it back in as a real fallback tier, ahead of the shared
`cursor`-only chain:

```yaml
# ~/.omp/agent/config.local.yml
retry:
  fallbackChains:
    default:
      - openai/gpt-5.6-terra:medium
      - cursor/composer-2.5
```

A whole chain replaces per role rather than merging — a YAML list is a leaf value, not a
mapping, so a deep merge overwrites it outright — which is exactly what's wanted here:
`anthropic` (primary, from `modelRoles`) falls through to this machine's own
`openai -> cursor`, not to the tracked file's bare `cursor`. It's also where a machine
trials a model only it has a key for, e.g. pointing `task`/`smol` at a different
provider's models via `modelRoles`, or references a custom provider from its own
`models.yml`.

It has to ship as a valid object even with nothing overridden: `PI_CONFIG_FILES` pointing
at a missing or unparsable file is a hard omp startup error, not a silent skip the way an
unauthenticated built-in provider is — unlike `models.yml`'s validation-warning failure
mode, a bad overlay here refuses to start at all. The shipped copy carries a literal `{}`
for exactly that reason.

**Why a custom provider id is normally forbidden in the shared chains, and stays out of
them entirely.** omp validates every fallback-chain entry against its model catalog, not
against credentials: an unresolvable *built-in* id (no credential) is skipped silently,
but an unresolvable *custom* id (missing from that machine's `models.yml`) warns once per
role at every startup:

```
Warning: Fallback chain for role 'default' references unknown model: fireworks/kimi-k2.7-code
```

That is why the tracked `config.yml` allows only omp's built-in ids and nothing else — a
custom id has no guarantee every machine defines it, so it belongs in that machine's own
`config.local.yml` overlay instead, where an undefined reference only warns on the one
machine that added it.

`~/.omp/agent/models.yml` is created from `dot_omp/agent/create_private_models.yml` on
every machine, so the mechanism is discoverable even where a given machine only uses part
of it. Both it and `config.local.yml` ship inert but not empty — `providers: {}` and `{}`
respectively — because omp validates each file's root as an object and a copy trimmed to
pure comments parses as null.

That leaves nothing per-machine in `config.yml` at all, which is the point: one tracked
file with a deliberately thin default, every machine, and the only differences are which
providers each one has authenticated and what it chose to layer on top locally.

### omp compaction — a fold is priced in cache, not tokens

`compaction` in `dot_omp/agent/config.yml` is tuned against measured spend rather than
comfort. Across 61k Anthropic messages, 44% of the bill came from requests carrying a
cached prefix over 200k tokens, and Anthropic's 1M window charges no long-context
premium — so every extra cached token was a straight linear cost with nothing bought
back. Both knobs below exist to keep that prefix small, against the one cost a fold
actually has: rewriting the head of the history invalidates the prompt cache from that
point forward, plus one summarizer call.

`thresholdPercent: 40` is an explicit percent-of-window trigger where omp's own default is
`-1` (reserve-based, which only fires once the window is nearly full). It read 55 for as
long as `billion-context-omp` was installed: that extension's forced-nudge floor is
hardcoded at 45%, so omp's snapcompact had to sit above it or the plugin's whole tier was
unreachable. The plugin is gone and the floor with it — 40 is the number the spend data
produced on its own.

`idleEnabled: true` (omp ships it off) is the cheapest fold available and the only one that
targets the 200k figure directly. It fires only above `idleThresholdTokens` (200000) and
only after `idleTimeoutSeconds` (120, down from upstream's 300) of idle, so it folds
precisely the sessions whose oversized prefix is about to be re-read many more times, and
it spends the fold when no turn is waiting on it. The token guard is what keeps it honest:
below 200k there is not enough prefix to earn back the cache a fold invalidates. The
shortened timeout means a session left alone has already folded by the time it's picked
back up, instead of paying the oversized prefix on the next turn and folding after it.

### Atuin

`dot_config/atuin/config.toml` holds overrides only; run `atuin default-config` to see
the full annotated template. It exists mainly so `atuin setup` never runs: that wizard is
what asks about Atuin AI and the daemon. With the answers committed, mise's own atuin
install has nothing left to ask interactively.

Sync is never configured: this history stays on the machine, so there's no account state
to set up and nothing to prompt for.

`dot_omp/agent/extensions/atuin.ts` records commands omp runs through its `bash` tool
into the same history, tagged `--author pi` — omp is a distribution of pi, and "pi" is
one of the five names in Atuin's `KNOWN_AGENTS`, which is what makes the agent
pseudo-filters work:

```sh
atuin search --author pi            # just the agent
atuin search --author '$all-agent'  # any known agent
atuin search --author '$all-user'   # just me
```

`$all-user` is applied to every interactive search, so agent rows stay out of `Ctrl+R`
and out of the up-arrow list without any configuration. The one gap is a *typed* `Ctrl+R`
query: it's answered by the daemon's index, which has no author column, so agent rows
reappear there. The up-arrow search is exempt because it's pinned to the sqlite engine
(`search_mode_shell_up_key_binding`).

Rows recorded before this switch keep `--author omp` and behave like hand-typed commands.
Retagging them isn't worth it: `history.db` is a projection of the record store, so a
sqlite `UPDATE` would be reverted by the next `atuin store rebuild history`.

Two things had to be fixed for Atuin to behave under `zsh-vi-mode`, and both fail
silently, so they're worth knowing about if either ever regresses.

**Ctrl+R.** Being last in `zshrc` isn't enough to own it. `zsh-vi-mode` rebuilds the
`viins`/`vicmd` keymaps during its own init, which runs on the first `precmd` — after
every line of `zshrc` — and its insert mode re-binds `^R` to zsh's builtin
`history-incremental-search-backward`. The binding Atuin installed survived only in the
`emacs` keymap, which vi mode never uses, so `Ctrl+R` was the builtin search. `zshrc`
now defers `atuin init zsh` into `zvm_after_init_commands` (still binding inline when the
plugin isn't loaded) and adds the `vicmd` `^R` that Atuin itself leaves to `fzf`. Check
it with:

```sh
for m in emacs viins vicmd; do bindkey -M $m "^R"; done   # all three -> atuin-search*
```

**Keymap mode.** The widgets Atuin installs pass `--keymap-mode=vim-insert`/`vim-normal`,
but config beats that flag for every value except `auto`, and the default is `emacs` —
so the search opened in emacs keymap and threw the shell's actual mode away. Hence
`keymap_mode = "auto"` in the config.

### herdr — mise on both platforms

`herdr`'s `packages.yaml` entry is `via: mise` on both platforms — mise's registry
resolves it directly, the same as every other CLI in the "mise, both platforms" section of
the manifest. No Homebrew formula, no curl installer, and no `~/.local/bin`-shadows-
Homebrew trap to watch for: mise is the only source this manifest names, so there's
nowhere for a second copy to come from. `which -a herdr` should show exactly one path,
under `~/.local/share/mise/`.

### Herdr plugins — one manifest, herdr's registry stays untracked

Herdr keeps its installed-plugin state in `~/.config/herdr/plugins.json`, which it
rewrites on every install: absolute paths, resolved commit SHAs, install timestamps.
That's generated state, not config, so it stays out of this repo — the `via: herdr`
entries in `packages.yaml` are the tracked source of truth instead:

```yaml
- { name: herdr/vim-herdr-navigation, all: { via: herdr, id: paulbkim-dev/vim-herdr-navigation } }
- { name: herdr/ticket-worktree,      all: { via: herdr, id: "local:linked/herdr-plugins/ticket-worktree" } }
```

An `id` with no `local:` prefix installs a GitHub `owner/repo` the normal way
(`herdr plugin install <id>`); a `local:<path>` id resolves the path against
`{{ .chezmoi.workingTree }}` and link-installs it instead
(`herdr plugin link <path>`), so a plugin still being developed in this repo stays live
rather than frozen at install time. To add a plugin, add the entry and re-apply — or run
`herdr plugin install <owner>/<repo> --yes` now and add the entry so the other machine
picks it up on its next apply. To remove one, delete the entry and run
`herdr plugin uninstall <plugin-id>` by hand — nothing prunes plugins automatically, since
removing a plugin also throws away whatever config it had.

A plugin you're developing on this machine is the one case where re-applying would do
damage if it weren't for the `local:` handling above: `herdr plugin link <path>` and
`omp plugin link <path>` point the manager at a working checkout, and installing the
published copy over one of those replaces the link — the checkout keeps existing but stops
being what runs. `run_onchange_after_60-agents.sh.tmpl` always runs `herdr plugin link` for
a `local:` entry, never `herdr plugin install`, so this can't happen by accident here.

Four plugins used to be listed and aren't any more. `ribbons-digital/pi-herd` hardcoded
`--name` and `--session-id` into every harness launch, and omp — the agent this setup
drives — hard-errors on `unknown flags: --name, --session-id`; it also shipped a Pi-only
extension. It couldn't drive omp without patching, so it was dropped rather than carried
as permanently broken.

`AltanS/collie` — a mobile web UI for the herd, served over Tailscale — was removed
because it wasn't wanted, not because it was broken. Worth recording is that taking it
out was three steps, not one: a plugin that installs a service owns state herdr knows
nothing about. `herdr plugin action invoke uninstall --plugin herdr.collie` came first,
to pull the `herdr.collie` LaunchAgent and the `tailscale serve` mapping the bridge had
published to the tailnet; then `herdr plugin uninstall herdr.collie`; then its config
directory, which `herdr plugin uninstall` leaves behind and which held a `.env` of VAPID
push keys. Uninstalling the plugin alone would have left a service running against a
plugin that no longer existed.

`razajamil/herdr-plugin-workspace-manager` — declarative tab/pane layouts applied to
each new worktree — went the same way once a per-worker dispatch tool started building
the workspaces it dispatches into itself. Two things arranging one fresh worktree is a race other plugins
have hit before, and the plugin only ever won it on a repo it had
a YAML layout for; every other worktree got the bare pane anyway. Removal was two
steps: `herdr plugin uninstall herdr-plugin-workspace-manager` on each machine, then
its config directory — which lives in `linked/herdr-plugin-config`, so deleting
`linked/herdr-plugin-config/herdr-plugin-workspace-manager` here clears it everywhere
the tree is linked. The one capability lost with it is `remove-gone`, which previewed
and cleared worktrees whose upstream branch had been deleted; `herdr worktree list`
then `herdr worktree remove --workspace <id>` is the manual form.

`nikok6/herdr-mirror` — a remote herdr's workspaces mirrored into this one's sidebar
over ssh, remote panes streaming into local ones — was removed because it wasn't
wanted. It took the `# local-only` manifest marker with it: mirror was the only entry
that ever carried one, and manifest entries no longer carry per-line markers at all now
that the list is a structured YAML entry per tool rather than plain text. Removal was
four steps, and collie is the reason to expect that: a plugin that runs a daemon owns
state herdr knows nothing about. `herdr plugin action invoke teardown --plugin mirror`
came first, closing every mirrored workspace and pausing autostart; then `herdr plugin
uninstall mirror` — no `--yes` there, uninstall rejects that flag as a usage error
where install requires it; then `linked/herdr-plugin-config/mirror`, which deleting here
clears everywhere the tree is linked. The fourth is the one teardown doesn't do:
`~/.local/state/herdr-mirror` held a per-host ssh ControlMaster started with
`ControlPersist=yes`, so an `ssh -N` to the remote outlived the daemon, the plugin and the
uninstall. Closing it takes `ssh -S ~/.local/state/herdr-mirror/<host>.ctl -O exit <host>`;
then the state directory goes, along with the empty `~/.config/herdr-mirror` that pre-dated
the move of `hosts.toml` into this repo. Only the laptop needed any of it, since
local-only meant mirror was never installed anywhere else. `prefix+alt+n`, `prefix+alt+c`,
`prefix+alt+v` and `prefix+alt+s` are free again, and the palette lost ten of its
thirty-three actions with it.

With two plugins and four registered actions between them, keybindings stopped
being a per-plugin question and became one decision: `dot_config/herdr/palette/palette.sh`,
bound to `prefix+p` — free because this config moved herdr's own `previous_tab` off it
and onto `prefix+shift+tab` — builds its fzf list at run time from `herdr plugin action
list`, so every action of every installed plugin is one fuzzy search away whether or not
it has a key. Only the ones reached for constantly earn a `[[keys.command]]` entry;

`andyhite.ticket-worktree` — the `prefix+t` binding — lives in this repo at
`linked/herdr-plugins/ticket-worktree` and is registered through its `packages.yaml`
`local:` entry (same status command-palette had before it got its own repo: iterate
in-tree without a separate GitHub repo). Re-applying re-links it idempotently via
`herdr plugin link`. The plugin is a single manifest `[[panes]]` entry (`placement =
"popup"`) rather than an action, for the same TTY reason command-palette isn't an action
either — `modal.sh` draws its own form (text field, live `ticket/<key>` branch preview,
Create/Cancel buttons, one screen) in raw-mode ANSI to keep the form on one screen. From
the parsed key it calls `herdr worktree create`, `herdr agent start --kind omp`, and
`herdr pane send-text` (not `agent prompt`, which would submit immediately) to land the
ticket as a queued-but-unsent prompt. Its config
(`linked/herdr-plugin-config/andyhite.ticket-worktree/config.toml`) defaults the new
worktree to opening in the background; set `focus = true` there to switch to it immediately
instead, matching plain `prefix+shift+g`'s own default worktree behavior.

That palette started as the `JanTvrdik/herdr-command-palette` plugin and is now a script
in this repo, for two reasons that are really one. fzf needs a TTY; a herdr plugin action
runs on the server without one, so the plugin had to host the picker in an `overlay`
plugin pane, and an overlay covers the whole canvas — a command palette that takes the
screen is a tab, not a palette. A `type = "popup"` keybinding gets a TTY directly and is
session-modal, so the plugin's only job disappeared along with the full-screen overlay.
The fork also rewrote the rows: upstream led each one with a `plugin.action` id up to 42
characters wide, which buried the words you actually read behind an id and left the
titles in a ragged column. Titles come first now, in a fixed column, with the plugin id
trailing and dimmed. It stays visible rather than hidden in the invoke-only field
because fzf matches against what it displays, so a hidden field can't be searched.

### Herdr plugin keybindings — `[keys]` only knows herdr's own actions

herdr's `[keys]` table takes only its own built-in action names — there's no field in
it that names a plugin action. The only way to bind one to a key is `[[keys.command]]`,
which shells back out to the herdr CLI instead of naming the action in config:

```toml
[[keys.command]]
key = "ctrl+h"
type = "shell"
command = "herdr plugin action invoke left --plugin vim-herdr-navigation"
```

`type` controls how the command surfaces: `shell` runs it detached in the background,
`pane` opens a temporary pane that closes when the command exits, `popup` opens a
session-modal terminal. Plugin actions invoked this way are short control commands with
no output worth watching, so `shell` is the right call almost every time.

Some plugin READMEs still document
`type = "plugin_action"` with a combined `<plugin>.<action>` command string
instead of this. That form is stale: `herdr --default-config` on 0.8.0 documents only
`shell`/`pane`/`popup`, and `plugin_action` isn't one of them. Use the `shell`-plus-CLI
form above regardless of what a given plugin's own docs say.

### lin — mise's cargo backend, both platforms

`lin` ([aaronkwhite/linear-cli](https://github.com/aaronkwhite/linear-cli)) has no
Homebrew core formula, no apt package, and no mise registry entry
(`mise registry | awk '$1=="lin"'` is empty), so its `packages.yaml` entry pins the
`cargo:lincli` backend directly — the crate name (`lincli`) and the binary name (`lin`)
differ. It's the one entry in the manifest that names a cargo backend rather than a plain
registry name, which is why `rust` is also `via: mise` on both platforms rather than
Homebrew's on macOS: the cargo backend needs a `cargo` on `PATH` regardless of OS, and
`run_onchange_after_30-mise-install.sh.tmpl` installs `rust` before the bare
`mise install --yes` that resolves `lin`. No config file is tracked for it —
`lin auth login` (interactive) or the `LINEAR_API_KEY` environment variable authenticates
it per machine, same as any other credential this repo deliberately keeps out of tracked
content.

### Agent skills — one manifest, the lockfile isn't tracked

Same shape as Herdr plugins above: the `via: skill` entries in `packages.yaml` are the
tracked source of truth, one entry per skill name, and the state the CLI generates
alongside it — `~/.agents/.skill-lock.json`, content hashes and install/update
timestamps — stays untracked.

`run_onchange_after_60-agents.sh.tmpl` runs `mise exec -- npx skills add <id> --skill
<name> -g -y` for each entry — `-g` writes one canonical copy of the skill into
`~/.agents/skills` and symlinks every agent the CLI detects at that tree, instead of
installing into a single project; `-y` accepts its prompts so this can run with no tty
attached. omp needs no install target of its own here — it picks skills up through its
`agents` skill provider, reading `~/.agents/skills` directly rather than needing anything
copied into `~/.omp/agent/skills`.

(`~/.omp/agent/skills` is a separate, narrower thing: the same script also symlinks any
skill an installed Herdr plugin ships in its own `skills/` directory there — unrelated to
the `via: skill` entries.)

Skill names are prefixed `skill/` in the manifest (`skill/apple-design`, not
`apple-design`) — that's the naming rule every non-executable entry follows (herdr
plugins get `herdr/`, gh extensions get `gh/`), because `just data` enforces globally
unique names across the whole list and a skill name and a binary name could otherwise
collide.

### NvChad — diffview alongside telescope `git_status`

`linked/nvim/lua/plugins/init.lua` adds **diffview.nvim** next to NvChad's telescope
`git_status` picker, not instead of it. Telescope builds its file list once at open; the
`<C-g>` reload mapping closes and reopens the picker because telescope has no native way
to notice the index changed under it — still the right tool for jumping to a changed file
by name. diffview is for sitting inside the diff: a live file panel, a diff view that
tracks staging and edits, and a 3-way merge-conflict view telescope has no equivalent for.

Four mappings in `lua/mappings.lua`: `<leader>gd` (`DiffviewOpen`), `<leader>gc`
(`DiffviewClose`), `<leader>gh` (`DiffviewFileHistory %`), `<leader>gH`
(`DiffviewFileHistory`). The plugin is command-gated (`cmd = { … }`) so normal edits do
not pay to load it.

### NvChad's lockfile — apply restores it, `:Lazy sync` moves it

`linked/nvim/lazy-lock.json` is tracked, which makes it the pinned plugin set every
machine converges on. That only works if machine installs read it rather than write it,
so `run_onchange_after_80-nvchad.sh.tmpl` runs `Lazy! restore` and not `Lazy! sync`.

`sync` is the wrong verb for a shared lockfile: it updates every plugin to its latest
commit and rewrites the file. `~/.config/nvim` is a live symlink into `linked/nvim/`, so
that rewrite lands as an uncommitted change *in the repo* — harmless locally, and a real
problem on a remote where nobody's there to notice and commit it.

`restore` converges the other way. lazy's startup auto-install already clones anything
missing with `lockfile = true`, i.e. at the pinned commit, and `restore` puts any plugin
that drifted back on its pinned commit. lazy rewrites the lockfile either way, but with
every plugin sitting at the commit already recorded there the bytes come out identical
and git sees nothing. The script skips the restore entirely when a runtime hash of
`lazy-lock.json` matches the hash it wrote last time, so a normal apply doesn't even
launch nvim headlessly unless the lockfile actually changed.

Moving the pins is therefore deliberate, and belongs on one machine: run `:Lazy sync` in
a real session, then commit the bump (`chore(nvim): bump … lockfile`). Every other
machine picks it up on its next apply.

### NvChad's Mason/Treesitter setup — do this yourself, on purpose

NvChad's own quickstart docs say to run `:MasonInstallAll` and `:TSInstallAll` after the
first sync. Neither does what the docs imply on the current starter: `MasonInstallAll`
isn't a real command in `mason.nvim`, and `TSInstallAll` silently no-ops — the actual
command is `:TSInstall <lang>`, and `:TSInstall all` grabs *every* language
nvim-treesitter supports, which is not a sane default for anyone. Neither Mason nor
Treesitter auto-installs on first file-open in this config either. Nothing in this repo
papers over this with a guessed default set — install what you actually use:

```
:MasonInstall pyright lua-language-server   " example, not a real default
:TSInstall python lua bash
```

or declare an `ensure_installed` list in `lua/configs/mason.lua` /
`lua/configs/treesitter.lua` once you know what those are.

### Ghostty over SSH — `TERM=xterm-ghostty` doesn't exist on most remotes

Ghostty's `TERM` is `xterm-ghostty`, and most remote hosts don't have that terminfo
entry — without a fix, anything that opens a real terminal (`nvim` included) fails with
`Error opening terminal: xterm-ghostty` the moment you SSH in. `dot_config/ghostty/config`
sets:

```
shell-integration-features = cursor,sudo,title,ssh-env,ssh-terminfo
```

`ssh-terminfo` makes Ghostty's shell integration wrap interactive `ssh` calls, install
Ghostty's terminfo entry on the remote via `tic` the first time you connect (cached
after that, keyed by `user@host`), and fall back to `TERM=xterm-256color` automatically
if the install fails (no `tic` on the remote, etc.). `ssh-env` separately forwards
`COLORTERM`/`TERM_PROGRAM` so the remote shell can detect it's inside Ghostty — it does
**not** touch `TERM` on its own, so `ssh-terminfo` is the one actually preventing the
crash.

The wrapper is a shell function, so it only covers plain interactive `ssh` typed at a
prompt — not scripts run non-interactively, and not wrapper tools that spawn `ssh`
themselves (`mosh`, `gcloud compute ssh`, `git`/`rsync` over ssh, etc.). For those, or as
a one-off manual fix on a host you don't want Ghostty auto-installing terminfo onto:

```sh
infocmp -x xterm-ghostty | ssh host -- tic -x -
```

### Hammerspoon — per-Space Ghostty toggle, Ghostty's own is app-wide

Ghostty's built-in global show/hide keybind (`global:ctrl+enter=toggle_visibility`) is
app-wide: run one Ghostty window per macOS Space and it always jumps to whichever window
was most recently focused, instead of showing/hiding the one on the Space you're actually
on — see [ghostty-org/ghostty#11084](https://github.com/ghostty-org/ghostty/discussions/11084).
There's no Ghostty-side fix, so `dot_hammerspoon/init.lua` replaces the keybind
entirely: an `hs.window.filter` scoped to Ghostty with `currentSpace = true` finds the
window that belongs to the current Space (minimized or hidden windows included — they're
Space-agnostic in macOS, so a naive `visible`-only filter would miss one and spawn a
duplicate instead of restoring it), then hides the whole app (`hs.application:hide()` —
the same instant, no-genie-animation mechanism as Cmd+H, which is what Ghostty's own
toggle already used and the one part of it that was never broken) if that window is
focused, unhides and focuses it otherwise, or runs `ghostty +new-window` if the Space has
none.

Cask, not brew, and macOS-only in every sense — Hammerspoon has no Linux port and no
headless use, so its `packages.yaml` entry names `darwin` only (same treatment as Docker
Desktop above); `dot_hammerspoon/init.lua` is excluded on Linux entirely by
`.chezmoiignore`, rather than applied somewhere it can do nothing.

Launch-at-login is Hammerspoon's own preference toggle (menu-bar icon → Preferences →
"Launch at Login"), not something this repo tracks — deliberately: unlike dstack's server
(a background daemon with no UI of its own, hence its tracked LaunchAgent), Hammerspoon
already ships a working, per-machine-appropriate way to do this, and duplicating it with a
second tracked LaunchAgent just meant two mechanisms fighting over the same job.

## Making changes

Editing under `home/` does **not** change the live machine — chezmoi copies on apply, it
doesn't symlink. `linked/` is the one exception: those trees are live-symlinked into
`$HOME`, so editing them changes the running config immediately. See
["Copy mode vs. `linked/`"](./AGENTS.md#copy-mode-vs-linked) and
["Editing a tracked file"](./AGENTS.md#editing-a-tracked-file) in `AGENTS.md` for the two
edit loops (`chezmoi edit --apply <target>`, or edit under `home/`/`linked/` then
`chezmoi apply`). Commit and push, then `chezmoi update --apply` (or `just remote <host>`)
on the other machine to pick it up.

### Justfile and CI

The **`Justfile` is the single source of truth for checks.** `.github/workflows/ci.yml`
invokes its recipes and nothing more — a new check gets a recipe plus a one-line CI step,
never a command pasted into `ci.yml` a second time. Recipes assume their dependencies
(`chezmoi`, `shellcheck`, `jq`, `zsh`) are already on `PATH` and install nothing
themselves; CI's setup steps install them once before any recipe runs.

| Recipe | What it catches |
| --- | --- |
| `just data` | `packages.yaml` parses and every entry is well-formed — a typo'd `via` or a duplicate `name` |
| `just templates` | every `*.tmpl` under `home/` renders for both darwin and linux with no prompt answers supplied |
| `just scripts` | every `.chezmoiscripts/*.sh.tmpl` renders for both platforms and passes `shellcheck -S warning` |
| `just zsh-syntax` | `zsh -n` on `dot_zshenv`, `dot_zshrc`, and the rendered `create_private_dot_zshrc.local` |
| `just leakguard` | work identifiers and committed `"ssh_connections":` blocks in tracked content — the sole remaining guard now that Zed writes the key into project-local settings instead |
| `just brewfile` | prints the Brewfile `run_onchange_after_20-brew-bundle.sh.tmpl` would generate — there is no tracked Brewfile to read directly |
| `just check` | `data`, `templates`, `scripts`, `zsh-syntax`, `leakguard` — the fast gate before every commit |
| `just smoke` | applies the whole tree into a throwaway destination twice with `--exclude scripts,externals`; the second run must leave `chezmoi verify` clean |
| `just remote <host>` | applies this repo's chezmoi state on a remote host over ssh — see [Remote installs](#remote-installs----just-remote) above |

Run `just check` and `just smoke` locally before pushing — same as `AGENTS.md`. CI runs
three jobs: **lint** (`data`, `templates`, `scripts`, `zsh-syntax`, `leakguard`, on
`ubuntu-latest`), **apply** (`just smoke` plus explicit target-shape assertions on Linux —
`.zshrc`/`.gitconfig`/`.omp/agent/config.yml` exist as regular files, every
`create_private_` target exists and is not a symlink, `Library/` is absent), and
**darwin** (a real `macos-latest` runner asserting the inverse — the LaunchAgent plist and
the lazygit `Library/Application Support` symlink exist, `.config/systemd` is absent).
`darwin` replaces the old CI's stub-`uname` trick for faking macOS on an Ubuntu runner —
this is the check that trick could never actually perform.

Changes land as a direct push to `main`. CI runs on every push, on every branch, so the
checks still report whether a change went straight to `main` or through a branch first.
