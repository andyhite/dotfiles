#!/usr/bin/env bash

# Install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Install applications
brew bundle

# Install yadr
sh -c "`curl -fsSL https://raw.githubusercontent.com/skwp/dotfiles/master/install.sh`"

# Add this directory to the home directory
ln -s $PWD "/Users/$(whoami)/.dotfiles"

# Add custom zsh config
ln -s "/Users/$(whoami)/.dotfiles/zsh.prompts" "/Users/$(whoami)/.zsh.prompts"
ln -s "/Users/$(whoami)/.dotfiles/zshrc.before" "/Users/$(whoami)/.zshrc.before"
ln -s "/Users/$(whoami)/.dotfiles/zshrc.after" "/Users/$(whoami)/.zshrc.after"

# Add custom vim config
ln -s "/Users/$(whoami)/.dotfiles/vimrc.before" "/Users/$(whoami)/.vimrc.before"
ln -s "/Users/$(whoami)/.dotfiles/vimrc.after" "/Users/$(whoami)/.vimrc.after"

# Add custom tmux config
ln -s "/Users/$(whoami)/.dotfiles/tmux.conf.user" "/Users/$(whoami)/.tmux.conf.user"
tmux source-file ~/.tmux.conf
