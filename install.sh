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

STEPS=(tools completions configs runtimes paseo herdr omp skills nvim)
ASSUME_YES=0
VERBOSE=0
ONLY=""
SKIP=""
REMOTE_HOSTS=()
REMOTE_DIR="~/.dotfiles"

# Every flag except the remote ones is replayed verbatim on the far side, so
# `--host vm --only configs` means the same thing there as it would here.
FORWARD_ARGS=()

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
  -H, --host h[,h]     Install on these ssh hosts instead of here (repeatable)
      --remote-path p  Where the repo lives on a host (default ~/.dotfiles)
  -h, --help           Show this

${C_BOLD}Steps${C_RESET}
  tools        Package installs/upgrades (Brewfile on macOS), fonts, editors, agents
  completions  Generate zsh completions into ~/.local/share/zsh/site-functions
  configs      Symlink this repo's config files into place
  runtimes     Install the language versions pinned in tool-versions, with mise
  paseo        Merge config/paseo into ~/.paseo, ensure the CLI, supervise the daemon
  herdr        Install/update the Herdr plugins in herdr_plugins.txt
  omp          Install/update the omp plugins in omp_plugins.txt
  skills       Install agent skills from agent_skills.txt, link Herdr-shipped ones
  nvim         Headless NvChad plugin sync

${C_BOLD}Remote${C_RESET}
  With --host this machine installs nothing. It ssh's to each host in turn,
  clones or fast-forwards the repo at --remote-path from origin, and runs that
  copy's install.sh with every other flag passed through. The remote pulls from
  origin, not from this working copy — commit and push first. DOTFILES_REPO
  overrides the URL used for a first-time clone.

${C_BOLD}Examples${C_RESET}
  ./install.sh --yes                 unattended, everything
  ./install.sh --only configs        just re-link the dotfiles
  ./install.sh --skip tools,nvim     skip the slow parts
  ./install.sh --host vm             install on 'vm' over ssh, prompting as usual
  ./install.sh --host vm,box --yes   unattended, on two hosts in turn
EOF
}

die() { printf '%s%s%s %s\n' "$C_RED" "$G_ERR" "$C_RESET" "$*" >&2; exit 1; }

# --only/--skip take a required value. An empty or `-`-prefixed one means the
# flag swallowed the next flag's name instead of a step list — without this
# check, the loop's own `shift` below runs with $# already 0, returns
# non-zero, and set -e aborts with no message at all.
require_value() {
  case "${2:-}" in
    ""|-*) die "$1 needs a value — try --help" ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)     ASSUME_YES=1; FORWARD_ARGS+=("$1") ;;
    -v|--verbose) VERBOSE=1;    FORWARD_ARGS+=("$1") ;;
    --only)       require_value "--only" "${2:-}"; ONLY="$2"; FORWARD_ARGS+=("$1" "$2"); shift ;;
    --only=*)     ONLY="${1#*=}"; FORWARD_ARGS+=("$1") ;;
    --skip)       require_value "--skip" "${2:-}"; SKIP="$2"; FORWARD_ARGS+=("$1" "$2"); shift ;;
    --skip=*)     SKIP="${1#*=}"; FORWARD_ARGS+=("$1") ;;
    # Unquoted on purpose: the comma split is the point, and a hostname can't
    # contain whitespace. Repeating the flag accumulates instead of replacing.
    -H|--host)    REMOTE_HOSTS+=(${2//,/ }); shift ;;
    --host=*)     _hosts="${1#*=}"; REMOTE_HOSTS+=(${_hosts//,/ }) ;;
    --remote-path)   REMOTE_DIR="${2:-}"; shift ;;
    --remote-path=*) REMOTE_DIR="${1#*=}" ;;
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
  # A step's own failure is already recorded by failed() and reflected in the
  # exit status check at the bottom of this file — piping it straight through
  # would let one failing step's non-zero status take set -e down with it,
  # skipping every step still queued after it (configs, runtimes, the Done
  # summary) instead of just this one.
  "$fn" || true
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
  # Every curl (or curl|sh) in this file is guarded the same way: set -o
  # pipefail already fails the pipeline on a curl error, and leaving it
  # unguarded would abort the whole run under set -e on a transient network
  # blip instead of warning and letting the rest of the run continue.
  if ! curl -fsSL https://omp.sh/install | sh; then
    warned "omp" "download failed — re-run to retry"
    return 0
  fi
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
    "mise|_mise|mise completion zsh"
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

# Resolves a repo's latest release tag, or prints nothing when it can't.
#
# Two reasons this isn't a bare curl at each call site. The unauthenticated API
# allows 60 requests an hour per IP, and a shared or NAT'd network burns through
# that — the result is a 403, which reads as "no releases" rather than as the
# rate limit it is. And a failing curl inside `$(... | ...)` takes the entire
# script down under `set -e -o pipefail`, aborting the run before the install it
# was only trying to version-check. gh raises the limit to 5000/hour when
# authenticated, and the tracked gitconfig already names it as its credential
# helper, so it's usually present.
#
# Callers must treat empty output as "couldn't tell", never as "no release".
github_latest_tag() {
  local repo="$1"
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh api "repos/$repo/releases/latest" --jq .tag_name 2>/dev/null || true
    return 0
  fi
  curl -fsSL -H "User-Agent: dotfiles-install-script (github.com/andyhite/dotfiles)" \
    "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
    | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 || true
}

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
  latest="$(github_latest_tag tree-sitter/tree-sitter | sed 's/^v//')"
  if [ -z "$latest" ]; then
    if [ -n "$current" ]; then
      ok "tree-sitter-cli" "$current — skipped the update check (GitHub API unavailable)"
    else
      warned "tree-sitter-cli" "GitHub API unavailable — re-run to install it"
    fi
    return 0
  fi

  if [ -n "$current" ] && [ "$current" = "$latest" ]; then
    ok "tree-sitter-cli" "up to date ($current)"
    return
  fi
  # Prebuilt binary, not `cargo install tree-sitter-cli` — that pulls in
  # rquickjs-sys, which needs bindgen/clang to resolve its resource-dir
  # correctly and fails on stock Ubuntu with a missing stdbool.h. NvChad only
  # needs the binary on PATH; this sidesteps the build entirely.
  tmp="$(mktemp -d)"
  # Pinned to the tag already resolved above, not /latest/download/ — that
  # re-resolves at download time, and a release landing in the gap between
  # the two calls would install a version this function never verified, then
  # report the wrong "$current -> $latest" name.
  if ! curl -fsSL -o "$tmp/tree-sitter.gz" \
    "https://github.com/tree-sitter/tree-sitter/releases/download/v$latest/tree-sitter-$os_part.gz"; then
    rm -rf "$tmp"
    warned "tree-sitter-cli" "download failed — re-run to retry"
    return 0
  fi
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

# One Brewfile for formulae and casks together, instead of a hand-maintained
# loop per package type. `brew bundle` only ever adds: dropping a line never
# uninstalls anything (that's `brew bundle cleanup`), so pruning the file is
# safe, and anything installed by hand outside it is left alone.
ensure_brewfile() {
  local file="$DOTFILES_DIR/Brewfile" missing
  if [ ! -f "$file" ]; then
    skipped "Brewfile" "not present"
    return 0
  fi

  # `check` is the cheap path, and the common one on a machine that has run this
  # before: it exits 0 only when every entry is installed and current, so the
  # multi-minute `bundle install` below is reached only when there's real work.
  if brew bundle check --file "$file" >/dev/null 2>&1; then
    ok "Brewfile" "every entry installed and current"
    return 0
  fi

  # --verbose turns that one-line failure into a list of what's outstanding,
  # which is worth naming before a long install starts. It writes that list to
  # stderr, not stdout, so 2>&1 is load-bearing — without it the pipeline reads
  # an empty stream. The sed keeps just the name out of each
  # "→ Formula jq needs to be installed or updated." line.
  # The trailing `|| true` is required, not defensive: `check` exits non-zero
  # precisely *because* something is missing, and pipefail would propagate that
  # through the pipeline into the assignment, aborting the script under set -e
  # right before the install that fixes it.
  missing="$(brew bundle check --file "$file" --verbose 2>&1 \
    | sed -n 's/^→ [A-Za-z]* \(.*\) needs to be installed or updated\./\1/p' \
    | paste -sd' ' - || true)"
  # An `if`, not `[ -n … ] && say …`, so the test's exit status can't leak out as
  # this function's own return value if it ever ends up last.
  if [ -n "$missing" ]; then
    say "installing/upgrading: $missing"
  fi

  if run_quiet Brewfile brew bundle install --file "$file"; then
    added "Brewfile" "${missing:-entries installed}"
  fi
}

install_tools_macos() {
  command -v brew >/dev/null 2>&1 || { failed "Homebrew" "not found — install from https://brew.sh first"; return 1; }
  ensure_brewfile
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
    if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -q; then
      warned "rustup" "download failed — re-run to retry"
      return 0
    fi
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
  # Same reasoning as github_latest_tag: a failed probe must not abort the run,
  # and an empty result means "couldn't tell", not "no such crate".
  latest="$(curl -fsSL -H "User-Agent: dotfiles-install-script (github.com/andyhite/dotfiles)" \
    "https://crates.io/api/v1/crates/$crate" 2>/dev/null \
    | grep -o '"newest_version":"[^"]*"' | head -1 | cut -d'"' -f4 || true)"
  if [ -z "$latest" ]; then
    # A local copy plus no way to compare is not worth a multi-minute rebuild.
    if [ -n "$current" ]; then
      ok "$crate" "$current — skipped the update check (crates.io unavailable)"
      return 0
    fi
    # Nothing installed, so build anyway: cargo resolves the version itself.
    latest="latest"
  fi

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
  latest="$(github_latest_tag neovim/neovim)"
  if [ -z "$latest" ]; then
    if [ -n "$current" ]; then
      ok "neovim" "$current — skipped the update check (GitHub API unavailable)"
    else
      warned "neovim" "GitHub API unavailable — re-run to install it"
    fi
    return 0
  fi

  if [ -n "$current" ] && [ "$current" = "$latest" ]; then
    ok "neovim" "up to date ($current)"
    return
  fi
  tmp="$(mktemp -d)"
  # Pinned to the tag resolved above, not /latest/download/ — same race
  # tree-sitter's download guards against.
  if ! curl -fsSL -o "$tmp/nvim.tar.gz" "https://github.com/neovim/neovim/releases/download/$latest/$tarball"; then
    rm -rf "$tmp"
    warned "neovim" "download failed — re-run to retry"
    return 0
  fi
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

ensure_lazygit_linux() {
  local arch current latest tmp
  case "$(uname -m)" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="arm64" ;;
    *) warned "lazygit" "unsupported arch $(uname -m) — install manually"; return ;;
  esac

  current=""
  if command -v lazygit >/dev/null 2>&1; then
    current="$(lazygit --version 2>/dev/null \
      | sed -n 's/.*version=\([^,[:space:]]*\).*/\1/p')"
  fi
  latest="$(github_latest_tag jesseduffield/lazygit | sed 's/^v//')"
  if [ -z "$latest" ]; then
    if [ -n "$current" ]; then
      ok "lazygit" "$current — skipped the update check (GitHub API unavailable)"
    else
      warned "lazygit" "GitHub API unavailable — re-run to install it"
    fi
    return 0
  fi

  if [ -n "$current" ] && [ "$current" = "$latest" ]; then
    ok "lazygit" "up to date ($current)"
    return
  fi

  tmp="$(mktemp -d)"
  if ! curl -fsSL -o "$tmp/lazygit.tar.gz" \
    "https://github.com/jesseduffield/lazygit/releases/download/v${latest}/lazygit_${latest}_linux_${arch}.tar.gz"; then
    rm -rf "$tmp"
    warned "lazygit" "download failed — re-run to retry"
    return 0
  fi
  tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
  rm -rf "$tmp"
  if [ -n "$current" ]; then
    updated "lazygit" "$current -> $latest"
  else
    added "lazygit" "$latest"
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
  if ! curl -fsSL -o "$tmp/font.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
    rm -rf "$tmp"
    warned "JetBrainsMono Nerd Font" "download failed — re-run to retry"
    return 0
  fi
  mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  unzip -oq "$tmp/font.zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  fc-cache -f "$HOME/.local/share/fonts/JetBrainsMonoNerdFont" >/dev/null
  rm -rf "$tmp"
  added "JetBrainsMono Nerd Font" "installed"
}

# macOS gets mise from the Brewfile. Linux has no equally universal package for
# it, so use the upstream installer, which drops a single binary into
# ~/.local/bin — already on PATH via zshrc. `self-update` is the supported
# upgrade path for exactly that install method and is refused on a
# package-manager-managed mise, which is why this function is Linux-only.
ensure_mise_linux() {
  if command -v mise >/dev/null 2>&1; then
    if run_quiet mise mise self-update --yes; then
      ok "mise" "$(mise --version 2>/dev/null | awk '{print $1}')"
    fi
    return 0
  fi
  if run_quiet mise sh -c "curl -sS https://mise.run | sh"; then
    added "mise" "installed to ~/.local/bin"
  fi
}

install_tools_linux() {
  if command -v apt-get >/dev/null 2>&1; then
    run_quiet apt sudo apt-get update -y || true
    # zsh: the shell these dotfiles configure, not guaranteed on a minimal box.
    # fzf: apt's build may predate `fzf --zsh`; zshrc falls back to the
    #      key-binding scripts apt drops in /usr/share, so old is fine.
    # git-lfs, gh: gitconfig declares the lfs filter and names gh as its
    #      credential helper, so both are requirements of the tracked config
    #      rather than conveniences.
    # jq, yq, shellcheck, shfmt: the Brewfile's counterparts. The last two only
    #      exist in recent archives; apt_ensure skips whatever isn't there.
    # build-essential/pkg-config: needed by the cargo builds below.
    # fontconfig: fc-list/fc-cache for the Nerd Font install.
    # ncurses-bin: infocmp, for ghostty's ssh-terminfo shell integration.
    for p in zsh git curl zoxide eza bat fzf direnv tmux unzip ripgrep \
             git-lfs gh jq yq shellcheck shfmt tree wget moreutils rsync \
             fontconfig ncurses-bin build-essential pkg-config; do
      apt_ensure "$p" || true
    done
  else
    warned "apt-get" "not found — skipping distro packages; install manually"
  fi

  ensure_lazygit_linux

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

  ensure_mise_linux
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
    # Must be linked alongside zshrc, not instead of it: zshenv is the only file
    # a non-interactive `ssh host 'cmd'` reads, and it's what puts ~/.local/bin
    # (herdr, omp, paseo) on PATH for one-shot remote commands.
    "zshenv:$HOME/.zshenv"
    "zshrc:$HOME/.zshrc"
    "zsh_plugins.txt:$HOME/.zsh_plugins.txt"
    "tmux.conf:$HOME/.tmux.conf"
    "config/starship.toml:$HOME/.config/starship.toml"
    # The `osolmaz/ghzinga` herdr plugin is pure declarative wiring — it reads
    # nothing itself, just shells out to `gzg`. All behaviour and config belong
    # to that separately-installed binary, which reads this path directly, so
    # `dutifuldev.ghzinga`'s dir under plugins/config below is legitimately
    # empty and this file has to be linked on its own rather than living there.
    "config/ghzinga/config.toml:$HOME/.config/ghzinga/config.toml"
    "config/herdr/config.toml:$HOME/.config/herdr/config.toml"
    # The command palette bound to prefix+p in the config above. A directory
    # link because the script travels with the upstream MIT notice it's derived
    # from, and `type = "popup"` needs a real path to exec — this is the only
    # keybinding in that file pointing at this repo rather than a herdr
    # subcommand, so the link is what makes the binding work at all.
    "config/herdr/palette:$HOME/.config/herdr/palette"
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
    # Same per-file rule for themes. dark-one-tuned.json is omp's built-in
    # dark-one with its block backgrounds re-based onto Ghostty's canvas:
    # upstream hardcodes userMessageBg to #21252b, which is byte-identical to
    # One Dark Two's `background`, so the user-message block renders invisible.
    # Built-ins win name collisions, hence the distinct name.
    "omp/agent/themes/dark-one-tuned.json:$HOME/.omp/agent/themes/dark-one-tuned.json"
    # Runtime pins. mise finds this by walking up from whatever directory it's
    # invoked in, so the symlink sitting at $HOME is what makes it the default
    # for everything that doesn't carry its own.
    "tool-versions:$HOME/.tool-versions"
    "gitconfig:$HOME/.gitconfig"
    # git reads $XDG_CONFIG_HOME/git/ignore on its own, which is why gitconfig
    # declares no core.excludesFile.
    "config/git/ignore:$HOME/.config/git/ignore"
    # config.yml only: hosts.yml sits beside it and holds gh's OAuth tokens.
    "config/gh/config.yml:$HOME/.config/gh/config.yml"
    # One file, not the directory: ~/.ssh holds private keys. Machine-specific
    # hosts go in ~/.ssh/config.local, which this config includes first.
    "ssh/config:$HOME/.ssh/config"
    # settings.json only: ~/.config/zed also stores conversations and prompts.
    "config/zed/settings.json:$HOME/.config/zed/settings.json"
    # Per-file for the same reason as the extensions above — anything omp or
    # another tool drops into ~/.omp/agent/rules stays visible alongside it.
    "omp/agent/rules/output-style.md:$HOME/.omp/agent/rules/output-style.md"
    "omp/agent/rules/herdr-worktrees.md:$HOME/.omp/agent/rules/herdr-worktrees.md"
    # This stays deliberately narrow: it tells every session how to use
    # worktrees, not when to dispatch work, which is fleet's opt-in procedure.
    # Reads skill://paseo-config-authoring to detect and write a project's
    # paseo.json (worktree setup/teardown, workspace scripts, and commit/
    # branch conventions for Paseo's metadata generation). The skill itself
    # is a managed skill (~/.omp/agent/managed-skills), not tracked here.
    "omp/agent/commands/paseo-init.md:$HOME/.omp/agent/commands/paseo-init.md"
    # Read by the Paseo orchestration skills, never by Paseo itself — grepping
    # getpaseo/paseo for the name turns up only the five shipped SKILL.md
    # files. That's what makes it safe to link when its neighbour
    # ~/.paseo/config.json isn't: nothing rewrites it behind the symlink. The
    # rest of ~/.paseo is a keypair, a server id, push tokens, and ~1GB of
    # local speech models, so this is linked per-file like omp's.
    "config/paseo/orchestration-preferences.json:$HOME/.paseo/orchestration-preferences.json"
  )

  # Lazygit follows the native config directory on macOS rather than XDG's
  # ~/.config default. Keep one tracked source but link it where each platform
  # actually reads it; setting global XDG_CONFIG_HOME just for this would move
  # unrelated applications' state.
  if [ "$OS" = "Darwin" ]; then
    links+=("config/lazygit/config.yml:$HOME/Library/Application Support/lazygit/config.yml")
  else
    links+=("config/lazygit/config.yml:$HOME/.config/lazygit/config.yml")
  fi

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

  # bin/tailscale — a PATH shim for the Mac App Store build of Tailscale (see
  # that file for why a plain symlink to the app bundle doesn't work). Not in
  # the links array above because it can't be unconditional: Darwin only, and
  # only when the App Store bundle is actually installed, so this stays a
  # no-op on Linux and on a Mac running the Homebrew/open-source tailscale —
  # that build drops a real binary straight onto PATH and needs no shim.
  if [ "$OS" = "Darwin" ] && [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
    src="$DOTFILES_DIR/bin/tailscale"
    dst="$HOME/.local/bin/tailscale"
    shown="${dst/#$HOME/\~}"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      ok "$shown"
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
      backup="$dst.bak.$(date +%s)"
      mv "$dst" "$backup"
      ln -s "$src" "$dst"
      warned "$shown" "backed up to ${backup##*/}"
    else
      ln -s "$src" "$dst"
      added "$shown" "-> bin/tailscale"
    fi
  fi

  # .gitattributes points config/zed/settings.json at a clean filter, but a
  # filter definition can't be committed: it names an absolute path, and this
  # repo sits somewhere different on every machine. Register it here instead.
  #
  # Without it Zed writes ssh_connections — real internal hosts, real work
  # project paths — through the symlink into a tracked file in a public repo,
  # on every remote connect. Deleting the key by hand doesn't hold; the next
  # connect restores it. git treats an unconfigured filter as a pass-through,
  # so this is what actually turns the .gitattributes entry on.
  #
  # `git config` overwrites rather than appends, so re-running is a no-op.
  if [ -d "$DOTFILES_DIR/.git" ]; then
    # `awk -f <script>`, not the script as a program: it carries no shebang on
    # purpose, because `#!/usr/bin/env awk -f` silently works on macOS and
    # fails on Linux. The path is single-quoted for git's `sh -c`, so a repo
    # checked out under a path with spaces still resolves.
    git -C "$DOTFILES_DIR" config filter.zed-local.clean \
      "awk -f '$DOTFILES_DIR/bin/zed-settings-clean'"
    # No smudge: the working file is Zed's, and this filter only ever removes
    # machine state on the way in. Reversing it on checkout would mean writing
    # this machine's hosts into another machine's file.
    git -C "$DOTFILES_DIR" config filter.zed-local.smudge cat
    ok "git filter" "zed-local — strips ssh_connections from the index"
  fi

  # Templates are copied, not linked: each holds machine-local values, and most
  # of them hold credentials. Copied only when absent, so a re-run can never
  # overwrite an already filled-in file.
  #
  # Same $HOME -> ~ display transform as the loop above, rather than a literal
  # "~/..." string: that reads as an unexpanded path to both shellcheck and the
  # next person, and drifts if the location ever changes.
  local example target
  for example in zshrc.local.example gitconfig.local.example ssh/config.local.example \
                 config/paseo/daemon.env.example omp/agent/models.yml.example; do
    # ssh's and paseo's live in a subdirectory on both sides; the rest are
    # dotfiles at $HOME. paseo's is the odd one out in that its target isn't a
    # dotfile at all — config/paseo/paseo.service names it as an
    # EnvironmentFile, and systemd resolves that path itself, so it has to land
    # where the unit says rather than where this loop's default would put it.
    # omp's lands beside the config.yml symlink, which is already where omp
    # looks for it. It ships inert but deliberately not empty: the active line
    # is a literal `providers: {}`, because omp validates the file's root as an
    # object and a copy trimmed to pure comments parses as null and warns on
    # every startup.
    case "$example" in
      ssh/*)          target="$HOME/.ssh/${example#ssh/}"; target="${target%.example}" ;;
      config/paseo/*) target="$HOME/.config/paseo/${example#config/paseo/}"; target="${target%.example}" ;;
      omp/agent/*)    target="$HOME/.omp/agent/${example#omp/agent/}"; target="${target%.example}" ;;
      *)              target="$HOME/.${example%.example}" ;;
    esac

    if [ -f "$target" ]; then
      ok "${target/#$HOME/\~}" "present"
      continue
    fi
    mkdir -p "$(dirname "$target")"
    cp "$DOTFILES_DIR/$example" "$target"
    chmod 600 "$target"
    added "${target/#$HOME/\~}" "created from ${example##*/} — fill in your values"
  done
}

# ── Language runtimes ────────────────────────────────────────────────────────

# Runs after the symlinks: the pins mise reads live in ~/.tool-versions, which
# is the symlink link_configs just created.
ensure_runtimes() {
  if ! command -v mise >/dev/null 2>&1; then
    skipped "mise" "not on PATH — run the tools step, then re-run"
    return 0
  fi

  # Invoked from $HOME rather than wherever this script was started, so the pins
  # that get installed are always the global ones. mise takes the nearest config
  # walking upward, so running it from inside some other checkout would install
  # that project's versions instead.
  if ! run_quiet mise sh -c "cd '$HOME' && mise install --yes"; then
    return 0
  fi

  # Cheap confirmation that every line of tool-versions resolved to a real
  # install, rather than trusting the installer's exit code alone.
  local tool version
  while read -r tool version _; do
    [ -n "$tool" ] || continue
    ok "$tool" "$version"
  done < <(cd "$HOME" && mise ls --current --quiet 2>/dev/null)
}

# ── Paseo ────────────────────────────────────────────────────────────────────

# Paseo supervises coding agents (Claude, Codex, omp) and exposes them to
# desktop, mobile and CLI clients. The two machines this repo bootstraps use it
# from opposite ends: the Mac runs the GUI app as a client, the Linux box runs
# the daemon the Mac connects to. Everything below is written to do the right
# thing on either.

# macOS gets the binary from the Brewfile cask and only needs it on PATH; Linux
# has no desktop app worth installing, so it gets the standalone npm package —
# @getpaseo/cli depends on @getpaseo/server, so that single package really is
# the whole daemon and not a thin remote client.
#
# --prefix "$HOME/.local" rather than a bare `npm install -g`: a plain global
# install lands inside whichever node mise currently has active and disappears
# the moment tool-versions bumps node, whereas ~/.local/bin is where every
# other manually-installed tool here already lives and is already on PATH. The
# launcher's shebang is `env -S node`, so it resolves node at run time either
# way.
ensure_paseo_cli() {
  local bundled="/Applications/Paseo.app/Contents/Resources/bin/paseo"
  local dst="$HOME/.local/bin/paseo"
  # Same $HOME -> ~ display transform link_configs uses; a literal "~/..."
  # string in a label doesn't expand and reads as a bug to shellcheck.
  local shown="${dst/#$HOME/\~}" backup

  if [ "$OS" = "Darwin" ]; then
    if [ ! -x "$bundled" ]; then
      skipped "paseo" "Paseo.app not installed — run the tools step, then re-run"
      return 1
    fi
    # The app's own first-run hook makes this link, but only when the GUI has
    # actually been launched at least once — `brew bundle` alone never opens it,
    # so on a fresh machine `paseo` would be missing from PATH until someone
    # double-clicked the icon.
    #
    # Same back-up-anything-unexpected shape as the bin/tailscale block in
    # link_configs, rather than an unconditional rm: a real binary sitting here
    # is someone's own install, and this script doesn't get to delete it.
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$bundled" ]; then
      ok "$shown"
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
      backup="$dst.bak.$(date +%s)"
      mv "$dst" "$backup"
      ln -s "$bundled" "$dst"
      warned "$shown" "backed up to ${backup##*/}"
    else
      ln -s "$bundled" "$dst"
      added "$shown" "-> Paseo.app bundled CLI"
    fi
    return 0
  fi

  # Same mise-first reasoning as install_agent_skills: `command -v npm` also
  # matches a dead shim from another version manager, so ask mise for the node
  # that tool-versions pins.
  local runner
  if command -v mise >/dev/null 2>&1; then
    runner="mise exec -- npm"
  elif command -v npm >/dev/null 2>&1; then
    runner="npm"
  else
    skipped "paseo" "no node — run the tools and runtimes steps first"
    return 1
  fi

  if run_quiet paseo sh -c "$runner install -g --prefix '$HOME/.local' @getpaseo/cli" </dev/null; then
    ok "paseo" "$(cd "$HOME" && mise exec -- "$HOME/.local/bin/paseo" --version 2>/dev/null || echo installed)"
    return 0
  fi
  return 1
}

# config/paseo/config.json is merged into ~/.paseo/config.json rather than
# symlinked over it, which is the one place Paseo breaks this repo's usual
# pattern. Two independent reasons, both verified against the upstream source:
#
#   1. Paseo saves config atomically. persisted-config.ts's savePersistedConfig
#      calls writePrivateFileAtomicSync, which writes a sibling tempfile and
#      renameSync()s it over the target — and rename *replaces* a symlink with a
#      real file. So the first settings change made in the app would silently
#      detach the link, leaving the repo showing a tracked config that no longer
#      has any effect.
#   2. The live file legitimately holds things that must never be committed:
#      `paseo daemon set-password` writes a bcrypt hash into daemon.auth, and
#      custom providers keep API keys under agents.providers.*.env.
#
# A merge solves both: the tracked file is authoritative for the keys it names,
# and every other key in the live file — secrets and per-machine settings
# included — is left exactly as Paseo wrote it. jq's `*` is a recursive object
# merge with the right side winning, which is why the tracked file is the second
# argument. Verified idempotent: merging an already-merged file changes nothing.
merge_paseo_config() {
  local src="$DOTFILES_DIR/config/paseo/config.json"
  local dst="$HOME/.paseo/config.json"
  local shown="${dst/#$HOME/\~}"

  if [ ! -f "$src" ]; then
    skipped "config/paseo/config.json" "not present"
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    skipped "$shown" "jq not on PATH — run the tools step, then re-run"
    return 0
  fi

  # 0700 to match what Paseo's own ensurePrivateDirectory sets, so a fresh
  # machine doesn't end up with a laxer mode than the daemon would have chosen.
  mkdir -p "$HOME/.paseo"
  chmod 700 "$HOME/.paseo" 2>/dev/null || true
  [ -f "$dst" ] || printf '{}\n' > "$dst"

  local merged
  merged="$(mktemp "$dst.merge.XXXXXX")" || return 1
  if ! jq -s '.[0] * .[1]' "$dst" "$src" > "$merged" 2>/dev/null; then
    rm -f "$merged"
    failed "$shown" "invalid JSON in it or in config/paseo/config.json"
    return 1
  fi

  # Compared semantically, not byte-wise: the daemon rewrites this file with its
  # own key order and formatting, so a textual diff would report drift on every
  # run and the "restart to apply" note below would cry wolf.
  if jq -e --slurpfile want "$merged" '. == $want[0]' "$dst" >/dev/null 2>&1; then
    rm -f "$merged"
    ok "$shown" "matches config/paseo/config.json"
    return 0
  fi

  mv "$merged" "$dst"
  chmod 600 "$dst"
  updated "$shown" "merged config/paseo/config.json"
  # Deliberately not restarting it here: config is read at startup, but a
  # restart kills every agent currently running under the daemon — including,
  # when an agent is the one running this script, itself.
  say "restart the daemon to apply: paseo daemon restart"
}

# Linux only. The Mac's daemon is started and supervised by the desktop app, so
# there is nothing to install there; the Linux box is the one that has to bring
# a daemon up on its own and keep it up across reboots.
#
# Copied rather than symlinked, unlike everything else in this repo: systemd
# reads units through its own path resolution and `systemctl --user daemon-reload`
# is what publishes a change, so a symlink would buy nothing and a stale
# in-memory unit would hide edits made here anyway. The copy is re-made on every
# run, so editing config/paseo/paseo.service and re-running is the update path.
ensure_paseo_service() {
  [ "$OS" = "Linux" ] || return 0

  local src="$DOTFILES_DIR/config/paseo/paseo.service"
  local dst="$HOME/.config/systemd/user/paseo.service"
  local shown="${dst/#$HOME/\~}"

  if [ ! -f "$src" ]; then
    skipped "paseo.service" "not present"
    return 0
  fi
  if ! command -v systemctl >/dev/null 2>&1; then
    skipped "paseo.service" "no systemd — start the daemon with: paseo daemon start"
    return 0
  fi

  mkdir -p "$(dirname "$dst")"
  if cmp -s "$src" "$dst"; then
    ok "$shown"
  else
    cp "$src" "$dst"
    added "$shown" "<- config/paseo/paseo.service"
  fi

  # --user units normally start at login, which never happens on a box that's
  # only ever reached over ssh. Lingering is what makes the user manager come up
  # at boot instead. It needs root, so ask rather than assume: a machine where
  # the daemon only has to be running while you're logged in doesn't need it.
  if command -v loginctl >/dev/null 2>&1; then
    if [ "$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null)" = "yes" ]; then
      ok "linger" "enabled for $USER"
    elif ! confirm "Enable systemd lingering for $USER, so the Paseo daemon starts at boot?"; then
      skipped "linger" "daemon will start at login instead of at boot"
    # `sudo -n` first, deliberately not run_quiet: an unattended run has no tty
    # for a password prompt, and confirm() returns true in exactly that case, so
    # without this gate every ssh'd `--yes` install would record a hard error for
    # something entirely optional. A warning that names the command is the right
    # severity — the daemon still works, it just waits for a login.
    elif ! sudo -n true 2>/dev/null; then
      warned "linger" "needs sudo — run: sudo loginctl enable-linger $USER"
    elif sudo -n loginctl enable-linger "$USER" >/dev/null 2>&1; then
      added "linger" "enabled for $USER"
    else
      warned "linger" "enable-linger failed — run: sudo loginctl enable-linger $USER"
    fi
  fi

  run_quiet "systemd reload" systemctl --user daemon-reload || return 0

  # enable, not `enable --now`: starting the daemon here would be a surprise on
  # a box that has one running already under a different launch override, and
  # `restart` on an active unit kills its agents. Enable the unit so a reboot
  # brings it up, and hand the first start to the user.
  if run_quiet "paseo.service" systemctl --user enable paseo.service; then
    if systemctl --user is-active --quiet paseo.service; then
      ok "paseo.service" "enabled, running"
      say "restart to pick up config changes: systemctl --user restart paseo"
    else
      updated "paseo.service" "enabled, not started"
      say "set PASEO_LISTEN in ~/.config/paseo/daemon.env, then: systemctl --user start paseo"
    fi
  fi
}

setup_paseo() {
  # The config merge and the unit are worth doing even when the CLI is missing —
  # they're both just files on disk, and doing them anyway means a box that
  # installs Paseo later is already configured for it.
  ensure_paseo_cli || true
  merge_paseo_config
  ensure_paseo_service
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
    #
    # </dev/null for the same reason as the skills loop below: this loop's stdin
    # is the manifest, and any prompt-reading child would eat the rest of it.
    if [ -n "$plugin_ref" ]; then
      if run_quiet "$plugin_spec" herdr plugin install "$plugin_spec" --ref "$plugin_ref" --yes </dev/null; then
        updated "$plugin_spec" "@$plugin_ref"
      fi
    else
      if run_quiet "$plugin_spec" herdr plugin install "$plugin_spec" --yes </dev/null; then
        updated "$plugin_spec" "default branch"
      fi
    fi
  done < "$DOTFILES_DIR/herdr_plugins.txt"
}

# ── omp plugins ──────────────────────────────────────────────────────────────

# The source a marketplace name is currently registered to, empty when the name
# is not registered at all. `marketplace list` prints "  <name>  <source>" rows
# under a heading; comparing the whole first field keeps one name that is a
# prefix of another from matching, and the heading line cannot collide because
# its first word is capitalised while marketplace names are lowercase.
omp_marketplace_source() {
  omp plugin marketplace list 2>/dev/null | awk -v n="$1" '$1 == n { print $2; exit }'
}

# The omp counterpart to install_herdr_plugins, and shaped differently because
# omp splits the job in two: a marketplace is registered once, then plugins are
# installed from it by `<plugin>@<marketplace>` id.
#
# The refresh is the part worth knowing. herdr updates a plugin by installing it
# again; omp does not. `omp plugin install --force` reinstalls from the
# marketplace clone already on disk, so a re-run without `marketplace update`
# first silently reinstalls the version you already had and reports success.
# Both commands run every time, which is what makes this step an updater.
install_omp_plugins() {
  if [ ! -f "$DOTFILES_DIR/omp_plugins.txt" ]; then
    skipped "omp_plugins.txt" "not present"
    return 0
  fi
  if ! command -v omp >/dev/null 2>&1; then
    skipped "omp" "not on PATH — install it, then re-run"
    return 0
  fi

  # Plain strings rather than arrays: bash 3.2 (what macOS ships) treats
  # ${arr[*]} on an empty array as an unbound variable under `set -u`, and
  # marketplace names cannot contain whitespace. `ready` is the marketplaces
  # already prepared this run, `broken` the ones that failed — a second plugin
  # from a bad marketplace must not fall through to install.
  local line source plugin_id marketplace registered ready="" broken=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue

    case "$line" in
      *[[:space:]]*@*) ;;
      *) warned "$line" "expected '<source> <plugin>@<marketplace>'"; continue ;;
    esac
    source="${line%%[[:space:]]*}"
    plugin_id="${line##*[[:space:]]}"
    marketplace="${plugin_id#*@}"

    case " $broken " in *" $marketplace "*) continue ;; esac

    # One marketplace can serve several plugins, so prepare it only on its first
    # line. The name is what `<plugin>@<marketplace>` resolves through, and it is
    # claimed by whoever registered it first — so a name already pointing at a
    # different source is refused rather than installed from. Swallowing the
    # duplicate-add error instead would quietly install a different plugin that
    # happens to share the id.
    case " $ready " in
      *" $marketplace "*) ;;
      *)
        registered=$(omp_marketplace_source "$marketplace")
        if [ -z "$registered" ]; then
          if ! run_quiet "$marketplace" omp plugin marketplace add "$source" </dev/null; then
            broken="$broken $marketplace"; continue
          fi
        elif [ "$registered" != "$source" ]; then
          warned "$marketplace" "registered to $registered, not $source"
          broken="$broken $marketplace"; continue
        fi
        if ! run_quiet "$marketplace" omp plugin marketplace update "$marketplace" </dev/null; then
          broken="$broken $marketplace"; continue
        fi
        ready="$ready $marketplace"
        ;;
    esac

    # </dev/null for the same reason as the loops above: this loop's stdin is
    # the manifest, and a prompt-reading child would eat the rest of it.
    if run_quiet "$plugin_id" omp plugin install --force "$plugin_id" </dev/null; then
      updated "$plugin_id" "from $source"
    fi
  done < "$DOTFILES_DIR/omp_plugins.txt"
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

# ── Cross-agent skills ───────────────────────────────────────────────────────

# `npx skills` keeps one canonical copy of each skill in ~/.agents/skills and
# symlinks every agent it detects at that tree. omp reads it directly (its
# `agents` skill provider), so there's no omp-specific install target to pass.
# Re-adding an installed skill is how the CLI updates one, so this runs every
# time rather than skipping what's already present.
install_agent_skills() {
  local manifest="$DOTFILES_DIR/agent_skills.txt"
  if [ ! -f "$manifest" ]; then
    skipped "agent_skills.txt" "not present"
    return 0
  fi

  # npx needs node, and this script runs under bash — where `mise activate` never
  # ran, so the pinned node is installed but not on PATH. `mise exec` loads it for
  # the length of one command.
  #
  # mise is tried *first*, not as the fallback: `command -v npx` also matches a
  # leftover shim from another version manager, and a shim that resolves to
  # nothing exits 126 with its own error instead of failing the lookup. Asking
  # mise means the node that runs this is the one tool-versions pins.
  local runner
  if command -v mise >/dev/null 2>&1; then
    runner="mise exec -- npx"
  elif command -v npx >/dev/null 2>&1; then
    runner="npx"
  else
    skipped "agent skills" "no node — run the tools and runtimes steps first"
    return 0
  fi

  local line source skill
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue

    # `<owner>/<repo> --skill <name>`, so the source is the first field and the
    # skill name the last.
    source="${line%% *}"
    skill="${line##* }"

    # -g installs for every agent on the machine instead of into a project, and
    # -y answers the CLI's prompts so this works with no tty.
    #
    # </dev/null is load-bearing: this loop's stdin *is* the manifest, and the
    # CLI reads stdin looking for prompt answers — draining the rest of the file
    # and silently reducing the loop to a single iteration.
    if run_quiet "$skill" sh -c "cd '$HOME' && $runner --yes skills add '$source' --skill '$skill' -g -y" </dev/null; then
      updated "$skill" "from $source"
    fi
  done < "$manifest"
}

# One step, two sources: the manifest above, then whatever the installed Herdr
# plugins ship.
setup_skills() {
  install_agent_skills
  link_omp_skills
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

# ── Remote hosts ─────────────────────────────────────────────────────────────

# With --host this script installs nothing locally — it becomes a driver for
# the *remote's own copy* of install.sh. That's deliberate: the remote clone is
# the thing being bootstrapped, and piping this file over the wire would
# happily install a version that was never committed, leaving the box in a
# state no git ref describes.

# Quotes one argument for a remote Bourne shell. ssh joins its command
# arguments with spaces and hands the string to the login shell, so everything
# has to survive one extra round of word splitting on the far side. Single
# quotes are the only quoting every shell agrees on: printf %q emits bash/zsh
# $'...' for anything with a newline in it, which a dash login shell doesn't
# understand — and the bootstrap below is one big multi-line argument.
shquote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# The URL a first-time `git clone` on a remote is given. The tracked origin is
# an ssh Host alias defined in this repo's own ssh/config (github.com-personal)
# — which a machine that hasn't been bootstrapped yet doesn't have, nor the key
# it names. So resolve the alias to its real hostname through `ssh -G` (exact,
# and no hostname is hardcoded here) and hand over the public https URL, which
# needs no credentials at all. A remote that already has a clone keeps whatever
# origin it has; this only ever feeds `git clone`. DOTFILES_REPO overrides it,
# for a fork or a private mirror the remote can reach on its own.
remote_clone_url() {
  local url host path
  if [ -n "${DOTFILES_REPO:-}" ]; then printf '%s\n' "$DOTFILES_REPO"; return 0; fi

  url="$(git -C "$DOTFILES_DIR" remote get-url origin 2>/dev/null)" || return 1
  case "$url" in
    git@*:*)
      host="${url%%:*}"; host="${host#git@}"; path="${url#*:}"
      host="$(ssh -G "$host" 2>/dev/null | awk '$1 == "hostname" { print $2; exit }')"
      [ -n "$host" ] || return 1
      printf 'https://%s/%s\n' "$host" "$path" ;;
    *)
      printf '%s\n' "$url" ;;
  esac
}

# The script that runs on the far side. Kept small and POSIX-ish on purpose:
# all it does is get the repo into place and hand over to the real install.sh,
# which prints everything you actually read.
remote_bootstrap() {
  cat <<'REMOTE_SCRIPT'
set -eu

repo=$1 dir=$2 branch=$3
shift 3

# --remote-path defaults to a literal ~/… string; only this side knows $HOME.
case $dir in
  "~/"*) dir="$HOME/${dir#\~/}" ;;
  "~")   dir="$HOME" ;;
esac

# ssh runs a non-login, non-interactive shell, so none of the PATH that zshrc
# assembles exists here: ~/.local/bin (omp, mise, paseo, herdr, tree-sitter),
# the mise shims that provide node, Homebrew on a macOS host. Without them
# install.sh's `command -v` guards would each decide their tool is missing and
# reinstall it from scratch — a correct result reached the slowest way.
PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/mise/shims:$PATH"
for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$brew" ]; then eval "$("$brew" shellenv)"; break; fi
done
export PATH

if ! command -v git >/dev/null 2>&1; then
  echo "no git on this host — install it, then run this again" >&2
  exit 1
fi

if [ -d "$dir/.git" ]; then
  git -C "$dir" fetch --quiet origin
  # A dirty worktree is left exactly as it is and installed from anyway: this
  # is how you try a change on the remote before committing it, and silently
  # resetting someone's edits to match origin would be unforgivable.
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "! $dir has uncommitted changes — installing it as-is, without updating" >&2
  else
    git -C "$dir" checkout --quiet "$branch"
    git -C "$dir" merge --ff-only --quiet "origin/$branch"
  fi
else
  mkdir -p "$(dirname "$dir")"
  git clone --quiet --branch "$branch" "$repo" "$dir"
fi

exec "$dir/install.sh" "$@"
REMOTE_SCRIPT
}

# The remote pulls from origin, so anything that exists only in this working
# copy is not part of what lands there. Worth one line before a run that would
# otherwise look like it had picked up the change you just made.
warn_unpushed() {
  local dirty ahead
  dirty="$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null || true)"
  ahead="$(git -C "$DOTFILES_DIR" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)"

  [ -z "$dirty" ]        || warned "uncommitted changes" "won't reach the remote — commit and push first"
  [ "${ahead:-0}" -eq 0 ] || warned "$ahead unpushed commit(s)" "won't reach the remote — push first"
  return 0
}

# Runs the bootstrap on one host. Everything it prints is the remote's own
# install.sh output, so the only thing added is the heading naming where it
# went — two hosts' transcripts would otherwise be impossible to tell apart.
install_remote() {
  local host=$1 repo=$2 branch=$3 cmd arg
  local -a ssh_flags

  heading "$host" "$REMOTE_DIR ← $repo ($branch)"

  # `bash -c SCRIPT NAME ARGS…` — NAME lands in $0, so the positional
  # parameters the bootstrap reads start at the repo URL.
  cmd="bash -c $(shquote "$(remote_bootstrap)") install.sh"
  for arg in "$repo" "$REMOTE_DIR" "$branch" ${FORWARD_ARGS+"${FORWARD_ARGS[@]}"}; do
    cmd="$cmd $(shquote "$arg")"
  done

  # A tty is only worth asking for when there's a human on this end to answer
  # the remote's prompts. Forcing one with -tt when nobody is watching would
  # make every step sit out its 60s read timeout instead of running unattended.
  if [ -t 0 ] && [ -t 1 ]; then ssh_flags=(-t); else ssh_flags=(-T); fi

  ssh "${ssh_flags[@]}" "$host" "$cmd"
}

# One host failing doesn't cancel the rest, matching how a failed step behaves
# inside a single run; the exit status still reflects it.
install_remote_all() {
  local repo branch host rc=0

  repo="$(remote_clone_url)" ||
    die "couldn't work out a clone URL from origin — set DOTFILES_REPO"
  branch="$(git -C "$DOTFILES_DIR" symbolic-ref --short HEAD 2>/dev/null)" ||
    die "not on a branch here, so there's nothing for the remote to track"

  printf '\n%s%sdotfiles%s %s→ %s%s\n' \
    "$C_BOLD" "$C_CYAN" "$C_RESET" "$C_DIM" "${REMOTE_HOSTS[*]}" "$C_RESET"
  say "installing remotely; this machine is left untouched"
  warn_unpushed

  for host in "${REMOTE_HOSTS[@]}"; do
    install_remote "$host" "$repo" "$branch" || { failed "$host" "install failed"; rc=1; }
  done
  return "$rc"
}

# ── Run ──────────────────────────────────────────────────────────────────────

# --host redirects the whole run elsewhere rather than adding to it, so this
# sits ahead of every local step. It lands after the step-name validation above
# on purpose: a typo in --only is caught here, before any network round trip.
if [ "${#REMOTE_HOSTS[@]}" -gt 0 ]; then
  install_remote_all
  exit $?
fi

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
#   runtimes after configs     mise reads its pins from ~/.tool-versions, and
#                              that symlink is created by the configs step.
#   paseo after configs        the orchestration-preferences symlink is made by
#                              the configs step, and config/paseo/paseo.service
#                              names ~/.config/paseo/daemon.env, which the same
#                              step copies from its template.
#   paseo after runtimes       on Linux the CLI is an npm package, so it needs
#                              the node that the runtimes step installs. On
#                              macOS it comes from the Brewfile cask instead,
#                              which makes the tools step the real prerequisite
#                              there — after runtimes satisfies both.
#   herdr after configs        each plugin's config dir then gets created inside
#                              this repo rather than in a real directory that
#                              would have to be adopted later.
#   skills after runtimes      the skills CLI runs under npx, which needs the
#                              node that the runtimes step installs.
#   skills after herdr         herdr stores each plugin under a content-hashed
#                              directory, so a link made before an update points
#                              at a path that no longer exists.
#   nvim last                  it needs both neovim and config/nvim in place.
run_step tools       "Tools"         "Brewfile/apt, fonts, editors, agents"             install_tools
run_step completions "Completions"   "generated into ~/.local/share/zsh/site-functions" ensure_completions
run_step configs     "Configs"       "symlink this repo into place"                     link_configs
run_step runtimes    "Runtimes"      "language versions pinned in tool-versions"        ensure_runtimes
run_step paseo       "Paseo"         "merge config/paseo, ensure the CLI and daemon"     setup_paseo
run_step herdr       "Herdr plugins" "from herdr_plugins.txt"                           install_herdr_plugins
run_step omp         "omp plugins"   "from omp_plugins.txt"                             install_omp_plugins
run_step skills      "Skills"        "agent_skills.txt, plus Herdr-shipped omp skills"  setup_skills
run_step nvim        "NvChad"        "headless plugin sync"                             sync_nvchad

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
