#!/usr/bin/env bash
# Installs/updates the tools this config depends on, then symlinks every
# config file into place. Safe to re-run — installs what's missing, updates
# what's already there.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# ── git-based tools (identical on every OS) ─────────────────────────────────

ensure_antidote() {
  if [ -d "$HOME/.antidote" ]; then
    echo "antidote: updating"
    git -C "$HOME/.antidote" pull --ff-only --quiet
  else
    echo "antidote: installing"
    git clone --depth=1 --quiet https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  fi
}

ensure_tpm() {
  if [ -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "tpm: updating"
    git -C "$HOME/.tmux/plugins/tpm" pull --ff-only --quiet
  else
    echo "tpm: installing"
    git clone --depth=1 --quiet https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi
}

ensure_nvchad() {
  if [ -f "$DOTFILES_DIR/config/nvim/init.lua" ]; then
    echo "NvChad starter: already vendored in dotfiles"
    return
  fi
  echo "NvChad starter: cloning into dotfiles (one-time — becomes yours to edit from here)"
  git clone --depth=1 --quiet https://github.com/NvChad/starter "$DOTFILES_DIR/config/nvim"
  rm -rf "$DOTFILES_DIR/config/nvim/.git"
}

# ── Cross-platform via GitHub releases (no package manager needed) ─────────

ensure_tree_sitter_cli() {
  local os_part current latest tmp
  case "$(uname -s)" in
    Darwin) case "$(uname -m)" in
              arm64)  os_part="macos-arm64" ;;
              x86_64) os_part="macos-x64" ;;
            esac ;;
    Linux)  case "$(uname -m)" in
              aarch64) os_part="linux-arm64" ;;
              x86_64)  os_part="linux-x64" ;;
            esac ;;
  esac
  if [ -z "${os_part:-}" ]; then
    echo "tree-sitter-cli: unsupported platform $(uname -s)/$(uname -m) — install manually"
    return
  fi

  current=""
  command -v tree-sitter >/dev/null 2>&1 && current="$(tree-sitter --version | awk '{print $2}')"
  latest="$(curl -fsSL -H "User-Agent: dotfiles-install-script (github.com/andyhite/dotfiles)" \
    https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest \
    | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')"

  if [ -n "$current" ] && [ "$current" = "$latest" ]; then
    echo "tree-sitter-cli: up to date ($current)"
    return
  fi
  # Prebuilt binary, not `cargo install tree-sitter-cli` — that pulls in
  # rquickjs-sys, which needs bindgen/clang to resolve its resource-dir
  # correctly and fails on stock Ubuntu with a missing stdbool.h. NvChad only
  # needs the binary on PATH; this sidesteps the build entirely.
  echo "tree-sitter-cli: ${current:+updating $current -> }${current:-installing }$latest"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/tree-sitter.gz" \
    "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-$os_part.gz"
  gunzip -f "$tmp/tree-sitter.gz"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp/tree-sitter" "$HOME/.local/bin/tree-sitter"
  rm -rf "$tmp"
}

# ── macOS: Homebrew ──────────────────────────────────────────────────────────

brew_ensure() {
  if brew list --formula "$1" &>/dev/null; then
    echo "$1: upgrading"; brew upgrade "$1" 2>&1 | tail -1
  else
    echo "$1: installing"; brew install "$1"
  fi
}

brew_ensure_cask() {
  if brew list --cask "$1" &>/dev/null; then
    echo "$1: upgrading"; brew upgrade --cask "$1" 2>&1 | tail -1
  else
    echo "$1: installing"; brew install --cask "$1"
  fi
}

install_tools_macos() {
  command -v brew >/dev/null 2>&1 || { echo "Homebrew not found — install from https://brew.sh first"; return 1; }
  for f in starship zellij zoxide atuin fzf eza bat tmux neovim ripgrep; do brew_ensure "$f"; done
  brew_ensure_cask ghostty
  brew_ensure_cask font-jetbrains-mono-nerd-font
  ensure_antidote
  ensure_tpm
  ensure_tree_sitter_cli
  ensure_nvchad
}

# ── Linux: apt + native installers ──────────────────────────────────────────

apt_ensure() {
  if dpkg -s "$1" &>/dev/null; then
    echo "$1: upgrading"; sudo apt-get install --only-upgrade -y "$1" >/dev/null
  else
    echo "$1: installing"; sudo apt-get install -y "$1" >/dev/null
  fi
}

ensure_rustup() {
  if ! command -v cargo >/dev/null 2>&1; then
    echo "cargo not found — installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -q
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env"
  fi
}

# Installs/updates a cargo-installed CLI tool by comparing against crates.io's
# latest published version — skips the (multi-minute) rebuild when already
# current. $1 = crate name, $2 = binary name if it differs from the crate name.
cargo_ensure_latest() {
  local crate="$1" bin="${2:-$1}" current latest
  ensure_rustup
  current=""
  command -v "$bin" >/dev/null 2>&1 && current="$("$bin" --version | awk '{print $2}')"
  latest="$(curl -fsSL -H "User-Agent: dotfiles-install-script (github.com/andyhite/dotfiles)" \
    "https://crates.io/api/v1/crates/$crate" | grep -o '"newest_version":"[^"]*"' | head -1 | cut -d'"' -f4)"

  if [ -n "$current" ] && [ "$current" = "$latest" ]; then
    echo "$crate: up to date ($current)"
    return
  fi
  echo "$crate: ${current:+updating $current -> }${current:-installing }$latest (compiling — this takes a few minutes)"
  cargo install --locked "$crate"
}

ensure_neovim_linux() {
  local tarball current latest tmp
  case "$(uname -m)" in
    x86_64)  tarball="nvim-linux-x86_64.tar.gz" ;;
    aarch64) tarball="nvim-linux-arm64.tar.gz" ;;
    *) echo "neovim: unsupported arch $(uname -m) — install manually"; return ;;
  esac

  current=""
  command -v nvim >/dev/null 2>&1 && current="$(nvim --version | head -1 | awk '{print $2}')"
  latest="$(curl -fsSL -H "User-Agent: dotfiles-install-script (github.com/andyhite/dotfiles)" \
    https://api.github.com/repos/neovim/neovim/releases/latest \
    | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4)"

  if [ -n "$current" ] && [ "$current" = "$latest" ]; then
    echo "neovim: up to date ($current)"
    return
  fi
  echo "neovim: ${current:+updating $current -> }${current:-installing }$latest"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/$tarball"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
  # Ubuntu's apt neovim (0.9.5) is below NvChad's 0.11 floor, and there's no
  # PPA guaranteed available everywhere — take the official release tarball
  # and merge its bin/lib/share into ~/.local, which is already on PATH.
  mkdir -p "$HOME/.local"
  cp -rf "$tmp"/nvim-linux-*/* "$HOME/.local/"
  rm -rf "$tmp"
}

ensure_nerd_font_linux() {
  # Capture fully before grepping — `fc-list | grep -q` under `set -o
  # pipefail` SIGPIPEs fc-list on the first match, and pipefail then
  # propagates that as a failure even though grep matched, so this branch
  # would never fire despite the font actually being installed.
  local installed
  installed="$(fc-list 2>/dev/null)"
  if printf '%s' "$installed" | grep -qi "JetBrainsMono Nerd Font"; then
    echo "JetBrainsMono Nerd Font: already installed"
    return
  fi
  echo "JetBrainsMono Nerd Font: installing"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/font.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  unzip -oq "$tmp/font.zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  fc-cache -f "$HOME/.local/share/fonts/JetBrainsMonoNerdFont" >/dev/null
  rm -rf "$tmp"
}

install_tools_linux() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y >/dev/null
    for p in zoxide eza bat tmux unzip ripgrep ncurses-bin; do apt_ensure "$p"; done
  else
    echo "no apt-get found — skipping distro packages (zoxide/eza/bat/tmux/ripgrep/ncurses-bin); install manually"
  fi

  echo "starship: installing/updating (official installer always fetches latest)"
  curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"

  echo "atuin: installing/updating (official installer always fetches latest)"
  curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | bash

  cargo_ensure_latest zellij
  ensure_tree_sitter_cli
  ensure_neovim_linux
  ensure_antidote
  ensure_tpm
  ensure_nerd_font_linux
  ensure_nvchad
  # Ghostty itself is a local GUI app — install it on the machine it actually
  # runs on (macOS, via the branch above). Nothing to install here on a
  # headless/remote Linux box; its config still gets symlinked below in case
  # this same host ever runs Ghostty directly.
}

echo "== tools =="
case "$OS" in
  Darwin) install_tools_macos ;;
  Linux)  install_tools_linux ;;
  *) echo "unrecognized OS '$OS' — skipping tool install, symlinks only" ;;
esac

# ── Config symlinks ──────────────────────────────────────────────────────────

echo "== configs =="

links=(
  "zshrc:$HOME/.zshrc"
  "zsh_plugins.txt:$HOME/.zsh_plugins.txt"
  "tmux.conf:$HOME/.tmux.conf"
  "config/starship.toml:$HOME/.config/starship.toml"
  "config/zellij/config.kdl:$HOME/.config/zellij/config.kdl"
  "config/herdr/config.toml:$HOME/.config/herdr/config.toml"
  "config/ghostty/config:$HOME/.config/ghostty/config"
  "config/nvim:$HOME/.config/nvim"
)

for pair in "${links[@]}"; do
  src="$DOTFILES_DIR/${pair%%:*}"
  dst="${pair#*:}"
  mkdir -p "$(dirname "$dst")"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      echo "ok      $dst"
      continue
    fi
    backup="$dst.bak.$(date +%s)"
    mv "$dst" "$backup"
    echo "backed up existing $dst -> $backup"
  fi

  ln -s "$src" "$dst"
  echo "linked  $dst -> $src"
done

if [ ! -f "$HOME/.zshrc.local" ]; then
  cp "$DOTFILES_DIR/zshrc.local.example" "$HOME/.zshrc.local"
  echo "created $HOME/.zshrc.local from example — fill in your secrets"
fi

if command -v nvim >/dev/null 2>&1; then
  echo "== NvChad plugins (headless bootstrap) =="
  # lazy.nvim documents this exact incantation as its headless/CI sync
  # pattern and blocks on it, so it's safe before +qa — verified this
  # actually downloads every configured plugin, not just a partial set.
  #
  # NvChad's own quickstart docs say to also run :MasonInstallAll and
  # :TSInstallAll after this. Both are stale advice for the current
  # starter: MasonInstallAll doesn't exist in mason.nvim at all, and
  # TSInstallAll silently no-ops (current nvim-treesitter only has
  # `:TSInstall <lang>`, and `:TSInstall all` grabs every language
  # nvim-treesitter supports — hundreds of parsers nobody asked for, not
  # a sane default). Neither Mason nor Treesitter auto-installs on first
  # file-open in this config either. Install what you actually use with
  # `:MasonInstall <server>` / `:TSInstall <lang>`, or declare an
  # `ensure_installed` list in lua/configs/{mason,treesitter}.lua once you
  # know what those are — that's NvChad's own "make it yours" model, not
  # a gap this script should paper over with a guess at your stack.
  nvim --headless "+Lazy! sync" +qa 2>&1 | tail -5 || true
fi

echo "done. Zsh plugins install on next shell start (antidote) if this is a fresh machine."
echo "Open tmux and press prefix+I to have TPM install its plugins on first run."
echo "nvim: plugins are synced. Install the LSP servers/parsers you actually need with"
echo ":MasonInstall <server> and :TSInstall <lang> — see install.sh's comment for why."
