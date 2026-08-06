# ── Completion ──────────────────────────────────────────────────────────────
# Must run before antidote loads plugins that hook into it (fzf-tab).
autoload -Uz compinit
compinit -C

# ── Plugin manager (antidote, replaces Oh My Zsh) ───────────────────────────
source "$HOME/.antidote/antidote.zsh"
antidote load "$HOME/.zsh_plugins.txt"

# ── Machine-local secrets/overrides — never committed ───────────────────────
# See zshrc.local.example for the template.
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# ── Editor ───────────────────────────────────────────────────────────────────
# nvim locally; vim over SSH in case the remote box doesn't have nvim.
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
  export VISUAL='vim'
else
  export EDITOR='nvim'
  export VISUAL='nvim'
fi

# ── PATH ─────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ── History ──────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY       # store timestamps
setopt INC_APPEND_HISTORY     # write as commands run, not just on exit
setopt SHARE_HISTORY          # share across concurrent sessions
setopt HIST_IGNORE_DUPS       # don't record a line if it's a dup of the previous
setopt HIST_IGNORE_SPACE      # leading space = don't record

# ── Shell quality of life ────────────────────────────────────────────────────
setopt AUTO_CD                # typing a directory name cds into it
setopt EXTENDED_GLOB          # ~/^/# glob qualifiers

# ── Prompt / navigation / fuzzy search / modern ls & cat ────────────────────
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias tree='eza --tree --icons'
alias cat='batcat'

# ── direnv (per-directory env, e.g. per-worktree PORT) ──────────────────────
eval "$(direnv hook zsh)"

# ── Linux-only fixups ────────────────────────────────────────────────────────
if [[ "$(uname -s)" == "Linux" ]]; then
  # systemctl --user needs this set over SSH / non-login shells; harmless
  # no-op when a real login session already set it via pam_systemd.
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
fi

# ── bun ──────────────────────────────────────────────────────────────────────
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── atuin (shell history) — keep last, it needs to own Ctrl+R ──────────────
. "$HOME/.atuin/bin/env"
eval "$(atuin init zsh)"
