# ── Platform ─────────────────────────────────────────────────────────────────
# Cached once; `uname` in a hot startup path is a fork we don't need to repeat.
_os="$(uname -s)"

# ── Homebrew (macOS) ─────────────────────────────────────────────────────────
# Non-login shells (and Ghostty's default) don't always inherit /etc/paths.d,
# so brew-installed tools below would silently vanish. No-op if brew's already
# on PATH or isn't installed.
if [[ "$_os" == "Darwin" ]] && ! command -v brew >/dev/null 2>&1; then
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$_brew" ]; then eval "$("$_brew" shellenv)"; break; fi
  done
  unset _brew
fi

# ── PATH ─────────────────────────────────────────────────────────────────────
# Base entries first so ~/.zshrc.local (sourced below) can still prepend
# machine-specific paths that need to win.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# uv / pipx drop an env script here; it extends PATH and nothing else.
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"

# ── Version manager (asdf) ───────────────────────────────────────────────────
# Supports both the Go rewrite (0.16+, shims only) and the older shell
# implementation (asdf.sh). Absent asdf = clean no-op.
export ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
if [ -d "$ASDF_DATA_DIR" ]; then
  export PATH="$ASDF_DATA_DIR/shims:$PATH"
  [ -d "$ASDF_DATA_DIR/completions" ] && fpath=("$ASDF_DATA_DIR/completions" $fpath)
  [ -f "$HOME/.asdf/asdf.sh" ] && source "$HOME/.asdf/asdf.sh"
  # asdf's golang plugin exports GOROOT/GOPATH/GOBIN for the selected version.
  [ -f "$ASDF_DATA_DIR/plugins/golang/set-env.zsh" ] && source "$ASDF_DATA_DIR/plugins/golang/set-env.zsh"
fi

# ── Completion ──────────────────────────────────────────────────────────────
# fpath additions must land before compinit, and compinit must run before
# antidote loads plugins that hook into it (fzf-tab).
[ -d "$HOME/.docker/completions" ] && fpath=("$HOME/.docker/completions" $fpath)
autoload -Uz compinit
compinit -C

# ── Plugin manager (antidote, replaces Oh My Zsh) ───────────────────────────
# install.sh clones it to ~/.antidote, but a machine that got it from Homebrew
# keeps it under the brew prefix. Take whichever exists; an unguarded source
# here would throw on every single shell start.
_antidote=""
for _c in "$HOME/.antidote/antidote.zsh" \
          "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote/share/antidote/antidote.zsh" \
          /usr/local/opt/antidote/share/antidote/antidote.zsh \
          /usr/share/zsh-antidote/antidote.zsh; do
  [ -f "$_c" ] && { _antidote="$_c"; break; }
done
if [ -n "$_antidote" ]; then
  source "$_antidote"
  antidote load "$HOME/.zsh_plugins.txt"
else
  echo "zshrc: antidote not found — run the dotfiles install.sh to set up plugins"
fi
unset _antidote _c

# ── Machine-local secrets/overrides — never committed ───────────────────────
# See zshrc.local.example for the template. Sourced before the tool blocks
# below so it can set inputs they read (CLAUDE_WORK_PATH, PNPM_HOME, …).
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

# ── History ──────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY       # store timestamps
setopt INC_APPEND_HISTORY     # write as commands run, not just on exit
setopt SHARE_HISTORY          # share across concurrent sessions
setopt HIST_IGNORE_ALL_DUPS   # drop older duplicates, not just adjacent ones
setopt HIST_IGNORE_SPACE      # leading space = don't record
setopt HIST_REDUCE_BLANKS     # normalize whitespace before storing
setopt HIST_VERIFY            # expand history into the buffer, don't run it blind

# ── Shell quality of life ────────────────────────────────────────────────────
setopt AUTO_CD                # typing a directory name cds into it
setopt EXTENDED_GLOB          # ~/^/# glob qualifiers

# ── Prompt / navigation ──────────────────────────────────────────────────────
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v direnv   >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# ── fzf ──────────────────────────────────────────────────────────────────────
# `fzf --zsh` (0.48+) is the portable path. Older distro builds — Debian and
# Ubuntu LTS ship 0.29 — don't have it and install the scripts on disk under
# one of a few paths instead.
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    for _f in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/key-bindings.zsh \
              /usr/share/doc/fzf/examples/completion.zsh   /usr/share/fzf/completion.zsh; do
      [ -f "$_f" ] && source "$_f"
    done
    unset _f
  fi
fi

# ── Modern ls & cat ──────────────────────────────────────────────────────────
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l --icons --group-directories-first'
  alias tree='eza --tree --icons'
fi
# Debian/Ubuntu package bat as `batcat` (name clash with an unrelated package).
if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
elif command -v batcat >/dev/null 2>&1; then
  alias cat='batcat'
fi

# ── Node / pnpm / bun ────────────────────────────────────────────────────────
if [ -z "${PNPM_HOME:-}" ]; then
  case "$_os" in
    Darwin) PNPM_HOME="$HOME/Library/pnpm" ;;
    *)      PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm" ;;
  esac
fi
if [ -d "$PNPM_HOME" ]; then
  export PNPM_HOME
  case ":$PATH:" in *":$PNPM_HOME:"*) ;; *) export PATH="$PNPM_HOME:$PATH" ;; esac
else
  unset PNPM_HOME
fi

[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
if [ -d "$HOME/.bun/bin" ]; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

# ── Go ───────────────────────────────────────────────────────────────────────
# GOPATH default rather than `go env GOPATH` — that's a subprocess on every
# shell start for a value that's ~/go unless something already set it.
if command -v go >/dev/null 2>&1; then
  [ -n "${GOBIN:-}" ] && export PATH="$GOBIN:$PATH"
  export PATH="$PATH:${GOPATH:-$HOME/go}/bin"
fi

# Separate config dirs for work vs personal, switched on cwd. Opt in by setting
# CLAUDE_WORK_PATH (the root of your work checkouts) in ~/.zshrc.local.
set-claude-profile() {
  if [[ "$1" == "work" || "$1" == "personal" ]]; then
    local new_config="$HOME/.claude-$1"
    if [[ "$CLAUDE_CONFIG_DIR" != "$new_config" ]]; then
      export CLAUDE_CONFIG_DIR="$new_config"
      local color="36"                   # cyan for personal
      [[ "$1" == "work" ]] && color="33" # yellow for work
      print -P "🤖 Claude profile: %F{$color}%B$1%b%f"
    fi
  else
    echo "Usage: set-claude-profile [work|personal]"
    return 1
  fi
}

if [ -n "${CLAUDE_WORK_PATH:-}" ]; then
  autoload -U add-zsh-hook
  auto_claude_profile() {
    if [[ "$PWD" == "$CLAUDE_WORK_PATH"* ]]; then
      set-claude-profile work
    else
      set-claude-profile personal
    fi
  }
  add-zsh-hook chpwd auto_claude_profile
  auto_claude_profile
fi

# ── macOS-only fixups ────────────────────────────────────────────────────────
if [[ "$_os" == "Darwin" ]]; then
  # Apple ships GNU make 3.81 (2006). Prefer a modern one when installed.
  command -v gnumake >/dev/null 2>&1 && alias make="gnumake"
  alias disable-chrome-updater='sudo "/Library/Application Support/Google/GoogleUpdater/Current/GoogleUpdater.app/Contents/MacOS/GoogleUpdater" --uninstall --system'
fi

# ── Linux-only fixups ────────────────────────────────────────────────────────
if [[ "$_os" == "Linux" ]]; then
  # systemctl --user needs this set over SSH / non-login shells; harmless
  # no-op when a real login session already set it via pam_systemd.
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
fi

# ── atuin (shell history) — keep last, it needs to own Ctrl+R ──────────────
# The upstream installer (Linux) writes this env script; Homebrew (macOS)
# doesn't, so it must stay optional.
[ -f "$HOME/.atuin/bin/env" ] && source "$HOME/.atuin/bin/env"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"

unset _os
