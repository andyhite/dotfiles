# dotfiles

Shell and terminal config, synced between my Mac (Ghostty) and remote dev VMs. One Dark
theme everywhere, zsh with antidote instead of oh-my-zsh, starship for the prompt,
NvChad for editing.

## What's in here

| Path | Links to | What it is |
|---|---|---|
| `zshrc` | `~/.zshrc` | zsh config: completion, antidote plugin load, history, aliases, tool init hooks |
| `zsh_plugins.txt` | `~/.zsh_plugins.txt` | antidote's plugin list (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, zsh-vi-mode) |
| `tmux.conf` | `~/.tmux.conf` | tmux config, plugins managed by TPM |
| `config/starship.toml` | `~/.config/starship.toml` | prompt — One Dark Pro preset, hostname shown only over SSH |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager), `one-dark` theme + accent/border overrides |
| `herdr_plugins.txt` | (not linked — read by `install.sh`) | Herdr plugin list, one `owner/repo[@ref]` per line; `install.sh` installs/updates each one |
| `config/herdr/plugins/config` | `~/.config/herdr/plugins/config` | per-plugin Herdr config, one directory per plugin id — the whole tree is linked, so new plugins land here on install |
| `config/ghostty/config` | `~/.config/ghostty/config` | Ghostty terminal: `One Dark Two` theme, shell integration — same path on macOS and Linux |
| `config/atuin/config.toml` | `~/.config/atuin/config.toml` | Atuin (shell history): overrides only — daemon, fuzzy search, full-style UI, vi keymap, tmux popup, `atuin ai`. Also the answers `atuin setup` would otherwise re-ask on every install |
| `config/atuin/themes/one-dark.toml` | `~/.config/atuin/themes/one-dark.toml` | One Dark for Atuin; foreground colors only, background comes from Ghostty |
| `config/nvim` | `~/.config/nvim` | [NvChad](https://nvchad.com) starter — vendored once, `.git` stripped, fully mine to edit from here |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | [omp](https://omp.sh) coding agent settings — only this file; the rest of `~/.omp/agent` is databases, sessions, and a secrets key |
| `omp/agent/extensions/atuin.ts` | `~/.omp/agent/extensions/atuin.ts` | records omp's `bash` commands into Atuin history as `--author omp`, with omp's intent string as `--intent`. Hand-maintained: `atuin hook install` has no omp target |
| `zshrc.local.example` | (copy, not linked) | template for machine-local secrets — never committed |
| `install.sh` | — | installs/updates every tool below, then symlinks all the config above into place |

## Bootstrap a new machine

```sh
git clone https://github.com/andyhite/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` runs seven steps, and is safe to re-run any time (installs what's missing,
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
   ripgrep, tree-sitter-cli, omp, and NvChad. macOS goes through Homebrew (formulae + casks,
   including Ghostty itself); Linux goes through `apt` where a package exists, and falls
   back to each tool's official installer otherwise:
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
   go.
4. **Offers to log in to Atuin sync**, but only when not already logged in and only when
   a terminal is actually attached. Everything else about Atuin lives in
   `config/atuin/config.toml`; sync is account state, so it can't be committed. See
   [Atuin](#atuin) below.
5. **Installs/updates every Herdr plugin** listed in `herdr_plugins.txt`. Skipped with a
   note if `herdr` isn't on `PATH` — this repo configures Herdr but doesn't install it.
6. **Headlessly syncs NvChad's plugins** (`nvim --headless "+Lazy! sync" +qa`) once
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

Deliberately absent, because generating a file would be worse than what already works:
`eza` and `zoxide` have no generator (Homebrew ships `_eza`/`_zoxide`); `direnv` and
`nvim` publish no zsh completion at all; `fzf` comes from the `fzf --zsh` eval in
`zshrc`; and zsh itself ships `_tmux`, `_jq` and `_vim`.

Two details worth knowing. Generation goes through a temp file and only replaces the
target when the output is non-empty, so a tool that starts erroring can't blank a working
completion. And because `zshrc` runs `compinit -C` — which trusts a cached dump rather
than rescanning `fpath` on every shell start — `install.sh` deletes `~/.zcompdump*`
whenever it writes something new, so the next shell rebuilds once.

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
the same history, tagged `--author omp`:

```sh
atuin search --author omp    # just the agent
atuin search --author user   # just me
```

Prefer those literal author names: on Atuin 18.19.0 the `$all-user` pseudo-filter also
returns agent rows, so it does not mean "exclude agents".

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

- Fill in secrets. The installer copies `zshrc.local.example` to `~/.zshrc.local` if it
  doesn't already exist. Edit that file with real values — `zshrc` sources it
  automatically and it's git-ignored, so secrets never end up in this repo or its
  history.
- Restart your shell (or `exec zsh`). Antidote clones its plugins on first run.
- Open tmux and press `prefix+I` to have TPM install its plugins on first run.

## Making changes

Edit the files in this repo directly — they're the real config, not copies, since
everything under `$HOME` is a symlink back here. Commit and push like normal, then run
`install.sh` (or just `git pull`) on the other machine to pick it up.

`main` is protected — push a branch and open a PR rather than pushing directly.
