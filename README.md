# dotfiles

Shell and terminal config, synced between my Mac (Ghostty) and remote dev VMs. One Dark
theme everywhere, zsh with antidote instead of oh-my-zsh, starship for the prompt.

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
   fzf, eza, bat, tmux, antidote, TPM, and the JetBrains Mono Nerd Font. macOS goes
   through Homebrew (formulae + casks, including Ghostty itself); Linux goes through
   `apt` where a package exists, and falls back to each tool's official installer
   otherwise (starship/atuin ship curl-able install scripts; zellij has no apt package
   so it's built from source via `cargo`, bootstrapping `rustup` first if needed; the
   Nerd Font is fetched straight from its GitHub release and installed under
   `~/.local/share/fonts`). Ghostty itself is only installed on macOS — it's a local GUI
   app, so there's nothing to install on a headless remote box, though its config still
   gets symlinked in case that box ever runs Ghostty directly.
2. **Symlinks every config file** in the table above into place. Backs up
   (`.bak.<timestamp>`) anything real that's already sitting where a symlink needs to
   go.

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
