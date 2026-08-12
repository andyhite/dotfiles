# fleet

> Dispatches peer coding agents into their own worktree-backed workspaces, and collects their reports.
> Each worker is a separate agent process in its own pane, worktree, and branch. Requires herdr.
> More information: <https://github.com/andyhite/foreman>.

- Claim the orchestrator ("boss") handle for the current pane:

`fleet boss`

- Create a worktree, start a worker agent in it, and dispatch work without waiting:

`fleet spawn {{branch_name}}`

- Send a message to a running worker and return immediately:

`fleet send {{worker_handle}} {{message}}`

- Send a message to a worker and block until its report is ready:

`fleet ask {{worker_handle}} {{message}}`

- Collect every worker's report for the current repository:

`fleet join`

- List every worker, its kind, and its current state:

`fleet ls`

- Remove a worker's worktree and forget about it:

`fleet reap {{worker_handle}}`

- Check that every prerequisite (herdr, git, etc.) is in place:

`fleet doctor`
