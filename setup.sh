#!/usr/bin/env bash

# Install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Install applications
brew bundle

# Install yadr
sh -c "`curl -fsSL https://raw.githubusercontent.com/skwp/dotfiles/master/install.sh`"

# Add custom prompt
cp prompt_andyhite_setup ~/.zsh.prompts/prompt_andyhite_setup
mkdir -p ~/.zshrc.after
echo "prompt andyhite" >> ~/.zshrc.after/prompt.zsh
source ~/.zshrc

# Add custom vim config
cp vimrc.before ~/.vimrc.before
cp vimrc.after ~/.vimrc.after
