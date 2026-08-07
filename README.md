# dotfiles

Shell and terminal config, synced between my Mac (Ghostty) and remote dev VMs. One Dark
theme everywhere, zsh with antidote instead of oh-my-zsh, starship for the prompt,
NvChad for editing.

## What's in here

| Path | Links to | What it is |
|---|---|---|
| `zshrc` | `~/.zshrc` | zsh config: completion, antidote plugin load, history, aliases, tool init hooks |
| `tool-versions` | `~/.tool-versions` | mise runtime pins (node, python, go, bun, pnpm) — mise walks up from the current directory to find this, so the symlink is the global default under `$HOME`; see [mise](#mise) below |
| `zsh_plugins.txt` | `~/.zsh_plugins.txt` | antidote's plugin list (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, zsh-vi-mode) |
| `tmux.conf` | `~/.tmux.conf` | tmux config, plugins managed by TPM |
| `config/starship.toml` | `~/.config/starship.toml` | prompt — One Dark Pro preset, hostname shown only over SSH |
| `config/ghzinga/config.toml` | `~/.config/ghzinga/config.toml` | [ghzinga](https://github.com/osolmaz/ghzinga) — GitHub issue/PR viewer TUI that the herdr plugin shells out to |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager), `one-dark` theme + accent/border overrides |
| `herdr_plugins.txt` | (not linked — read by `install.sh`) | Herdr plugin list, one `owner/repo[@ref]` per line; `install.sh` installs/updates each one |
| `config/herdr/plugins/config` | `~/.config/herdr/plugins/config` | per-plugin Herdr config, one directory per plugin id — the whole tree is linked, so new plugins land here on install |
| `config/herdr/plugins/local/omp-subagents` | (not linked — `herdr plugin link`ed directly) | the `omp.subagents` Herdr plugin: read-only pane viewer for the subagent-panes feature; see [Subagent panes](#subagent-panes) below |
| `config/ghostty/config` | `~/.config/ghostty/config` | Ghostty terminal: `One Dark Two` theme, shell integration — same path on macOS and Linux |
| `config/aerospace/aerospace.toml` | `~/.config/aerospace/aerospace.toml` | [AeroSpace](https://nikitabobko.github.io/AeroSpace/guide) — i3-like tiling window manager. Bindings live on a `cmd+ctrl` layer rather than AeroSpace's default `alt`, which would collide with herdr; see [AeroSpace](#aerospace) below. Linked on macOS only, and `start-at-login = false` so it never runs uninvited |
| `config/atuin/config.toml` | `~/.config/atuin/config.toml` | Atuin (shell history): overrides only — daemon, fuzzy search, full-style UI, vi keymap, tmux popup, `atuin ai`. Also the answers `atuin setup` would otherwise re-ask on every install |
| `config/atuin/themes/one-dark.toml` | `~/.config/atuin/themes/one-dark.toml` | One Dark for Atuin; foreground colors only, background comes from Ghostty |
| `config/nvim` | `~/.config/nvim` | [NvChad](https://nvchad.com) starter — vendored once, `.git` stripped, fully mine to edit from here |
| `config/zed/settings.json` | `~/.config/zed/settings.json` | Zed editor settings — `disable_ai: true` since agents run from the terminal via omp, not inside the editor, so the `agent`/`agent_servers` keys go undefined rather than tracked as dead config. `ssh_connections` is also deliberately dropped: it's per-machine session state Zed rewrites on every connect |
| `gitconfig` | `~/.gitconfig` | tracked git identity, LFS/xet filter wiring, and defaults meant to hold on every machine; anything that varies per machine layers in through `gitconfig.local.example` below |
| `gitconfig.local.example` | (copy, not linked) | template for `~/.gitconfig.local` — work identity via `includeIf "gitdir:…"`, private-registry credentials. `gitconfig`'s trailing `[include]` applies last, so anything set here wins over every default in the tracked file |
| `config/git/ignore` | `~/.config/git/ignore` | global gitignore — git's own default `core.excludesFile` location when that setting is unset, so machine-tool droppings (`.DS_Store`, `.idea/`) never have to live in a project's own `.gitignore` |
| `config/gh/config.yml` | `~/.config/gh/config.yml` | gh CLI defaults and aliases; `git_protocol: https` is deliberate — `ssh/config` maps `github.com` to the work SSH key, so an ssh remote here would silently authenticate as the wrong account |
| `ssh/config` | `~/.ssh/config` | portable ssh identity config — per-key `Host` blocks for github.com (`IdentitiesOnly yes` so the agent can't offer the wrong key first), github.com-personal, hf.co, runpod.io; machine-specific hosts live in `~/.ssh/config.local` instead |
| `ssh/config.local.example` | (copy, not linked) | template for `~/.ssh/config.local` — dstack's generated `Include`, throwaway test hosts. `ssh/config`'s first real line is `Include ~/.ssh/config.local`, because ssh takes the first value it finds for any option and this is the only way the local file can override rather than be shadowed |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | [omp](https://omp.sh) coding agent settings — besides this file and `rules/output-style.md` below, the rest of `~/.omp/agent` is databases, sessions, and a secrets key |
| `omp/agent/extensions/atuin.ts` | `~/.omp/agent/extensions/atuin.ts` | records omp's `bash` commands into Atuin history as `--author pi` (a `KNOWN_AGENTS` name, so `$all-user` hides them), with omp's intent string as `--intent`. Hand-maintained: `atuin hook install` has no omp target |
| `omp/agent/extensions/herdr-subagent-panes.ts` | `~/.omp/agent/extensions/herdr-subagent-panes.ts` | opens a read-only Herdr pane per omp subagent the moment it spawns, tailing its live session transcript as it works; see [Subagent panes](#subagent-panes) below |
| `omp/agent/rules/output-style.md` | `~/.omp/agent/rules/output-style.md` | `alwaysApply: true` rule that shapes every omp response for an ADHD reader — answer first, numbered steps, one next action, no preamble or recap |
| `Brewfile` | (not linked — read by `install.sh`) | macOS formulae + casks for every tool this config drives, applied with `brew bundle` — replaced the old hand-maintained `brew_ensure`/`brew_ensure_cask` loop |
| `bin/tailscale` | `~/.local/bin/tailscale` | PATH shim for the Mac App Store build of Tailscale — `exec`s the bundled CLI directly, since a plain symlink to it fails at runtime (see the file itself for why). The `AltanS/collie` herdr plugin shells out to bare `tailscale`, so without this on `$PATH` its bridge can't publish itself. Linked only on macOS, and only when the App Store app is actually installed |
| `agent_skills.txt` | (not linked — read by `install.sh`) | cross-agent skill manifest, one `<owner>/<repo> --skill <name>` per line; `install.sh` runs `npx skills add … -g -y` for each |
| `zshrc.local.example` | (copy, not linked) | template for machine-local secrets — never committed |
| `install.sh` | — | installs/updates every tool below, then symlinks all the config above into place |

## Bootstrap a new machine

```sh
git clone https://github.com/andyhite/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` runs eight steps, and is safe to re-run any time (installs what's missing,
updates what's already there). With a terminal attached each step asks first and Enter
accepts; without one, or with `--yes`, it runs everything unattended:

```sh
./install.sh --yes                 # unattended, everything
./install.sh --only configs        # just re-link the dotfiles
./install.sh --skip tools,nvim     # skip the slow parts
./install.sh --verbose             # show each installer's own output
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
   fzf, eza, bat, direnv, tmux, antidote, TPM, the JetBrains Mono Nerd Font, neovim,
   ripgrep, tree-sitter-cli, mise, omp, and NvChad. macOS applies `Brewfile` with
   `brew bundle` (formulae + casks, including Ghostty itself); Linux goes through
   `apt` where a package exists, and falls back to each tool's official installer
   otherwise:
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
   (`.bak.<timestamp>`) anything real that's already sitting where a symlink needs to
   go. Also copies `zshrc.local.example`, `gitconfig.local.example`, and
   `ssh/config.local.example` to their `~/.*.local` targets at mode 600 the first time
   only — a re-run never overwrites an already filled-in file. See [The `*.local`
   templates](#the-local-templates) below.
4. **Installs the language runtimes pinned in `~/.tool-versions`**, via `mise install`.
   Runs right after the symlinks step and not before: mise reads its pins by walking up
   from wherever it's invoked, and `~/.tool-versions` is the symlink the configs step
   above just created — swap the order and this step runs against nothing on a fresh
   machine. See [mise](#mise) below.
5. **Offers to log in to Atuin sync**, but only when not already logged in and only when
   a terminal is actually attached. Everything else about Atuin lives in
   `config/atuin/config.toml`; sync is account state, so it can't be committed. See
   [Atuin](#atuin) below.
6. **Installs/updates every Herdr plugin** listed in `herdr_plugins.txt`, then links any
   plugin developed in this repo itself (`config/herdr/plugins/local/*/`, currently just
   `omp.subagents`) straight from its working copy with `herdr plugin link`. Skipped with
   a note if `herdr` isn't on `PATH` — this repo configures Herdr but doesn't install it.
7. **Installs cross-agent skills**, from two sources. `agent_skills.txt` first — one
   `npx skills add <owner>/<repo> --skill <name> -g -y` per line — which needs the
   `runtimes` step above to have already put node on `PATH`, hence the ordering. Then
   any skill an installed Herdr plugin ships in its own `skills/` directory, symlinked
   into `~/.omp/agent/skills` — unchanged from before, and run after Herdr because a
   link made before a plugin's first install would point at a path that doesn't exist
   yet.
8. **Headlessly syncs NvChad's plugins** (`nvim --headless "+Lazy! sync" +qa`) once
   neovim and the config are both in place.

### Completions

`zshrc` puts `~/.local/share/zsh/site-functions` first on `fpath` so a completion
generated from the installed binary beats a distro's stale copy. `install.sh` writes one
per tool that has a generator:

| Tool | Generator |
|---|---|
| starship | `starship completions zsh` |
| atuin | `atuin gen-completions --shell zsh` |
| bat | `bat --completion zsh` |
| ripgrep | `rg --generate complete-zsh` |
| omp | `omp completions zsh` |
| herdr | `herdr completion zsh` |
| tree-sitter | `tree-sitter complete --shell zsh` |
| mise | `mise completion zsh` |

Deliberately absent, because generating a file would be worse than what already works:
`eza` and `zoxide` have no generator (Homebrew ships `_eza`/`_zoxide`); `direnv` and
`nvim` publish no zsh completion at all; `fzf` comes from the `fzf --zsh` eval in
`zshrc`; and zsh itself ships `_tmux`, `_jq` and `_vim`.

Two details worth knowing. Generation goes through a temp file and only replaces the
target when the output is non-empty, so a tool that starts erroring can't blank a working
completion. And because `zshrc` runs `compinit -C` — which trusts a cached dump rather
than rescanning `fpath` on every shell start — `install.sh` deletes `~/.zcompdump*`
whenever it writes something new, so the next shell rebuilds once.

### The `*.local` templates

Three tracked templates, one convention: `zshrc.local.example`, `gitconfig.local.example`,
and `ssh/config.local.example` are copied — never linked — to their `~/.*.local` targets
at mode 600 the first time `install.sh` runs, and left alone on every run after that, so
a filled-in file is never clobbered. Each one holds real secrets or per-machine values
that have no business in a public repo.

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

### AeroSpace

`config/aerospace/aerospace.toml` configures [AeroSpace](https://nikitabobko.github.io/AeroSpace/guide),
an i3-like tiling window manager. Everything omitted falls back to AeroSpace's built-in
defaults with one exception that matters: `mode.*.binding` falls back to an **empty
table**, so that file is the complete and only source of keybindings — there is no
inherited default set underneath it.

**It does not start itself.** `start-at-login = false`, and nothing in `install.sh` runs
`open -a AeroSpace`. Launch it deliberately, and flip that key once it's earned a place
in the login sequence.

#### The bindings are on `cmd+ctrl`, and that's forced

AeroSpace's defaults are `alt`-based, following i3. They can't be kept here:

| Layer | Why it's unavailable |
|---|---|
| `alt + <key>` | herdr's plugin layer is `prefix+alt+<key>` — `ctrl+b` *then* the alt chord as a separate keystroke. AeroSpace's event tap sees that second keystroke as a bare `alt+<key>` and swallows it before herdr gets it, taking out `alt+h`, `alt+l`, `alt+m`, `alt+d`, `alt+r`, `alt+n`, `alt+c`, `alt+v`, `alt+s` and `alt+1..9` — almost exactly AeroSpace's default set |
| `ctrl + h/j/k/l` | bound globally by vim-herdr-navigation, via the `[[keys.command]]` blocks in `config/herdr/config.toml` |
| `cmd + <key>` | `cmd+h` is Hide Application, `cmd+l` the address bar in every browser, `cmd+w` closes the window |

`cmd+ctrl` is free. macOS only claims `ctrl+cmd+f` (native fullscreen, shadowed on
purpose), `ctrl+cmd+space` (Character Viewer) and `ctrl+cmd+q` (Lock Screen), none of
which are bound.

Shift widens each motion from *move focus* to *move the window*, matching
`config/herdr/config.toml`'s `focus_pane_*` vs `swap_pane_*` and vim's `<C-w>h` vs
`<C-w>H`. Anything that would need a third modifier goes in a binding mode instead of
growing a four-key chord.

| Chord | Action | + shift |
|---|---|---|
| `cmd+ctrl+h/j/k/l` | focus left/down/up/right | move the window |
| `cmd+ctrl+t/w/c/m/a` | workspace Terminal/Web/Comms/Mail/Ai | send window there and follow |
| `cmd+ctrl+1/2/3` | scratch workspaces | send window there and follow |
| `cmd+ctrl+tab` | last workspace | — |
| `cmd+ctrl+n` | focus other monitor | move window to it |
| `cmd+ctrl+f` | fullscreen (AeroSpace's, no macOS Space) | toggle floating |
| `cmd+ctrl+r` | resize mode — bare `h/l/j/k`, `esc` to exit | — |
| `cmd+ctrl+shift+;` | service mode — reload, flatten tree, `join-with` | — |

#### Ghostty gets a workspace, not a floating window

`config/ghostty/config` sets `fullscreen = non-native` and binds
`global:ctrl+enter=toggle_visibility`, making the terminal an always-fullscreen overlay
summonable from anywhere. Workspace `T` reproduces that and improves on it: one tiled
window on a workspace fills the screen identically, and `cmd+ctrl+t` switches with no
animation at all.

Floating it — the obvious translation of the overlay idea — is actively worse, because
AeroSpace has no sticky windows yet ([issue #2](https://github.com/nikitabobko/AeroSpace/issues/2)).
A floating window still belongs to one workspace, so `ctrl+enter` from a different
workspace would reveal an app whose window AeroSpace is holding off-screen.

#### Monitor arrangement — unlike some tilers, side-by-side is fine

AeroSpace parks inactive workspaces in a **bottom corner** of each monitor, so its only
requirement is that
[every monitor has free space in its bottom-right or bottom-left corner](https://nikitabobko.github.io/AeroSpace/guide#proper-monitor-arrangement).
Two displays side by side satisfy that — the left one hides bottom-left, the right one
bottom-right. No rearranging needed.

This is worth stating because it is *not* a general property of macOS tilers. Ones that
park windows off the left and right edges (paneru, for instance) are broken by a
horizontal neighbour and need the displays stacked vertically instead.

`Displays have separate Spaces` stays **enabled** here, against upstream's mild
recommendation. Disabling it is more stable, but it makes the second monitor a black
screen whenever anything is in native fullscreen — and native fullscreen still gets used
for video and screen sharing.

#### Validating the config without running it

`aerospace reload-config --dry-run` needs a live server, which means launching the window
manager to find out whether the file parses. The CLI parses arguments locally before
contacting the server, though, so every command string can be checked offline: run it
and treat `Can't connect to AeroSpace server` as success and anything else as a parse
error. Combined with a plain `tomllib.load`, that catches bad command names, bad flags,
bad key notations and TOML mistakes before AeroSpace ever starts.

That's also why the `on-window-detected` rules are written as single-line inline tables
rather than upstream's multi-line form — multi-line inline tables are a TOML 1.1 feature,
and staying within 1.0 syntax keeps the file loadable by a stock parser.

### Atuin

`config/atuin/config.toml` holds overrides only; run `atuin default-config` to see the
full annotated template. It exists mainly so `atuin setup` never runs: that wizard is
what asks about Atuin AI and the daemon, and the upstream installer re-ran it on every
single `install.sh`. With the answers committed, `install.sh` passes `--non-interactive`
and the wizard has nothing left to decide.

Sync login is the exception — it's account state, not config — so `install.sh` prompts
for it, but only while genuinely logged out (`atuin status` exits non-zero) and only when
`/dev/tty` can actually be opened. The read is bounded at 30s, so a backgrounded or
piped run can't hang on it.

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

A spec line can also end with `# local-only` — skipped whenever `install.sh` runs
inside an ssh session (`$SSH_CONNECTION` set), for a plugin that only makes sense on
the machine you physically sit at. `nikok6/herdr-mirror` is the one entry using it: it
mirrors a *remote* herdr into this one's sidebar over ssh, which inverts the moment
`install.sh` itself is run over ssh — installed on a box you've ssh'd into, it would
mirror some other machine's herdr back into the session you're already viewing
remotely.

One plugin on the list is installed but not yet running: `AltanS/collie` starts
stopped on purpose (see `config/herdr/plugins/config/herdr.collie/env.example`) —
bring the bridge up yourself with `herdr plugin action invoke start --plugin
herdr.collie` once `COLLIE_TRUSTED_USER`/`COLLIE_PUBLIC_HOSTS` are filled in. It needs
the `tailscale` CLI on `$PATH` to publish itself, which `bin/tailscale` now provides
(see the config table above) — the App Store build hides that CLI inside its own app
bundle otherwise.

`ribbons-digital/pi-herd` used to be listed here too; it's gone. It hardcoded `--name`
and `--session-id` into every harness launch, and omp — the agent this setup drives —
hard-errors on `unknown flags: --name, --session-id`; it also shipped a Pi-only
extension. It couldn't drive omp without patching, so it was dropped from
`herdr_plugins.txt` rather than carried as permanently broken.

With twelve plugins and forty-two registered actions between them, keybindings stopped
being a per-plugin question and became one decision: `command-palette`'s `open` action,
bound to `prefix+p` — free because this config moved herdr's own `previous_tab` off it
and onto `prefix+shift+tab` — builds its fzf list at run time from `herdr plugin action
list`, so every action of every installed plugin is one fuzzy search away whether or not
it has a key. Only the ones reached for constantly earn a `[[keys.command]]` entry;
ghzinga's click-driven `open`, workspace-manager's `apply`/`validate`/`remove-gone`, and
worktree-setup's total absence of actions all stay reachable through the palette instead
of crowding the keymap.

Herdr's packed sidebar renders only the tokens named in a `[ui.sidebar.agents]`/
`[ui.sidebar.spaces]` row — a plugin can write a custom token correctly and still be
invisible if nothing names it. Two plugins depend on this: `herdr-agent-inbox`
contributes `$title`, `$flag`, `$age`, `$since`, and the workspace-level `$agents`/
`$busy`; `gh-pr` contributes `$pr`, the branch's PR state as `#123 ✓`. Both rows are
named in `config/herdr/config.toml` — miss one and its plugin looks broken when it's
actually just unrendered.

Three plugins now cooperate on a worktree's life, in a fixed order. `worktree.created`
fires; `worktree-setup` runs first and makes the checkout usable — copies `.env*` from
the main checkout, `mise trust`, `direnv allow`, installs deps — then `workspace-manager`
applies its YAML layout for that repo/branch, arranging tabs and panes and starting the
agent pane itself via `herdr agent start`, which blocks until herdr detects it's ready.
Later, once a branch's PR merges and its upstream is gone, `workspace-manager`'s
`remove-gone` action previews and clears the worktree. `reviewr` used to also open on
`worktree.created`; two plugins independently arranging the same fresh workspace race
each other with no clear winner, so `reviewr`'s `auto_open` is now off and
`workspace-manager` owns that moment alone — its `issue` layout carries a review tab
where `reviewr`'s auto-open used to land. `prefix+alt+r` still opens it by hand.

### Local Herdr plugins

`config/herdr/plugins/local/<id>/` holds plugins developed in this repo itself rather
than fetched from GitHub — currently just `omp.subagents` (see [Subagent
panes](#subagent-panes) below). `install.sh` links each one with `herdr plugin link
<path>` instead of `herdr plugin install`: `install` only knows how to resolve a GitHub
spec, and even a hypothetical local variant of it would have to copy the plugin out of
the repo to install it into herdr's content-hashed plugin store, the same as every
GitHub plugin under `~/.config/herdr/plugins/github/`. `link` instead points herdr
straight at this working copy, so an edit here takes effect on herdr's next read with no
reinstall step. Re-linking an already-linked plugin was checked and is a no-op success
(`plugin_linked`, exit 0, both times) rather than an error, so — same as the GitHub loop
above — `install.sh` just links every local plugin directory on every run instead of
detecting "already linked" itself.

They're not listed in `herdr_plugins.txt`: that file's `<owner>/<repo>[@ref]` line format
has no way to spell a local path, and there's no ref to pin against a repo that isn't on
GitHub. The `local/` directory itself is the manifest — any subdirectory with an
`herdr-plugin.toml` gets linked.

### Subagent panes

`omp/agent/extensions/herdr-subagent-panes.ts` and the `omp.subagents` Herdr plugin
(`config/herdr/plugins/local/omp-subagents/`) together open a read-only pane the moment
any omp subagent spawns, laying panes out as a stacked column next to the parent omp
pane and tailing each one's live session transcript as it works. It only observes —
nothing about how or when a subagent gets dispatched changes.

Two halves, one process each:

- **The omp extension** listens for `task:subagent:lifecycle` on omp's own event bus.
  On `status: "started"` it writes a small status file under
  `${XDG_STATE_HOME:-$HOME/.local/state}/omp-subagent-panes/<agentId>.json` — the
  subagent's id, type, description, and its session JSONL path — then asks herdr to open
  a pane (`herdr plugin pane open`) and renames it (`herdr pane rename`) to the
  subagent's own name. The first pane opened splits the parent omp pane in
  `OMP_SUBAGENT_PANES_COLUMN`'s direction, creating the column; every pane after that
  splits the most recently opened subagent pane in `OMP_SUBAGENT_PANES_DIRECTION`'s
  direction, stacking inside that column instead of narrowing the omp pane further. On a
  terminal status it rewrites the same file with the outcome, relabels the pane with a
  check or cross, and closes the pane — unless the operator is focused on it, in which
  case it waits and closes once focus moves elsewhere. `OMP_SUBAGENT_PANES_AUTOCLOSE=0`
  keeps every settled pane instead.
- **The Herdr plugin** owns the pane: `src/viewer.ts` mounts omp's own
  `AgentTranscriptViewer` component (imported straight out of the installed
  `@oh-my-pi/pi-coding-agent` package — the same renderer omp's own Agent Hub
  uses for a parked subagent/advisor transcript) inside a real `pi-tui` `TUI`,
  so the pane looks exactly like omp because it *is* omp's renderer. It's
  read-only by construction (the component's message-editor/revive path is
  gated behind deps this file never wires) and pinned to the exact installed
  `omp` version by the plugin's own `[[build]]` step; a version mismatch —
  or any other failure — degrades to a bundled ANSI-art fallback renderer
  rather than losing the pane. See
  `config/herdr/plugins/local/omp-subagents/README.md` for the full split.

Config, all read by the extension, all optional:

| Variable | Default | Meaning |
|---|---|---|
| `OMP_SUBAGENT_PANES` | `1` | set `0` to disable |
| `OMP_SUBAGENT_PANES_MAX` | `4` | cap on concurrently open panes |
| `OMP_SUBAGENT_PANES_PLACEMENT` | `split` | `overlay`, `split`, `tab`, or `zoomed` |
| `OMP_SUBAGENT_PANES_COLUMN` | `right` | `right` or `down` — direction of the one split off the parent omp pane that creates the column |
| `OMP_SUBAGENT_PANES_DIRECTION` | `down` | `right` or `down` — direction panes stack *within* that column |
| `OMP_SUBAGENT_PANES_AUTOCLOSE` | `1` | closes the pane when the agent settles, but never while it's focused — that one waits for focus to move. `0` keeps settled panes until closed by hand |

Inert outside Herdr: the extension checks `HERDR_ENV` before doing anything, so running
omp directly in a plain terminal (or inside some other multiplexer) never tries to shell
out to a `herdr` binary that isn't managing the session.

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

Several plugin READMEs (reviewr, vim-herdr-navigation, mirror, token-dashboard) still
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

`main` is protected — push a branch and open a PR rather than pushing directly.
