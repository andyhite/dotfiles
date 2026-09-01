#!/usr/bin/env bash
# ticket-worktree modal — herdr-plugin.toml's "modal" pane entrypoint.
#
# Bound to prefix+t in ../../config.toml as a `herdr plugin pane open`
# popup, invoked directly rather than through `plugin action invoke`: reading
# a ticket URL needs a real TTY, and a plugin ACTION runs on the server with
# none — the same constraint ../../palette/palette.sh documents for fzf.
# Declaring this as a manifest `[[panes]]` entry with `placement = "popup"`
# gets the TTY for free; opening it is what makes it session-modal.
#
# Flow: one form — a text field, a live branch preview, and Create / Cancel
# buttons on a single screen — then parse a ticket key (and, for Linear, a
# slug) out of the input -> `herdr worktree create` with a branch name derived
# from that key -> `herdr agent start` an omp agent in the new worktree's root
# pane -> `herdr pane send-text` the ticket back into that agent's input
# WITHOUT submitting it, so the first prompt is queued but the user decides
# when — or whether — to send it.
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

# ── Ticket parsing ───────────────────────────────────────────────────────────
# Jira: .../browse/KEY-123. Linear: .../issue/KEY-123[/slug-words]. Anything
# else falls back to the first KEY-123-shaped token anywhere in the input, so
# a bare key (no URL at all) still works. Sets the three globals the form's
# live preview and the create path both read, so what the preview promised is
# literally what gets created.
key=""
slug=""
branch=""
parse_ticket() {
  local text="$1"
  key=""
  slug=""
  branch=""
  if [[ "$text" =~ atlassian\.net/browse/([A-Za-z][A-Za-z0-9]*-[0-9]+) ]]; then
    key="${BASH_REMATCH[1]}"
  elif [[ "$text" =~ linear\.app/[^/]+/issue/([A-Za-z][A-Za-z0-9]*-[0-9]+)(/([a-z0-9]+(-[a-z0-9]+)*))? ]]; then
    key="${BASH_REMATCH[1]}"
    slug="${BASH_REMATCH[3]:-}"
  elif [[ "$text" =~ ([A-Za-z][A-Za-z0-9]*-[0-9]+) ]]; then
    key="${BASH_REMATCH[1]}"
  fi
  [ -n "$key" ] || return 1
  # Consistent format: ticket/<key>, or ticket/<key>-<slug> when Linear's URL
  # handed us readable slug words for free.
  branch="ticket/${key,,}"
  [ -n "$slug" ] && branch="${branch}-${slug}"
  return 0
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
FORM_ROWS=10
FIELD_ROW=4

value=""    # what the user has typed
cur=0       # cursor offset within $value
scroll=0    # first visible character, for values wider than the field
field=0     # 0 = input, 1 = Create, 2 = Cancel

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
  local visible cursor_col create_style cancel_style preview box

  # Keep the cursor inside the window even when the value is longer than the
  # field — scroll by whole characters as it walks off either edge.
  ((cur < scroll)) && scroll=$cur
  ((cur > scroll + FIELD_W - 1)) && scroll=$((cur - FIELD_W + 1))
  visible="${value:scroll:FIELD_W}"
  cursor_col=$((5 + cur - scroll))

  if parse_ticket "$value"; then
    preview="${OK}${branch}${OFF}"
  elif [ -z "$value" ]; then
    preview="${DIM}waiting for a ticket key…${OFF}"
  else
    preview="${DIM}no ENG-123-shaped key in that yet${OFF}"
  fi

  create_style="$BTN_OFF"
  cancel_style="$BTN_OFF"
  [ "$field" -eq 1 ] && create_style="$BTN_ON"
  [ "$field" -eq 2 ] && cancel_style="$BTN_ON"
  box="$DIM"
  [ "$field" -eq 0 ] && box="$ACCENT"

  printf '\033[H\033[2J\033[?25l'
  printf '  %sPaste a Jira or Linear URL, or type a bare key like ENG-123.%s\r\n' "$DIM" "$OFF"
  printf '\r\n'
  printf '  %s╭%s╮%s\r\n' "$box" "$RULE" "$OFF"
  printf '  %s│%s %s%-*s%s %s│%s\r\n' "$box" "$OFF" "$TEXT" "$FIELD_W" "$visible" "$OFF" "$box" "$OFF"
  printf '  %s╰%s╯%s\r\n' "$box" "$RULE" "$OFF"
  printf '  %sbranch%s  %b\r\n' "$DIM" "$OFF" "$preview"
  printf '\r\n'
  printf '   %s  Create worktree  %s   %s  Cancel  %s\r\n' "$create_style" "$OFF" "$cancel_style" "$OFF"
  printf '\r\n'
  printf '  %stab move · ↵ confirm · esc cancel%s' "$DIM" "$OFF"

  # Only show a cursor while the text field owns focus; on a button there is
  # nothing to point at and a stray block cursor reads as a rendering bug.
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
  draw
  read_key || break
  case "$keyname" in
  esc) break ;;
  tab | down) field=$(((field + 1) % 3)) ;;
  shift-tab | up) field=$(((field + 2) % 3)) ;;
  enter)
    if [ "$field" -eq 2 ]; then
      break
    elif parse_ticket "$value"; then
      submitted="$value"
      break
    else
      # Invalid input on Create is a no-op: the preview line already says why,
      # so bouncing focus or flashing an error would be redundant noise.
      field=0
    fi
    ;;
  left)
    if [ "$field" -eq 0 ]; then
      ((cur > 0)) && cur=$((cur - 1))
    else
      field=$((field == 1 ? 0 : 1))
    fi
    ;;
  right)
    if [ "$field" -eq 0 ]; then
      ((cur < ${#value})) && cur=$((cur + 1))
    else
      field=$((field == 1 ? 2 : 1))
    fi
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

restore_tty
trap - EXIT
printf '\033[H\033[2J'

[ -n "$submitted" ] || exit 0

input="$submitted"
parse_ticket "$input" || die "Couldn't find a ticket key (e.g. ENG-123) in '$input'."
key_upper="${key^^}"
key_lower="${key,,}"

# A bare key has no URL to hand the agent — only pass through what the user
# actually typed as a link.
case "$input" in
http://* | https://*) ticket_ref="$input" ;;
*) ticket_ref="$key_upper" ;;
esac

create_resp="$("$herdr_bin" worktree create --cwd "$origin_cwd" --branch "$branch" --label "$key_upper" "$focus_flag" 2>&1)"
pane_id="$(printf '%s' "$create_resp" | jq -r '.result.root_pane.pane_id // empty' 2>/dev/null)"
[ -n "$pane_id" ] || die "worktree create failed: $create_resp"

# Agent names must be unique and match [a-z][a-z0-9_-]{0,31}; key_lower
# already satisfies the pattern, so only a name collision needs handling —
# e.g. a second worktree for the same ticket while the first is still live.
existing_names="$("$herdr_bin" agent list 2>/dev/null | jq -r '.result.agents[].name // empty' 2>/dev/null)"
name="$key_lower"
suffix=2
while printf '%s\n' "$existing_names" | grep -qx "$name"; do
  name="${key_lower}-${suffix}"
  suffix=$((suffix + 1))
done

start_resp="$("$herdr_bin" agent start "$name" --kind omp --pane "$pane_id" 2>&1)"
printf '%s' "$start_resp" | jq -e '.result' >/dev/null 2>&1 ||
  die "Created ${branch} but agent start failed: $start_resp"

# The whole point: land the ticket in the agent's input without sending it.
"$herdr_bin" pane send-text "$pane_id" "Work on ${key_upper} — ${ticket_ref}" >/dev/null 2>&1 ||
  die "Created ${branch} and started ${name}, but couldn't queue the prompt."

[ "$focus" = "true" ] && "$herdr_bin" agent focus "$name" >/dev/null 2>&1

printf '\nCreated %s and queued %s for agent "%s" (unsubmitted).\n' "$branch" "$key_upper" "$name"
sleep 1
