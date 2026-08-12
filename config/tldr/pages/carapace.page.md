# carapace

> Multi-shell command-line completion generator with built-in specs for hundreds of CLIs.
> Feeds a shell's native completion system rather than replacing it.
> More information: <https://carapace-sh.github.io/carapace-bin/>.

- Generate and load completions for the current shell (typically called from a shell rc file):

`source <(carapace {{shell}})`

- List every command carapace ships a built-in completer for:

`carapace --list`

- Print the raw completion function/script carapace generates for one command and shell:

`carapace {{command}} {{shell}}`

- Fall back to another completion system (comma-separated) for a command with no built-in spec:

`export CARAPACE_BRIDGES={{zsh,bash,fish,inshellisense}}`

- Show carapace's own version:

`carapace --version`
