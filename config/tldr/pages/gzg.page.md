# gzg

> ghzinga: a terminal UI for browsing and acting on GitHub issues and pull requests.
> Binary name is `gzg`; install with `cargo install ghzinga`.
> More information: <https://github.com/osolmaz/ghzinga>.

- Open the issue/PR browser for the repository in the current directory:

`gzg`

- Jump straight to a specific issue:

`gzg issue {{issue_number}}`

- Jump straight to a specific pull request:

`gzg pr {{pr_number}}`

- Browse a repository other than the current directory's:

`gzg --repo {{owner/name}}`

- List open issues without opening the full TUI:

`gzg issue list --state {{open}}`
