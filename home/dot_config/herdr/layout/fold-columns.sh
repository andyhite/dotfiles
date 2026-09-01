#!/usr/bin/env bash
# Fold a row of side-by-side herdr panes into half as many two-row columns:
# six panes across become three columns of two, pairing left to right. Bound to
# prefix+f in ../config.toml. The point is reclaiming width — past three or four
# agents side by side every pane is too narrow to read, while the vertical space
# below each one sits unused.
#
# This wraps no herdr feature. herdr has no restack, rebalance or layout command
# of any kind, so the fold has to be spelled out as a sequence of pane moves.
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

# A `type = "shell"` keybinding runs with no TTY and nowhere to print, so a
# failure would otherwise be indistinguishable from a key that isn't bound.
# herdr's own notification surface is the only thing the user will actually see.
fail() {
  "$herdr_bin" notification show "Fold columns failed" --body "$1" >/dev/null 2>&1
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is not on PATH"

# $HERDR_PANE_ID is injected into a pane's own shell, so it's set when this runs
# by hand from a pane. The keybinding runs it from the herdr server instead,
# where it is absent and an omitted --pane resolves to the UI-focused pane — the
# tab the user is looking at, which is the one they meant. Handling both keeps
# the binding and a manual run on one code path.
if [ -n "${HERDR_PANE_ID:-}" ]; then
  layout=$("$herdr_bin" pane layout --pane "$HERDR_PANE_ID") || fail "pane layout failed"
else
  layout=$("$herdr_bin" pane layout) || fail "pane layout failed"
fi

workspace=$(jq -r '.result.layout.workspace_id' <<<"$layout") || fail "no workspace in layout"
tab=$(jq -r '.result.layout.tab_id' <<<"$layout") || fail "no tab in layout"

# Pairs of pane ids, one pair per line, in left-to-right screen order: the first
# of each pair keeps its place, the second is stacked underneath it. An odd pane
# count leaves the last line with an empty second field, and that pane stays a
# full-height column.
pairs=$(jq -r '.result.layout.panes | sort_by(.rect.x)[].pane_id' <<<"$layout" | paste - -)

# Fed by here-string rather than by a pipe so the loop body runs in this shell
# and `fail` can exit the script rather than just a subshell.
while read -r top bottom; do
  [ -n "$bottom" ] || continue

  # `pane move --tab <the pane's own tab> --split down` is a silent no-op: it
  # answers changed:false, reason:"same_tab", because herdr refuses to
  # restructure a tab against itself. Parking the pane in a throwaway tab first
  # makes the second move cross a tab boundary, which herdr does honour. The
  # throwaway tab must be in the same workspace — a cross-workspace move issues
  # the pane a new id, and the id below would go stale. Emptied tabs close with
  # their last pane, so the parking tab needs no cleanup.
  "$herdr_bin" pane move "$bottom" --new-tab --workspace "$workspace" --no-focus >/dev/null ||
    fail "could not park $bottom"
  "$herdr_bin" pane move "$bottom" --tab "$tab" --split down --target-pane "$top" --no-focus >/dev/null ||
    fail "could not stack $bottom under $top"
done <<<"$pairs"
