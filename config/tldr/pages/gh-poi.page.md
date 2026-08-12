# gh-poi

> Safely delete local branches whose pull request has been merged or closed.
> A `gh` extension: checks PR *state* on GitHub, so it also catches squash-merged branches `git branch --merged` misses.
> More information: <https://github.com/seachicken/gh-poi>.

- Interactively review and delete branches whose PR is merged or closed:

`gh poi`

- Show what would be deleted without deleting anything:

`gh poi --dry-run`

- Check merged/closed status against a base branch other than the repository's default:

`gh poi --base {{main}}`

- Never offer specific branches for deletion:

`gh poi --exclude {{branch1,branch2}}`

- Print why each candidate branch is, or isn't, deletable:

`gh poi --describe`

- Skip the confirmation prompt and delete immediately:

`gh poi --force`
