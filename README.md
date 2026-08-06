# dotfiles

Shell and terminal config, synced between my Mac (Ghostty) and remote dev VMs. One Dark
theme everywhere, zsh with antidote instead of oh-my-zsh, starship for the prompt.

## What's in here

| Path | Links to | What it is |
|---|---|---|
| `zshrc` | `~/.zshrc` | zsh config: antidote plugin load, path setup, aliases, tool init hooks |
| `zsh_plugins.txt` | `~/.zsh_plugins.txt` | antidote's plugin list (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, zsh-vi-mode) |
| `config/starship.toml` | `~/.config/starship.toml` | prompt — One Dark Pro preset |
| `config/zellij/config.kdl` | `~/.config/zellij/config.kdl` | terminal multiplexer, `onedark` theme |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager), `one-dark` theme + accent/border overrides |
| `config/ghostty/config` | OS-dependent, see below | Ghostty terminal: `One Dark Two` theme, shell integration |
| `zshrc.local.example` | (copy, not linked) | template for machine-local secrets — never committed |
| `install.sh` | — | symlinks everything above into place |

zsh, starship, zoxide, atuin, fzf, eza, and bat are the actual tools this config drives.
`install.sh` only wires up config files — it doesn't install the tools themselves (see
below).

## Bootstrap a new machine

1. Install the tools this config expects to find on `$PATH`:
   - **macOS**: `brew install ghostty starship zellij zoxide atuin fzf eza bat antidote`
   - **Linux (Debian/Ubuntu)**: `apt` has `zoxide`, `eza`, and `bat` (installs as `batcat`
     — the `zshrc` aliases around this). `starship` and `atuin` ship official install
     scripts (`curl -sS https://starship.rs/install.sh | sh`, `curl ... | sh -s --
     https://setup.atuin.sh`). `zellij` has no apt package here — `cargo install --locked
     zellij`. `antidote`: `git clone --depth=1 https://github.com/mattmc3/antidote.git
     ~/.antidote`.
   - [Herdr](https://herdr.dev): `curl -fsSL https://herdr.dev/install.sh | sh`
   - A [Nerd Font](https://www.nerdfonts.com/) for the icons in starship/eza — this repo
     assumes JetBrains Mono Nerd Font.

2. Clone this repo and run the installer:
   ```sh
   git clone https://github.com/andyhite/dotfiles.git ~/dotfiles
   ~/dotfiles/install.sh
   ```
   It symlinks every file in the table above into place, detects macOS vs Linux for the
   Ghostty config path, and backs up (`.bak.<timestamp>`) anything real that's already
   sitting where a symlink needs to go — safe to re-run.

3. Fill in secrets. The installer copies `zshrc.local.example` to `~/.zshrc.local` if it
   doesn't already exist. Edit that file with real values — `zshrc` sources it
   automatically and it's git-ignored, so secrets never end up in this repo or its
   history.

4. Restart your shell (or `exec zsh`). Antidote clones its plugins on first run.

## Making changes

Edit the files in this repo directly — they're the real config, not copies, since
everything under `$HOME` is a symlink back here. Commit and push like normal, then run
`install.sh` (or just `git pull`) on the other machine to pick it up.

`master` is protected — push a branch and open a PR rather than pushing directly.
