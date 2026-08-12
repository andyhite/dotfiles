# antidote

> Fast, static-file zsh plugin manager.
> Reads a plain text file of `owner/repo` lines and clones/sources each one.
> More information: <https://getantidote.github.io>.

- Load every plugin listed in a plugins file (typically called from `.zshrc`):

`antidote load {{path/to/zsh_plugins.txt}}`

- Clone and source a single plugin ad hoc, outside any plugins file:

`antidote bundle {{owner/repo}}`

- List every plugin antidote currently has loaded:

`antidote list`

- Generate a static, pre-compiled loader script from a plugins file (faster startup than `load`):

`antidote bundle < {{path/to/zsh_plugins.txt}} > {{path/to/zsh_plugins.zsh}}`

- Show the local clone path for a plugin:

`antidote path {{owner/repo}}`

- Print the antidote version:

`antidote version`
