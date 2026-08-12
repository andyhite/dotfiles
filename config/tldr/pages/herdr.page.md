# herdr

> Terminal multiplexer built for running and supervising coding agents, with worktree-backed workspaces.
> More information: <https://herdr.dev>.

- Launch or attach to the persistent session:

`herdr`

- Start a supported interactive agent in the current pane:

`herdr agent start`

- List running agents across every pane:

`herdr agent list`

- Create a git worktree and open it as a new workspace:

`herdr worktree create {{branch_name}}`

- List worktree-backed workspaces:

`herdr worktree list`

- Install (or update, by re-running) a plugin from GitHub:

`herdr plugin install {{owner/repo}}`

- List every action every installed plugin exposes:

`herdr plugin action list`

- Run one plugin action directly, bypassing any keybinding or palette:

`herdr plugin action invoke {{action_id}} --plugin {{plugin_id}}`
