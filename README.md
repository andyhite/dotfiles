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
| `config/zellij/config.kdl` | `~/.config/zellij/config.kdl` | terminal multiplexer, `onedark` theme |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager), `one-dark` theme + accent/border overrides |
| `config/ghostty/config` | `~/.config/ghostty/config` | Ghostty terminal: `One Dark Two` theme, shell integration — same path on macOS and Linux |
| `config/nvim` | `~/.config/nvim` | [NvChad](https://nvchad.com) starter — vendored once, `.git` stripped, fully mine to edit from here |
| `zshrc.local.example` | (copy, not linked) | template for machine-local secrets — never committed |
| `install.sh` | — | installs/updates every tool below, then symlinks all the config above into place |

## Bootstrap a new machine

```sh
git clone https://github.com/andyhite/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` does two things, and is safe to re-run any time (installs what's missing,
updates what's already there):

1. **Installs/updates the tools this config drives**: starship, zellij, zoxide, atuin,
   fzf, eza, bat, tmux, antidote, TPM, the JetBrains Mono Nerd Font, neovim,
   ripgrep, tree-sitter-cli, and NvChad. macOS goes through Homebrew (formulae + casks,
   including Ghostty itself); Linux goes through `apt` where a package exists, and falls
   back to each tool's official installer otherwise:
   - starship/atuin ship curl-able install scripts.
   - zellij has no apt package, so it's built from source via `cargo` — bootstrapping
     `rustup` first if needed, and only rebuilding when crates.io actually has a newer
     version than what's installed.
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

   Ghostty itself is only installed on macOS — it's a local GUI app, so there's nothing
   to install on a headless remote box, though its config still gets symlinked in case
   that box ever runs Ghostty directly.
2. **Symlinks every config file** in the table above into place. Backs up
   (`.bak.<timestamp>`) anything real that's already sitting where a symlink needs to
   go.
3. **Headlessly syncs NvChad's plugins** (`nvim --headless "+Lazy! sync" +qa`) once
   neovim and the config are both in place.

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

`master` is protected — push a branch and open a PR rather than pushing directly.
