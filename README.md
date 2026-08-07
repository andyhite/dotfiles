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
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager), `one-dark` theme + accent/border overrides |
| `herdr_plugins.txt` | (not linked — read by `install.sh`) | Herdr plugin list, one `owner/repo[@ref]` per line; `install.sh` installs/updates each one |
| `config/herdr/plugins/config` | `~/.config/herdr/plugins/config` | per-plugin Herdr config, one directory per plugin id — the whole tree is linked, so new plugins land here on install |
| `config/ghostty/config` | `~/.config/ghostty/config` | Ghostty terminal: `One Dark Two` theme, shell integration — same path on macOS and Linux |
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
| `omp/agent/rules/output-style.md` | `~/.omp/agent/rules/output-style.md` | `alwaysApply: true` rule that shapes every omp response for an ADHD reader — answer first, numbered steps, one next action, no preamble or recap |
| `Brewfile` | (not linked — read by `install.sh`) | macOS formulae + casks for every tool this config drives, applied with `brew bundle` — replaced the old hand-maintained `brew_ensure`/`brew_ensure_cask` loop |
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
6. **Installs/updates every Herdr plugin** listed in `herdr_plugins.txt`. Skipped with a
   note if `herdr` isn't on `PATH` — this repo configures Herdr but doesn't install it.
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
