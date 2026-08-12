# omp

> Terminal coding agent with per-role model routing, plugins, and skills.
> More information: <https://omp.sh>.

- Launch or resume the interactive session:

`omp`

- Override the model for this run (fuzzy-matched name):

`omp --model {{model_name}}`

- Continue the most recent session:

`omp -c`

- Resume a session by picking from a list:

`omp -r`

- Download and install the latest release:

`omp update`

- Check whether an update is available without installing it:

`omp update --check`

- Refresh a plugin marketplace's catalog, then install a plugin from it:

`omp plugin marketplace update && omp plugin install {{plugin}}@{{marketplace}}`

- List installed plugins:

`omp plugin list`
