# Homebrew formulas and casks for this repo's configs and install.sh's tools
# step. `brew bundle install --file Brewfile` (or the bare `brew bundle` when
# run from this directory) installs/upgrades everything below.
#
# macOS only — the Linux branch of install.sh uses apt plus a handful of
# native installers (rustup, cargo, GitHub releases) instead, because none of
# this has a single cross-distro package name.
#
# `brew bundle` never uninstalls anything absent from this file, so trimming a
# line here doesn't remove the formula from a machine that already has it —
# that's a manual `brew uninstall` if you actually want it gone.
#
# Deliberately excluded: anything work/project-specific (AWS, k8s, terraform,
# postgres clients) and QMK/hardware-flashing tools. Those belong to whichever
# project needs them, not to every fresh machine this repo bootstraps.
#
# antidote is also absent on purpose: install.sh git-clones it to
# ~/.antidote instead of installing it via brew, so Linux and macOS share the
# exact same install path rather than diverging into brew-vs-git.

# ── Config dependencies ──────────────────────────────────────────────────────
# Each of these is loaded or shelled out to by a tracked config, not merely
# nice to have: starship (config/starship.toml + zshrc's prompt init), zoxide
# and direnv (zshrc's shell hooks), atuin (config/atuin/config.toml + zshrc's
# ^R binding), fzf (zshrc's completion/keybinding source and tmux.conf's
# prefix+F switcher), eza and bat (zshrc's ls/cat aliases), tmux (tmux.conf),
# neovim (config/nvim) and ripgrep (nvim's telescope live-grep pickers).
brew "starship"
brew "zoxide"
brew "atuin"
brew "fzf"
brew "eza"
brew "bat"
brew "direnv"
brew "tmux"
brew "neovim"
brew "ripgrep"

# ── Version manager ───────────────────────────────────────────────────────────
# mise reads the tracked ~/.tool-versions (this repo's `tool-versions`) and
# replaced asdf: one binary instead of a plugin per language, PATH activation
# instead of shims, and no per-tool `plugin add` step to keep in sync here.
brew "mise"

# ── Git + GitHub ─────────────────────────────────────────────────────────────
# Not conveniences — the tracked gitconfig names `gh` as its credential
# helper and declares a `filter "lfs"` block, so both gh and git-lfs are hard
# requirements of that config, not optional extras.
brew "git"
brew "gh"
brew "git-lfs"

# ── Shell/JSON tooling this repo's own scripts use ──────────────────────────
brew "jq"
brew "yq"
brew "shellcheck"
brew "shfmt"
brew "coreutils"
brew "moreutils"
brew "wget"
brew "tree"

# ── General dev CLIs ─────────────────────────────────────────────────────────
brew "rust"
brew "cmake"
brew "make"
brew "pipx"
brew "pre-commit"
brew "golangci-lint"
brew "clang-format"
brew "watchexec"
brew "just"
brew "fswatch"
brew "ncdu"
brew "dive"
brew "ctop"
brew "cloc"
brew "rsync"

# ── Casks ─────────────────────────────────────────────────────────────────────
cask "ghostty"
cask "zed"
# config/zed/settings.json sets buffer_font_family to "Monaspace Neon", so
# font-monaspace is a hard requirement of that config, not a nice-to-have.
cask "font-monaspace"
# ghostty and nvim both render Nerd Font glyphs (icons in eza/telescope
# output, powerline separators in the prompt); this is the one font both need.
cask "font-jetbrains-mono-nerd-font"
cask "1password-cli"
# AeroSpace — i3-like tiling window manager, configured by
# config/aerospace/aerospace.toml. macOS-only by nature, which is also why the
# Linux branch of install.sh has no counterpart.
#
# From the author's tap; it isn't in homebrew/core. Newer Homebrew gates
# non-official taps behind a trust check that `brew bundle` can't answer, so
# prepare a fresh machine for an unattended run with:
#
#   brew trust --cask nikitabobko/tap/aerospace
#
# Installing the cask does not launch it: config/aerospace/aerospace.toml sets
# start-at-login = false, and nothing here runs `open -a AeroSpace`. Starting
# it is a deliberate act.
tap "nikitabobko/tap"
cask "aerospace"
