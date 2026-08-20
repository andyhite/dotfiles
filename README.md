# dotfiles

Shell and terminal config, synced between my Mac (Ghostty) and remote dev VMs. One Dark
theme everywhere, zsh with antidote instead of oh-my-zsh, starship for the prompt,
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
  - [Git — rebase-first, with delta, difftastic, absorb, and jj](#git--rebase-first-with-delta-difftastic-absorb-and-jj)
  - [Shell — carapace, fd, uv, and Linux clipboards](#shell--carapace-fd-uv-and-linux-clipboards)
  - [dotfiles-help — the `help/` corpus and `dh`](#dotfiles-help--the-help-corpus-and-dh)
  - [gh extensions — manifest beside `herdr_plugins.txt`](#gh-extensions--manifest-beside-herdr_pluginstxt)
  - [btop — One Dark theme, and the config-rewrite trap](#btop--one-dark-theme-and-the-config-rewrite-trap)
  - [Misc dev CLIs — hyperfine, sd, tealdeer, and Docker Desktop](#misc-dev-clis--hyperfine-sd-tealdeer-and-docker-desktop)
  - [Caddy — local HTTPS for internal-only dev hostnames](#caddy--local-https-for-internal-only-dev-hostnames)
  - [dnsmasq — wildcard local DNS via macOS's per-domain resolver](#dnsmasq--wildcard-local-dns-via-macoss-per-domain-resolver)
  - [Zed's `ssh_connections` is stripped by a clean filter](#zeds-ssh_connections-is-stripped-by-a-clean-filter)
  - [omp — one tracked config, two machines, different accounts](#omp--one-tracked-config-two-machines-different-accounts)
  - [billion-context — the model decides what leaves the context](#billion-context--the-model-decides-what-leaves-the-context)
  - [Atuin](#atuin)
  - [herdr — Homebrew on macOS, curl installer on Linux](#herdr--homebrew-on-macos-curl-installer-on-linux)
  - [Herdr plugins — the list is tracked, herdr's registry isn't](#herdr-plugins--the-list-is-tracked-herdrs-registry-isnt)
  - [Herdr plugin keybindings — `[keys]` only knows herdr's own actions](#herdr-plugin-keybindings--keys-only-knows-herdrs-own-actions)
  - [Agent skills — the list is tracked, the lockfile isn't](#agent-skills--the-list-is-tracked-the-lockfile-isnt)
  - [`fleet` — dispatching agents herdr can reach, because omp can't](#fleet--dispatching-agents-herdr-can-reach-because-omp-cant)
  - [The worktree rule was wrong in a way `fleet` made visible](#the-worktree-rule-was-wrong-in-a-way-fleet-made-visible)
  - [The orchestrator is opt-in](#the-orchestrator-is-opt-in)
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
| `config/starship.toml` | `~/.config/starship.toml` | prompt — One Dark Pro preset, hostname shown only over SSH |
| `config/atuin/config.toml` | `~/.config/atuin/config.toml` | Atuin (shell history): overrides only — daemon, fuzzy search, full-style UI, vi keymap, tmux popup, `atuin ai`. Also the answers `atuin setup` would otherwise re-ask on every install |
| `config/atuin/themes/one-dark.toml` | `~/.config/atuin/themes/one-dark.toml` | One Dark for Atuin; foreground colors only, background comes from Ghostty |
| `zshrc.local.example` | (copy, not linked) | template for machine-local secrets — never committed |

### Terminal & workspace

| Path | Links to | What it is |
| --- | --- | --- |
| `tmux.conf` | `~/.tmux.conf` | tmux config, plugins managed by TPM |
| `config/ghostty/config` | `~/.config/ghostty/config` | Ghostty terminal: `One Dark Two` theme, shell integration — same path on macOS and Linux |
| `config/hammerspoon` | `~/.hammerspoon` (macOS only) | Hammerspoon: `init.lua` binds the per-Space Ghostty show/hide toggle that replaced Ghostty's own app-wide one — see [Hammerspoon](#hammerspoon--per-space-ghostty-toggle-ghosttys-own-is-app-wide) below |
| `config/btop` | `~/.config/btop` | btop resource monitor: One Dark theme, `save_config_on_exit = false` so btop's default full-config-rewrite-on-quit can't overwrite this file — see [btop](#btop--one-dark-theme-and-the-config-rewrite-trap) below |
| `config/ghzinga/config.toml` | `~/.config/ghzinga/config.toml` | [ghzinga](https://github.com/osolmaz/ghzinga) — GitHub issue/PR viewer TUI that the herdr plugin shells out to |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager), `one-dark` theme + accent/border overrides |
| `config/herdr/palette` | `~/.config/herdr/palette` | the `prefix+p` command palette — an fzf script run by a `type = "popup"` keybinding, plus the MIT notice of the plugin it's derived from |
| `herdr_plugins.txt` | (not linked — read by `install.sh`) | Herdr plugin list, one `owner/repo[@ref]` per line; `install.sh` installs/updates each one |
| `config/herdr/plugins/config` | `~/.config/herdr/plugins/config` | per-plugin Herdr config, one directory per plugin id — the whole tree is linked, so new plugins land here on install |
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
| `gitconfig` | `~/.gitconfig` | tracked git identity, LFS/xet filter wiring, rebase-first defaults, delta pager + difftastic difftool, and `git absorb`; anything that varies per machine layers in through `gitconfig.local.example` below |
| `gitconfig.local.example` | (copy, not linked) | template for `~/.gitconfig.local` — work identity via `includeIf "gitdir:…"`, private-registry credentials. `gitconfig`'s trailing `[include]` applies last, so anything set here wins over every default in the tracked file |
| `config/git/ignore` | `~/.config/git/ignore` | global gitignore — git's own default `core.excludesFile` location when that setting is unset, so machine-tool droppings (`.DS_Store`, `.idea/`) never have to live in a project's own `.gitignore` |
| `config/gh/config.yml` | `~/.config/gh/config.yml` | gh CLI defaults and aliases; `git_protocol: https` is deliberate — `ssh/config` maps `github.com` to the work SSH key, so an ssh remote here would silently authenticate as the wrong account |
| `gh_extensions.txt` | (not linked — read by `install.sh`) | gh CLI extension manifest, one `owner/repo` per line; `install.sh`'s `gh` step installs new extensions and upgrades ones already present — see [gh extensions](#gh-extensions--manifest-beside-herdr_pluginstxt) |
| `config/jj/config.toml` | `~/.config/jj/config.toml` | jj config for colocated repos — identity, pager, diff formatter; linked because jj refuses to commit without `user.name`/`user.email` |
| `config/lazygit/config.yml` | `~/Library/Application Support/lazygit/config.yml` (macOS), `~/.config/lazygit/config.yml` (Linux) | Lazygit: One Dark theme, Nerd Font v3 icons, fuzzy filtering, and nvim integration; `zshrc` exposes it as `lg`, while the OS-specific destinations are Lazygit's native defaults |
| `ssh/config` | `~/.ssh/config` | portable ssh identity config — per-key `Host` blocks for github.com (`IdentitiesOnly yes` so the agent can't offer the wrong key first), github.com-personal, hf.co, runpod.io, plus dstack's `Include ~/.dstack/ssh/config` (dstack injects that line into `~/.ssh/config` — a symlink into this repo — on every provision, so tracking it is the only way the tree stays clean; inert where dstack has never run); machine-specific hosts live in `~/.ssh/config.local` instead |
| `ssh/config.local.example` | (copy, not linked) | template for `~/.ssh/config.local` — throwaway test hosts, machine-specific aliases. `ssh/config`'s first non-dstack line is `Include ~/.ssh/config.local`, because ssh takes the first value it finds for any option and this is the only way the local file can override rather than be shadowed |

### Agents & orchestration

| Path | Links to | What it is |
| --- | --- | --- |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | [omp](https://omp.sh) coding agent settings — besides this file, `AGENTS.md`, and `rules/output-style.md` below, the rest of `~/.omp/agent` is databases, sessions, and a secrets key |
| `omp/agent/extensions/atuin.ts` | `~/.omp/agent/extensions/atuin.ts` | records omp's `bash` commands into Atuin history as `--author pi` (a `KNOWN_AGENTS` name, so `$all-user` hides them), with omp's intent string as `--intent`. Hand-maintained: `atuin hook install` has no omp target |
| `omp/agent/rules/output-style.md` | `~/.omp/agent/rules/output-style.md` | `alwaysApply: true` rule that shapes every omp response for an ADHD reader — answer first, numbered steps, one next action, no preamble or recap |
| `omp/agent/AGENTS.md` | `~/.omp/agent/AGENTS.md` | omp's native global context file (highest-priority discovery provider — shadows every other tool's user-level context). Holds the same ADHD output-style guidance as `rules/output-style.md` above, since it's a personal preference rather than an omp-specific one; `config/claude/CLAUDE.md` below symlinks straight to this file, so it's the one source of truth |
| `omp/acp-omp.json` | `~/.omp/acp-omp.json` | `billion-context-omp` settings — the compression thresholds, and the two upstream tool guardrails turned off in favour of omp's own. Ordered against `compaction.thresholdPercent` in `config.yml`; see [billion-context](#billion-context--the-model-decides-what-leaves-the-context) |
| `omp_plugins.txt` | (not linked — read by `install.sh`) | omp plugin manifest, one `<install-source> <plugin-name>` per line; `install.sh` runs `omp plugin install <source>` for each, and skips one that's link-installed for local development |
| `agent_skills.txt` | (not linked — read by `install.sh`) | cross-agent skill manifest, one `<owner>/<repo> --skill <name>` per line; `install.sh` runs `npx skills add … -g -y` for each |
| `config/claude/settings.json` | `~/.claude/settings.json` | [Claude Code](https://claude.com/product/claude-code) CLI global settings — ships with only `$schema` for editor validation; the rest of `~/.claude` is sessions, an oauth/telemetry cache, a machine ID, backups, and the `skills/` symlinks `agent_skills.txt` already manages |
| `config/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | a symlink (tracked as one in git) to `omp/agent/AGENTS.md` above — Claude Code's global user memory reuses the exact same content rather than carrying a second copy. The `claude` discovery provider is disabled in `omp/agent/config.yml`, so omp itself reads `AGENTS.md` directly and never this path |

### Repo scripts, checks & docs

| Path | Links to | What it is |
| --- | --- | --- |
| `Brewfile` | (not linked — read by `install.sh`) | macOS formulae + casks for every tool this config drives, applied with `brew bundle` — replaced the old hand-maintained `brew_ensure`/`brew_ensure_cask` loop |
| `Justfile` | (not linked — invoked by `just` and CI) | single source of truth for every check — `.github/workflows/ci.yml` calls its recipes instead of duplicating them; see [Justfile and CI](#justfile-and-ci) |
| `.pre-commit-config.yaml` | (not linked — read by `pre-commit`) | gitleaks plus the local `just leakguard` hook; `install.sh` runs `pre-commit install` during the hooks step so a fresh clone gets both |
| `.markdownlint.yaml` | (not linked — read by `markdownlint-cli2` and nvim's `markdownlint` linter) | shared markdown lint rules: MD013 (line-length) and MD041 (require a top-level heading) off, since neither matches this repo's own conventions — `just fix-md` and the nvim linter both read this one file |
| `bin/dotfiles-help` | `~/.local/bin/dotfiles-help` | renders the `help/` corpus — fzf picker, search, and per-tool sections; aliased as `dh` in `zshrc` — see [dotfiles-help](#dotfiles-help--the-help-corpus-and-dh) |
| `help/` | (not linked — read by `bin/dotfiles-help`) | curated command reference keyed to the Brewfile — one `## <name> — <tagline>` section per tool; `just help-coverage` fails if a formula has no matching section |
| `bin/tailscale` | `~/.local/bin/tailscale` | PATH shim for the Mac App Store build of Tailscale — `exec`s the bundled CLI directly, since a plain symlink to it fails at runtime (see the file itself for why). Linked only on macOS, and only when the App Store app is actually installed |
| `install.sh` | — | installs/updates every tool above, then symlinks all of it into place — locally, or on another machine with `--host` |

## Bootstrap a new machine

```sh
git clone https://github.com/andyhite/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` runs ten steps, and is safe to re-run any time (installs what's missing,
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

1. **Installs/updates the tools this config drives**: starship, zoxide, atuin,
   fzf, eza, bat, direnv, tmux, lazygit, delta, difftastic, git-absorb, jj, fd,
   carapace, gitleaks, pre-commit, just, uv, antidote, TPM, the JetBrains Mono
   Nerd Font, neovim, ripgrep, tree-sitter-cli, mise, omp, claude, btop, herdr,
   gzg (ghzinga), and NvChad —
   plus Docker Desktop on macOS. macOS applies
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
   - gzg (the `ghzinga` crate): no Homebrew formula on either platform, so both branches
     fall back to `cargo install --locked ghzinga` via the same `cargo_ensure_latest`
     helper the Linux-only fallback tools below use.
   - Linux-only: `fd-find` installs as `fdfind`, so `ensure_fd_shim_linux` symlinks
     `~/.local/bin/fd` — telescope and fzf shell out to the literal name `fd`, not a
     shell alias. delta, difftastic, git-absorb, sd, tealdeer, hyperfine, and jj fall
     back to `cargo install` where apt has no package. gitleaks and carapace pull
     GitHub release binaries. `wl-clipboard` and `xclip` install together on Linux so
     tmux-yank and nvim's `+` register can paste on either Wayland or X11.
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
3. **Symlinks every config file** in the table above into place — including
   `config/jj/config.toml` and `bin/dotfiles-help`. Backs up (`.bak.<timestamp>`)
   anything real that's already sitting where a symlink needs to go. Also copies
   `zshrc.local.example`, `gitconfig.local.example`, and `ssh/config.local.example`
   to their `~/.*.local` targets at mode 600 the first time only — a re-run never
   overwrites an already filled-in file. See [The `*.local` templates](#the-local-templates) below.
4. **Registers repo hooks**: the zed-local git clean filter (strips `ssh_connections`
   from `config/zed/settings.json` on the way into the index) and `pre-commit install`
   when the binary is on `PATH`, so `.pre-commit-config.yaml` is live from the first
   commit on a fresh clone. Kept out of the configs step because neither touches a
   home-directory symlink — both act on this repo's `.git`. See the Zed clean-filter and gitleaks / pre-commit notes under Notes by tool below.
5. **Installs the language runtimes pinned in `~/.tool-versions`**, via `mise install`.
   Runs right after the symlinks step and not before: mise reads its pins by walking up
   from wherever it's invoked, and `~/.tool-versions` is the symlink the configs step
   above just created — swap the order and this step runs against nothing on a fresh
   machine. See [mise](#mise) below.
6. **Installs/updates every Herdr plugin** listed in `herdr_plugins.txt`. The tools step
   above installs herdr itself (Brewfile on macOS, the official installer on Linux — see
   [herdr](#herdr--homebrew-on-macos-curl-installer-on-linux) below), and this step is
   still guarded on `command -v herdr` in case that step was skipped or failed on this run.
7. **Installs/updates omp plugins** from `omp_plugins.txt` — one direct git install per
   line, no marketplace. Re-running the install is what updates a git-sourced plugin, the
   opposite of the gh extensions trap below.
8. **Installs/upgrades gh extensions** from `gh_extensions.txt`. Skipped when `gh` is
   missing or unauthenticated; see [gh extensions](#gh-extensions--manifest-beside-herdr_pluginstxt).
9. **Installs cross-agent skills**, from two sources. `agent_skills.txt` first — one
   `npx skills add <owner>/<repo> --skill <name> -g -y` per line — which needs the
   `runtimes` step above to have already put node on `PATH`, hence the ordering. Then
   any skill an installed Herdr plugin ships in its own `skills/` directory, symlinked
   into `~/.omp/agent/skills` — unchanged from before, and run after Herdr because a
   link made before a plugin's first install would point at a path that doesn't exist
   yet.
10. **Headlessly restores NvChad's plugins** (`nvim --headless "+Lazy! restore" +qa`) once
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
all; and zsh itself ships `_tmux`, `_jq`, and `_vim`.

Two details worth knowing. Generation goes through a temp file and only replaces the
target when the output is non-empty, so a tool that starts erroring can't blank a working
completion. And because `zshrc` runs `compinit -C` — which trusts a cached dump rather
than rescanning `fpath` on every shell start — `install.sh` deletes `~/.zcompdump*`
whenever it writes something new, so the next shell rebuilds once.

### The `*.local` templates

Four tracked templates, one convention: `zshrc.local.example`, `gitconfig.local.example`,
`ssh/config.local.example` and `omp/agent/models.yml.example` are copied — never linked —
to their targets at mode 600 the first time `install.sh` runs, and left alone on every
run after that, so a filled-in file is never clobbered. Each one holds real secrets or
per-machine values that have no business in a public repo.

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

`models.yml` doesn't land at `~/.*.local` like the first three — it has to sit in
`~/.omp/agent/` where omp looks for it. It's also the one template that ships inert rather
than empty — it carries a literal `providers: {}`, because omp validates the file's root as
an object and a copy trimmed to pure comments parses as null and warns on every startup.
See [the omp section](#omp--one-tracked-config-two-machines-different-accounts) for what
goes in it.

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
the interactive layer still runs: `PATH`, mise, `compinit`, aliases, zoxide, direnv and
atuin all load exactly as before, so a scripted shell resolves the same commands an
interactive one does.

## Notes by tool

### Git — rebase-first, with delta, difftastic, absorb, and jj

`gitconfig` is deliberately rebase-oriented (`pull.rebase`, `rebase.autoStash`,
`rebase.autoSquash`, `rebase.updateRefs`, `rerere.enabled`, `rerere.autoupdate`) so
review fixups belong spread across existing commits rather than piled into one "address
review" commit at the tip. **delta** is the pager that finally renders those settings:
`core.pager = delta || less` and `interactive.diffFilter = delta --color-only || cat`.
The `|| less` / `|| cat` fallbacks are mandatory — git runs both through `sh -c`, so a
missing delta on a fresh machine (or one where the tools step was declined) falls through
instead of bricking every `git diff`/`log`/`show` and `git add -p`. Delta ships no theme
literally named One Dark; `syntax-theme = OneHalfDark` (sonph/onehalf, based on Atom One
Dark) is the closest bundled match and lines up with lazygit, Ghostty, starship, atuin,
nvim, and omp. `config/lazygit/config.yml` reuses the same `[delta]` block with
`pager: delta --dark --paging=never` — `--paging=never` is load-bearing because lazygit
already scrolls the diff panel itself; a delta that also spawned `less` would deadlock
the panel for input.

**difftastic** is wired as `git dft` (`difftool -t difftastic`), not the default pager.
It diffs syntax trees, which is what you want when a refactor moved or reindented code
and a line-based view reads as a wholesale rewrite; it is deliberately not on every
`git diff` because it is slower on large diffs and has no intra-line word diff.

**git-absorb** (`git absorb = !git-absorb --and-rebase`) is the review-fixup step the
rebase settings above were missing: it assigns worktree hunks to the commits that last
touched those lines and autosquashes immediately, which pairs with `rerere` when the
rebase replays a conflict you already resolved once.

**jj** is optional per checkout (`jj git init --colocate` once) — `.git` stays
authoritative, so lazygit, `gh`, and delta keep working unchanged. It earns its place
from fleet-style work: `jj undo` reverts one operation atomically, and descendant commits
rebase automatically when you amend mid-stack. `config/jj/config.toml` is linked
unconditionally because jj refuses to create a commit without `user.name`/`user.email`,
unlike git. The honest tradeoff is a second mental model on top of git — no staging
area, the working copy is always a commit — which pays off on stacked agent branches but
is not worth reaching for on every repo.

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
`~/.local/bin` on Linux, where no formula exists. **pipx** stays on the Brewfile anyway —
four tools are already installed through it, and removing the manager would strand them.

The trap to know, because it is silent: `zshrc` puts `~/.local/bin` first on `PATH`, so a
standalone Astral install there *shadows* the Homebrew formula on macOS. Both binaries
work, `brew upgrade` only ever moves the one that loses, and nothing warns you — this
machine had a 14-month-old `~/.local/bin/uv` winning over a current formula until it was
removed. On a Mac, let the Brewfile own `uv`; the `uv tool` installs live in
`~/.local/share/uv` and survive deleting the binary.

**wl-clipboard** and **xclip** install together on Linux only. `tmux.conf` sets
`set-clipboard on`, so copy-*out* over SSH uses OSC 52 and lands in the local terminal's
clipboard; tmux-yank and nvim's `+` register still need a real local clipboard binary for
paste-*in*, and Wayland (`wl-copy`) and X11 (`xclip`) need different ones. Installing
both and letting the session pick is cheaper than detecting the display server at install
time.

### dotfiles-help — the `help/` corpus and `dh`

`bin/dotfiles-help` is the front door to the toolchain this repo installs. `install.sh`
symlinks it to `~/.local/bin/dotfiles-help`; `zshrc` aliases `dh` (not `help`, which
zsh's `run-help` already owns). The script resolves its own real path through the
symlink with a portable loop — not `readlink -f`, which BSD/macOS lacks before
`brew install coreutils` — then reads `help/*.md` next to the checkout.

Five modes, all parsing the same corpus:

- **default** (no args, with a tty and `fzf`): interactive picker sorted A–Z by
  name, with a preview pane that re-invokes `dotfiles-help <name>` so the preview
  cannot drift from a direct lookup
- **`<name>`**: print one section — exact match first, then case-insensitive substring on
  name and tagline
- **`--list` / `-l`**: tools grouped by category (A–Z), name A–Z within each
- **`--all` / `-a`**: the whole corpus in curated file order (`00-shell.md`, …)
- **`--search` / `-s TEXT`**: grep section bodies, list matching lines tagged by tool

The parser is shape-sensitive: each tool is `## <name> — <tagline>` (em dash, not hyphen)
with command examples indented four spaces. Retitle a heading out of that shape, or let
another `##` line appear in a body paragraph, and the tool silently drops from every
mode. `just help-coverage` is the other half — it fails when a Brewfile formula has no
matching section (with an explicit alias map for the six names that differ, like
`git-delta` → `delta`).

To add a tool: Brewfile line, Linux install path in `install.sh`, inventory row here, and
a new `## <command> — …` section in the right `help/*.md` file.

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
— squash-merged branches never look merged to `git branch --merged`, but fleet creates a
worktree and branch per dispatched worker, so merged-branch churn is continuous rather
than occasional.

### btop — One Dark theme, and the config-rewrite trap

`config/btop` is linked whole to `~/.config/btop`: `btop.conf` sets `color_theme =
"one-dark"` and `config/btop/themes/one-dark.theme` maps the same hex values as
`config/starship.toml`'s `[palettes.one_dark]` and `config/atuin/themes/one-dark.toml`.
`main_bg` in the theme is Ghostty's actual terminal background (`#21252b`, One Dark Two)
rather than the theoretical One Dark background (`#282c34`) starship and atuin document —
btop always paints its own background pixels, so matching the real terminal is what
avoids a visible seam around the window, the same distinction `config/herdr/config.toml`'s
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

### Misc dev CLIs — hyperfine, sd, tealdeer, and Docker Desktop

**hyperfine** is the only deliberate benchmarking tool beside cloc/dive/ctop.
**sd** is the sed-shaped find/replace with a literal mode; **tealdeer** (`tldr` on
`PATH`) is example-first man pages. Neither drives tracked config beyond being on
the Brewfile/apt path.

**docker-desktop** was the missing runtime for **dive** and **ctop**, which were already
tracked and useless without a daemon. `args: { adopt: true }` on the Brewfile cask is
load-bearing: `/Applications/Docker.app` already exists on the machine this repo runs on,
and a plain `brew bundle` install aborts with "already an App" unless adopt takes over the
existing install. No Linux counterpart in `install.sh` — Docker's apt repo is a host-level
decision, not a dotfiles one.

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
machine, and the model routing in it is identical everywhere: same `modelRoles`, same
`retry.fallbackChains`. Every role names five provider ids in try order — two Anthropic
identities, two OpenAI identities, and Cursor:

```yaml
default:
  - anthropic/claude-sonnet-5         # modelRoles primary — subscription
  - openai-codex/gpt-5.6-terra:medium # subscription
  - anthropic-api/claude-sonnet-5     # API key
  - openai/gpt-5.6-terra:medium       # API key
  - cursor/composer-2.5               # subscription, employer-billed on both machines
```

The Mac authenticates all five, in that order: personal subscriptions first, personal API
keys as overflow once subscription usage is exhausted. A work box authenticates only the
last three and never logs into the subscription providers at all, so its effective order
collapses to `anthropic-api -> openai -> cursor` — with no `config.yml` difference behind
that, only different accounts on each machine.

**Which account pays — an auth question.** The provider name doesn't change: `anthropic`
is `anthropic` everywhere, reached with a subscription OAuth token wherever one is logged
in. omp resolves credentials in a fixed order, and a stored OAuth session beats every
environment variable:

```
1  --api-key (runtime)          5  provider env var, incl. .env files
2  models.yml apiKey            6  other stored API key
3  stored OAuth credential      7  models.yml custom-provider resolver
4  login-sourced stored key
```

So exporting `ANTHROPIC_API_KEY` on a box that has ever run `/login anthropic` does
nothing for the bare `anthropic` id — the subscription keeps paying, silently, and
nothing warns you.

**Anthropic needs a second provider id, not a credential swap.** A `models.yml`
`providers.anthropic.apiKey` override replaces the one credential `anthropic` resolves
to; it can't hold a subscription and an API key concurrently for the same id. Since the
chain wants both as distinct, ordered tiers, the API-key account gets its own id —
`anthropic-api` — with its own full model catalog, because a custom provider id doesn't
inherit the built-in one:

```yaml
# ~/.omp/agent/models.yml
providers:
  anthropic-api:
    baseUrl: https://api.anthropic.com
    api: anthropic-messages
    auth: none
    headers:
      x-api-key: "!sh -c '. \"$HOME/.omp/agent/.env\"; printf %s \"$ANTHROPIC_API_KEY\"'"
    models:
      - id: claude-sonnet-5
        name: Claude Sonnet 5 (API)
        reasoning: true
        input: [text, image]
        contextWindow: 1000000
        maxTokens: 128000
      # ...one entry per model referenced from config.yml
```

`auth: none` skips the normal credential lookup so the explicit header authenticates
instead. API keys use `x-api-key`; `Authorization: Bearer` is for OAuth/WIF tokens, and on
omp 17.2.13 the plain `apiKey` field produced bearer-auth 401s in fresh interactive
sessions where print mode succeeded — the internal cause is unconfirmed, so the header
form is deliberate. The `!` resolver sources the dotenv file itself: command resolvers do
not inherit values loaded by omp's own dotenv loader, so `!printenv ANTHROPIC_API_KEY`
resolves to nothing for a key that lives only in `~/.omp/agent/.env`. OpenAI's API tier
needs no override at all — the built-in `openai` id already means "API key", separate
from the subscription `openai-codex` id, so a plain `export OPENAI_API_KEY` is enough as
long as that box has never run `/login openai`.

Secrets go in `~/.omp/agent/.env`, not `~/.zshrc.local`: omp loads that dotenv file
itself, so the keys are present no matter how omp is launched, while `~/.zshrc.local`
only reaches processes started from a login shell.

**Why a custom provider id in a shared chain is normally forbidden, and why this one is
allowed.** omp validates every fallback-chain entry against its model catalog, not
against credentials: an unresolvable *built-in* id (no credential) is skipped silently,
but an unresolvable *custom* id (missing from `models.yml` entirely) warns once per role
at every startup:

```
Warning: Fallback chain for role 'default' references unknown model: anthropic-api/claude-sonnet-5
```

That is why the Justfile's routing check allows built-in ids plus `anthropic-api`
specifically, and nothing else: every machine that runs this config is required to define
`anthropic-api` locally — even a fresh personal machine — so that warning never fires. A
one-off custom id doesn't carry that guarantee and has no business in the tracked chains.

**Reducing a machine to API tiers only needs no `config.yml` change.** A work VM that must
only ever bill an employer's API accounts doesn't get a different `config.yml` — it gets a
different `~/.omp/agent/models.yml` and a different set of authenticated providers.
Define `anthropic-api` there (the same block, an employer key), export
`ANTHROPIC_API_KEY` / `OPENAI_API_KEY` in its `~/.omp/agent/.env`, and never run `/login
anthropic` or `/login openai-codex` on that box. With both subscription ids permanently
unresolvable there, every role's fallback order collapses on its own — no separate config,
no warning, because "no credential" and "no such provider" are different failure modes and
only the second one is noisy. Cursor is unaffected either way: it's the one tier both
machines are meant to share, billed to the same employer-provided account on both.

`~/.omp/agent/models.yml` is created from `omp/agent/models.yml.example` on every machine,
so the mechanism is discoverable even where a given machine only uses part of it. The
shipped copy is inert but not empty — it carries a literal `providers: {}`, because omp
validates the root as an object and a file trimmed to pure comments parses as null and
prints a validation warning on every startup.

That leaves nothing per-machine in `config.yml` at all, which is the point: one tracked
file, every machine, and the only difference is which providers each one has bothered to
authenticate.

### billion-context — the model decides what leaves the context

`billion-context-omp` (`omp_plugins.txt`) takes over from omp's auto-compaction as the
*primary* context authority. omp's own compaction is threshold-driven and destructive:
cross the line and the history becomes one summary. This extension hands the model a
`compress` tool instead and lets it choose which message ranges to fold, so a folded range
stays a labelled block — `decompress` restores it, `search_context` searches inside it
without restoring, and `/acp` reports what's currently folded.

Its settings live in `omp/acp-omp.json`, linked to `~/.omp/acp-omp.json`. They can't live
in `config.yml`: that file belongs to omp, which rewrites it, so a comment explaining a
number there wouldn't survive one session. JSON can't carry comments either — which is why
every value in that file is justified here instead.

**The threshold ladder is the load-bearing part.** Four mechanisms can drop content, and
they only compose as an escalation if their thresholds stay ordered. Percentages are of the
model's context window:

| At | What fires | Where it's set |
| --- | --- | --- |
| +22.5k growth, 50k foldable | soft nudge — the model is asked to compress | `compress.nudgeGrowthTokens` |
| 30% | forced nudge — the ask stops being optional | `compress.maxContextLimit` |
| 35% | the extension truncates old tool output itself | `compress.emergencyThresholdPercent` |
| 40% | omp's snapcompact, as a genuine last resort | `compaction.thresholdPercent` |

The *ordering* is what makes the extension primary. `compaction.thresholdPercent` was once
70, below the extension's forced nudge, which left that whole tier unreachable — the plugin
would be installed and snapcompact would still do all the work. Upstream's default
`emergencyThresholdPercent` of 95% inverts the same way against an omp backstop, which is
why it sits below it here. **Those four numbers are one setting spread across two files** —
move one and check the rest.

The tier *values* came down from 75/85/90 after measuring what they cost. Percentages are of
the window and every routed Anthropic model carries a 1M one, so a 75% forced nudge meant no
fold until three-quarters of a million tokens; the largest prefix actually observed was 767k.
Cache reads are 63.5% of this repo's Anthropic spend and scale linearly with prefix size —
there is no long-context premium to duck, a 900k request bills at the same per-token rate as
a 9k one — so that headroom was being re-read on every request of every long session. 30%
caps the routed models near 300k while staying above the observed 173k average, so typical
sessions fold no more often than before and only the expensive tail is cut.

`compaction.idleEnabled` is on for the same reason, and it is the cheapest tier to spend. It
fires only above `compaction.idleThresholdTokens` (200k) and only after
`compaction.idleTimeoutSeconds` (300s) of idle, so it targets precisely the sessions whose
oversized prefix is about to be re-read many more times, and it spends the fold when no turn
is waiting on it. The guard is what keeps it honest: a fold's real cost is the cache it
invalidates plus the summarizer call, and below 200k there is not enough prefix to earn that
back.

Auto-compaction stays *enabled* rather than switched off, so omp's overflow recovery — the
path taken when a request actually comes back with a context-length error — is still there.
Manual `/compact` works either way.

**Two guardrails are turned off because omp's own are better.** `toolOutputMaxBytes: 0` and
`toolBashDefaultTimeout: 0`. The extension head-truncates an oversized tool result and, for
anything but `bash`, keeps no copy of the rest — the tail is simply gone. omp already caps
tool output *and* spills the full text to an `artifact://` id the model can page through,
so its version costs the same and loses nothing. The 60-second `bash` default is likewise
narrower than omp's own deadline handling, and it would kill exactly the long, legitimate
commands this repo runs: `just smoke`, `brew bundle`.

**`autoUpdate: false`** because upstream defaults to polling npm after every LLM call and
`npm install`ing a newer release in place. For the code that rewrites every request, on a
package that shipped 17 versions in its first three days, that's the machine changing with
no commit here. `./install.sh --only omp` is the update path, same as everything else in
the manifest.

**Three keys are deliberately left unset.** `transformMode` resolves *per API* when unset —
the extension rewrites the provider wire payload for Anthropic and ollama, and rewrites the
context event everywhere else, because three of omp's other providers discard a payload
replacement outright. Pinning either value would break one of the two families, and the
routing in `config.yml` reaches both. `modelContextLimit` is unset for the same reason:
roles route to models with different windows, and one fixed number would mis-tune every
model but one. `prompts` is unset because those four strings *are* the compression rules;
overriding them is the one change here that trades summary quality directly, which is why
upstream gates it behind a separate `acknowledgePromptsRisk` flag.

**`nudgeGrowthTokens` stays at upstream's 50000**, even though fewer and larger folds is the
cheaper direction. The extension's fixed cost — roughly 5k tokens of system prompt and tool
schemas on every turn — sits in the cached prefix and is nearly free to re-read. What
actually costs money is the fold itself: a fold rewrites messages near the *start* of the
prefix, and editing a message invalidates the cache from that point forward, so an early
edit forfeits nearly all of it and the next turn pays full price. Raising the number buys
fewer forfeits at the price of coarser summaries, and that trade wants a measurement rather
than a guess. It's pinned rather than left implicit only so an upstream default change can't
move it silently.

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

**The tmux popup is latched into the environment.** `[tmux] enabled` is read by
`atuin init`, which exports `ATUIN_TMUX_POPUP_WIDTH`/`_HEIGHT` when it's on and
`ATUIN_TMUX_POPUP=false` when it's off — and the popup check honors that variable over
the config. So flipping it needs a new shell, and any shell started before the flip
keeps exporting the old answer into everything it spawns. If `Ctrl+R` draws inline
inside tmux when it shouldn't, that stale export is why:

```sh
printenv ATUIN_TMUX_POPUP   # prints nothing when the popup is live
```

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

**gzg**, the `ghzinga` crate's binary, lives one level below this: it's what the
`osolmaz/ghzinga/plugins/herdr` plugin (`herdr_plugins.txt`) shells out to on a
ctrl-click, and `config/ghzinga/config.toml` is its config, not the plugin's. No
Homebrew formula exists for it on either platform, so both branches of the tools
step fall back to `cargo_ensure_latest ghzinga gzg` — the same crates.io-version-
checked cargo install the Linux-only fallback tools use, just called unconditionally
here since there's no brew alternative to prefer first.

### Herdr plugins — the list is tracked, herdr's registry isn't

Herdr keeps its installed-plugin state in `~/.config/herdr/plugins.json`, which it
rewrites on every install: absolute paths, resolved commit SHAs, install timestamps.
That's generated state, not config, so it stays out of this repo — the same call
antidote's generated `zsh_plugins.zsh` gets. `herdr_plugins.txt` is the tracked source
of truth instead:

```
persiyanov/herdr-reviewr          # default branch at install time
someone/their-plugin@v1.2.0       # pinned to a tag, branch, or commit
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
each new worktree — went the same way once `fleet` started building the workspaces it
dispatches into itself. Two things arranging one fresh worktree is the same race that
got reviewr's `auto_open` turned off, and the plugin only ever won it on a repo it had
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

With ten plugins and twenty-three registered actions between them, keybindings stopped
being a per-plugin question and became one decision: `config/herdr/palette/palette.sh`,
bound to `prefix+p` — free because this config moved herdr's own `previous_tab` off it
and onto `prefix+shift+tab` — builds its fzf list at run time from `herdr plugin action
list`, so every action of every installed plugin is one fuzzy search away whether or not
it has a key. Only the ones reached for constantly earn a `[[keys.command]]` entry;
ghzinga's click-driven `open` and worktree-setup's total absence of actions all stay
reachable through the palette instead of crowding the keymap.

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

Herdr's packed sidebar renders only the tokens named in a `[ui.sidebar.agents]`/
`[ui.sidebar.spaces]` row — a plugin can write a custom token correctly and still be
invisible if nothing names it. Two plugins depend on this: `herdr-agent-inbox`
contributes `$title`, `$flag`, `$age`, `$since`, and the workspace-level `$agents`/
`$busy`; `gh-pr` contributes `$pr`, the branch's PR state as `#123 ✓`. Both rows are
named in `config/herdr/config.toml` — miss one and its plugin looks broken when it's
actually just unrendered.

`worktree.created` fires on a new worktree and `worktree-setup` makes the checkout
usable — copies `.env*` from the main checkout, `mise trust`, `direnv allow`, installs
deps. Nothing else runs at that moment, by design: arranging the workspace belongs to
whoever asked for the worktree. `fleet` builds its own tabs and panes and starts the
agent itself via `herdr agent start`, which blocks until herdr detects it's ready; a
worktree created by hand stays one bare pane until you shape it. `reviewr` could
auto-open here too and deliberately doesn't — a branch cut seconds ago is a zero-line
diff, and on a fleet worktree the pane would land on top of the layout fleet just
declared. `prefix+alt+r` opens it when there is finally something to read.

### Herdr plugin keybindings — `[keys]` only knows herdr's own actions

herdr's `[keys]` table takes only its own built-in action names — there's no field in
it that names a plugin action. The only way to bind one to a key is `[[keys.command]]`,
which shells back out to the herdr CLI instead of naming the action in config:

```toml
[[keys.command]]
key = "prefix+i"
type = "shell"
command = "herdr plugin action invoke settle --plugin herdr-agent-inbox"
```

`type` controls how the command surfaces: `shell` runs it detached in the background,
`pane` opens a temporary pane that closes when the command exits, `popup` opens a
session-modal terminal. Plugin actions invoked this way are short control commands with
no output worth watching, so `shell` is the right call almost every time.

Several plugin READMEs (reviewr, vim-herdr-navigation, token-dashboard) still
document `type = "plugin_action"` with a combined `<plugin>.<action>` command string
instead of this. That form is stale: `herdr --default-config` on 0.8.0 documents only
`shell`/`pane`/`popup`, and `plugin_action` isn't one of them. Use the `shell`-plus-CLI
form above regardless of what a given plugin's own docs say.

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

### `fleet` — dispatching agents herdr can reach, because omp can't

`fleet` dispatches peer coding agents into herdr worktree workspaces: each worker is a
separate `omp` in its own pane, worktree, and branch, rather than an in-process `task`
subagent. It moved to [andyhite/foreman](https://github.com/andyhite/foreman), which
keeps the transport, lifecycle, and workspace-ownership rationale with the implementation.

Two names there, and they are not interchangeable: **Fleet** is what's published, as two
plugins; **Foreman** is only the repository they live in. It published them through a
marketplace named `foreman` until that was dropped — marketplace plugins load through
omp's claude-plugins provider, so a `disabledProviders` entry aimed at real `~/.claude`
content also silently excluded Fleet's own commands and skills. The CLI arrives through
Fleet's herdr plugin, listed in `herdr_plugins.txt`; its startup hook puts `fleet` on
`PATH`. The orchestrator procedure (`skill://fleet` and `/fleet:*`) plus the `fleet_*`
custom tools are Fleet's omp plugin, now a direct git install of the repo root — see
`omp_plugins.txt`, which also records the one-time cleanup for machines that still carry
either marketplace. This checkout retains only the general worktree rule below.

### The worktree rule was wrong in a way `fleet` made visible

`omp/agent/rules/herdr-worktrees.md` used to say, with `alwaysApply: true`, that inside
herdr you always use `herdr worktree` and never `git worktree`. Writing `fleet` on top of
it exposed the flaw: **an agent cannot move itself into the worktree it just created.** An
omp process keeps the directory it launched in, and `herdr pane move` relocates a pane's
display rather than its shell's cwd. So for an agent's own use — building another ref,
diffing two versions — `herdr worktree create` buys a sidebar entry, a tab and a pane it
did not want.

The rule is now organised around who will occupy the worktree. Someone else will sit in
it, human or agent: `herdr worktree create`, which is the only path that runs
`tdi.worktree-setup` (the `.env*` copy, `mise trust`, `direnv allow`).
Nobody will, and you only need the files: plain `git worktree add` in a temp directory,
plain `git worktree remove` after. Removal has to match creation — `git worktree remove`
on a herdr-created worktree orphans the workspace, leaving a sidebar entry pointing at
nothing.

One measured trap, on 0.8.0: `herdr worktree open` is *not* a way to promote a plain
`git worktree add` into a real workspace. `tdi.worktree-setup` hooks `worktree.created`
only, so an opened worktree never gets its `.env*`, its `mise trust` or its installed
deps — you get a workspace wrapped around a checkout that is still unusable.

### The orchestrator is opt-in

Dropping `alwaysApply` was also what kept `fleet` from becoming ambient. An always-on rule
about worktrees is one short step from every session deciding to dispatch a fleet at its
own discretion. The rule is now a rulebook entry — it keeps its `description`, and the
model reads it through `rule://herdr-worktrees` when it is actually about to touch a
worktree. Orchestration is a separate, deliberate opt-in: `/fleet:foreman <objective>`, a
command from Fleet's omp plugin, which adopts the role and points at `skill://fleet`
for the procedure. Nothing loads that skill on its own; a session that never asks for a
fleet never hears about one.

Worth being clear about what is *not* doing the gating here, because all three look like
they should. Rules have no per-agent scoping — there is no frontmatter field binding one
to an agent, and `scope:` scopes TTSR stream surfaces, not agents. Skills are session-wide
for the same reason: every documented filter (`ignoredSkills`, `disabledExtensions`,
the per-source toggles) applies to the whole session. And omp has no `--agent` flag, so a
task-agent definition can't back a top-level session either. The launch is identical for
orchestrator and worker; the only difference is that one of them was told to be one.

### NvChad — diffview alongside telescope `git_status`

`config/nvim/lua/plugins/init.lua` adds **diffview.nvim** next to NvChad's telescope
`git_status` picker, not instead of it. Telescope builds its file list once at open; the
`<C-g>` reload mapping closes and reopens the picker because telescope has no native way
to notice the index changed under it — still the right tool for jumping to a changed file
by name. diffview is for sitting inside the diff: a live file panel, a diff view that
tracks staging and edits, and a 3-way merge-conflict view telescope has no equivalent for.
herdr-reviewr covers reviewing from a standalone pane; diffview covers "already inside
nvim on this repo".

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
none. See the `hammerspoon` section in `help/00-shell.md` for the command reference.

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
- Open tmux and press `prefix+I` to have TPM install its plugins on first run.

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
| `just help-coverage` | every Brewfile entry has a matching `help/*.md` section |
| `just check` | all of the above — the fast gate before every commit |
| `just smoke` | `--only configs` twice in a throwaway `HOME`; second run is a no-op |
| `just cli-checks` | `install.sh` argument handling still fails loudly |

Run `just check` and `just smoke` locally before pushing — same as `AGENTS.md`. CI's
**configs** job still asserts individual symlink targets that `smoke` does not; the
**cli** job fakes Darwin on Ubuntu to prove a failed tools step does not abort the run.

Changes land as a direct push to `main`. CI runs on every push, on every branch, so the
checks still report whether a change went straight to `main` or through a branch first.
