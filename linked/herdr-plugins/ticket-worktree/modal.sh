#!/usr/bin/env bash
# ticket-worktree modal — herdr-plugin.toml's "modal" pane entrypoint.
#
# Bound to prefix+t in ../../config.toml as a `herdr plugin pane open`
# popup, invoked directly rather than through `plugin action invoke`: reading
# a ticket/PR/branch URL needs a real TTY, and a plugin ACTION runs on the
# server with none — the same constraint ../../palette/palette.sh documents
# for fzf. Declaring this as a manifest `[[panes]]` entry with
# `placement = "popup"` gets the TTY for free; opening it is what makes it
# session-modal.
#
# Flow: one form — a text field, a branch preview, a chip (Conventional-
# Commits type for a ticket, PR/branch for GitHub), and Create / Cancel
# buttons on a single screen. Two distinct paths after that, both ending the
# same way:
#   - Jira/Linear/bare key: parse a ticket key (and, for Linear, a slug);
#     look up the ticket's real type in the background via `acli` (Jira) or
#     `lin` (Linear) and populate the type chip once that lands, overridable
#     at any time with ←/→ -> `herdr worktree create` with a NEW branch name
#     built from config.toml's per-provider template.
#   - GitHub PR/branch URL: look up the PR's head branch in the background
#     via `gh`, if installed -> `git fetch` the EXISTING ref straight into a
#     local branch of the same name -> `herdr worktree create` checks that
#     branch out as-is; no template, no type.
# Either way: -> `herdr agent start` an omp agent in the new worktree's root
# pane -> `herdr pane send-text` a prompt back into that agent's input
# WITHOUT submitting it, so it's queued but the user decides when — or
# whether — to send it.
#
# The form is hand-rolled ANSI rather than gum because gum has no form widget
# that mixes a live-updating preview with buttons: `gum input` and `gum
# confirm` each own the whole TTY for the duration of one widget, which is
# what forced the old two-screen "type, then confirm" flow. 150 lines of raw
# mode buys a single screen and drops a dependency.
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

# Brief pause + message so a failure is readable before the popup closes
# (its process exiting is what closes it — there is no separate dismiss).
die() {
  printf '\nticket-worktree: %s\n' "$1" >&2
  printf '\nPress any key to close...' >&2
  read -r -n 1 -s -t 10 _ 2>/dev/null || true
  exit 1
}

command -v jq >/dev/null 2>&1 || die "jq is not installed or not on PATH."

# This popup's own process always runs with the plugin directory as its cwd
# (see plugins.mdx's "Commands and environment" section), so the repo to
# branch from has to come from context rather than $PWD. Context reflects
# whichever pane had focus when prefix+t was pressed.
ctx="${HERDR_PLUGIN_CONTEXT_JSON:-{}}"
origin_cwd="$(printf '%s' "$ctx" | jq -r '.worktree.repo_root // .workspace_cwd // empty' 2>/dev/null)"
[ -n "$origin_cwd" ] || die "Couldn't resolve the origin workspace's repo — is it a git checkout?"

# Background by default — same "don't steal focus for background work" call
# the herdr skill makes for split panes. Override per machine with
# `focus = true` in $HERDR_PLUGIN_CONFIG_DIR/config.toml (seeded, commented
# out, at config/herdr/plugins/config/andyhite.ticket-worktree/config.toml).
focus="false"
config_file="${HERDR_PLUGIN_CONFIG_DIR:-}/config.toml"
if [ -n "${HERDR_PLUGIN_CONFIG_DIR:-}" ] && [ -f "$config_file" ]; then
  cfg_val="$(sed -n 's/^[[:space:]]*focus[[:space:]]*=[[:space:]]*\(true\|false\).*/\1/p' "$config_file" | tail -1)"
  [ -n "$cfg_val" ] && focus="$cfg_val"
fi
if [ "$focus" = "true" ]; then
  focus_flag="--focus"
else
  focus_flag="--no-focus"
fi

# ── Branch-naming config ─────────────────────────────────────────────────────
# Minimal reader for config.toml's flat `[section]` / `[section.subsection]`
# shape — not a general TOML parser: no arrays, no multiline strings, one
# `key = "value"` per line. Good enough for the config this plugin owns.
toml_block() {
  # $1 file  $2 exact section header text, e.g. "jira" or "jira.types"
  local file="$1" header="[$2]"
  [ -f "$file" ] || return 0
  awk -v want="$header" '
    $0 == want { insec = 1; next }
    /^\[/ { insec = 0 }
    insec { print }
  ' "$file"
}
toml_scalar() {
  # $1 file  $2 section  $3 key -> last matching value, quotes stripped.
  toml_block "$1" "$2" | sed -n "s/^[[:space:]]*$3[[:space:]]*=[[:space:]]*\"\\(.*\\)\"[[:space:]]*\$/\\1/p" | tail -1
}
toml_table() {
  # $1 file  $2 section -> "key=value" lines, quotes stripped both sides.
  local line k v
  while IFS= read -r line; do
    line="${line%%#*}"
    [[ "$line" == *=* ]] || continue
    k="${line%%=*}"
    v="${line#*=}"
    k="$(printf '%s' "$k" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
    v="$(printf '%s' "$v" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
    [ -n "$k" ] || continue
    printf '%s=%s\n' "$k" "$v"
  done < <(toml_block "$1" "$2")
}

# Per-provider branch template and Conventional-Commits type mapping. Tokens
# in `format`: {type} (feat/fix/… — see TYPES below), {key} (lowercase
# ticket key), {slug} (kebab-case ticket title, when known). `types` maps the
# provider's own vocabulary — a Jira issue-type name, or a Linear label name
# — case-insensitively to one of those tokens; anything unmapped, or a lookup
# that fails outright (no CLI installed, not authenticated, offline), lands
# on `default_type`. "default" covers a bare key with no recognizable URL, so
# provider — and therefore the ticket's real type — is unknown.
declare -A jira_types=() linear_types=()
jira_format="$(toml_scalar "$config_file" jira format)"
jira_default_type="$(toml_scalar "$config_file" jira default_type)"
linear_format="$(toml_scalar "$config_file" linear format)"
linear_default_type="$(toml_scalar "$config_file" linear default_type)"
default_format="$(toml_scalar "$config_file" default format)"
default_default_type="$(toml_scalar "$config_file" default default_type)"
: "${jira_format:={type}/{key}-{slug}}"
: "${jira_default_type:=chore}"
: "${linear_format:={type}/{key}-{slug}}"
: "${linear_default_type:=feat}"
: "${default_format:={type}/{key}}"
: "${default_default_type:=chore}"
while IFS='=' read -r k v; do jira_types["$k"]="$v"; done < <(toml_table "$config_file" jira.types)
while IFS='=' read -r k v; do linear_types["$k"]="$v"; done < <(toml_table "$config_file" linear.types)

# ── Ticket / PR / branch parsing ────────────────────────────────────────────
# Jira: .../browse/KEY-123. Linear: .../issue/KEY-123[/slug-words]. GitHub:
# .../pull/123 (PR) or .../tree/branch-name (branch — captures everything
# after `tree/`, since a branch name may itself contain slashes). Anything
# else falls back to the first KEY-123-shaped token anywhere in the input, so
# a bare key (no URL at all) still works. `key`/`slug`/`provider` (and, for
# GitHub, `gh_*`) feed both the live preview and the create path, so what the
# preview promised is literally what gets created; `branch` itself comes from
# compute_branch() for a ticket, or straight from the parsed PR/branch for
# GitHub — see the submit-time split near the end of this script.
key=""
slug=""
provider=""
branch=""
gh_owner=""
gh_repo=""
gh_kind=""      # "pr" | "branch", set only when provider is "github"
gh_number=""    # PR number, "pr" kind only
gh_branch=""    # branch name, "branch" kind only
gh_head_ref=""  # PR's actual head branch, filled in by the background fetch
parse_ticket() {
  local text="$1"
  key=""
  slug=""
  provider=""
  gh_owner=""
  gh_repo=""
  gh_kind=""
  gh_number=""
  gh_branch=""
  if [[ "$text" =~ github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/pull/([0-9]+) ]]; then
    gh_owner="${BASH_REMATCH[1]}"
    gh_repo="${BASH_REMATCH[2]%.git}"
    gh_number="${BASH_REMATCH[3]}"
    provider="github"
    gh_kind="pr"
    key="${gh_owner}/${gh_repo}#${gh_number}"
  elif [[ "$text" =~ github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/tree/(.+)$ ]]; then
    gh_owner="${BASH_REMATCH[1]}"
    gh_repo="${BASH_REMATCH[2]%.git}"
    gh_branch="${BASH_REMATCH[3]}"
    gh_branch="${gh_branch%%\?*}"
    gh_branch="${gh_branch%%#*}"
    gh_branch="${gh_branch%/}"
    provider="github"
    gh_kind="branch"
    key="${gh_owner}/${gh_repo}@${gh_branch}"
  elif [[ "$text" =~ atlassian\.net/browse/([A-Za-z][A-Za-z0-9]*-[0-9]+) ]]; then
    key="${BASH_REMATCH[1]}"
    provider="jira"
  elif [[ "$text" =~ linear\.app/[^/]+/issue/([A-Za-z][A-Za-z0-9]*-[0-9]+)(/([a-z0-9]+(-[a-z0-9]+)*))? ]]; then
    key="${BASH_REMATCH[1]}"
    slug="${BASH_REMATCH[3]:-}"
    provider="linear"
  elif [[ "$text" =~ ([A-Za-z][A-Za-z0-9]*-[0-9]+) ]]; then
    key="${BASH_REMATCH[1]}"
  fi
  [ -n "$key" ] || return 1
  return 0
}

# Kebab-case, capped at 6 words / 40 chars so a long title doesn't produce an
# unwieldy branch name.
slugify() {
  local s="${1,,}" IFS='-'
  s="$(printf '%s' "$s" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  # Splitting on the hyphens set as IFS above is the point: `s` is already
  # sed-normalized to `[a-z0-9]` runs joined by single hyphens, so this
  # can't glob and word-splits exactly into words.
  # shellcheck disable=SC2206
  local -a words=($s)
  s="${words[*]:0:6}"
  s="${s:0:40}"
  s="${s%-}"
  printf '%s' "$s"
}

# Maps a provider's own type/label vocabulary to a Conventional-Commits
# token, case-insensitively, falling back to that provider's default_type.
map_type() {
  local provider="$1" src="${2,,}" k
  case "$provider" in
  jira)
    if [ -n "$src" ]; then
      for k in "${!jira_types[@]}"; do
        [ "${k,,}" = "$src" ] && { printf '%s' "${jira_types[$k]}"; return; }
      done
    fi
    printf '%s' "$jira_default_type"
    ;;
  linear)
    if [ -n "$src" ]; then
      for k in "${!linear_types[@]}"; do
        [ "${k,,}" = "$src" ] && { printf '%s' "${linear_types[$k]}"; return; }
      done
    fi
    printf '%s' "$linear_default_type"
    ;;
  *) printf '%s' "$default_default_type" ;;
  esac
}

# Fills $branch from the current $key/$slug/$provider/$type_value using that
# provider's format template. Empty tokens (no slug yet) leave a stray
# separator behind — the trailing sed pass cleans that up rather than
# threading conditional separators through every possible template shape.
compute_branch() {
  local fmt="$default_format"
  case "$provider" in
  jira) fmt="$jira_format" ;;
  linear) fmt="$linear_format" ;;
  esac
  branch="$fmt"
  branch="${branch//\{type\}/$type_value}"
  branch="${branch//\{key\}/${key,,}}"
  branch="${branch//\{KEY\}/${key^^}}"
  branch="${branch//\{slug\}/$slug}"
  branch="$(printf '%s' "$branch" | sed -E 's#-+$##; s#-+/#/#g; s#/-+#/#g; s#^-+##')"
}

# Background metadata lookup — run only in the child fetch_pid started from
# the main loop, never inline: a network stall must not freeze keystrokes.
# Prints `{"type_source":…,"title":…,"head_ref":…}` on success, nothing on
# any failure (missing CLI, no auth, unknown key/PR, offline) — every caller
# treats empty as "couldn't detect": ticket callers fall back to
# default_type, and the GitHub PR path falls back to a `pr-<number>` local
# branch name instead of the PR's real head branch.
fetch_ticket_meta() {
  local provider="$1" key="$2" gh_kind="$3" gh_owner="$4" gh_repo="$5" gh_number="$6"
  case "$provider" in
  jira)
    command -v acli >/dev/null 2>&1 || return 0
    acli jira workitem view "$key" --fields issuetype,summary --json 2>/dev/null |
      jq -c '{
        type_source: (.fields.issuetype.name // .issuetype.name // .workItem.fields.issuetype.name // empty),
        title: (.fields.summary // .summary // .workItem.fields.summary // empty)
      }' 2>/dev/null
    ;;
  linear)
    command -v lin >/dev/null 2>&1 || return 0
    lin issues get "$key" --json 2>/dev/null |
      jq -c '{
        type_source: (.issue.labels.nodes[0].name // empty),
        title: (.issue.title // empty)
      }' 2>/dev/null
    ;;
  github)
    # Branch kind has nothing worth prefetching — the branch's existence and
    # content are only confirmed by the real `git fetch` at submit time.
    [ "$gh_kind" = "pr" ] || return 0
    command -v gh >/dev/null 2>&1 || return 0
    gh pr view "$gh_number" -R "${gh_owner}/${gh_repo}" --json title,headRefName 2>/dev/null |
      jq -c '{
        title: (.title // empty),
        head_ref: (.headRefName // empty)
      }' 2>/dev/null
    ;;
  esac
}

# Every Conventional Commits type, feat/fix first since they're by far the
# most common — the modal's type chip cycles this list, and a lookup miss in
# either provider's `types` table falls back to `default_type`, not to
# walking this list.
TYPES=(feat fix chore docs style refactor perf test build ci revert)
TYPES_COUNT=${#TYPES[@]}
type_idx=0
type_value="${TYPES[0]}"
type_source=""
type_overridden=0
fetch_pid=""
fetch_key=""
fetch_provider=""
fetch_tmpfile=""

# Pulls a *finished* fetch job's result into type_source/type_value/slug (or,
# for a GitHub PR, gh_head_ref). Caller must already know the job has exited
# (kill -0 failed, or a settle timeout gave up on it) — this only reaps and
# parses.
absorb_fetch_result() {
  local meta fetch_title i
  wait "$fetch_pid" 2>/dev/null
  meta="$(cat "$fetch_tmpfile" 2>/dev/null)"
  rm -f "$fetch_tmpfile"
  if [ "$fetch_key" = "$key" ]; then
    fetch_title="$(printf '%s' "$meta" | jq -r '.title // empty' 2>/dev/null)"
    if [ "$fetch_provider" = "github" ]; then
      gh_head_ref="$(printf '%s' "$meta" | jq -r '.head_ref // empty' 2>/dev/null)"
    else
      type_source="$(printf '%s' "$meta" | jq -r '.type_source // empty' 2>/dev/null)"
      if [ "$type_overridden" -eq 0 ]; then
        type_value="$(map_type "$fetch_provider" "$type_source")"
        for i in "${!TYPES[@]}"; do [ "${TYPES[$i]}" = "$type_value" ] && type_idx=$i; done
      fi
      [ -n "$fetch_title" ] && slug="$(slugify "$fetch_title")"
    fi
  fi
  fetch_pid=""
}

# Give a still-in-flight fetch a brief window to land before Enter finalizes
# the branch — a fast paste-then-Enter can otherwise race the network call
# and submit with the un-refined default type. Never blocks indefinitely:
# past this budget (2s), submission proceeds with whatever type is current.
settle_fetch() {
  local waited=0
  while [ -n "$fetch_pid" ] && kill -0 "$fetch_pid" 2>/dev/null && [ "$waited" -lt 20 ]; do
    sleep 0.1
    waited=$((waited + 1))
  done
  if [ -n "$fetch_pid" ] && ! kill -0 "$fetch_pid" 2>/dev/null; then
    absorb_fetch_result
  fi
}

# ── Form ─────────────────────────────────────────────────────────────────────
# Steel blue rather than the Charm-pink default this started with: the popup
# sits on top of ordinary panes, and blue reads as chrome next to the green
# the branch preview needs for "this is what you'll get".
DIM=$'\033[38;5;240m'
TEXT=$'\033[38;5;252m'
ACCENT=$'\033[38;5;110m'
OK=$'\033[38;5;114m'
OFF=$'\033[0m'
BTN_ON=$'\033[48;5;110m\033[38;5;235m\033[1m'
BTN_OFF=$'\033[38;5;245m'

FIELD_W=66 # inner width of the input box; box + 2-space indent fits width 72

# The box rule is fixed-width, so build it once rather than shelling out to
# seq on every keystroke.
printf -v RULE '─%.0s' $(seq 1 $((FIELD_W + 2)))

# Geometry of the frame draw() prints, in lines: the whole form, and which of
# those lines carries the input box. Only the distance between them matters —
# see the cursor placement at the end of draw().
FORM_ROWS=11
FIELD_ROW=4

value=""    # what the user has typed
cur=0       # cursor offset within $value
scroll=0    # first visible character, for values wider than the field
field=0     # 0 = input, 1 = type, 2 = Create, 3 = Cancel

# Raw mode: one keypress at a time, nothing echoed, and the terminal restored
# however this exits — including the die() paths below, which print to a
# terminal that would otherwise still be raw and cursor-less.
saved_stty="$(stty -g 2>/dev/null)"
restore_tty() {
  [ -n "$saved_stty" ] && stty "$saved_stty" 2>/dev/null
  printf '\033[?25h'
}
trap restore_tty EXIT
stty raw -echo 2>/dev/null

draw() {
  local visible cursor_col create_style cancel_style preview box type_box type_note type_label type_display

  # Keep the cursor inside the window even when the value is longer than the
  # field — scroll by whole characters as it walks off either edge.
  ((cur < scroll)) && scroll=$cur
  ((cur > scroll + FIELD_W - 1)) && scroll=$((cur - FIELD_W + 1))
  visible="${value:scroll:FIELD_W}"
  cursor_col=$((5 + cur - scroll))

  if parse_ticket "$value"; then
    if [ "$provider" = "github" ]; then
      case "$gh_kind" in
      pr) preview="${OK}${gh_head_ref:-pr-${gh_number}}${OFF} ${DIM}(PR #${gh_number} · ${gh_owner}/${gh_repo})${OFF}" ;;
      branch) preview="${OK}${gh_branch}${OFF} ${DIM}(${gh_owner}/${gh_repo})${OFF}" ;;
      esac
    else
      compute_branch
      preview="${OK}${branch}${OFF}"
    fi
  elif [ -z "$value" ]; then
    preview="${DIM}waiting for a ticket key or a GitHub PR/branch URL…${OFF}"
  else
    preview="${DIM}no ticket key or GitHub PR/branch URL in that yet${OFF}"
  fi

  create_style="$BTN_OFF"
  cancel_style="$BTN_OFF"
  [ "$field" -eq 2 ] && create_style="$BTN_ON"
  [ "$field" -eq 3 ] && cancel_style="$BTN_ON"
  box="$DIM"
  [ "$field" -eq 0 ] && box="$ACCENT"
  type_box="$DIM"
  [ "$field" -eq 1 ] && type_box="$ACCENT"

  # The chip is a Conventional-Commits type for a ticket (cyclable with
  # ←/→) or a read-only PR/branch indicator for GitHub — there's no "type"
  # to pick when the worktree just checks out a ref that already exists.
  if [ "$provider" = "github" ]; then
    type_label="kind"
    type_display="${gh_kind:-github}"
    type_note="${DIM}github — checks out the existing ref${OFF}"
  else
    type_label="type"
    type_display="$type_value"
    # What's driving the shown type: an in-flight lookup, an explicit
    # override, a completed lookup, or (no ticket recognized/lookup failed)
    # the provider's configured default.
    if [ -n "$fetch_pid" ] && [ "$fetch_key" = "$key" ]; then
      type_note="${DIM}detecting…${OFF}"
    elif [ "$type_overridden" -eq 1 ]; then
      type_note="${DIM}manual${OFF}"
    elif [ -n "$type_source" ]; then
      type_note="${DIM}from ${type_source}${OFF}"
    else
      type_note="${DIM}default${OFF}"
    fi
  fi

  printf '\033[H\033[2J\033[?25l'
  printf '  %sPaste a Jira/Linear URL, a GitHub PR/branch URL, or a bare key.%s\r\n' "$DIM" "$OFF"
  printf '\r\n'
  printf '  %s╭%s╮%s\r\n' "$box" "$RULE" "$OFF"
  printf '  %s│%s %s%-*s%s %s│%s\r\n' "$box" "$OFF" "$TEXT" "$FIELD_W" "$visible" "$OFF" "$box" "$OFF"
  printf '  %s╰%s╯%s\r\n' "$box" "$RULE" "$OFF"
  printf '  %sbranch%s  %b\r\n' "$DIM" "$OFF" "$preview"
  printf '  %s%-4s%s    %s‹ %s%-8s%s %s›%s  %b\r\n' "$DIM" "$type_label" "$OFF" "$type_box" "$TEXT" "$type_display" "$OFF" "$type_box" "$OFF" "$type_note"
  printf '\r\n'
  printf '   %s  Create worktree  %s   %s  Cancel  %s\r\n' "$create_style" "$OFF" "$cancel_style" "$OFF"
  printf '\r\n'
  printf '  %stab move · ‹›/type cycles · ↵ confirm · esc cancel%s' "$DIM" "$OFF"

  # Only show a cursor while the text field owns focus; on a button or the
  # type chip there is nothing to point at and a stray block cursor reads as
  # a rendering bug.
  #
  # Placed by walking UP from the last line drawn, never by absolute row: a
  # pane one row shorter than this frame scrolls the whole thing up by one,
  # and an absolute \033[row;colH would then point a line below the field.
  if [ "$field" -eq 0 ]; then
    printf '\033[%dA\033[%dG\033[?25h' "$((FORM_ROWS - FIELD_ROW))" "$cursor_col"
  fi
}

# Returns one logical key in $keyname: a literal character, or a name for the
# control keys. Escape sequences arrive as several bytes with no delimiter, so
# a bare ESC is distinguished from an arrow key by nothing following it within
# the read timeout.
keyname=""
read_key() {
  local c c2 c3 seq=""
  IFS= read -rsn1 c || return 1
  case "$c" in
  $'\e')
    if IFS= read -rsn1 -t 0.05 c2 2>/dev/null && { [ "$c2" = "[" ] || [ "$c2" = "O" ]; }; then
      while IFS= read -rsn1 -t 0.05 c3 2>/dev/null; do
        seq+="$c3"
        [[ "$c3" == [A-Za-z~] ]] && break
      done
      case "$seq" in
      A) keyname="up" ;;
      B) keyname="down" ;;
      C) keyname="right" ;;
      D) keyname="left" ;;
      H | 1~ | 7~) keyname="home" ;;
      F | 4~ | 8~) keyname="end" ;;
      3~) keyname="delete" ;;
      Z) keyname="shift-tab" ;;
      *) keyname="ignore" ;; # bracketed-paste markers and anything unmapped
      esac
    else
      keyname="esc"
    fi
    ;;
  "" | $'\r' | $'\n') keyname="enter" ;;
  $'\t') keyname="tab" ;;
  $'\x7f' | $'\b') keyname="backspace" ;;
  $'\x01') keyname="home" ;;
  $'\x05') keyname="end" ;;
  $'\x15') keyname="clear" ;;
  $'\x17') keyname="word-back" ;;
  $'\x03' | $'\x04') keyname="esc" ;;
  *)
    if [[ "$c" == [[:print:]] ]]; then
      keyname="$c"
    else
      keyname="ignore"
    fi
    ;;
  esac
}

submitted=""
while :; do
  # Refresh key/slug/provider from the current value *before* drawing, so
  # the poll/kickoff blocks below can settle type_value in time for this
  # frame's draw() — draw() re-parses internally too, but only for its own
  # branch/preview text; it never touches type_value itself.
  parse_ticket "$value" >/dev/null 2>&1

  # Poll a background metadata fetch that finished since the last frame, and
  # let it (re)populate the auto-detected type/slug — unless the user has
  # already overridden the type, in which case their choice stands.
  if [ -n "$fetch_pid" ] && ! kill -0 "$fetch_pid" 2>/dev/null; then
    absorb_fetch_result
  fi

  # On every distinct, fully-parsed key — including a bare key with no
  # provider to ask — apply that provider's configured default_type right
  # away, so the chip never sits on a stale type from a previous ticket.
  # Then, if a provider is known, kick off a background fetch to refine it
  # to the ticket's real type once that lands. Never inline/blocking — a
  # network stall would otherwise freeze every keystroke — and a key edited
  # again before the old fetch lands drops that stale in-flight lookup
  # rather than racing it.
  if [ -n "$key" ] && [ "$key" != "$fetch_key" ]; then
    if [ -n "$fetch_pid" ]; then
      kill "$fetch_pid" 2>/dev/null
      wait "$fetch_pid" 2>/dev/null
      rm -f "$fetch_tmpfile"
    fi
    type_source=""
    type_overridden=0
    gh_head_ref=""
    fetch_key="$key"
    fetch_provider="$provider"
    fetch_pid=""
    if [ "$provider" = "github" ]; then
      type_value=""
    else
      type_value="$(map_type "$provider" "")"
      for i in "${!TYPES[@]}"; do [ "${TYPES[$i]}" = "$type_value" ] && type_idx=$i; done
    fi
    if [ -n "$provider" ]; then
      fetch_tmpfile="$(mktemp)"
      fetch_ticket_meta "$provider" "$key" "$gh_kind" "$gh_owner" "$gh_repo" "$gh_number" >"$fetch_tmpfile" 2>/dev/null &
      fetch_pid=$!
    fi
  fi

  draw

  read_key || break
  case "$keyname" in
  esc) break ;;
  tab | down) field=$(((field + 1) % 4)) ;;
  shift-tab | up) field=$(((field + 3) % 4)) ;;
  enter)
    if [ "$field" -eq 3 ]; then
      break
    elif parse_ticket "$value"; then
      # A fast paste-then-Enter can otherwise beat the network lookup —
      # give it a brief, bounded window to land so the branch this creates
      # uses the real detected type, not the still-unrefined default.
      settle_fetch
      submitted="$value"
      break
    else
      # Invalid input on Create is a no-op: the preview line already says why,
      # so bouncing focus or flashing an error would be redundant noise.
      field=0
    fi
    ;;
  left)
    case "$field" in
    0) ((cur > 0)) && cur=$((cur - 1)) ;;
    1)
      if [ "$provider" != "github" ]; then
        type_idx=$(((type_idx + TYPES_COUNT - 1) % TYPES_COUNT))
        type_value="${TYPES[type_idx]}"
        type_overridden=1
      fi
      ;;
    2) field=1 ;;
    3) field=2 ;;
    esac
    ;;
  right)
    case "$field" in
    0) ((cur < ${#value})) && cur=$((cur + 1)) ;;
    1)
      if [ "$provider" != "github" ]; then
        type_idx=$(((type_idx + 1) % TYPES_COUNT))
        type_value="${TYPES[type_idx]}"
        type_overridden=1
      fi
      ;;
    2) field=3 ;;
    3) field=2 ;;
    esac
    ;;
  home) [ "$field" -eq 0 ] && cur=0 ;;
  end) [ "$field" -eq 0 ] && cur=${#value} ;;
  backspace)
    if [ "$field" -eq 0 ] && ((cur > 0)); then
      value="${value:0:cur-1}${value:cur}"
      cur=$((cur - 1))
    fi
    ;;
  delete)
    if [ "$field" -eq 0 ] && ((cur < ${#value})); then
      value="${value:0:cur}${value:cur+1}"
    fi
    ;;
  clear)
    if [ "$field" -eq 0 ]; then
      value=""
      cur=0
      scroll=0
    fi
    ;;
  word-back)
    if [ "$field" -eq 0 ] && ((cur > 0)); then
      local_head="${value:0:cur}"
      local_head="${local_head%"${local_head##*[![:space:]]}"}"
      local_head="${local_head%[^[:space:]]*}"
      value="${local_head}${value:cur}"
      cur=${#local_head}
    fi
    ;;
  ignore) ;;
  *)
    # Any printable character, including every byte of a pasted URL: typing
    # into a button jumps back to the field rather than being swallowed.
    field=0
    value="${value:0:cur}${keyname}${value:cur}"
    cur=$((cur + 1))
    ;;
  esac
done

# Drop any fetch still running when the user submits/cancels quickly — its
# tmpfile would otherwise leak, and nothing reads its result once the raw
# terminal session below is torn down.
[ -n "$fetch_pid" ] && kill "$fetch_pid" 2>/dev/null
[ -n "$fetch_tmpfile" ] && rm -f "$fetch_tmpfile"

restore_tty
trap - EXIT
printf '\033[H\033[2J'

[ -n "$submitted" ] || exit 0

input="$submitted"

if [ "$provider" = "github" ]; then
  # ── GitHub PR / branch checkout ──────────────────────────────────────────
  # Both kinds check out a ref that already exists rather than naming a new
  # one from a template, so none of the branch-naming config above applies.
  # `herdr worktree create --branch NAME` only checks NAME out as-is when it
  # already names a LOCAL branch — otherwise it creates a fresh one from
  # --base/HEAD — and a plain `git fetch` only updates the origin/* remote-
  # tracking ref, so a fetch refspec that writes straight to refs/heads/NAME
  # is what actually materializes the local branch herdr's DWIM depends on.
  # The leading `+` forces the update even when the remote ref moved
  # non-fast-forward (a rebased PR, a force-pushed branch); git still
  # refuses outright if NAME is checked out in some other worktree already.
  origin_url="$(git -C "$origin_cwd" remote get-url origin 2>/dev/null)"
  [ -n "$origin_url" ] || die "Couldn't resolve this repo's 'origin' remote — is it a GitHub checkout?"
  origin_slug="$(printf '%s' "$origin_url" | sed -E 's#^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)##; s#\.git$##')"
  [ "${origin_slug,,}" = "${gh_owner,,}/${gh_repo,,}" ] ||
    die "This launcher only works within its own repo; pasted URL points to '${gh_owner}/${gh_repo}', not '${origin_slug}'."

  case "$gh_kind" in
  pr)
    local_branch="${gh_head_ref:-pr-${gh_number}}"
    fetch_resp="$(git -C "$origin_cwd" fetch origin "+pull/${gh_number}/head:refs/heads/${local_branch}" 2>&1)" ||
      die "Couldn't fetch PR #${gh_number}: $fetch_resp"
    label="PR #${gh_number}"
    name_base="pr-${gh_number}"
    prompt_msg="Review PR #${gh_number} — ${input}"
    ;;
  branch)
    local_branch="$gh_branch"
    fetch_resp="$(git -C "$origin_cwd" fetch origin "+${gh_branch}:refs/heads/${gh_branch}" 2>&1)" ||
      die "Couldn't fetch branch '${gh_branch}': $fetch_resp"
    label="$gh_branch"
    name_base="$(printf '%s' "$gh_branch" | tr '[:upper:]' '[:lower:]' | sed -E 's#[^a-z0-9]+#-#g; s#^-+##; s#-+$##')"
    [[ "$name_base" =~ ^[a-z] ]] || name_base="b-${name_base}"
    name_base="${name_base:0:32}"
    name_base="${name_base%-}"
    prompt_msg="Continue work on branch ${gh_branch} — ${input}"
    ;;
  esac
  branch="$local_branch"
else
  # key/slug/provider/type_value are already correct here — the loop only
  # ever sets `submitted` right after a successful parse_ticket, refined by
  # any completed/settled background fetch. Re-parsing `input` now would
  # reset slug/provider to what the bare URL alone implies, throwing away a
  # live-fetched title-derived slug that beats it. Just assert the invariant.
  [ -n "$key" ] || die "Couldn't find a ticket key (e.g. ENG-123) in '$input'."
  compute_branch
  key_upper="${key^^}"
  key_lower="${key,,}"
  # A bare key has no URL to hand the agent — only pass through what the
  # user actually typed as a link.
  case "$input" in
  http://* | https://*) ticket_ref="$input" ;;
  *) ticket_ref="$key_upper" ;;
  esac
  label="$key_upper"
  name_base="$key_lower"
  prompt_msg="Work on ${key_upper} — ${ticket_ref}"
fi

# Group the new worktree under the repo's MAIN checkout workspace, not
# whatever workspace happens to be active. `worktree create --cwd` alone
# groups with the active workspace, which is wrong when prefix+t is pressed
# from a pane in some other repo's tab, or from a linked worktree of this
# same repo. `worktree list --cwd` walks real `git worktree` state (not just
# open Herdr workspaces), so the main checkout is found even if it isn't
# tagged with `.worktree` metadata in `workspace list` — that field is only
# populated for workspaces herdr itself opened via the worktree flow.
worktree_list_resp="$("$herdr_bin" worktree list --cwd "$origin_cwd" 2>/dev/null)"
main_workspace_id="$(printf '%s' "$worktree_list_resp" | jq -r '
  [.result.worktrees[] | select(.is_linked_worktree == false)][0].open_workspace_id // empty
' 2>/dev/null)"

if [ -n "$main_workspace_id" ]; then
  create_resp="$("$herdr_bin" worktree create --workspace "$main_workspace_id" --branch "$branch" --label "$label" "$focus_flag" 2>&1)"
else
  # Main checkout isn't open as a Herdr workspace right now — fall back to
  # the origin pane's own cwd, same as before this fix.
  create_resp="$("$herdr_bin" worktree create --cwd "$origin_cwd" --branch "$branch" --label "$label" "$focus_flag" 2>&1)"
fi
pane_id="$(printf '%s' "$create_resp" | jq -r '.result.root_pane.pane_id // empty' 2>/dev/null)"
[ -n "$pane_id" ] || die "worktree create failed: $create_resp"

# Agent names must be unique and match [a-z][a-z0-9_-]{0,31}; name_base is
# already built to satisfy the pattern, so only a name collision needs
# handling — e.g. a second worktree for the same ticket/PR/branch while the
# first is still live.
existing_names="$("$herdr_bin" agent list 2>/dev/null | jq -r '.result.agents[].name // empty' 2>/dev/null)"
name="$name_base"
suffix=2
while printf '%s\n' "$existing_names" | grep -qx "$name"; do
  name="${name_base}-${suffix}"
  suffix=$((suffix + 1))
done

start_resp="$("$herdr_bin" agent start "$name" --kind omp --pane "$pane_id" 2>&1)"
printf '%s' "$start_resp" | jq -e '.result' >/dev/null 2>&1 ||
  die "Created ${branch} but agent start failed: $start_resp"

# The whole point: land the ticket/PR/branch context in the agent's input
# without sending it.
"$herdr_bin" pane send-text "$pane_id" "$prompt_msg" >/dev/null 2>&1 ||
  die "Created ${branch} and started ${name}, but couldn't queue the prompt."

[ "$focus" = "true" ] && "$herdr_bin" agent focus "$name" >/dev/null 2>&1

printf '\nCreated %s and queued %s for agent "%s" (unsubmitted).\n' "$branch" "$label" "$name"
sleep 1
