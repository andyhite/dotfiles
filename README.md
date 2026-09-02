# dotfiles

Shell and terminal config, synced between my Mac (Ghostty) and remote dev VMs. GitHub Dark
Default theme everywhere, zsh with antidote, starship for the prompt, NvChad for editing.

Applied with [chezmoi](https://chezmoi.io) and [mise](https://mise.jdx.dev). See
`AGENTS.md` for how to change things here.

## Contents

- [What's in here](#whats-in-here)
- [Bootstrap a new machine](#bootstrap-a-new-machine)
- [Making changes](#making-changes)

## What's in here

### Shell & prompt

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_zshrc` | `~/.zshrc` | zsh config: completion, antidote plugin load, history, aliases, tool init hooks |
| `home/dot_zshenv` | `~/.zshenv` | `PATH` setup read by every zsh invocation |
| `home/dot_zsh_plugins.txt` | `~/.zsh_plugins.txt` | antidote's plugin list (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, zsh-vi-mode) |
| `home/dot_config/starship.toml` | `~/.config/starship.toml` | prompt config |
| `home/dot_config/atuin/config.toml` | `~/.config/atuin/config.toml` | Atuin (shell history) config |
| `home/dot_config/atuin/themes/github-dark-default.toml` | `~/.config/atuin/themes/github-dark-default.toml` | Atuin theme |
| `home/create_private_dot_zshrc.local` | `~/.zshrc.local` (created once, mode 0600) | machine-local secrets — never committed |

### Terminal & workspace

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_config/ghostty/config` | `~/.config/ghostty/config` | Ghostty terminal config |
| `home/dot_hammerspoon/init.lua` | `~/.hammerspoon/init.lua` (macOS only) | Hammerspoon: per-Space Ghostty show/hide toggle |
| `home/dot_config/btop/` | `~/.config/btop/` | btop resource monitor config |
| `home/dot_config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager) config |
| `home/dot_config/herdr/palette/` | `~/.config/herdr/palette/` | the `prefix+p` command palette |
| `home/dot_config/herdr/layout/` | `~/.config/herdr/layout/` | the `prefix+f` fold command |
| `home/dot_config/herdr/plugins/symlink_config.tmpl` | `~/.config/herdr/plugins/config` → `linked/herdr-plugin-config` | per-plugin Herdr config |
| `linked/herdr-plugins/ticket-worktree/` | reached via `herdr plugin link` | the `prefix+t` ticket-to-worktree plugin |
| `home/dot_config/caddy/Caddyfile` | `~/.config/caddy/Caddyfile` (macOS only) | base Caddyfile |
| `home/dot_config/caddy/create_private_Caddyfile.local` | `~/.config/caddy/Caddyfile.local` (created once, mode 0600) | machine-local site blocks, never committed |
| `home/dot_config/dnsmasq/dnsmasq.conf.tmpl` | `~/.config/dnsmasq/dnsmasq.conf` (macOS only) | base dnsmasq config |
| `home/dot_config/dnsmasq/create_private_dnsmasq.local.conf` | `~/.config/dnsmasq/dnsmasq.local.conf` (created once, mode 0600) | machine-local wildcard-domain records, never committed |
| `home/Library/LaunchAgents/dev.caddy.plist` | `~/Library/LaunchAgents/dev.caddy.plist` (macOS) | LaunchAgent for caddy — load by hand with `launchctl load -w` |
| `home/Library/LaunchAgents/dev.dnsmasq.plist` | `~/Library/LaunchAgents/dev.dnsmasq.plist` (macOS) | same, for dnsmasq |

### Editor

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_config/symlink_nvim.tmpl` | `~/.config/nvim` → `linked/nvim` | [NvChad](https://nvchad.com) config, including `lazy-lock.json` |
| `home/dot_config/zed/settings.json` | `~/.config/zed/settings.json` | Zed editor settings |

### Git

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_gitconfig.tmpl` | `~/.gitconfig` | git identity, LFS/xet filters, rebase-first defaults, hunk pager/difftool |
| `home/create_private_dot_gitconfig.local` | `~/.gitconfig.local` (created once, mode 0600) | work identity, private-registry credentials |
| `home/create_private_dot_gitconfig-work.tmpl` | `~/.gitconfig-work` (created once, mode 0600; skipped when `workGitDir` is blank) | work git `[user] name`/`email` |
| `home/dot_config/git/ignore` | `~/.config/git/ignore` | global gitignore |
| `home/dot_config/gh/config.yml` | `~/.config/gh/config.yml` | gh CLI defaults and aliases |
| `home/dot_config/lazygit/config.yml` | `~/.config/lazygit/config.yml` (Linux) | Lazygit config — exposed as `lg` |
| `home/Library/Application Support/lazygit/symlink_config.yml.tmpl` | `~/Library/Application Support/lazygit/config.yml` → `home/dot_config/lazygit/config.yml` (macOS) | same file, macOS location |
| `home/dot_config/hunk/config.toml` | `~/.config/hunk/config.toml` | Hunk review-stream viewer config — wired as `core.pager` and `diff.tool` |
| `home/private_dot_ssh/config` | `~/.ssh/config` (mode 0600) | portable ssh identity config |
| `home/private_dot_ssh/create_private_config.local` | `~/.ssh/config.local` (created once, mode 0600) | throwaway test hosts, machine-specific aliases |

### Agents & orchestration

| Path | Target | What it is |
| --- | --- | --- |
| `home/dot_omp/private_agent/config.yml` | `~/.omp/agent/config.yml` | [omp](https://omp.sh) coding agent settings |
| `home/dot_omp/private_agent/extensions/symlink_atuin.ts.tmpl` | `~/.omp/agent/extensions/atuin.ts` → `linked/omp-extensions/atuin.ts` | records omp's `bash` commands into Atuin history |
| `home/dot_omp/private_agent/extensions/symlink_daily-budget.ts.tmpl` | `~/.omp/agent/extensions/daily-budget.ts` → `linked/omp-extensions/daily-budget.ts` | weekday spend-pacing warnings |
| `home/dot_omp/private_agent/daily-budget.json` | `~/.omp/agent/daily-budget.json` | usage/cost budget schedule read by the extension above |
| `home/dot_omp/private_agent/create_private_daily-budget.local.json` | `~/.omp/agent/daily-budget.local.json` (created once, mode 0600) | machine-local `daily-budget.json` overlay (e.g. a smaller `cost.dailyCapUsd`) |
| `home/dot_omp/private_agent/rules/output-style.md` | `~/.omp/agent/rules/output-style.md` | output-style rule for omp responses |
| `home/dot_omp/private_agent/AGENTS.md` | `~/.omp/agent/AGENTS.md` | omp's global context file |
| `home/dot_omp/private_agent/create_private_models.yml` | `~/.omp/agent/models.yml` (created once, mode 0600) | credentials and custom provider ids |
| `home/dot_omp/private_agent/create_private_config.local.yml` | `~/.omp/agent/config.local.yml` (created once, mode 0600) | machine-local `modelRoles`/`retry.fallbackChains` overlay |
| `home/dot_claude/settings.json` | `~/.claude/settings.json` | [Claude Code](https://claude.com/product/claude-code) CLI global settings |
| `home/dot_claude/symlink_CLAUDE.md.tmpl` | `~/.claude/CLAUDE.md` → `~/.omp/agent/AGENTS.md` | symlink to the applied omp `AGENTS.md` |
| `home/dot_dstack/server/create_private_config.yml` | `~/.dstack/server/config.yml` (created once, mode 0600, macOS) | [dstack](https://dstack.ai) GPU-cloud orchestrator config |
| `home/Library/LaunchAgents/ai.dstack.server.plist` | `~/Library/LaunchAgents/ai.dstack.server.plist` (macOS) | LaunchAgent that starts `dstack server` at login |
| `home/dot_local/bin/executable_tailscale` | `~/.local/bin/tailscale` | PATH shim for the Mac App Store build of Tailscale |

### Repo scripts, checks & docs

| Path | Target | What it is |
| --- | --- | --- |
| `home/.chezmoidata/packages.yaml` | not applied | the one manifest for every installable thing |
| `home/dot_config/mise/config.toml.tmpl` | `~/.config/mise/config.toml` | mise's global tool-version config |
| `home/.chezmoiscripts/*.sh.tmpl` | not applied | provisioning scripts, run in numbered order — see below |
| `home/.chezmoitemplates/output.sh.tmpl` | not applied | shared output helpers used by the provisioning scripts |
| `home/.chezmoi.toml.tmpl` | `~/.config/chezmoi/chezmoi.toml` | sets `sourceDir`, prompts `workName`/`workEmail`/`workGitDir` once |
| `home/.chezmoiignore` | not applied | OS-conditional exclusions |
| `home/.chezmoiexternal.toml` | not applied | antidote's git-repo clone and the Nerd Font archive |
| `Justfile` | not applied | every check — see [Making changes](#making-changes) |
| `.pre-commit-config.yaml` | not applied | gitleaks plus the local `just leakguard` hook |
| `.markdownlint.yaml` | not applied | shared markdown lint rules |

## Bootstrap a new machine

```sh
brew install chezmoi                 # macOS, with Homebrew already present
# or, on Linux:
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

chezmoi init --apply https://github.com/andyhite/dotfiles.git
```

`chezmoi apply` is safe to re-run any time: it installs what's missing and updates what's
already there. `home/.chezmoidata/packages.yaml` is the manifest for every installable
thing — CLI tools, language runtimes, Homebrew casks, apt packages, uv tools, herdr
plugins, gh extensions, cross-agent skills. See `AGENTS.md` for how to add an entry.

Thirteen scripts under `home/.chezmoiscripts/` run in numbered order:

| Script | Platform | What it does |
| --- | --- | --- |
| `run_onchange_before_05-apt.sh.tmpl` | linux | `apt-get update` + install per `via: apt` entry |
| `run_onchange_before_06-homebrew.sh.tmpl` | darwin | fails with install instructions if `brew` isn't on `PATH` |
| `run_onchange_before_10-mise.sh.tmpl` | both | installs mise itself if missing |
| `run_onchange_after_20-brew-bundle.sh.tmpl` | darwin | `brew bundle` against every `via: brew`/`via: cask` entry |
| `run_onchange_after_30-mise-install.sh.tmpl` | both | `mise install --yes` for every `via: mise` entry |
| `run_onchange_after_35-uv-tools.sh.tmpl` | both | installs/upgrades every `via: uv` entry |
| `run_once_after_40-installers.sh.tmpl` | both | installs every `via: installer` entry |
| `run_onchange_after_45-fontcache.sh.tmpl` | linux | `fc-cache -f` on the Nerd Font directory |
| `run_onchange_after_50-completions.sh.tmpl` | both | generates zsh completions for tools carapace doesn't cover |
| `run_onchange_after_60-agents.sh.tmpl` | both | installs `via: herdr`/`via: omp`/`via: gh`/`via: skill` entries |
| `run_onchange_after_70-services.sh.tmpl` | darwin | starts the dstack service |
| `run_onchange_after_80-nvchad.sh.tmpl` | both | restores the NvChad plugin lockfile if it changed |
| `run_onchange_after_90-repo-hooks.sh.tmpl` | both | `pre-commit install` in this repo |

```sh
just remote <host>
```

applies this repo's chezmoi state on a remote host over ssh.

## Making changes

Editing under `home/` does **not** change the live machine — chezmoi copies on apply.
`linked/` is live-symlinked into `$HOME`, so editing it changes the running config
immediately. See `AGENTS.md` for the edit loop. Commit and push, then
`chezmoi update --apply` (or `just remote <host>`) on the other machine.

`Justfile` is the single source of truth for checks; CI just calls its recipes.

| Recipe | What it catches |
| --- | --- |
| `just data` | `packages.yaml` parses and every entry is well-formed |
| `just templates` | every `*.tmpl` under `home/` renders for both platforms |
| `just scripts` | every provisioning script renders and passes shellcheck |
| `just zsh-syntax` | `zsh -n` on the zsh config files |
| `just leakguard` | work identifiers in tracked content |
| `just gitleaks` | token-shaped secrets in a `git archive HEAD` export |
| `just brewfile` | prints the Brewfile the brew-bundle script would generate |
| `just check` | `data`, `templates`, `scripts`, `zsh-syntax`, `leakguard`, `gitleaks` |
| `just smoke` | applies the whole tree twice into a throwaway destination |
| `just remote <host>` | applies this repo's chezmoi state on a remote host |
