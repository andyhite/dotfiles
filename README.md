# dotfiles

Shell and terminal config, synced between my Mac (Ghostty) and remote dev VMs. GitHub Dark
Default theme everywhere, zsh with antidote instead of oh-my-zsh, starship for the prompt,
NvChad for editing.

## Contents

- [What's in here](#whats-in-here)
- [Bootstrap a new machine](#bootstrap-a-new-machine)
  - [Remote installs — `--host`](#remote-installs----host)
  - [Completions](#completions)
  - [The `*.local` templates](#the-local-templates)
  - [mise](#mise)
  - [`make` on macOS — `gmake`, not `gnumake`](#make-on-macos--gmake-not-gnumake)
  - [Shells with no line editor — `TERM=dumb`, or no tty](#shells-with-no-line-editor--termdumb-or-no-tty)
- [Notes by tool](#notes-by-tool)
  - [Git — rebase-first, with hunk and delta](#git--rebase-first-with-hunk-and-delta)
  - [Shell — carapace, fd, uv, and Linux clipboards](#shell--carapace-fd-uv-and-linux-clipboards)
  - [gh extensions — manifest beside `herdr_plugins.txt`](#gh-extensions--manifest-beside-herdr_pluginstxt)
  - [btop — GitHub Dark Default theme, and the config-rewrite trap](#btop--github-dark-default-theme-and-the-config-rewrite-trap)
  - [Docker Desktop](#docker-desktop)
  - [Caddy — local HTTPS for internal-only dev hostnames](#caddy--local-https-for-internal-only-dev-hostnames)
  - [dnsmasq — wildcard local DNS via macOS's per-domain resolver](#dnsmasq--wildcard-local-dns-via-macoss-per-domain-resolver)
  - [Zed's `ssh_connections` is stripped by a clean filter](#zeds-ssh_connections-is-stripped-by-a-clean-filter)
  - [omp — one tracked config, two machines, different accounts](#omp--one-tracked-config-two-machines-different-accounts)
  - [omp compaction — a fold is priced in cache, not tokens](#omp-compaction--a-fold-is-priced-in-cache-not-tokens)
  - [Atuin](#atuin)
  - [herdr — Homebrew on macOS, curl installer on Linux](#herdr--homebrew-on-macos-curl-installer-on-linux)
  - [Herdr plugins — the list is tracked, herdr's registry isn't](#herdr-plugins--the-list-is-tracked-herdrs-registry-isnt)
  - [Herdr plugin keybindings — `[keys]` only knows herdr's own actions](#herdr-plugin-keybindings--keys-only-knows-herdrs-own-actions)
  - [lin — Homebrew tap on macOS, cargo on Linux](#lin--homebrew-tap-on-macos-cargo-on-linux)
  - [Agent skills — the list is tracked, the lockfile isn't](#agent-skills--the-list-is-tracked-the-lockfile-isnt)
  - [NvChad — diffview alongside telescope `git_status`](#nvchad--diffview-alongside-telescope-git_status)
  - [NvChad's lockfile — install restores it, `:Lazy sync` moves it](#nvchads-lockfile--install-restores-it-lazy-sync-moves-it)
  - [NvChad's Mason/Treesitter setup — do this yourself, on purpose](#nvchads-masontreesitter-setup--do-this-yourself-on-purpose)
  - [Ghostty over SSH — `TERM=xterm-ghostty` doesn't exist on most remotes](#ghostty-over-ssh--termxterm-ghostty-doesnt-exist-on-most-remotes)
  - [Hammerspoon — per-Space Ghostty toggle, Ghostty's own is app-wide](#hammerspoon--per-space-ghostty-toggle-ghosttys-own-is-app-wide)
- [Making changes](#making-changes)
  - [Justfile and CI](#justfile-and-ci)

## What's in here

### Shell & prompt

| Path | Links to | What it is |
| --- | --- | --- |
| `zshrc` | `~/.zshrc` | zsh config: completion, antidote plugin load, history, aliases, tool init hooks |
| `tool-versions` | `~/.tool-versions` | mise runtime pins (node, python, go, bun, pnpm) — mise walks up from the current directory to find this, so the symlink is the global default under `$HOME`; see [mise](#mise) below |
| `zsh_plugins.txt` | `~/.zsh_plugins.txt` | antidote's plugin list (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, zsh-vi-mode) |
| `config/starship.toml` | `~/.config/starship.toml` | prompt — GitHub Dark Default palette, hostname shown only over SSH |
| `config/atuin/config.toml` | `~/.config/atuin/config.toml` | Atuin (shell history): overrides only — daemon, fuzzy search, full-style UI, vi keymap, `atuin ai`. Also the answers `atuin setup` would otherwise re-ask on every install |
| `config/atuin/themes/github-dark-default.toml` | `~/.config/atuin/themes/github-dark-default.toml` | GitHub Dark Default for Atuin; foreground colors only, background comes from Ghostty |
| `zshrc.local.example` | (copy, not linked) | template for machine-local secrets — never committed |

### Terminal & workspace

| Path | Links to | What it is |
| --- | --- | --- |
| `config/ghostty/config` | `~/.config/ghostty/config` | Ghostty terminal: `GitHub Dark Default` theme, shell integration — same path on macOS and Linux |
| `config/hammerspoon` | `~/.hammerspoon` (macOS only) | Hammerspoon: `init.lua` binds the per-Space Ghostty show/hide toggle that replaced Ghostty's own app-wide one — see [Hammerspoon](#hammerspoon--per-space-ghostty-toggle-ghosttys-own-is-app-wide) below |
| `config/btop` | `~/.config/btop` | btop resource monitor: GitHub Dark Default theme, `save_config_on_exit = false` so btop's default full-config-rewrite-on-quit can't overwrite this file — see [btop](#btop--github-dark-default-theme-and-the-config-rewrite-trap) below |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager), native theme resynced to Ghostty's accent blue, no contrast-repair overrides needed |
| `config/herdr/palette` | `~/.config/herdr/palette` | the `prefix+p` command palette — an fzf script run by a `type = "popup"` keybinding, plus the MIT notice of the plugin it's derived from |
| `config/herdr/layout` | `~/.config/herdr/layout` | the `prefix+f` fold command — a `type = "shell"` keybinding that folds a row of N side-by-side panes into N/2 columns of two |
| `herdr_plugins.txt` | (not linked — read by `install.sh`) | Herdr plugin list — GitHub `owner/repo[@ref]` lines install/update via `herdr plugin install`; `local:<path>` lines link a checkout in this repo |
| `config/herdr/plugins/config` | `~/.config/herdr/plugins/config` | per-plugin Herdr config, one directory per plugin id — the whole tree is linked, so new plugins land here on install |
| `config/herdr/plugins/ticket-worktree` | (linked via `herdr_plugins.txt`) | the `prefix+t` ticket-to-worktree plugin: a single-screen form popup for a Jira/Linear ticket URL, then creates a `ticket/<key>` branch + worktree and starts an omp agent with the ticket queued as an unsubmitted prompt — see [Herdr plugins](#herdr-plugins--the-list-is-tracked-herdrs-registry-isnt) below |
| `caddy/Caddyfile` | `/opt/homebrew/etc/Caddyfile` (macOS only) | base Caddyfile — `local_certs` only, imports the machine-local one below; symlinked by the `tools` step, not `configs` — see [Caddy](#caddy--local-https-for-internal-only-dev-hostnames) below |
| `caddy/Caddyfile.local.example` | (copy, not linked) | template for `/opt/homebrew/etc/Caddyfile.local` — machine-local site blocks, never committed |
| `dnsmasq/dnsmasq.conf` | `/opt/homebrew/etc/dnsmasq.conf` (macOS only) | base dnsmasq config — loopback-only, non-privileged port; symlinked by the `tools` step, not `configs` — see [dnsmasq](#dnsmasq--wildcard-local-dns-via-macoss-per-domain-resolver) below |
| `dnsmasq/dnsmasq.local.conf.example` | (copy, not linked) | template for `/opt/homebrew/etc/dnsmasq.local.conf` — machine-local wildcard-domain records, never committed |

### Editor

| Path | Links to | What it is |
| --- | --- | --- |
| `config/nvim` | `~/.config/nvim` | [NvChad](https://nvchad.com) starter — vendored once, `.git` stripped, fully mine to edit from here. Includes `lazy-lock.json`: tracked on purpose, so it's the pinned plugin set every machine restores to rather than per-machine generated state — see [the lockfile section](#nvchads-lockfile--install-restores-it-lazy-sync-moves-it) |
| `config/zed/settings.json` | `~/.config/zed/settings.json` | Zed editor settings — `disable_ai: true` since agents run from the terminal via omp, not inside the editor, so the `agent`/`agent_servers` keys go undefined rather than tracked as dead config. `ssh_connections` never reaches the index: Zed rewrites it through this symlink on every remote connect, so a git clean filter strips it on the way in — see [below](#zeds-ssh_connections-is-stripped-by-a-clean-filter) |

### Git

| Path | Links to | What it is |
| --- | --- | --- |
| `gitconfig` | `~/.gitconfig` | tracked git identity, LFS/xet filter wiring, rebase-first defaults, hunk pager + hunk difftool (delta retained for `add -p`); anything that varies per machine layers in through `gitconfig.local.example` below |
| `gitconfig.local.example` | (copy, not linked) | template for `~/.gitconfig.local` — work identity via `includeIf "gitdir:…"`, private-registry credentials. `gitconfig`'s trailing `[include]` applies last, so anything set here wins over every default in the tracked file |
| `config/git/ignore` | `~/.config/git/ignore` | global gitignore — git's own default `core.excludesFile` location when that setting is unset, so machine-tool droppings (`.DS_Store`, `.idea/`) never have to live in a project's own `.gitignore` |
| `config/gh/config.yml` | `~/.config/gh/config.yml` | gh CLI defaults and aliases; `git_protocol: https` is deliberate — `ssh/config` maps `github.com` to the work SSH key, so an ssh remote here would silently authenticate as the wrong account |
| `gh_extensions.txt` | (not linked — read by `install.sh`) | gh CLI extension manifest, one `owner/repo` per line; `install.sh`'s `gh` step installs new extensions and upgrades ones already present — see [gh extensions](#gh-extensions--manifest-beside-herdr_pluginstxt) |
| `config/lazygit/config.yml` | `~/Library/Application Support/lazygit/config.yml` (macOS), `~/.config/lazygit/config.yml` (Linux) | Lazygit: GitHub Dark Default theme, Nerd Font v3 icons, fuzzy filtering, and nvim integration; `zshrc` exposes it as `lg`, while the OS-specific destinations are Lazygit's native defaults |
| `config/hunk/config.toml` | `~/.config/hunk/config.toml` | Hunk review-stream viewer: `github-dark-default` theme (an exact built-in Shiki theme id), line numbers, and default-on agent notes for reviewing agent-authored changesets; wired as both `core.pager` and `diff.tool` — see the Git section below |
| `ssh/config` | `~/.ssh/config` | portable ssh identity config — per-key `Host` blocks for github.com (`IdentitiesOnly yes` so the agent can't offer the wrong key first), github.com-personal, hf.co, runpod.io, plus dstack's `Include ~/.dstack/ssh/config` (dstack injects that line into `~/.ssh/config` — a symlink into this repo — on every provision, so tracking it is the only way the tree stays clean; inert where dstack has never run); machine-specific hosts live in `~/.ssh/config.local` instead |
| `ssh/config.local.example` | (copy, not linked) | template for `~/.ssh/config.local` — throwaway test hosts, machine-specific aliases. `ssh/config`'s first non-dstack line is `Include ~/.ssh/config.local`, because ssh takes the first value it finds for any option and this is the only way the local file can override rather than be shadowed |

### Agents & orchestration

| Path | Links to | What it is |
| --- | --- | --- |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | [omp](https://omp.sh) coding agent settings — besides this file, `AGENTS.md`, and `rules/output-style.md` below, the rest of `~/.omp/agent` is databases, sessions, and a secrets key |
| `omp/agent/extensions/atuin.ts` | `~/.omp/agent/extensions/atuin.ts` | records omp's `bash` commands into Atuin history as `--author pi` (a `KNOWN_AGENTS` name, so `$all-user` hides them), with omp's intent string as `--intent`. Hand-maintained: `atuin hook install` has no omp target |
| `omp/agent/extensions/daily-budget.ts` | `~/.omp/agent/extensions/daily-budget.ts` | weekday spend-pacing warnings layered on top of `retry.usageAwareFallback` — shells out to `omp usage --json` on `turn_end` (plus a 5-minute idle fallback timer while a session sits quiet) and warns (never falls back — that stays `usageAwareFallback`'s job) once real usage outruns the cumulative allocation in `daily-budget.json` through today's weekday |
| `omp/agent/daily-budget.json` | `~/.omp/agent/daily-budget.json` | two independent budgets, `usage` (%-of-7d-quota, for whichever providers `omp usage --json` actually reports — never a static list) and `cost` (a $ cap pooled across every other, pay-per-token provider by default); each is a global default schedule plus an optional per-provider `providers` override, read by the extension above. The runtime ledger it writes (`daily-budget-state.json`) is untracked state, not this file |
| `omp/agent/rules/output-style.md` | `~/.omp/agent/rules/output-style.md` | `alwaysApply: true` rule that shapes every omp response for an ADHD reader — answer first, numbered steps, one next action, no preamble or recap |
| `omp/agent/AGENTS.md` | `~/.omp/agent/AGENTS.md` | omp's native global context file (highest-priority discovery provider — shadows every other tool's user-level context). Holds the same ADHD output-style guidance as `rules/output-style.md` above, since it's a personal preference rather than an omp-specific one; `config/claude/CLAUDE.md` below symlinks straight to this file, so it's the one source of truth |
| `omp_plugins.txt` | (not linked — read by `install.sh`) | omp plugin manifest, one `<install-source> <plugin-name>` per line; `install.sh` runs `omp plugin install <source>` for each, and skips one that's link-installed for local development |
| `agent_skills.txt` | (not linked — read by `install.sh`) | cross-agent skill manifest, one `<owner>/<repo> --skill <name>` per line; `install.sh` runs `npx skills add … -g -y` for each |
| `config/claude/settings.json` | `~/.claude/settings.json` | [Claude Code](https://claude.com/product/claude-code) CLI global settings — push/input-needed notifications, `theme: auto`, `skipDangerousModePermissionPrompt`, `tui: fullscreen`, and `PreToolUse`/`PostToolUse`/`PostToolUseFailure` hooks (all matcher `Bash`) that pipe `atuin hook claude-code` the same way `omp/agent/extensions/atuin.ts` does for omp; the rest of `~/.claude` is sessions, an oauth/telemetry cache, a machine ID, backups, and the `skills/` symlinks `agent_skills.txt` already manages |
| `config/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | a symlink (tracked as one in git) to `omp/agent/AGENTS.md` above — Claude Code's global user memory reuses the exact same content rather than carrying a second copy. The `claude` discovery provider is disabled in `omp/agent/config.yml`, so omp itself reads `AGENTS.md` directly and never this path |
| `dstack/server/config.yml.example` | (template) | [dstack](https://dstack.ai) GPU-cloud task/dev-environment orchestrator — `install.sh` installs the CLI via `uv tool install`, and copies this to `~/.dstack/server/config.yml` on first run; see [the templates section](#the-local-templates) for why it's a template rather than a symlink |
| `launchd/ai.dstack.server.plist` | `~/Library/LaunchAgents/ai.dstack.server.plist` (macOS) | `RunAtLoad`+`KeepAlive` LaunchAgent that starts `dstack server` at login and restarts it if it dies; loaded by the `services` step, never by `configs`, so a throwaway-`$HOME` test run never touches the real launchd namespace — see [the services step](#bootstrap-a-new-machine) |
| `systemd/dstack-server.service` | `~/.config/systemd/user/dstack-server.service` (Linux) | the same job as the plist above, as a systemd `--user` unit (`Restart=on-failure`, `WantedBy=default.target`); same split from `configs` into the dedicated `services` step |

### Repo scripts, checks & docs

| Path | Links to | What it is |
| --- | --- | --- |
| `Brewfile` | (not linked — read by `install.sh`) | macOS formulae + casks for every tool this config drives, applied with `brew bundle` — replaced the old hand-maintained `brew_ensure`/`brew_ensure_cask` loop |
| `Justfile` | (not linked — invoked by `just` and CI) | single source of truth for every check — `.github/workflows/ci.yml` calls its recipes instead of duplicating them; see [Justfile and CI](#justfile-and-ci) |
| `.pre-commit-config.yaml` | (not linked — read by `pre-commit`) | gitleaks plus the local `just leakguard` hook; `install.sh` runs `pre-commit install` during the hooks step so a fresh clone gets both |
| `.markdownlint.yaml` | (not linked — read by `markdownlint-cli2` and nvim's `markdownlint` linter) | shared markdown lint rules: MD013 (line-length) and MD041 (require a top-level heading) off, since neither matches this repo's own conventions — `just fix-md` and the nvim linter both read this one file |
| `bin/tailscale` | `~/.local/bin/tailscale` | PATH shim for the Mac App Store build of Tailscale — `exec`s the bundled CLI directly, since a plain symlink to it fails at runtime (see the file itself for why). Linked only on macOS, and only when the App Store app is actually installed |
| `install.sh` | — | installs/updates every tool above, then symlinks all of it into place — locally, or on another machine with `--host` |

## Bootstrap a new machine

```sh
git clone https://github.com/andyhite/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` runs eleven steps, and is safe to re-run any time (installs what's missing,
updates what's already there). With a terminal attached each step asks first and Enter
accepts; without one, or with `--yes`, it runs everything unattended:

```sh
./install.sh --yes                 # unattended, everything
./install.sh --only configs        # just re-link the dotfiles
./install.sh --skip tools,nvim     # skip the slow parts
./install.sh --verbose             # show each installer's own output
./install.sh --host vm             # install on another machine over ssh
./install.sh --help                # list steps and flags
```

Output is one line per item: `✓` already correct, `+` created, `↑` updated, `·` skipped,
`!` needs your attention, `✗` failed — then a tally. Installer output is suppressed unless
something fails, in which case the last 12 lines are replayed under the failure; `--verbose`
shows it all. A failed step reports and the run continues, so one broken formula doesn't
cost you the rest; the script exits non-zero if anything failed. Colour follows `NO_COLOR`
and `TERM`, and the glyphs fall back to ASCII outside a UTF-8 locale.

The steps, in order — the order is load-bearing, which is why `--only` exists but
reordering doesn't:

1. **Installs/updates the tools this config drives**: starship, atuin, fzf, eza, bat,
   direnv, lazygit, delta, hunk, fd, carapace, gitleaks, pre-commit, just, uv, antidote,
   the Geist Mono Nerd Font, neovim, ripgrep, tree-sitter-cli, mise, omp, claude, btop,
   herdr, and NvChad — plus Docker Desktop on macOS. macOS applies
   `Brewfile` with `brew bundle` (formulae + casks, including Ghostty itself);
   Linux goes through `apt` where a package exists, and falls back
   to each tool's official installer otherwise:
   - `brew bundle check --file Brewfile` runs first and is the common path on a
     repeat install: it exits clean only when every formula/cask is already
     installed and current, so the slower `brew bundle install` runs only when
     there's real work outstanding. `brew bundle` itself only ever adds — dropping
     a line from `Brewfile` never uninstalls anything already on the machine; that
     takes a manual `brew bundle cleanup`.
   - starship/atuin ship curl-able install scripts.
   - eza predates its Ubuntu packaging (24.04+), so on older releases it's built from
     source via `cargo` — bootstrapping `rustup` first if needed, and only rebuilding
     when crates.io actually has a newer version than what's installed.
   - lazygit: Linux pulls upstream's architecture-specific release binary into
     `~/.local/bin`, avoiding distro-version gaps and stale package transitions.
   - neovim: Ubuntu's apt package (0.9.5 on 24.04) is below NvChad's 0.11 floor, so this
     pulls the official release tarball instead and merges it into `~/.local`, which is
     already on `PATH`.
   - tree-sitter-cli: **not** `cargo install tree-sitter-cli` — that pulls in
     `rquickjs-sys`, which needs bindgen/clang to resolve its resource-dir correctly and
     fails to build on stock Ubuntu (`fatal error: 'stdbool.h' file not found`). Uses
     tree-sitter's own prebuilt release binary instead.
   - mise: macOS gets it from `Brewfile` like everything above it; Linux has no
     equally universal package for it, so this runs the upstream `mise.run` installer,
     which drops a single binary into `~/.local/bin` — already on `PATH` via `zshrc`.
   - The Nerd Font is fetched straight from its GitHub release and installed under
     `~/.local/share/fonts`.
   - NvChad: clones `NvChad/starter` straight into this repo the first time
     (`config/nvim`), strips its `.git` immediately per NvChad's own docs, then
     symlinks it like everything else — so all my NvChad customization lives here too,
     not in some separate untracked directory.
   - omp: install-only, via the installer at [omp.sh](https://omp.sh) — the binary is
     ~120MB and ships its own `omp update`, so re-running this script skips it rather
     than re-downloading.
   - claude: the native installer at
     [claude.ai/install.sh](https://claude.ai/install.sh) auto-detects the platform, so
     one curl call covers both branches — run_quiet-wrapped like herdr/atuin/starship
     below, not install-only like omp above, since Anthropic's installer is fast and
     idempotent rather than a 120MB one-time download; re-running it is how `claude`
     stays current.
   - herdr: a real Homebrew core formula on macOS (`brew "herdr"`, not a tap or a
     cargo build) — Linux gets the official installer
     (`curl -fsSL https://herdr.dev/install.sh | sh`), same `~/.local/bin` pattern as
     starship/atuin/uv above, including the exact same shadow trap uv already taught
     this repo: herdr's own installer also targets `~/.local/bin`, which `zshrc` puts
     ahead of Homebrew's `bin` on `PATH`, so a machine that ever ran that installer by
     hand keeps a copy `brew upgrade` will never touch. `which -a herdr` shows both if
     that's happened.
   - Linux-only: `fd-find` installs as `fdfind`, so `ensure_fd_shim_linux` symlinks
     `~/.local/bin/fd` — telescope and fzf shell out to the literal name `fd`, not a
     shell alias. delta and lin fall back to `cargo install` where apt has no package
     (and, for `lin`, where macOS has no tap bottle for the target arch). hunk (npm
     package `hunkdiff`)
     installs the same mise-first-`npm`-then-plain-`npm` way as markdownlint-cli2,
     since it ships neither an apt package nor a crate. gitleaks and carapace pull
     GitHub release binaries. `wl-clipboard` and `xclip` install together on Linux so
     nvim's `+` register can paste on either Wayland or X11.
   - `pre-commit` lands via apt when possible, otherwise `uv tool install` after the
     uv installer runs.

   Ghostty itself is only installed on macOS — it's a local GUI app, so there's nothing
   to install on a headless remote box, though its config still gets symlinked in case
   that box ever runs Ghostty directly.
2. **Generates zsh completions** into `~/.local/share/zsh/site-functions`, which `zshrc`
   prepends to `fpath`. Homebrew already drops completions for many of these tools into
   its own `site-functions`, but that covers nothing on a Linux box, and tools installed
   outside a package manager (`omp`, `herdr`, `tree-sitter`) are uncovered on both. Each
   file is generated by the binary itself, so it can never drift from the installed
   version. See [Completions](#completions) below.
3. **Symlinks every config file** in the table above into place. Backs up
   (`.bak.<timestamp>`) anything real that's already sitting where a symlink needs to go.
   Also copies `zshrc.local.example`, `gitconfig.local.example`, and `ssh/config.local.example`
   to their `~/.*.local` targets at mode 600 the first time only — a re-run never
   overwrites an already filled-in file. See [The `*.local` templates](#the-local-templates) below.
4. **Enables the dstack server to start at login**, via a launchd `LaunchAgent`
   (macOS) or a systemd `--user` unit (Linux) — `launchd/ai.dstack.server.plist` /
   `systemd/dstack-server.service`, symlinked into place by the configs step above like
   any other config file, then loaded/enabled here. Split into its own step rather than
   folded into configs because `--only configs` (and `just smoke`/CI's `configs` job) run
   against a throwaway `$HOME`, but `launchctl`/`systemctl` are OS-global and not
   sandboxed by `$HOME` — enabling a real login service from a test run would leave it
   running on the real machine. Guarded on `command -v dstack` and on the unit file
   actually existing (skips cleanly if the configs step hasn't run yet); idempotent on
   both platforms — re-running never double-loads the launchd job or re-enables an
   already-enabled systemd unit.
5. **Registers repo hooks**: the zed-local git clean filter (strips `ssh_connections`
   from `config/zed/settings.json` on the way into the index) and `pre-commit install`
   when the binary is on `PATH`, so `.pre-commit-config.yaml` is live from the first
   commit on a fresh clone. Kept out of the configs step because neither touches a
   home-directory symlink — both act on this repo's `.git`. See the Zed clean-filter and gitleaks / pre-commit notes under Notes by tool below.
6. **Installs the language runtimes pinned in `~/.tool-versions`**, via `mise install`.
   Runs right after the symlinks step and not before: mise reads its pins by walking up
   from wherever it's invoked, and `~/.tool-versions` is the symlink the configs step
   above just created — swap the order and this step runs against nothing on a fresh
   machine. See [mise](#mise) below.
7. **Installs/updates every Herdr plugin** listed in `herdr_plugins.txt`. The tools step
   above installs herdr itself (Brewfile on macOS, the official installer on Linux — see
   [herdr](#herdr--homebrew-on-macos-curl-installer-on-linux) below), and this step is
   still guarded on `command -v herdr` in case that step was skipped or failed on this run.
8. **Installs/updates omp plugins** from `omp_plugins.txt` — one direct git install per
   line, no marketplace. Re-running the install is what updates a git-sourced plugin, the
   opposite of the gh extensions trap below.
9. **Installs/upgrades gh extensions** from `gh_extensions.txt`. Skipped when `gh` is
   missing or unauthenticated; see [gh extensions](#gh-extensions--manifest-beside-herdr_pluginstxt).
10. **Installs cross-agent skills**, from two sources. `agent_skills.txt` first — one
   `npx skills add <owner>/<repo> --skill <name> -g -y` per line — which needs the
   `runtimes` step above to have already put node on `PATH`, hence the ordering. Then
   any skill an installed Herdr plugin ships in its own `skills/` directory, symlinked
   into `~/.omp/agent/skills` — unchanged from before, and run after Herdr because a
   link made before a plugin's first install would point at a path that doesn't exist
   yet.
11. **Headlessly restores NvChad's plugins** (`nvim --headless "+Lazy! restore" +qa`) once
    neovim and the config are both in place — to the commits in `config/nvim/lazy-lock.json`,
    never past them. See [the lockfile section](#nvchads-lockfile--install-restores-it-lazy-sync-moves-it).

### Remote installs — `--host`

`--host <ssh-host>` redirects the whole run to another machine instead of adding to it:
this box installs nothing. For each host it ssh's in, clones the repo at `--remote-path`
(default `~/.dotfiles`) or fast-forwards it if it's already there, and then runs *that
copy's* `install.sh` with every other flag passed through.

```sh
./install.sh --host vm                        # prompts per step, as if you were sitting there
./install.sh --host vm --yes --only configs   # unattended, one step
./install.sh --host vm,box --yes              # two hosts in turn
./install.sh --host vm --remote-path ~/src/dotfiles
```

Five things worth knowing:

- **The remote pulls from origin, not from this working copy.** Commit and push first —
  the driver prints a warning when the local tree is dirty or ahead of `origin`, because
  a run that silently installs the previous commit is the one failure mode here that
  looks like success.
- **The remote's own `install.sh` is what runs.** Nothing is piped over the wire, so the
  box always ends up in a state some git ref actually describes.
- **A dirty remote worktree is installed as-is**, with a warning and no update — that's
  how you try a change on the remote before committing it, and resetting someone's edits
  to match origin isn't this script's call to make.
- **The first clone uses the public https URL.** The tracked `origin` is
  `git@github.com-personal:…`, a `Host` alias from this repo's own `ssh/config` that a
  machine being bootstrapped doesn't have yet (nor the key it names), so the alias is
  resolved through `ssh -G` and the `https://github.com/…` form is handed over instead.
  `DOTFILES_REPO=<url>` overrides it. An existing clone keeps whatever origin it has.
- **A tty is forwarded only when you have one.** With a terminal on this end, `ssh -t`
  makes the remote's per-step prompts work normally; without one it runs unattended
  rather than sitting out a read timeout per step. One host failing doesn't cancel the
  rest, and the exit status still reflects it.

`ssh` runs a non-login, non-interactive shell, so the bootstrap re-adds what `zshrc`
would have: `~/.local/bin`, `~/.cargo/bin`, mise's shims (node), and Homebrew on a macOS
host. Without that every `command -v` guard in `install.sh` would decide its tool is
missing and reinstall it — the right result, reached the slowest possible way.

### Completions

`zshrc` puts `~/.local/share/zsh/site-functions` first on `fpath` so a completion
generated from the installed binary beats a distro's stale copy. `install.sh` writes one
per tool that has a generator:

| Tool | Generator |
| --- | --- |
| starship | `starship completions zsh` |
| atuin | `atuin gen-completions --shell zsh` |
| bat | `bat --completion zsh` |
| ripgrep | `rg --generate complete-zsh` |
| omp | `omp completions zsh` |
| herdr | `herdr completion zsh` |
| tree-sitter | `tree-sitter complete --shell zsh` |
| mise | `mise completion zsh` |
| carapace | `carapace _carapace zsh` |

`zshrc` also `source`s `<(carapace _carapace)` after antidote loads fzf-tab — carapace
ships built-in specs for roughly a thousand CLIs and feeds them through the same fzf-tab
popup as everything else. It does **not** replace the three generators above: carapace
has no spec for `omp`, `herdr`, or `tree-sitter`, which is exactly why `install.sh`
still hand-writes `_omp`, `_herdr`, and `_tree-sitter` — the two mechanisms cover
disjoint command sets.

Deliberately absent from the generator step because something else already covers them:
most other Brewfile formulae (git, gh, docker, …) via carapace; `fzf` from the
`fzf --zsh` eval in `zshrc`; `direnv` and `nvim`, which publish no zsh completion at
all; and zsh itself ships `_jq` and `_vim`.

Two details worth knowing. Generation goes through a temp file and only replaces the
target when the output is non-empty, so a tool that starts erroring can't blank a working
completion. And because `zshrc` runs `compinit -C` — which trusts a cached dump rather
than rescanning `fpath` on every shell start — `install.sh` deletes `~/.zcompdump*`
whenever it writes something new, so the next shell rebuilds once.

### The `*.local` templates

Six tracked templates, one convention: `zshrc.local.example`, `gitconfig.local.example`,
`ssh/config.local.example`, `omp/agent/models.yml.example`,
`omp/agent/config.local.yml.example`, and `dstack/server/config.yml.example` are copied —
never linked — to their targets at mode 600 the first time `install.sh` runs, and left
alone on every run after that, so a filled-in file is never clobbered. Each one holds real
secrets or per-machine values that have no business in a public repo.

The two config templates exist because of how their tracked file reads the copy back, not
just as a place to dump overrides:

- `gitconfig` ends with `[include]` / `path = ~/.gitconfig.local`. Git applies repeated
  keys in file order, so an include at the very end wins over every default set above it
  — `~/.gitconfig.local` doesn't need to know what it's overriding, it just wins by
  coming last.
- `ssh/config` *starts* with `Include ~/.ssh/config.local`, before any `Host` block. ssh
  takes the first value it finds for a given option, so the include has to come first or
  a later `Host github.com` block would shadow it instead of losing to it. A missing
  include target isn't an error in `ssh_config`, so this line is safe on a machine that
  hasn't run `install.sh` yet.

`zshrc.local.example` needs no such trick — `zshrc` just sources `~/.zshrc.local` near
the top, before the tool blocks that read values like `AWS_PROFILE`.

`models.yml` and `config.local.yml` don't land at `~/.*.local` like the first three —
they sit in `~/.omp/agent/`, beside the `config.yml` symlink, where omp looks for both.
They're also the two templates that ship inert rather than empty — `providers: {}` and
`{}` respectively — because omp validates each file's root as an object, and a copy
trimmed to pure comments parses as null: a validation warning for `models.yml`, a hard
startup error for `config.local.yml` (loaded via `PI_CONFIG_FILES`, which `zshrc` exports
once the file exists). See [the omp section](#omp--one-tracked-config-two-machines-different-accounts)
for what goes in each.

`dstack/server/config.yml.example` follows the same mirrored-path convention as
`omp/agent/models.yml.example`, landing at `~/.dstack/server/config.yml` — the rest of
`~/.dstack` (the sqlite db, server/job/runner logs, a generated ssh keypair) is state
dstack writes itself, so only this one file is templated. It ships with the `main` project
defined but no backend configured — dstack's docs require the project to exist even with
zero backends — plus a commented RunPod block showing where a real `api_key` goes.

### mise

Replaces the old per-language version manager: one binary instead of a plugin per
language (no `plugin add node`/`plugin add golang` to run on every machine), and it
activates by rewriting `PATH` on every prompt instead of installing shims — a version
change in `~/.tool-versions` is live in the shell you're already sitting in, with no
`reshim` step.

`tool-versions` pins exact versions on purpose — `node 26.7.0`, not "latest" — so a
machine doesn't silently drift to whatever happened to be current the day someone ran
`install.sh`. mise resolves `.tool-versions`/`mise.toml` by walking up from the current
directory to `$HOME` and beyond, which is exactly what makes the `~/.tool-versions`
symlink the global default everywhere that doesn't have its own: mise takes the nearest
file, so a project with its own pins still wins inside that project.

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

`gitconfig` is deliberately rebase-oriented (`pull.rebase`, `rebase.autoStash`,
`rebase.autoSquash`, `rebase.updateRefs`, `rerere.enabled`, `rerere.autoupdate`) so
review fixups belong spread across existing commits rather than piled into one "address
review" commit at the tip. **delta** is the pager that finally renders those settings:
`core.pager = delta || less` and `interactive.diffFilter = delta --color-only || cat`.
The `|| less` / `|| cat` fallbacks are mandatory — git runs both through `sh -c`, so a
missing delta on a fresh machine (or one where the tools step was declined) falls through
instead of bricking every `git diff`/`log`/`show` and `git add -p`. `syntax-theme =
none` disables delta's own syntax highlighting: `delta --list-syntax-themes` ships
only a light `GitHub` entry and no dark one, so there is no bundled delta theme that
matches GitHub Dark Default — delta is the one surface in this repo that cannot match
the palette at all, rather than approximating it. `config/lazygit/config.yml` reuses the same `[delta]` block with `pager: delta
--dark --paging=never` — `--paging=never` is load-bearing because lazygit already
scrolls the diff panel itself; a delta that also spawned `less` would deadlock the panel
for input.

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
terminal delta would have to take over. `config/hunk/config.toml`
(`~/.config/hunk/config.toml`) sets `theme = "github-dark-default"` — hunk is
Shiki-backed and actually ships a theme with that exact id — plus
`line_numbers = true` to match delta's gutter and `agent_notes = true`, since this
machine's diffs are read almost entirely as agent-authored changesets rather than
opting the notes rail in per session.

**gitleaks** and **pre-commit** are both deliberate. `.pre-commit-config.yaml` runs
gitleaks at commit time for tokens, keys, and credential-shaped strings; the local
`just leakguard` hook is the other half, running the same work-identifier grep CI uses.
Gitleaks has no idea those strings matter — they look like ordinary words — and
leakguard would not catch a real API key. `install.sh`'s hooks step runs
`pre-commit install` so neither hook requires a manual opt-in on a fresh clone.

### Shell — carapace, fd, uv, and Linux clipboards

**carapace** initializes in `zshrc` after antidote loads fzf-tab (`source <(carapace
_carapace)` with `CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'`). It is skipped in
`TERM=dumb` / non-interactive shells for the same reason starship and fzf key bindings
are. See [Completions](#completions) for how it coexists with install.sh's generated
`_omp`/`_herdr`/`_tree-sitter` files.

**fd** backs `FZF_DEFAULT_COMMAND` and telescope's `find_files` picker. Debian/Ubuntu's
`fd-find` package installs the binary as `fdfind`; `ensure_fd_shim_linux` symlinks
`~/.local/bin/fd` because those consumers exec the literal name `fd`, not a shell that
would expand an alias.

**uv** comes from the Brewfile on macOS and from Astral's curl installer into
`~/.local/bin` on Linux, where no formula exists.

The trap to know, because it is silent: `zshrc` puts `~/.local/bin` first on `PATH`, so a
standalone Astral install there *shadows* the Homebrew formula on macOS. Both binaries
work, `brew upgrade` only ever moves the one that loses, and nothing warns you — this
machine had a 14-month-old `~/.local/bin/uv` winning over a current formula until it was
removed. On a Mac, let the Brewfile own `uv`; the `uv tool` installs live in
`~/.local/share/uv` and survive deleting the binary.

### gh extensions — manifest beside `herdr_plugins.txt`

`gh_extensions.txt` is the tracked source of truth, one `owner/repo` per line — same
shape as `herdr_plugins.txt` and `agent_skills.txt`, read rather than linked. The
`install.sh` **gh** step runs after **tools** (needs `gh` on `PATH`) and is independent
of **configs** (extensions are per-user, not symlinked files).

Install is not update: `gh extension install` fails on an already-installed extension,
and `gh extension upgrade` is the only command that moves an existing one forward. omp's
plugin installs work the other way round — see `omp_plugins.txt`. The step checks
`gh auth status` once up front; an unauthenticated box skips the whole manifest with a
note rather than failing once per line. The one extension listed today is `seachicken/gh-poi`
— squash-merged branches never look merged to `git branch --merged`, and a worktree per
branch of stacked agent work means merged-branch churn is continuous rather than
occasional.

### btop — GitHub Dark Default theme, and the config-rewrite trap

`config/btop` is linked whole to `~/.config/btop`: `btop.conf` sets `color_theme =
"github-dark-default"` and `config/btop/themes/github-dark-default.theme` maps the same
hex values as `config/starship.toml`'s `[palettes.github_dark_default]` and
`config/atuin/themes/github-dark-default.toml` — Ghostty's actual rendered ANSI colors.
btop bundles 41 themes, none of them a GitHub theme, so a custom file is the only way to
run this palette here — there's no bundled candidate to fall back to instead. `main_bg` in
the theme is Ghostty's actual terminal background (`#0d1117`, GitHub Dark Default) — btop
always paints its own background pixels, so matching the real terminal is what avoids a
visible seam around the window, the same distinction `config/herdr/config.toml`'s
contrast-repair block had to make.

`btop.conf` also sets `save_config_on_exit = false`, and that one isn't taste. btop's own
default is `true`, and on quit it rewrites its **entire** config file — every key, not
just the ones this file sets — back to disk. Confirmed by launching btop against a
one-line config and diffing before/after: it came back as a ~280-line dump of every
built-in option. Left at the default, the first `btop` + `q` after `install.sh` runs
would balloon this tracked file into that dump and turn it into a live, constantly-
diffing file the moment two machines quit btop with different terminal sizes or GPU
detection results. `save_config_on_exit = false` is what keeps this file exactly what's
tracked, forever.

### Docker Desktop

`docker-desktop` is configured with `args: { adopt: true }` on the Brewfile cask:
`/Applications/Docker.app` already exists on the machine this repo runs on, and a plain
`brew bundle` install aborts with "already an App" unless adopt takes over the existing
install. No Linux counterpart in `install.sh` — Docker's apt repo is a host-level decision,
not a dotfiles one.

### Caddy — local HTTPS for internal-only dev hostnames

`caddy/Caddyfile` is deliberately thin — `local_certs` and one `import` line — because a
real site block always names a real internal hostname and a real IP, neither of which
belongs in a public repo. `local_certs` is what makes that possible at all: it mints certs
from Caddy's own built-in CA instead of asking Let's Encrypt, which could never issue for
a hostname that isn't publicly resolvable. `caddy trust` installs that CA into your
keychain once, and every site the imported file defines is trusted with no browser warning
from then on.

The imported file, `/opt/homebrew/etc/Caddyfile.local`, is created once from
`caddy/Caddyfile.local.example` — inert until you uncomment a block and fill in a
real hostname and IP, same contract as `ssh/config.local.example`. A single regex-matched
wildcard block there can stand in for a whole family of hostnames — `<service>-<port>` —
without a new site block per port; the template shows the pattern.

`brew services start caddy` (not part of `install.sh` — a machine with nothing to proxy
doesn't need it running) always sets `HOME=/opt/homebrew/var/lib` for the service, so
Caddy's default cert-storage location under that `HOME` is the same on every start
regardless of who launches it — no path to pin. After editing the local Caddyfile, apply
it with `caddy reload --config /opt/homebrew/etc/Caddyfile` (no restart, no dropped
connections) rather than `brew services restart caddy`.

### dnsmasq — wildcard local DNS via macOS's per-domain resolver

`/etc/hosts` has no wildcard syntax — every hostname needs its own literal line, which
doesn't scale to a naming scheme like `<service>-<port>.example.internal` where new
hostnames show up as often as new local services do. macOS's per-domain resolver
(`/etc/resolver/<domain>`) fixes that: any lookup under that one domain gets sent to a
resolver you name instead of the system default, and dnsmasq answers every hostname under
it — including ones that don't exist yet — with a single `address=/.<domain>/127.0.0.1`
line.

`dnsmasq/dnsmasq.conf` binds `127.0.0.1` on port `5453`, not the standard `53`, so
`brew services start dnsmasq` never needs root — macOS's own resolver keeps port 53
regardless, since `/etc/resolver` only redirects the one domain named there, not the
whole system. Its final line, `conf-file=/opt/homebrew/etc/dnsmasq.local.conf`, is the
actual domain list, deliberately not this tracked file: real internal hostnames don't
belong in a public repo.

Both `dnsmasq.conf`'s symlink and `dnsmasq.local.conf`'s one-time copy — like Caddy's
above — happen in `install.sh`'s `tools` step, not `configs`: `/opt/homebrew/etc` sits
outside every `$HOME`, so `just smoke`'s throwaway-`HOME` sandbox would otherwise
silently touch the real machine's copy on every run instead of staying contained.
`ensure_homebrew_etc_config` is the one function both tools share, since they need the
exact same symlink-plus-template-copy shape.

Wiring a new domain in is two steps this repo can't do for you, since the domain name
itself is the machine-local part:

```
# in /opt/homebrew/etc/dnsmasq.local.conf
address=/.example.internal/127.0.0.1

# /etc/resolver/example.internal
nameserver 127.0.0.1
port 5453
```

`brew services start dnsmasq` (not part of `install.sh` — a machine with no wildcard
domain to resolve doesn't need it running) picks up edits to `dnsmasq.local.conf` on
`brew services restart dnsmasq`, since dnsmasq doesn't watch the file for changes.

### Zed's `ssh_connections` is stripped by a clean filter

`config/zed/settings.json` is symlinked into `~/.config/zed`, and Zed rewrites
`ssh_connections` every time you connect to or disconnect from a remote host. So the
moment you open a project on a remote box, its hostname and absolute project paths are
written straight into a tracked file in a public repo. Deleting the key by hand fixes it
until the next connect, which is to say it doesn't fix it.

`.gitattributes` routes the file through a clean filter — `bin/zed-settings-clean`, run by
git on the way into the index, leaving the working file exactly as Zed wrote it:

```
config/zed/settings.json filter=zed-local
```

Three choices worth naming. It's a filter rather than `update-index --skip-worktree`,
which hides *every* change to a file — and the reason this one is tracked at all is that
settings changed in Zed's UI should show up as diffs here. It's a line filter rather than
`jq`, because the file is JSONC with `//` comments in its header *and* through its body,
which jq can't read and any reformatting pass would throw away. And there's no smudge
half: the filter only ever removes machine state on the way in, so reversing it on
checkout would mean writing one machine's hosts into another's file.

The filter definition can't be committed — it names an absolute path, and this repo sits
somewhere different on every machine — so `install.sh`'s hooks step registers it with
`git config filter.zed-local.clean`. Until that runs, git treats an unknown filter as a
pass-through: nothing errors, and nothing is stripped either. That gap is real — clone
onto a new machine, open a remote project in Zed before running `install.sh`, and the
hostnames commit exactly as they used to. CI closes it from the other end by grepping
committed content for work identifiers, so a leak through any unfiltered path fails the
build instead of shipping.

### omp — one tracked config, two machines, different accounts

`omp/agent/config.yml` is symlinked to `~/.omp/agent/config.yml` and shared by every
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
tiers, need two distinct provider ids instead — see `omp/agent/models.yml.example` for
that pattern (self-hosted or trial providers use it too).

**A machine's own model routing lives in `~/.omp/agent/config.local.yml`, not
`config.yml`.** `omp/agent/config.local.yml.example` is copied there by `install.sh` on
every machine (never committed), and `zshrc` exports `PI_CONFIG_FILES` pointing at it so
omp layers it as a CLI config overlay on top of the shared `config.yml` — a deep merge of
settings objects, so only the keys a machine actually sets override anything. This is
where a machine that authenticates `openai` adds it back in as a real fallback tier,
ahead of the shared `cursor`-only chain:

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

That is why the Justfile's routing check allows only omp's built-in ids in `config.yml`
and nothing else — a custom id has no guarantee every machine defines it, so it belongs
in that machine's own `config.local.yml` overlay instead, where an undefined reference
only warns on the one machine that added it.

`~/.omp/agent/models.yml` is created from `omp/agent/models.yml.example` on every machine,
so the mechanism is discoverable even where a given machine only uses part of it. Both it
and `config.local.yml` ship inert but not empty — `providers: {}` and `{}` respectively —
because omp validates each file's root as an object and a copy trimmed to pure comments
parses as null.

That leaves nothing per-machine in `config.yml` at all, which is the point: one tracked
file with a deliberately thin default, every machine, and the only differences are which
providers each one has authenticated and what it chose to layer on top locally.

### omp compaction — a fold is priced in cache, not tokens

`compaction` in `omp/agent/config.yml` is tuned against measured spend rather than comfort.
Across 61k Anthropic messages, 44% of the bill came from requests carrying a cached prefix
over 200k tokens, and Anthropic's 1M window charges no long-context premium — so every
extra cached token was a straight linear cost with nothing bought back. Both knobs below
exist to keep that prefix small, against the one cost a fold actually has: rewriting the
head of the history invalidates the prompt cache from that point forward, plus one
summarizer call.

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

`config/atuin/config.toml` holds overrides only; run `atuin default-config` to see the
full annotated template. It exists mainly so `atuin setup` never runs: that wizard is
what asks about Atuin AI and the daemon, and the upstream installer re-ran it on every
single `install.sh`. With the answers committed, `install.sh` passes `--non-interactive`
and the wizard has nothing left to decide.

Sync is never configured: this history stays on the machine, so there's no account state
to set up and nothing `install.sh` has to prompt for. `--non-interactive` also skips the
installer's own sync-signup prompt.

`omp/agent/extensions/atuin.ts` records commands omp runs through its `bash` tool into
the same history, tagged `--author pi` — omp is a distribution of pi, and "pi" is one of
the five names in Atuin's `KNOWN_AGENTS`, which is what makes the agent pseudo-filters
work:

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

### herdr — Homebrew on macOS, curl installer on Linux

`herdr` is a real Homebrew core formula (`brew info herdr` shows
`Homebrew/homebrew-core`, not a tap), so macOS gets it the same way as lazygit/btop
above it in the Brewfile. Linux has no package this young, so it gets the same shape
of official curl installer already used for starship/atuin/uv — `curl -fsSL
https://herdr.dev/install.sh | sh`, landing in `~/.local/bin`.

That `~/.local/bin` destination is exactly the trap [uv](#shell--carapace-fd-uv-and-linux-clipboards)
already taught this repo: `zshrc` puts `~/.local/bin` ahead of Homebrew's `bin` on
`PATH`, so a machine that ever ran herdr's curl installer by hand — before this
Brewfile line existed, or by following herdr's own README — keeps a copy `brew
upgrade` will never see or touch. `which -a herdr` shows both if that's happened;
`rm ~/.local/bin/herdr` lets the Homebrew copy win, same fix as uv's.

### Herdr plugins — the list is tracked, herdr's registry isn't

Herdr keeps its installed-plugin state in `~/.config/herdr/plugins.json`, which it
rewrites on every install: absolute paths, resolved commit SHAs, install timestamps.
That's generated state, not config, so it stays out of this repo — the same call
`herdr_plugins.txt` is the tracked source of truth instead:
```
paulbkim-dev/vim-herdr-navigation           # default branch at install time
someone/their-plugin@v1.2.0                # pinned to a tag, branch, or commit
local:config/herdr/plugins/ticket-worktree # link a checkout in this repo
```

To add a plugin, add the line and re-run `install.sh` — or run
`herdr plugin install <owner>/<repo> --yes` now and add the line so the other machine
picks it up. (Flags go *after* the repo argument; `herdr plugin install --yes <repo>`
is a usage error.) To remove one, delete the line and run
`herdr plugin uninstall <plugin-id>` — nothing prunes plugins automatically, since
removing a plugin also throws away whatever config it had.

A plugin you're developing on this machine is the one case where re-running `install.sh`
would do damage. `herdr plugin link <path>` and `omp plugin link <path>` point the manager
at a working checkout, and installing the published copy over one of those replaces the
link — the checkout keeps existing but stops being what runs. Both plugin steps detect it
and report `local link: <path>` instead of installing. Neither CLI has an "install unless
linked" mode, so the check reads the state each one keeps: herdr records a
`{"kind":"local"}` source in `~/.config/herdr/plugins.json`, and omp's `plugin list --json`
reports a link as a symlinked install directory (git and npm installs are real
directories, and marketplace installs live in a separate array — so a leftover marketplace
install can't be mistaken for a link and skipped forever). herdr's registry records only a
path for a linked plugin, never an `owner/repo`, so the manifest line is matched to it by
the checkout's git origin, falling back to the path tail for a checkout with no origin.

Four plugins used to be listed here and aren't any more. `ribbons-digital/pi-herd`
hardcoded `--name` and `--session-id` into every harness launch, and omp — the agent
this setup drives — hard-errors on `unknown flags: --name, --session-id`; it also
shipped a Pi-only extension. It couldn't drive omp without patching, so it was dropped
from `herdr_plugins.txt` rather than carried as permanently broken.

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
its config directory — which lives in this repo, so deleting
`config/herdr/plugins/config/herdr-plugin-workspace-manager` here clears it everywhere
the tree is linked. The one capability lost with it is `remove-gone`, which previewed
and cleared worktrees whose upstream branch had been deleted; `herdr worktree list`
then `herdr worktree remove --workspace <id>` is the manual form.

`nikok6/herdr-mirror` — a remote herdr's workspaces mirrored into this one's sidebar
over ssh, remote panes streaming into local ones — was removed because it wasn't
wanted. It took the `# local-only` manifest marker with it: mirror was the only spec
that ever carried one and the marker existed *for* it, so `install.sh` no longer
captures a line's trailing comment or looks at `$SSH_CONNECTION` at all. Removal was
four steps, and collie is the reason to expect that: a plugin that runs a daemon owns
state herdr knows nothing about. `herdr plugin action invoke teardown --plugin mirror`
came first, closing every mirrored workspace and pausing autostart; then `herdr plugin
uninstall mirror` — no `--yes` there, uninstall rejects that flag as a usage error
where install requires it; then `config/herdr/plugins/config/mirror`, which lives in
this repo, so deleting it here clears it everywhere the tree is linked. The fourth is
the one teardown doesn't do: `~/.local/state/herdr-mirror` held a per-host ssh
ControlMaster started with `ControlPersist=yes`, so an `ssh -N` to the remote outlived
the daemon, the plugin and the uninstall. Closing it takes
`ssh -S ~/.local/state/herdr-mirror/<host>.ctl -O exit <host>`; then the state
directory goes, along with the empty
`~/.config/herdr-mirror` that pre-dated the move of `hosts.toml` into this repo. Only
the laptop needed any of it, since local-only meant mirror was never installed
anywhere else. `prefix+alt+n`, `prefix+alt+c`, `prefix+alt+v` and `prefix+alt+s` are
free again, and the palette lost ten of its thirty-three actions with it.

With two plugins and four registered actions between them, keybindings stopped
being a per-plugin question and became one decision: `config/herdr/palette/palette.sh`,
bound to `prefix+p` — free because this config moved herdr's own `previous_tab` off it
and onto `prefix+shift+tab` — builds its fzf list at run time from `herdr plugin action
list`, so every action of every installed plugin is one fuzzy search away whether or not
it has a key. Only the ones reached for constantly earn a `[[keys.command]]` entry;

`andyhite.ticket-worktree` — the `prefix+t` binding — lives in this repo at
`config/herdr/plugins/ticket-worktree` and is registered through `herdr_plugins.txt` as a
`local:` line (same status command-palette had before it got its own repo: iterate in-tree
without a separate GitHub repo). Re-running `install.sh` re-links it idempotently via
`herdr plugin link`. The plugin is a single manifest `[[panes]]` entry (`placement =
"popup"`) rather than an action, for the same TTY reason command-palette isn't an action
either — `modal.sh` draws its own form (text field, live `ticket/<key>` branch preview,
Create/Cancel buttons, one screen) in raw-mode ANSI to keep the form on one screen. From
the parsed key it calls `herdr worktree create`, `herdr agent start --kind omp`, and
`herdr pane send-text` (not `agent prompt`, which would submit immediately) to land the
ticket as a queued-but-unsent prompt. Its config
(`config/herdr/plugins/config/andyhite.ticket-worktree/config.toml`) defaults the new
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

### lin — Homebrew tap on macOS, cargo on Linux

`lin` ([aaronkwhite/linear-cli](https://github.com/aaronkwhite/linear-cli)) has no
Homebrew core formula and no apt package, so the Brewfile pulls the author's own tap
(`brew "aaronkwhite/tap/lin"`) rather than building it — same tier as the `herdr` Linux
fallback above, just a tap instead of a curl installer. Linux gets it via `cargo install
lincli` in `install.sh`'s Linux branch (see the [general dev CLIs
bullet](#bootstrap-a-new-machine) above); the crate name (`lincli`) and the binary name
(`lin`) differ. No config file is tracked for it — `lin auth login` (interactive) or the
`LINEAR_API_KEY` environment variable authenticates it per machine, same as any other
credential this repo deliberately keeps out of tracked content.

### Agent skills — the list is tracked, the lockfile isn't

Same shape as Herdr plugins above: `agent_skills.txt` is the tracked source of truth, one
`<owner>/<repo> --skill <name>` per line, and the state the CLI generates alongside it —
`~/.agents/.skill-lock.json`, content hashes and install/update timestamps — stays
untracked.

`install.sh` runs `npx skills add <owner>/<repo> --skill <name> -g -y` for each line.
`-g` writes one canonical copy of the skill into `~/.agents/skills` and symlinks every
agent the CLI detects at that tree, instead of installing into a single project; `-y`
accepts its prompts so this can run with no tty attached. omp needs no install target of
its own here — it picks skills up through its `agents` skill provider, reading
`~/.agents/skills` directly rather than needing anything copied into
`~/.omp/agent/skills`.

(`~/.omp/agent/skills` is a separate, narrower thing: the same `skills` step also
symlinks any skill an installed Herdr plugin ships in its own `skills/` directory there —
unrelated to `agent_skills.txt`, and the one part of this step that isn't new.)

### NvChad — diffview alongside telescope `git_status`

`config/nvim/lua/plugins/init.lua` adds **diffview.nvim** next to NvChad's telescope
`git_status` picker, not instead of it. Telescope builds its file list once at open; the
`<C-g>` reload mapping closes and reopens the picker because telescope has no native way
to notice the index changed under it — still the right tool for jumping to a changed file
by name. diffview is for sitting inside the diff: a live file panel, a diff view that
tracks staging and edits, and a 3-way merge-conflict view telescope has no equivalent for.

Four mappings in `lua/mappings.lua`: `<leader>gd` (`DiffviewOpen`), `<leader>gc`
(`DiffviewClose`), `<leader>gh` (`DiffviewFileHistory %`), `<leader>gH`
(`DiffviewFileHistory`). The plugin is command-gated (`cmd = { … }`) so normal edits do
not pay to load it.

### NvChad's lockfile — install restores it, `:Lazy sync` moves it

`config/nvim/lazy-lock.json` is tracked, which makes it the pinned plugin set every
machine converges on. That only works if machine installs read it rather than write it,
so the **nvim** step runs `Lazy! restore` and not `Lazy! sync`.

`sync` is the wrong verb for a shared lockfile: it updates every plugin to its latest
commit and rewrites the file. `~/.config/nvim` is a symlink into this repo, so that
rewrite lands as an uncommitted change *in the checkout* — harmless locally, and a real
problem on a remote. `--host` refuses to fast-forward a dirty worktree (deliberately: an
edit you made on the far side is not something an installer should discard), so a host
that had run the step once would install a stale copy on every run after it, until
someone ssh'd in and reset the file by hand. The dirty-worktree warning now lists the
paths for exactly this reason — `config/nvim/lazy-lock.json` on that list is the old
behaviour's leftover, and safe to `git checkout --`.

`restore` converges the other way. lazy's startup auto-install already clones anything
missing with `lockfile = true`, i.e. at the pinned commit, and `restore` puts any plugin
that drifted back on its pinned commit. lazy rewrites the lockfile either way, but with
every plugin sitting at the commit already recorded there the bytes come out identical
and git sees nothing.

Moving the pins is therefore deliberate, and belongs on one machine: run `:Lazy sync` in
a real session, then commit the bump (`chore(nvim): bump … lockfile`). Every other
machine picks it up on its next install.

### NvChad's Mason/Treesitter setup — do this yourself, on purpose

NvChad's own quickstart docs say to run `:MasonInstallAll` and `:TSInstallAll` after the
first sync. Neither does what the docs imply on the current starter: `MasonInstallAll`
isn't a real command in `mason.nvim`, and `TSInstallAll` silently no-ops — the actual
command is `:TSInstall <lang>`, and `:TSInstall all` grabs *every* language
nvim-treesitter supports, which is not a sane default for anyone. Neither Mason nor
Treesitter auto-installs on first file-open in this config either. `install.sh`
deliberately does not paper over this with a guessed default set — install what you
actually use:

```
:MasonInstall pyright lua-language-server   " example, not a real default
:TSInstall python lua bash
```

or declare an `ensure_installed` list in `lua/configs/mason.lua` /
`lua/configs/treesitter.lua` once you know what those are.

### Ghostty over SSH — `TERM=xterm-ghostty` doesn't exist on most remotes

Ghostty's `TERM` is `xterm-ghostty`, and most remote hosts don't have that terminfo
entry — without a fix, anything that opens a real terminal (`nvim` included) fails with
`Error opening terminal: xterm-ghostty` the moment you SSH in. `config/ghostty/config`
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
There's no Ghostty-side fix, so `config/hammerspoon/init.lua` replaces the keybind
entirely: an `hs.window.filter` scoped to Ghostty with `currentSpace = true` finds the
window that belongs to the current Space (minimized or hidden windows included — they're
Space-agnostic in macOS, so a naive `visible`-only filter would miss one and spawn a
duplicate instead of restoring it), then hides the whole app (`hs.application:hide()` —
the same instant, no-genie-animation mechanism as Cmd+H, which is what Ghostty's own
toggle already used and the one part of it that was never broken) if that window is
focused, unhides and focuses it otherwise, or runs `ghostty +new-window` if the Space has
none.

Cask, not brew, and macOS-only in every sense — Hammerspoon has no Linux port and no
headless use, so it's absent from `install.sh`'s Linux branch entirely (same treatment as
Docker Desktop above); `config/hammerspoon` is still symlinked on Linux for consistency,
it just does nothing there.

Launch-at-login is Hammerspoon's own preference toggle (menu-bar icon → Preferences →
"Launch at Login"), not something this repo tracks — deliberately: unlike dstack's server
(a background daemon with no UI of its own, hence its tracked LaunchAgent under
`launchd/`), Hammerspoon already ships a working, per-machine-appropriate way to do this,
and duplicating it with a second tracked LaunchAgent just meant two mechanisms fighting
over the same job.

After that:

- Fill in secrets. The installer copies `zshrc.local.example`, `gitconfig.local.example`,
  and `ssh/config.local.example` to their `~/.*.local` targets (mode 600) if they don't
  already exist. Edit those files with real values — `zshrc`/`gitconfig`/`ssh/config`
  each source or include the copy automatically, and all three are git-ignored, so
  secrets never end up in this repo or its history. See [The `*.local`
  templates](#the-local-templates) below.
- Restart your shell (or `exec zsh`). Antidote clones its plugins on first run.

## Making changes

Edit the files in this repo directly — they're the real config, not copies, since
everything under `$HOME` is a symlink back here. Commit and push like normal, then run
`install.sh` (or just `git pull`) on the other machine to pick it up.

### Justfile and CI

The **`Justfile` is the single source of truth for checks.** `.github/workflows/ci.yml`
invokes its recipes and nothing more — a new check gets a recipe plus a one-line CI step,
never a command pasted into `ci.yml` a second time. Recipes assume their dependencies are
already on `PATH` and install nothing themselves; CI's setup step installs `just` (via
`extractions/setup-just@v3`), `zsh` (for `zsh-syntax`), and `pyyaml` (for `templates`)
once before any recipe runs.

| Recipe | What it catches |
| --- | --- |
| `just parse` | `bash -n install.sh` — quoting/`set -e` bugs nobody hits until bootstrap |
| `just shellcheck` | shellcheck on `install.sh` (three deliberate SC codes excluded) |
| `just zsh-syntax` | `zsh -n` on `zshrc`, `zshenv`, and the local template |
| `just templates` | models template parses; tracked routing uses built-in providers only |
| `just leakguard` | work identifiers and committed `ssh_connections` in tracked content |
| `just zed-filter` | the clean filter strips, repairs JSON, and pass-throughs correctly |
| `just check` | all of the above — the fast gate before every commit |
| `just smoke` | `--only configs` twice in a throwaway `HOME`; second run is a no-op |
| `just cli-checks` | `install.sh` argument handling still fails loudly |

Run `just check` and `just smoke` locally before pushing — same as `AGENTS.md`. CI's
**configs** job still asserts individual symlink targets that `smoke` does not; the
**cli** job fakes Darwin on Ubuntu to prove a failed tools step does not abort the run.

Changes land as a direct push to `main`. CI runs on every push, on every branch, so the
checks still report whether a change went straight to `main` or through a branch first.
