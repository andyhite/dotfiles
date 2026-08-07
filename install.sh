#!/usr/bin/env bash
# Installs/updates the tools this config depends on, then symlinks every
# config file into place. Safe to re-run — installs what's missing, updates
# what's already there.
#
# Every step is opt-in when a terminal is attached; run with --yes for the old
# unattended behaviour. `--help` lists the steps and flags.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# ── Output ───────────────────────────────────────────────────────────────────

# Colour only when stdout is a terminal that wants it. NO_COLOR is the de-facto
# opt-out (no-color.org) and TERM=dumb covers CI and inferior shells.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

# Glyphs fall back to ASCII outside a UTF-8 locale — a freshly imaged box may
# not have one yet, and mojibake in a bootstrap script reads as breakage. Both
# sets are one column wide so the label column stays aligned either way.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8*|*utf-8*|*UTF8*|*utf8*)
    G_OK="✓"; G_ADD="+"; G_UPD="↑"; G_SKIP="·"; G_WARN="!"; G_ERR="✗"; G_NOTE="›"; G_ASK="?"
    G_RULE="─" ;;
  *)
    G_OK="*"; G_ADD="+"; G_UPD="^"; G_SKIP="-"; G_WARN="!"; G_ERR="x"; G_NOTE=">"; G_ASK="?"
    G_RULE="-" ;;
esac

RULE_WIDTH="${COLUMNS:-72}"
[ "$RULE_WIDTH" -gt 72 ] && RULE_WIDTH=72

declare -i N_OK=0 N_ADD=0 N_UPD=0 N_SKIP=0 N_WARN=0 N_ERR=0

# One writer for every status line, so the glyph, colour and label column can
# never drift between call sites.
_line() {
  local color=$1 glyph=$2 label=$3; shift 3
  # Only pad the label when a detail follows it, so a bare label doesn't emit a
  # run of trailing spaces (visible when selecting output, and noise in a log).
  if [ -n "$*" ]; then
    printf '  %s%s%s %s%-26s%s %s%s%s\n' \
      "$color" "$glyph" "$C_RESET" \
      "$C_BOLD" "$label" "$C_RESET" \
      "$C_DIM" "$*" "$C_RESET"
  else
    printf '  %s%s%s %s%s%s\n' \
      "$color" "$glyph" "$C_RESET" "$C_BOLD" "$label" "$C_RESET"
  fi
}

ok()      { N_OK+=1;   _line "$C_GREEN"  "$G_OK"   "$@"; }
added()   { N_ADD+=1;  _line "$C_GREEN"  "$G_ADD"  "$@"; }
updated() { N_UPD+=1;  _line "$C_BLUE"   "$G_UPD"  "$@"; }
skipped() { N_SKIP+=1; _line "$C_DIM"    "$G_SKIP" "$@"; }
warned()  { N_WARN+=1; _line "$C_YELLOW" "$G_WARN" "$@"; }
failed()  { N_ERR+=1;  _line "$C_RED"    "$G_ERR"  "$@"; }
note()    { _line "$C_CYAN" "$G_NOTE" "$@"; }

# Free-form indented text, for guidance that doesn't fit the label/detail shape.
say() { printf '     %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

heading() {
  local title=$1 blurb=${2:-} rule
  rule="$(printf "${G_RULE}%.0s" $(seq 1 "$RULE_WIDTH"))"
  printf '\n%s%s%s\n' "$C_DIM" "$rule" "$C_RESET"
  printf '%s%s%s\n' "$C_BOLD$C_CYAN" "$title" "$C_RESET"
  [ -n "$blurb" ] && printf '%s%s%s\n' "$C_DIM" "$blurb" "$C_RESET"
  printf '\n'
}

# Runs a command with its output suppressed, then replays the tail only if it
# failed. Long installers otherwise bury the structured output above in build
# noise; --verbose puts it all back.
run_quiet() {
  local label=$1; shift
  if [ "$VERBOSE" = 1 ]; then "$@"; return $?; fi

  local log rc=0
  log="$(mktemp)"
  "$@" >"$log" 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    failed "$label" "exit $rc"
    sed 's/^/       /' "$log" | tail -12
  fi
  rm -f "$log"
  return "$rc"
}

# ── Prompting ────────────────────────────────────────────────────────────────

# True when a human can actually answer. Opening /dev/tty is the real test: the
# device node passes `[ -r ]` even with no controlling terminal, so CI would
# print a prompt nobody sees and then fail the read.
has_tty() {
  { exec 3</dev/tty; } 2>/dev/null || return 1
  exec 3<&-
  return 0
}

# Asks a yes/no question. Unattended runs and --yes proceed without asking, so
# the default answer is always the one that does the work. The read is bounded:
# a tty can exist with nobody watching (backgrounded job, `</dev/null`), and
# `read -t` exiting >128 must not abort the script under `set -e`.
confirm() {
  local question=$1 reply=""
  [ "$ASSUME_YES" = 1 ] && return 0
  has_tty || return 0

  printf '  %s%s%s %s %s[Y/n]%s ' \
    "$C_YELLOW" "$G_ASK" "$C_RESET" "$question" "$C_DIM" "$C_RESET"
  read -t 60 -r reply </dev/tty || reply=""
  printf '\n'

  case "${reply:-y}" in
    y*|Y*) return 0 ;;
    *)     return 1 ;;
  esac
}

# ── Steps ────────────────────────────────────────────────────────────────────

STEPS=(tools completions configs atuin herdr skills nvim)
ASSUME_YES=0
VERBOSE=0
ONLY=""
SKIP=""

usage() {
  cat <<EOF
${C_BOLD}install.sh${C_RESET} — install/update tools, then symlink this repo's config into place.

${C_BOLD}Usage${C_RESET}
  ./install.sh [options]

${C_BOLD}Options${C_RESET}
  -y, --yes            Run every step without prompting (implied with no tty)
  -v, --verbose        Show each installer's own output instead of only failures
      --only a,b       Run only these steps
      --skip a,b       Run everything except these steps
  -h, --help           Show this

${C_BOLD}Steps${C_RESET}
  tools        Package-manager installs/upgrades, fonts, neovim, omp
  completions  Generate zsh completions into ~/.local/share/zsh/site-functions
  configs      Symlink this repo's config files into place
  atuin        Offer to log in to Atuin sync when not already logged in
  herdr        Install/update the Herdr plugins in herdr_plugins.txt
  skills       Link omp skills shipped by installed Herdr plugins
  nvim         Headless NvChad plugin sync

${C_BOLD}Examples${C_RESET}
  ./install.sh --yes                 unattended, everything
  ./install.sh --only configs        just re-link the dotfiles
  ./install.sh --skip tools,nvim     skip the slow parts
EOF
}

die() { printf '%s%s%s %s\n' "$C_RED" "$G_ERR" "$C_RESET" "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)     ASSUME_YES=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    --only)       ONLY="${2:-}"; shift ;;
    --only=*)     ONLY="${1#*=}" ;;
    --skip)       SKIP="${2:-}"; shift ;;
    --skip=*)     SKIP="${1#*=}" ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "unknown option '$1' — try --help" ;;
  esac
  shift
done

# Fail on a misspelled step name rather than silently running everything.
for _given in ${ONLY//,/ } ${SKIP//,/ }; do
  case " ${STEPS[*]} " in
    *" $_given "*) ;;
    *) die "unknown step '$_given' — valid steps: ${STEPS[*]}" ;;
  esac
done

step_wanted() {
  [ -z "$ONLY" ] || case ",$ONLY," in *",$1,"*) ;; *) return 1 ;; esac
  case ",$SKIP," in *",$1,"*) return 1 ;; esac
  return 0
}

# Prints the heading, asks, and runs. Declined and filtered steps leave a single
# line behind so the transcript still shows what was passed over.
run_step() {
  local key=$1 title=$2 blurb=$3 fn=$4
  step_wanted "$key" || return 0
  heading "$title" "$blurb"
  confirm "Run this step?" || { skipped "$key" "declined"; return 0; }
  "$fn"
}

# Everything installed without a package manager lands here, and zshrc puts it
# on PATH. Create it up front so no installer has to guess.
mkdir -p "$HOME/.local/bin"

# ── git-based tools (identical on every OS) ─────────────────────────────────

ensure_antidote() {
  if [ -d "$HOME/.antidote" ]; then
    run_quiet antidote git -C "$HOME/.antidote" pull --ff-only --quiet || return 0
    updated "antidote" "pulled"
  else
    run_quiet antidote git clone --depth=1 --quiet https://github.com/mattmc3/antidote.git "$HOME/.antidote" || return 0
    added "antidote" "cloned"
  fi
}

ensure_tpm() {
  if [ -d "$HOME/.tmux/plugins/tpm" ]; then
    run_quiet tpm git -C "$HOME/.tmux/plugins/tpm" pull --ff-only --quiet || return 0
    updated "tpm" "pulled"
  else
    run_quiet tpm git clone --depth=1 --quiet https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" || return 0
    added "tpm" "cloned"
  fi
}

ensure_nvchad() {
  if [ -f "$DOTFILES_DIR/config/nvim/init.lua" ]; then
    ok "NvChad starter" "already vendored in dotfiles"
    return
  fi
  run_quiet "NvChad starter" git clone --depth=1 --quiet https://github.com/NvChad/starter "$DOTFILES_DIR/config/nvim" || return 0
  rm -rf "$DOTFILES_DIR/config/nvim/.git"
  added "NvChad starter" "vendored — becomes yours to edit from here"
}

# ── Cross-platform via upstream installer ───────────────────────────────────

ensure_omp() {
  # https://omp.sh — coding agent. The upstream installer handles both OSes and
  # drops the binary in ~/.local/bin (override with PI_INSTALL_DIR).
  #
  # Install-only, unlike everything else here: the binary is ~120MB, and omp
  # ships its own `omp update` for upgrades. Re-downloading it on every run of
  # this script would be a slow no-op.
  if command -v omp >/dev/null 2>&1; then
    ok "omp" "$(omp --version 2>/dev/null | head -1) — upgrade with 'omp update'"
    return
  fi
  added "omp" "installing"
  curl -fsSL https://omp.sh/install | sh
}

ensure_atuin_account() {
  if ! command -v atuin >/dev/null 2>&1; then
    skipped "atuin" "not installed"
    return 0
  fi

  # `atuin status` is the cheapest honest probe: it exits non-zero with "You are
  # not logged in to a sync server" until a session exists. Checking for the
  # session file instead would miss an expired/invalidated one.
  if atuin status >/dev/null 2>&1; then
    ok "atuin" "already logged in to sync"
    return 0
  fi

  # Sync is the one part of atuin's setup that can't be committed — it's account
  # state, not config. So prompt for it, but only when a human can actually
  # answer.
  if ! has_tty; then
    skipped "atuin" "not logged in — run 'atuin login' or 'atuin register' later"
    return 0
  fi

  local reply=""
  printf '  %s%s%s Log in to Atuin sync? %s[l]ogin / [r]egister / [s]kip%s ' \
    "$C_YELLOW" "$G_ASK" "$C_RESET" "$C_DIM" "$C_RESET"
  # `read -t` exits >128 on timeout; `|| reply=s` turns that into a skip rather
  # than aborting the script under `set -e`.
  read -t 30 -r reply </dev/tty || reply="s"
  printf '\n'

  # Every branch swallows failure: a mistyped password must not abort a script
  # running under `set -e` with steps still ahead of it. Written as if/else
  # rather than `cmd && ok || warned`, which would also report failure whenever
  # the success reporter itself returned non-zero.
  case "${reply:-s}" in
    l*|L*)
      if atuin login </dev/tty; then
        ok "atuin" "logged in"
      else
        warned "atuin" "login incomplete — retry with 'atuin login'"
      fi ;;
    r*|R*)
      if atuin register </dev/tty; then
        ok "atuin" "registered"
      else
        warned "atuin" "registration incomplete — retry with 'atuin register'"
      fi ;;
    *) skipped "atuin" "run 'atuin login' or 'atuin register' later" ;;
  esac
}

# ── Shell completions ───────────────────────────────────────────────────────

# zsh autoloads completions from files named `_<cmd>` anywhere on fpath.
# Homebrew drops a lot of them into $(brew --prefix)/share/zsh/site-functions,
# which `brew shellenv` already puts on fpath — but that covers exactly nothing
# on a Linux box, and tools installed outside any package manager (omp, herdr,
# tree-sitter) are uncovered on both. So generate them from the binaries
# themselves into one directory that zshrc prepends to fpath.
#
# Only tools with a real generator are listed. Deliberately absent:
#   eza, zoxide, direnv  — no generator; brew ships _eza/_zoxide, direnv has none
#   fzf                  — zshrc already evals `fzf --zsh`, which includes it
#   tmux, jq, vim        — zsh ships _tmux/_jq/_vim itself
#   nvim                 — upstream provides no zsh completion
ensure_completions() {
  local dir="$HOME/.local/share/zsh/site-functions"
  mkdir -p "$dir"

  # bin|outfile|generator argv...
  local specs=(
    "starship|_starship|starship completions zsh"
    "atuin|_atuin|atuin gen-completions --shell zsh"
    "bat|_bat|bat --completion zsh"
    "rg|_rg|rg --generate complete-zsh"
    "omp|_omp|omp completions zsh"
    "herdr|_herdr|herdr completion zsh"
    "tree-sitter|_tree-sitter|tree-sitter complete --shell zsh"
  )

  local wrote=0 spec bin out gen tmp
  for spec in "${specs[@]}"; do
    bin="${spec%%|*}"
    out="${spec#*|}"; out="${out%%|*}"
    gen="${spec##*|}"

    if ! command -v "$bin" >/dev/null 2>&1; then
      skipped "$bin" "not installed"
      continue
    fi

    # Generate to a temp file first: a tool that errors or emits nothing must not
    # replace a working completion with an empty one.
    tmp="$(mktemp)"
    if $gen >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      if ! cmp -s "$tmp" "$dir/$out"; then
        mv "$tmp" "$dir/$out"
        updated "$bin" "wrote $out"
        wrote=1
      else
        rm -f "$tmp"
        ok "$bin" "$out current"
      fi
    else
      rm -f "$tmp"
      warned "$bin" "generator failed — leaving any existing file alone"
    fi
  done

  # zshrc runs `compinit -C`, which trusts a cached dump and would never notice
  # the files above. Dropping the dumps forces the next shell to rebuild once.
  if [ "$wrote" = 1 ]; then
    rm -f "$HOME"/.zcompdump*
    say "cleared ~/.zcompdump* — the next shell rebuilds it once"
  fi
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
    warned "tree-sitter-cli" "unsupported platform $(uname -s)/$(uname -m) — install manually"
    return
  fi

  current=""
  command -v tree-sitter >/dev/null 2>&1 && current="$(tree-sitter --version | awk '{print $2}')"
  latest="$(curl -fsSL -H "User-Agent: dotfiles-install-script (github.com/andyhite/dotfiles)" \
    https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest \
    | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')"

  if [ -n "$current" ] && [ "$current" = "$latest" ]; then
    ok "tree-sitter-cli" "up to date ($current)"
    return
  fi
  # Prebuilt binary, not `cargo install tree-sitter-cli` — that pulls in
  # rquickjs-sys, which needs bindgen/clang to resolve its resource-dir
  # correctly and fails on stock Ubuntu with a missing stdbool.h. NvChad only
  # needs the binary on PATH; this sidesteps the build entirely.
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/tree-sitter.gz" \
    "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-$os_part.gz"
  gunzip -f "$tmp/tree-sitter.gz"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp/tree-sitter" "$HOME/.local/bin/tree-sitter"
  rm -rf "$tmp"
  if [ -n "$current" ]; then
    updated "tree-sitter-cli" "$current -> $latest"
  else
    added "tree-sitter-cli" "$latest"
  fi
}

# ── macOS: Homebrew ──────────────────────────────────────────────────────────

brew_ensure() {
  if brew list --formula "$1" &>/dev/null; then
    local out
    out="$(brew upgrade "$1" 2>&1 | tail -1)"
    case "$out" in
      *"already installed"*|*"up-to-date"*|*"up to date"*) ok "$1" "up to date" ;;
      *) updated "$1" "${out:-upgraded}" ;;
    esac
  else
    # `run_quiet` already reported the failure and replayed the log tail, so
    # swallow the status: one broken formula shouldn't abort the run and cost the
    # summary. A non-zero N_ERR still makes the script exit 1 at the end.
    if run_quiet "$1" brew install "$1"; then added "$1" "installed"; fi
  fi
}

brew_ensure_cask() {
  if brew list --cask "$1" &>/dev/null; then
    local out
    out="$(brew upgrade --cask "$1" 2>&1 | tail -1)"
    case "$out" in
      *"already installed"*|*"up-to-date"*|*"up to date"*) ok "$1" "up to date" ;;
      *) updated "$1" "${out:-upgraded}" ;;
    esac
  else
    if run_quiet "$1" brew install --cask "$1"; then added "$1" "installed"; fi
  fi
}

install_tools_macos() {
  command -v brew >/dev/null 2>&1 || { failed "Homebrew" "not found — install from https://brew.sh first"; return 1; }
  # direnv is required by zshrc's hook; the rest are what the configs call out.
  for f in starship zoxide atuin fzf eza bat direnv tmux neovim ripgrep; do brew_ensure "$f"; done
  brew_ensure_cask ghostty
  brew_ensure_cask font-jetbrains-mono-nerd-font
  ensure_antidote
  ensure_tpm
  ensure_tree_sitter_cli
  ensure_nvchad
  ensure_omp
}

# ── Linux: apt + native installers ──────────────────────────────────────────

# Returns 1 (without aborting the caller) when the package doesn't exist in
# this release's archive — eza, for one, only landed in Ubuntu 24.04, and a
# hard failure there would kill the whole run under `set -e`.
apt_ensure() {
  if dpkg -s "$1" &>/dev/null; then
    if run_quiet "$1" sudo apt-get install --only-upgrade -y "$1"; then ok "$1" "up to date"; fi
    return 0
  fi
  if ! apt-cache show "$1" &>/dev/null; then
    skipped "$1" "not in this distro's archive"
    return 1
  fi
  if run_quiet "$1" sudo apt-get install -y "$1"; then added "$1" "installed"; fi
  return 0
}

ensure_rustup() {
  if ! command -v cargo >/dev/null 2>&1; then
    added "rustup" "cargo not found — installing"
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
    ok "$crate" "up to date ($current)"
    return
  fi
  say "$crate: ${current:+updating $current -> }${current:-installing }$latest (compiling — takes a few minutes)"
  run_quiet "$crate" cargo install --locked "$crate" || return 0
  if [ -n "$current" ]; then
    updated "$crate" "$current -> $latest"
  else
    added "$crate" "$latest"
  fi
}

ensure_neovim_linux() {
  local tarball current latest tmp
  case "$(uname -m)" in
    x86_64)  tarball="nvim-linux-x86_64.tar.gz" ;;
    aarch64) tarball="nvim-linux-arm64.tar.gz" ;;
    *) warned "neovim" "unsupported arch $(uname -m) — install manually"; return ;;
  esac

  current=""
  command -v nvim >/dev/null 2>&1 && current="$(nvim --version | head -1 | awk '{print $2}')"
  latest="$(curl -fsSL -H "User-Agent: dotfiles-install-script (github.com/andyhite/dotfiles)" \
    https://api.github.com/repos/neovim/neovim/releases/latest \
    | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4)"

  if [ -n "$current" ] && [ "$current" = "$latest" ]; then
    ok "neovim" "up to date ($current)"
    return
  fi
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/$tarball"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
  # Ubuntu's apt neovim (0.9.5) is below NvChad's 0.11 floor, and there's no
  # PPA guaranteed available everywhere — take the official release tarball
  # and merge its bin/lib/share into ~/.local, which is already on PATH.
  mkdir -p "$HOME/.local"
  cp -rf "$tmp"/nvim-linux-*/* "$HOME/.local/"
  rm -rf "$tmp"
  if [ -n "$current" ]; then
    updated "neovim" "$current -> $latest"
  else
    added "neovim" "$latest"
  fi
}

ensure_nerd_font_linux() {
  # Capture fully before grepping — `fc-list | grep -q` under `set -o
  # pipefail` SIGPIPEs fc-list on the first match, and pipefail then
  # propagates that as a failure even though grep matched, so this branch
  # would never fire despite the font actually being installed.
  local installed
  installed="$(fc-list 2>/dev/null)"
  if printf '%s' "$installed" | grep -qi "JetBrainsMono Nerd Font"; then
    ok "JetBrainsMono Nerd Font" "already installed"
    return
  fi
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/font.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  unzip -oq "$tmp/font.zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  fc-cache -f "$HOME/.local/share/fonts/JetBrainsMonoNerdFont" >/dev/null
  rm -rf "$tmp"
  added "JetBrainsMono Nerd Font" "installed"
}

install_tools_linux() {
  if command -v apt-get >/dev/null 2>&1; then
    run_quiet apt sudo apt-get update -y || true
    # zsh: the shell these dotfiles configure, not guaranteed on a minimal box.
    # fzf: apt's build may predate `fzf --zsh`; zshrc falls back to the
    #      key-binding scripts apt drops in /usr/share, so old is fine.
    # build-essential/pkg-config: needed by the cargo builds below.
    # fontconfig: fc-list/fc-cache for the Nerd Font install.
    # ncurses-bin: infocmp, for ghostty's ssh-terminfo shell integration.
    for p in zsh git curl zoxide eza bat fzf direnv tmux unzip ripgrep \
             fontconfig ncurses-bin build-essential pkg-config; do
      apt_ensure "$p" || true
    done
  else
    warned "apt-get" "not found — skipping distro packages; install manually"
  fi

  # eza predates its Ubuntu packaging (24.04+); build it where apt can't.
  command -v eza >/dev/null 2>&1 || cargo_ensure_latest eza

  # $HOME expanded here rather than left for the inner `sh -c` — one less layer
  # of quoting to reason about, and it fails loudly if it's ever unset.
  if run_quiet starship sh -c "curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir '$HOME/.local/bin'"; then
    ok "starship" "installed/updated (installer always fetches latest)"
  fi

  # --non-interactive is load-bearing, not just politeness: without it the
  # installer ends by running `atuin setup`, the wizard that asks about Atuin AI
  # and the daemon, and it re-asks on every single run. Those answers are
  # checked into config/atuin/config.toml instead, so the wizard has nothing
  # left to decide. The flag also skips the history-import and sync-signup
  # prompts. It re-runs on every invocation because that's how atuin updates.
  if run_quiet atuin sh -c "curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | bash -s -- --non-interactive"; then
    ok "atuin" "installed/updated (installer always fetches latest)"
  fi

  ensure_tree_sitter_cli
  ensure_neovim_linux
  ensure_antidote
  ensure_tpm
  ensure_nerd_font_linux
  ensure_nvchad
  ensure_omp
  # Ghostty itself is a local GUI app — install it on the machine it actually
  # runs on (macOS, via the branch above). Nothing to install here on a
  # headless/remote Linux box; its config still gets symlinked below in case
  # this same host ever runs Ghostty directly.
}

install_tools() {
  case "$OS" in
    Darwin) install_tools_macos ;;
    Linux)  install_tools_linux ;;
    *) warned "$OS" "unrecognized OS — skipping tool install, symlinks only" ;;
  esac
}

# ── Config symlinks ──────────────────────────────────────────────────────────

link_configs() {
  local links=(
    "zshrc:$HOME/.zshrc"
    "zsh_plugins.txt:$HOME/.zsh_plugins.txt"
    "tmux.conf:$HOME/.tmux.conf"
    "config/starship.toml:$HOME/.config/starship.toml"
    "config/herdr/config.toml:$HOME/.config/herdr/config.toml"
    "config/ghostty/config:$HOME/.config/ghostty/config"
    "config/atuin/config.toml:$HOME/.config/atuin/config.toml"
    # Themes live in a subdirectory atuin resolves by name; linked per-file so a
    # theme installed by any other means still shows up alongside this one.
    "config/atuin/themes/one-dark.toml:$HOME/.config/atuin/themes/one-dark.toml"
    "config/nvim:$HOME/.config/nvim"
    # The whole per-plugin config tree, not individual plugins — herdr creates a
    # config dir per plugin at install time, so linking the parent means new
    # plugins land in this repo automatically. herdr's own plugins.json registry
    # stays untracked: it's generated state (absolute paths, resolved commits,
    # install timestamps), and herdr_plugins.txt is the source of truth instead.
    "config/herdr/plugins/config:$HOME/.config/herdr/plugins/config"
    # Only the settings file — ~/.omp/agent also holds databases, sessions and a
    # secrets key, none of which belong in a repo. omp writes through the
    # symlink, so changes made in-app show up as diffs here.
    "omp/agent/config.yml:$HOME/.omp/agent/config.yml"
    # Individual extension files, not the directory: ~/.omp/agent/extensions also
    # receives extensions written by other tools (herdr drops one in), and linking
    # the parent would hide them. `atuin hook install` has no omp target, so this
    # one is maintained here by hand.
    "omp/agent/extensions/atuin.ts:$HOME/.omp/agent/extensions/atuin.ts"
  )

  # An unescaped `~` in the replacement half of ${var/#pat/rep} is tilde-expanded
  # back to $HOME, making the substitution a silent no-op. `\~` keeps it literal.
  local pair src dst backup shown
  for pair in "${links[@]}"; do
    src="$DOTFILES_DIR/${pair%%:*}"
    dst="${pair#*:}"
    shown="${dst/#$HOME/\~}"
    mkdir -p "$(dirname "$dst")"

    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        # No detail: the glyph already says "linked", and these paths are long
        # enough that a redundant word pushes every line out of alignment.
        ok "$shown"
        continue
      fi
      backup="$dst.bak.$(date +%s)"
      mv "$dst" "$backup"
      warned "$shown" "backed up to ${backup##*/}"
    fi

    ln -s "$src" "$dst"
    added "$shown" "-> ${pair%%:*}"
  done

  # Same $HOME -> ~ display transform as the loop above, rather than a literal
  # "~/..." string: that reads as an unexpanded path to both shellcheck and the
  # next person, and drifts if the location ever changes.
  local local_rc="$HOME/.zshrc.local"
  if [ ! -f "$local_rc" ]; then
    cp "$DOTFILES_DIR/zshrc.local.example" "$local_rc"
    added "${local_rc/#$HOME/\~}" "created from example — fill in your secrets"
  else
    ok "${local_rc/#$HOME/\~}" "present"
  fi
}

# ── Herdr plugins ────────────────────────────────────────────────────────────

# Runs after the symlinks so each plugin's config dir is created inside this
# repo rather than in a real directory that would have to be adopted later.
# Re-installing an already-installed plugin is exactly how herdr updates one
# (it re-resolves the ref and replaces the install), so this runs every time
# instead of skipping what's present.
install_herdr_plugins() {
  if [ ! -f "$DOTFILES_DIR/herdr_plugins.txt" ]; then
    skipped "herdr_plugins.txt" "not present"
    return 0
  fi
  if ! command -v herdr >/dev/null 2>&1; then
    skipped "herdr" "not on PATH — install it, then re-run"
    return 0
  fi

  local line plugin_spec plugin_ref
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue

    plugin_spec="${line%%@*}"
    plugin_ref=""
    [ "$line" != "$plugin_spec" ] && plugin_ref="${line#*@}"

    # Flags must follow the positional argument — herdr's plugin parser
    # rejects `herdr plugin install --yes <spec>` with a usage error.
    if [ -n "$plugin_ref" ]; then
      if run_quiet "$plugin_spec" herdr plugin install "$plugin_spec" --ref "$plugin_ref" --yes; then
        updated "$plugin_spec" "@$plugin_ref"
      fi
    else
      if run_quiet "$plugin_spec" herdr plugin install "$plugin_spec" --yes; then
        updated "$plugin_spec" "default branch"
      fi
    fi
  done < "$DOTFILES_DIR/herdr_plugins.txt"
}

# ── omp skills from herdr plugins ───────────────────────────────────────────

# Some herdr plugins ship an omp skill describing how to drive them (the
# browser plugin's herdr-browser skill, for one). Link rather than copy so the
# skill tracks the plugin, and run after the installs above because herdr
# stores each plugin under a content-hashed directory — a link made before an
# update points at a path that no longer exists.
link_omp_skills() {
  local omp_skills="$HOME/.omp/agent/skills"
  local plugin_root skill_src skill_dst backup found=0

  for plugin_root in "$HOME"/.config/herdr/plugins/*/*/; do
    # The manifest is what makes a directory a plugin root; without this check
    # the glob also matches the per-plugin config tree symlinked in above.
    [ -f "$plugin_root/herdr-plugin.toml" ] || continue

    for skill_src in "$plugin_root"skills/*/; do
      [ -f "$skill_src/SKILL.md" ] || continue
      skill_src="${skill_src%/}"
      skill_dst="$omp_skills/$(basename "$skill_src")"
      mkdir -p "$omp_skills"
      found=1

      if [ -L "$skill_dst" ]; then
        if [ "$(readlink "$skill_dst")" = "$skill_src" ]; then
          ok "$(basename "$skill_src")" "linked"
          continue
        fi
        rm "$skill_dst"
      elif [ -e "$skill_dst" ]; then
        backup="$skill_dst.bak.$(date +%s)"
        mv "$skill_dst" "$backup"
        warned "$(basename "$skill_src")" "existing dir backed up to ${backup##*/}"
      fi

      ln -s "$skill_src" "$skill_dst"
      added "$(basename "$skill_src")" "from ${plugin_root#"$HOME"/.config/herdr/plugins/}"
    done
  done

  [ "$found" = 0 ] && skipped "omp skills" "no installed Herdr plugin ships one"
  return 0
}

# ── NvChad ───────────────────────────────────────────────────────────────────

sync_nvchad() {
  if ! command -v nvim >/dev/null 2>&1; then
    skipped "nvim" "not installed"
    return 0
  fi
  # lazy.nvim documents this exact incantation as its headless/CI sync
  # pattern and blocks on it, so it's safe before +qa — verified this
  # actually downloads every configured plugin, not just a partial set.
  #
  # NvChad's quickstart also says to run :MasonInstallAll and :TSInstallAll.
  # Both are real commands — NvChad defines them in the NvChad/ui plugin
  # (lua/nvchad/au.lua), not in mason.nvim or nvim-treesitter, which is why
  # they're absent from those plugins' own docs. Neither can run from here
  # though: NvChad gates plugin loading on UIEnter, and --headless has no
  # UI, so nvim-lspconfig never loads and MasonInstallAll would see an
  # empty server list. They have to be run from a real nvim session.
  run_quiet nvim nvim --headless "+Lazy! sync" +qa || true
  ok "NvChad plugins" "synced"
}

# ── Run ──────────────────────────────────────────────────────────────────────

printf '\n%s%sdotfiles%s %s%s%s\n' \
  "$C_BOLD" "$C_CYAN" "$C_RESET" "$C_DIM" "$DOTFILES_DIR" "$C_RESET"
if [ "$ASSUME_YES" = 1 ]; then
  say "running every step unattended (--yes)"
elif ! has_tty; then
  say "no terminal attached — running every step unattended"
else
  say "each step asks first; Enter accepts. --yes runs everything, --help lists steps"
fi

# The order is load-bearing, which is why --only exists but reordering doesn't:
#
#   completions after tools    each generator must run against the version that
#                              just landed. Tools this script doesn't install
#                              (herdr) are picked up too — see the per-entry
#                              command -v guard.
#   atuin after configs        a login writes session state that should sit
#                              alongside the committed settings in
#                              config/atuin/config.toml, not ahead of them.
#   herdr after configs        each plugin's config dir then gets created inside
#                              this repo rather than in a real directory that
#                              would have to be adopted later.
#   skills after herdr         herdr stores each plugin under a content-hashed
#                              directory, so a link made before an update points
#                              at a path that no longer exists.
#   nvim last                  it needs both neovim and config/nvim in place.
run_step tools       "Tools"        "package manager, fonts, editors, agents"          install_tools
run_step completions "Completions"  "generated into ~/.local/share/zsh/site-functions" ensure_completions
run_step configs     "Configs"      "symlink this repo into place"                     link_configs
run_step atuin       "Atuin sync"   "account state — the only thing not committed"     ensure_atuin_account
run_step herdr       "Herdr plugins" "from herdr_plugins.txt"                          install_herdr_plugins
run_step skills      "omp skills"   "linked from installed Herdr plugins"              link_omp_skills
run_step nvim        "NvChad"       "headless plugin sync"                             sync_nvchad

# ── Summary ──────────────────────────────────────────────────────────────────

heading "Done" ""
printf '  %s%d ok%s   %s%d added%s   %s%d updated%s   %s%d skipped%s   %s%d warnings%s   %s%d errors%s\n\n' \
  "$C_GREEN"  "$N_OK"   "$C_RESET" \
  "$C_GREEN"  "$N_ADD"  "$C_RESET" \
  "$C_BLUE"   "$N_UPD"  "$C_RESET" \
  "$C_DIM"    "$N_SKIP" "$C_RESET" \
  "$C_YELLOW" "$N_WARN" "$C_RESET" \
  "$C_RED"    "$N_ERR"  "$C_RESET"

note "zsh"   "plugins install on next shell start (antidote) on a fresh machine"
note "tmux"  "open it and press prefix+I so TPM installs its plugins"
note "nvim"  "run :MasonInstallAll — it installs every LSP server in config/nvim/lua/configs/lspconfig.lua"
printf '\n'

[ "$N_ERR" -eq 0 ] || exit 1
