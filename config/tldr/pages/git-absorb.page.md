# git-absorb

> Automatically create `fixup!` commits for uncommitted changes, targeting the commit that last touched each changed line.
> Requires `rebase.autoSquash` to actually squash the fixups on the next interactive rebase.
> More information: <https://github.com/tummychow/git-absorb>.

- Show which hunk would be absorbed into which commit, without changing anything:

`git absorb --dry-run`

- Create `fixup!` commits for every uncommitted hunk, targeting the commit that last touched each line:

`git absorb`

- Create the `fixup!` commits and immediately autosquash them via an interactive rebase:

`git absorb --and-rebase`

- Limit the search for a target commit to a specific range:

`git absorb --base {{main}}`

- Absorb changes even with a detached `HEAD`:

`git absorb --force-detach`

- Only absorb hunks that are staged:

`git absorb --only-staged`
