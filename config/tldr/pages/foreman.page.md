# foreman

> Dispatches peer coding agents into their own worktree-backed workspaces, and collects their reports.
> Each worker is a separate agent process in its own pane, worktree, and branch. Requires herdr.
> More information: <https://github.com/andyhite/foreman>.

- Claim the boss handle for the current pane:

`foreman boss`

- Create a worktree, start a worker agent in it, and dispatch work without waiting:

`foreman spawn {{branch_name}}`

- Send a message to a running worker and return immediately:

`foreman send {{worker_handle}} {{message}}`

- Send a message to a worker and block until its report is ready:

`foreman ask {{worker_handle}} {{message}}`

- Collect every worker's report for the current repository:

`foreman join`

- List every worker, its kind, and its current state:

`foreman ls`

- Remove a worker's worktree and forget about it:

`foreman reap {{worker_handle}}`

- Check that every prerequisite (herdr, git, etc.) is in place:

`foreman doctor`
