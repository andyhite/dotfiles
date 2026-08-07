---
description: inside herdr, worktrees go through `herdr worktree`, never `git worktree` — the git command fires no event and creates no workspace
alwaysApply: true
---

## Worktrees inside herdr

When `HERDR_ENV=1`, create, open, and remove git worktrees with `herdr
worktree` — never `git worktree add|remove|move|prune`. This **overrides the
`worktree` skill and the foreman dev loop**, which spell out raw `git worktree`
commands; the naming conventions there still stand, only the command changes.

`git worktree add` still produces a valid checkout, which is why the mistake is
easy to miss. What it silently skips is everything downstream: herdr emits no
`worktree.created` event, so `tdi.worktree-setup` never copies `.env*`, runs
`mise trust` or `direnv allow`, and `herdr-plugin-workspace-manager` never
applies the layout or starts the agent. No herdr workspace is created either,
so the worktree is invisible in the sidebar and `herdr worktree remove` cannot
clean it up later.

```sh
# Create. --path keeps the foreman sibling convention; herdr would otherwise
# use ~/.herdr/worktrees. --no-focus leaves the operator where they were.
herdr worktree create --cwd "$PRIMARY" \
  --branch <type>/<issue>-<slug> \
  --base origin/<mainBranch> \
  --path "$PRIMARY/../<repo-slug>-<issue>-<slug>" \
  --no-focus

# Adopt a worktree that already exists on disk.
herdr worktree open --cwd "$PRIMARY" --branch <type>/<issue>-<slug> --no-focus

# Remove. Takes a workspace id, not a path — read it from the list first.
herdr worktree list --cwd "$PRIMARY"   # .result.worktrees[] -> open_workspace_id
herdr worktree remove --workspace <id>
```

Two things that do not change: `git worktree list` stays fine for reading state,
and every other git operation inside the worktree — commit, rebase, push — is
ordinary git. Only worktree lifecycle goes through herdr.

Outside herdr (`HERDR_ENV` unset), use `git worktree` exactly as the skill says.
