# Zsh plugin manager: antidote (replaces Oh My Zsh)
source "$HOME/.antidote/antidote.zsh"
antidote load "$HOME/.zsh_plugins.txt"

# machine-local secrets/overrides — never committed (see zshrc.local.example)
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi
export EDITOR='vim'
export VISUAL='vim'

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# fab-remote indicator now lives in starship.toml's `format`
# (see the "🏭" line — matches the Ghostty/macOS setup)
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# prompt / navigation / fuzzy search / modern ls & cat
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias tree='eza --tree --icons'
alias cat='batcat'

# direnv (per-directory env, e.g. per-worktree PORT)
eval "$(direnv hook zsh)"

# Task Master aliases added on 7/16/2026
alias tm='task-master'
alias taskmaster='task-master'

# Ensure systemctl --user works over SSH / non-login shells
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# claude config
alias claude="claude --dangerously-skip-permissions"

# bun completions
[ -s "/home/andyhite/.bun/_bun" ] && source "/home/andyhite/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"


# omp/pi: disable inline images under tmux — Kitty graphics protocol placements
# don't track tmux pane scroll/resize/redraw, so they get stuck on screen.
if [ -n "$TMUX" ]; then
  export PI_FORCE_IMAGE_PROTOCOL=none
fi

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"
