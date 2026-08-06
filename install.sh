#!/usr/bin/env bash
# Symlinks this repo's config files into place. Safe to re-run.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ghostty's config path differs by OS.
case "$(uname -s)" in
  Darwin) ghostty_target="$HOME/Library/Application Support/com.mitchellh.ghostty/config" ;;
  *)      ghostty_target="$HOME/.config/ghostty/config" ;;
esac

# "source:target" pairs, source relative to this repo.
links=(
  "zshrc:$HOME/.zshrc"
  "zsh_plugins.txt:$HOME/.zsh_plugins.txt"
  "config/starship.toml:$HOME/.config/starship.toml"
  "config/zellij/config.kdl:$HOME/.config/zellij/config.kdl"
  "config/herdr/config.toml:$HOME/.config/herdr/config.toml"
  "config/ghostty/config:$ghostty_target"
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

echo "done. Zsh plugins install on next shell start (antidote) if this is a fresh machine."
