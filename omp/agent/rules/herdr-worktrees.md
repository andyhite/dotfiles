---
description: creating or removing a git worktree while inside herdr (HERDR_ENV=1) — which of `herdr worktree` and `git worktree` to use depends on who will occupy the worktree, and removal has to match creation
---

## Worktrees inside herdr

The question is not which command is correct. It is **who is going to sit in
this worktree.**

`herdr worktree create` does not produce a directory. It produces a *workspace*:
a sidebar entry, a tab, a pane, and `tdi.worktree-setup` copying `.env*` and
running `mise trust` / `direnv allow`. That whole apparatus exists to give a
person or an agent somewhere to work.

None of it is reachable by the agent that runs the command. An omp process keeps
the directory it launched in; `herdr pane move` relocates a pane's display, not
its shell's cwd. So an agent cannot move itself into the worktree it just made.
Calling `herdr worktree create` for its own use gets it a directory it will
address by absolute path anyway, plus a workspace, a tab and a pane it did not
want.

**A worktree a person or another agent will occupy** — `herdr worktree create`:

```sh
# --path keeps the sibling convention; herdr would otherwise use
# ~/.herdr/worktrees. --no-focus leaves the operator where they were.
herdr worktree create --cwd "$PRIMARY" \
  --branch <type>/<issue>-<slug> \
  --base origin/<mainBranch> \
  --path "$PRIMARY/../<repo-slug>-<issue>-<slug>" \
  --no-focus

# Remove. Takes a workspace id, not a path — read it from the list first.
herdr worktree list --cwd "$PRIMARY"   # .result.worktrees[] -> open_workspace_id
herdr worktree remove --workspace <id>
```

Dispatching an agent into one is a level up again: `fleet spawn` sequences
create, agent discovery, rename, and dispatch in one command, and
`skill://fleet` covers when that is worth doing.

**A worktree you will only read and write through the filesystem** — building
another ref, diffing two versions, running a test suite against a branch —
plain `git worktree`:

```sh
git worktree add /tmp/<slug> <ref>
# ... work by absolute path ...
git worktree remove /tmp/<slug>
```

No workspace, no pane, no agent, and no setup hooks — none of which you want for
a checkout whose lifetime is shorter than the task. herdr still lists it under
`herdr worktree list` with a null `open_workspace_id`, so it is not invisible,
just unmanaged.

### Remove with whatever created it

`git worktree remove` on a herdr-created worktree deletes the checkout and
orphans the workspace: a sidebar entry pointing at nothing, with the agent that
was living there now homeless. Going the other way is fine —
`herdr worktree remove --workspace <id>` works on any worktree that has a
workspace, however it got one.

### `herdr worktree open` is not a promotion path

It re-opens a worktree that already has a herdr history, and that is all it is
good for. It does **not** run `tdi.worktree-setup` — that plugin hooks
`worktree.created` only, so an opened worktree never gets its `.env*` or its
`mise trust`. You get a workspace around a checkout that is still missing the
files the setup hook would have put there.

If a plain `git worktree` checkout turns out to need a real workspace, delete it
and `herdr worktree create` the branch properly.

### Unchanged

`git worktree list` is always fine for reading state. Every other git operation
inside a worktree — commit, rebase, push — is ordinary git regardless of how the
worktree was made. Only creation and removal are provenance-sensitive.

Outside herdr (`HERDR_ENV` unset), all of this collapses: use `git worktree`.
