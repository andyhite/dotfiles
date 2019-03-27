#!/usr/bin/env bash

# Install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Install yadr
sh -c "`curl -fsSL https://raw.githubusercontent.com/skwp/dotfiles/master/install.sh`"

# Clone this repo into the home directory
git clone https://github.com/andyhite/dotfiles.git ~/.dotfiles

# Install applications
cd ~/.dotfiles && brew bundle

# Add custom zsh config
ln -s "/Users/$(whoami)/.dotfiles/zsh.prompts" "/Users/$(whoami)/.zsh.prompts"
ln -s "/Users/$(whoami)/.dotfiles/zsh.before" "/Users/$(whoami)/.zsh.before"
ln -s "/Users/$(whoami)/.dotfiles/zsh.after" "/Users/$(whoami)/.zsh.after"

# Add custom vim config
ln -s "/Users/$(whoami)/.dotfiles/vimrc.before" "/Users/$(whoami)/.vimrc.before"
ln -s "/Users/$(whoami)/.dotfiles/vimrc.after" "/Users/$(whoami)/.vimrc.after"

# Add custom tmux config
ln -s "/Users/$(whoami)/.dotfiles/tmux.conf.user" "/Users/$(whoami)/.tmux.conf.user"
tmux source-file ~/.tmux.conf
