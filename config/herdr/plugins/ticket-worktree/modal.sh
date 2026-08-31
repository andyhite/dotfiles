#!/usr/bin/env bash
# ticket-worktree modal — herdr-plugin.toml's "modal" pane entrypoint.
#
# Bound to prefix+alt+g in ../../config.toml as a `herdr plugin pane open`
# popup, invoked directly rather than through `plugin action invoke`: reading
# a ticket URL needs a real TTY, and a plugin ACTION runs on the server with
# none — the same constraint ../../palette/palette.sh documents for fzf.
# Declaring this as a manifest `[[panes]]` entry with `placement = "popup"`
# gets the TTY for free; opening it is what makes it session-modal.
#
# Flow: prompt for a Jira/Linear ticket URL -> parse a ticket key (and, for
# Linear, a slug) out of it -> `herdr worktree create` with a branch name
# derived from that key -> `herdr agent start` an omp agent in the new
# worktree's root pane -> `herdr pane send-text` the ticket back into that
# agent's input WITHOUT submitting it, so the first prompt is queued but the
# user decides when — or whether — to send it.
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
# whichever pane had focus when prefix+alt+g was pressed.
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

printf 'Jira/Linear ticket URL (or bare key, e.g. ENG-123): '
IFS= read -r input
input="$(printf '%s' "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ -n "$input" ] || exit 0 # empty input cancels quietly, same as an fzf esc

# Jira: .../browse/KEY-123. Linear: .../issue/KEY-123[/slug-words]. Anything
# else falls back to the first KEY-123-shaped token anywhere in the input, so
# a bare key (no URL at all) still works.
key=""
slug=""
if [[ "$input" =~ atlassian\.net/browse/([A-Za-z][A-Za-z0-9]*-[0-9]+) ]]; then
  key="${BASH_REMATCH[1]}"
elif [[ "$input" =~ linear\.app/[^/]+/issue/([A-Za-z][A-Za-z0-9]*-[0-9]+)(/([a-z0-9]+(-[a-z0-9]+)*))? ]]; then
  key="${BASH_REMATCH[1]}"
  slug="${BASH_REMATCH[3]:-}"
elif [[ "$input" =~ ([A-Za-z][A-Za-z0-9]*-[0-9]+) ]]; then
  key="${BASH_REMATCH[1]}"
fi
[ -n "$key" ] || die "Couldn't find a ticket key (e.g. ENG-123) in '$input'."

key_upper="${key^^}"
key_lower="${key,,}"

# Consistent format: ticket/<key>, or ticket/<key>-<slug> when Linear's URL
# handed us readable slug words for free.
branch="ticket/${key_lower}"
[ -n "$slug" ] && branch="${branch}-${slug}"

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
