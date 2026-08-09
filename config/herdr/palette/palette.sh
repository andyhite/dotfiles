#!/usr/bin/env bash
# herdr command palette: fzf over every action of every installed plugin,
# enumerated at run time from `herdr plugin action list`.
#
# Bound to prefix+p in ../config.toml as a `type = "popup"` command — a
# session-modal terminal that leaves the tab layout alone. That popup is the
# reason this is a plain script rather than a herdr plugin. A plugin ACTION
# runs on the server with NO TTY and so cannot host fzf; upstream worked around
# that by having the action open an `overlay` plugin pane, and herdr's overlay
# placement covers the whole canvas. A keybinding popup gets a TTY directly, so
# the bounce through the plugin disappears along with the full-screen overlay.
#
# What was lost with the plugin, and why it doesn't matter: upstream's action
# forwarded the origin workspace's cwd to the overlay with `--cwd`, because the
# overlay is a real pane and becomes the focused one, which is what the server
# resolves action context from. A popup is not a pane and never takes focus, so
# context still resolves against the pane you triggered it from — the problem
# the workaround existed for cannot arise here.
#
# Derived from JanTvrdik/herdr-command-palette (MIT; see LICENSE beside this
# file), which is still the upstream for everything below except the popup
# hosting above and the row format in `rows`.
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

# Brief pause + message helper so failures don't vanish when the popup closes.
die() {
  printf '%s\n' "$*" >&2
  printf 'Press any key to close…' >&2
  read -r -n1 _ 2>/dev/null || sleep 2
  exit 1
}

command -v fzf >/dev/null 2>&1 || die "command-palette: fzf is not installed or not on PATH."
command -v jq  >/dev/null 2>&1 || die "command-palette: jq is not installed or not on PATH."

# Each line is "<plugin_id>.<action_id>\t<title><pad>  <plugin_id>": field 1 is
# the id we invoke, field 2 is the only thing fzf shows.
#
# Upstream displayed "<plugin_id>.<action_id> <title>", which puts up to 42
# characters of id in front of the words you actually read, and leaves the
# titles in a ragged column that starts at a different place on every row.
# Title first, plugin id trailing in a fixed column and dimmed, no action id —
# the title already says what the action id says.
#
# The plugin id has to stay VISIBLE to stay searchable. fzf matches against the
# transformed line, not the original (man fzf, --nth: "fzf doesn't allow
# searching against the hidden fields"), so field 1 is invoke-only and typing
# "mirror" can only filter if "mirror" is on screen.
#
# The pad is `// ""` because jq's string repetition returns null, not "", when
# the count is zero — which is exactly the widest title on the list.
rows="$(
  "$herdr_bin" plugin action list 2>/dev/null \
    | jq -r '
        [ .result.actions[] ] as $actions
        | ($actions | map(.title | length) | max) as $width
        | $actions[]
        | [
            (.plugin_id + "." + .action_id),
            (
              .title
              + ((" " * ($width - (.title | length))) // "")
              + "  \u001b[2m" + .plugin_id + "\u001b[22m"
            )
          ]
        | @tsv
      ' 2>/dev/null \
    | sort -t$'\t' -k2,2
)"

[ -n "$rows" ] || die "command-palette: no plugin actions available."

# --no-sort keeps the title ordering from `sort` above; --ansi is what makes the
# dim on the trailing plugin id render instead of printing as an escape.
# Esc/Ctrl-C abort → empty selection → silent close.
choice="$(
  printf '%s\n' "$rows" \
    | fzf --delimiter=$'\t' \
          --with-nth=2 \
          --ansi \
          --prompt='herdr action ▸ ' \
          --header='↑↓ select · enter run · esc cancel' \
          --reverse \
          --cycle \
          --no-multi \
          --no-sort
)" || true

[ -n "$choice" ] || exit 0

action_id="${choice%%$'\t'*}"

# Invoke the action. `herdr plugin action invoke` is fire-and-forget: it returns
# as soon as the action is DISPATCHED, so a zero exit only means "accepted" — the
# action's command can still fail afterwards (e.g. a moved/missing script exits
# 127). The response carries the dispatched run's log_id; we poll the plugin log
# until it reaches a terminal state so a failed action surfaces its error instead
# of the popup vanishing on a silent no-op.
resp="$("$herdr_bin" plugin action invoke "$action_id" 2>&1)"
if [ $? -ne 0 ]; then
  die "command-palette: failed to invoke ${action_id}
${resp}"
fi

# Pull the run's log_id and owning plugin straight from the invoke response (the
# plugin_id is taken from the response rather than split off the action_id, which
# can itself contain dots, e.g. dave.token-dashboard). If the response isn't the
# shape we expect (older herdr), skip polling and exit cleanly — never make a
# working invoke look broken.
log_id="$(printf '%s' "$resp" | jq -r '.result.log.log_id // empty' 2>/dev/null)"
plugin_id="$(printf '%s' "$resp" | jq -r '.result.log.plugin_id // empty' 2>/dev/null)"
[ -n "$log_id" ] && [ -n "$plugin_id" ] || exit 0

# Poll that run's log entry until it finishes (or we hit the deadline). Most
# actions complete in well under a second; one still "running" at the deadline is
# assumed to be a healthy long-running action and left alone.
i=0
while [ "$i" -lt 25 ]; do  # ~5s at 0.2s/iteration
  i=$((i + 1))
  entry="$(
    "$herdr_bin" plugin log list --plugin "$plugin_id" --limit 20 2>/dev/null \
      | jq -c --arg id "$log_id" '.result.logs[]? | select(.log_id == $id)' 2>/dev/null
  )"
  case "$(printf '%s' "$entry" | jq -r '.status // empty' 2>/dev/null)" in
    succeeded) exit 0 ;;
    failed)
      code="$(printf '%s' "$entry" | jq -r '.exit_code // "?"' 2>/dev/null)"
      err="$(printf '%s' "$entry" | jq -r '.stderr // empty' 2>/dev/null)"
      die "command-palette: ${action_id} failed (exit ${code})
${err}"
      ;;
  esac
  sleep 0.2
done
