## git — the version-control settings this repo actually changes

Not a git tutorial — this section only documents what `gitconfig` sets away
from stock. Everything below is tracked, so it follows you to every machine
this repo is installed on.

    git pull                       # rebases onto upstream instead of merging (pull.rebase)
    git rebase -i main             # dirty tree gets stashed first, popped after (rebase.autoStash)
    git fetch                      # deletes stale remote-tracking branches and tags (fetch.prune/pruneTags)
    git diff                       # histogram algorithm, moved lines shown as moved, copies detected too
    git branch                     # most recently committed-to branch first (branch.sort)
    git tag                        # v9 before v10, not lexicographic (tag.sort)
    git commit                     # message editor shows the diff being committed (commit.verbose)
    git rbase                      # git offers to run `rebase` instead of failing outright (help.autocorrect)

Gotcha: `merge.conflictStyle = zdiff3` prints the common-ancestor text inside
conflict markers, so a marker block is three-way, not two — read past the
extra `|||||||` section instead of assuming the file is corrupted. `rerere`
(enabled, with autoupdate) means a conflict you resolved once auto-resolves
identically on a repeated rebase — if a resolution looks wrong, check
`git rerere status` before blaming yourself.

## gh — GitHub from the terminal

`config/gh/config.yml` pins `git_protocol: https`, not ssh — the tracked ssh
config maps `github.com` to a specific key with `IdentitiesOnly yes` for a
different account, so an ssh remote here would silently authenticate as the
wrong identity. https instead goes through `gh`'s own credential helper
(wired into `gitconfig`'s `[credential]` blocks), which authenticates as
whichever account `gh auth switch` last activated.

    gh repo clone owner/repo       # clone a GitHub repository locally
    gh co 1234                     # alias for `pr checkout` — pulls PR #1234 into a local branch
    gh pv                          # alias for `pr view --web` — opens the current branch's PR
    gh prs                         # alias for `pr list`
    gh il                          # alias for `issue list`
    gh rv                          # alias for `pr review`
    gh issue create                # open a new issue in the current repository
    gh auth switch                 # change which account git/gh https operations authenticate as
    gh auth status                 # see which account is currently active

## gh-poi — safe local branch cleanup

Deletes local branches whose PR is merged or closed. Unlike `git branch -d`
or a merge-base check, it asks GitHub for PR *state*, which is what makes it
correct after a squash merge — a squash rewrites commits, so the local branch
never looks merged by merge-base alone.

    gh poi                         # interactive prompt over deletable branches
    gh poi --dry-run               # show what would be deleted, delete nothing — run this first
    gh poi --base main             # check merged/closed status against a base other than the default
    gh poi --exclude main,develop  # never offer these branches for deletion
    gh poi --describe              # print why each candidate branch is/isn't deletable
    gh poi --force                 # skip the confirmation prompt and delete immediately

## lin — Linear issue tracker from the terminal

`aaronkwhite/linear-cli`, installed from the author's own Homebrew tap on
macOS (`brew "aaronkwhite/tap/lin"` — no core formula, no apt package) and
via `cargo install lincli` on Linux. Binary name is `lin`, not `linear-cli`
or `lincli`. Needs a Linear API key once: `lin auth login` (interactive) or
the `LINEAR_API_KEY` environment variable.

    lin auth login                  # interactive setup, saves a named workspace
    lin issue list                  # list issues in the current workspace
    lin issue view ABC-123          # show one issue's details
    lin issue create                # create a new issue, interactive prompts
    lin issue create -t "title"     # create a new issue non-interactively

## git-lfs — large file storage

Wired globally, not per-repo: `gitconfig`'s `filter "lfs"` block (clean,
smudge, process, `required = true`) has to exist outside any single repo so
`git clone`/`git lfs clone` can hydrate LFS files before that repo's own
`.gitattributes`-driven hooks have even run. A repo that uses LFS still
needs `git lfs install` run once per clone to wire the pre-push hook, but
the filter itself is already there globally.

`gitconfig` also registers `lfs.customtransfer.xet` — `git-xet` as a
custom transfer agent, faster than LFS's default HTTP transfer. It only
activates for a repo that opts in via its own `.lfsconfig`; without that,
LFS transfers go over plain HTTP as normal.

    git lfs install                 # wire this clone's pre-push hook (once per clone)
    git lfs track "*.psd"           # add a pattern to .gitattributes for LFS tracking
    git lfs ls-files                 # list files tracked by LFS in this repo
    git lfs pull                     # download the LFS content for the current checkout
    git lfs fetch                    # fetch LFS objects for the current checkout without checking them out
    git lfs status                   # show which tracked files are staged/modified
    git lfs migrate import --include="*.psd"  # move already-committed files into LFS
    git lfs prune                    # delete old local LFS objects no longer referenced

## lazygit — git TUI

Aliased to `lg` in zshrc. Theme matches Ghostty's One Dark palette so nested
TUIs agree on the accent color; `os.editPreset` is `nvim`.

    lg                              # open in the current repo (aliased to `lazygit`)
    lazygit --path path/to/repo     # open lazygit for a specific repository
    lazygit status                  # start with focus on a specific panel
    space                           # stage/unstage the file under the cursor
    a                               # stage/unstage every changed file
    <enter>                         # on a file: open it hunk-by-hunk; on a hunk: stage/unstage lines
    c                               # commit staged changes
    C                               # commit, opening the full editor
    <ctrl-a>                        # amend the last commit with what's staged
    i                               # start an interactive rebase from the commit under the cursor
    <tab>                           # cycle branches/commits/stash/status panels
    ?                               # context-sensitive keybinding help for the current panel

## delta — the git pager

Wired via `core.pager` (a `.gitconfig.local`-friendly hook, falling back
to `|| less` so a machine without delta on PATH still has a working pager).

    git log                         # rendered through delta instead of raw diff text
    git diff                        # side-by-side view, syntax highlighting, line numbers
    delta old_file new_file         # compare two files directly, outside git
    delta --show-config             # display the currently active delta settings
    n                                # jump to the next file in the diff (navigate = true)
    N                                # jump to the previous file
    q                                # quit the pager

Gotcha: delta only replaces the *pager* — `git diff` output piped to another
program (a CI log, `| cat`) skips delta entirely and prints plain diff text.

## difft — structural diff

Wired as `git dft`, a `difftool -t difftastic` alias — deliberately NOT
the default pager. It's slower than delta and does no intra-line word diff,
so day-to-day `git diff` stays on delta; reach for `difft` specifically when
a change moved or reindented code and a line-based diff would just show a
wall of red/green noise.

    git dft                         # diff the working tree against HEAD, structurally
    git dft main                    # diff against another ref
    git dft --staged                # diff staged changes structurally
    difft old.rs new.rs             # diff two files directly, outside git
    difft --display side-by-side old.rs new.rs  # force side-by-side rendering

## git-absorb — auto-fixup for stacked commits

`git absorb --and-rebase` looks at your worktree's uncommitted hunks,
figures out which commit in the current stack last touched each of those
lines, and creates `fixup!` commits targeting them — then immediately
autosquashes (rebase.autoSquash is already on, so a plain `git rebase -i`
would do the same squash without the `--and-rebase` flag).

    git absorb --dry-run             # show which hunk would be absorbed into which commit
    git absorb                       # create the fixup! commits, leave them for a manual rebase -i
    git absorb --and-rebase          # create the fixup! commits AND autosquash them immediately
    git absorb --base main           # limit the search for a target commit to main..HEAD
    git absorb --force-detach        # allow absorbing even with a detached HEAD
    git absorb --only-staged         # only absorb hunks that are staged

This is why it fits this config specifically: rerere is on, so if the
rebase absorb triggers regenerates a conflict you've already resolved once,
it resolves silently instead of asking again.

## jj — a second mental model on top of the same git repo

`jj git init --colocate` in an existing checkout keeps `.git` as the
authoritative store — every existing git tool (lazygit, delta, gh, hooks)
keeps working untouched, because there's still a real `.git` underneath. jj
is a layer, not a replacement.

    jj st                          # working-copy status
    jj log                         # commit graph, including the working copy itself as a commit
    jj new                         # start a new empty commit on top of the current one
    jj describe -m "message"       # set/edit the message of a commit (default: the working copy)
    jj squash                      # fold the working copy's changes into its parent commit
    jj rebase -d main              # rebase the current change (and descendants) onto main
    jj undo                        # undo the last jj operation
    jj op log                      # full history of jj operations, what `undo` walks back through
    jj git fetch                   # pull from the git remote into jj's view of history
    jj git push                    # push jj's history back out as git commits/branches

Gotcha, the thing that most surprises a git user: there is no staging area.
The working copy IS a commit at all times — `jj st` shows a diff against its
parent, not an index. What git calls "add and commit" is just `jj describe`
on a commit that already exists; what git calls "amend" is the default
behavior of editing the working-copy commit in place.

## gitleaks — secret scanner

Run from this repo's own `.pre-commit-config.yaml`, and worth running
by hand before pushing anything that touched credentials-shaped files.

    gitleaks detect                 # scan the current tree for secrets, once
    gitleaks detect --redact        # same, but mask the matched secret in output instead of printing it
    gitleaks detect --repo-url https://github.com/user/repo.git  # scan a remote repository
    gitleaks protect --staged       # scan only staged changes — the pre-commit-hook mode
    gitleaks git                    # scan full git history, not just the working tree
    gitleaks detect --report-path report.json  # write findings to a file instead of stdout

## pre-commit — hook runner

This repo's `.pre-commit-config.yaml` runs `gitleaks` plus a local
`just leakguard` hook — the same check `just check` runs, so a commit and a
full CI run can't disagree about whether a secret leaked.

    pre-commit install             # install this repo's .pre-commit-config.yaml as a git hook
    pre-commit run                 # run hooks against staged files only
    pre-commit run --all-files     # run every configured hook against the whole tree, not just staged
    pre-commit run gitleaks        # run one hook by id
    pre-commit clean               # clear the pre-commit hook cache
    pre-commit autoupdate          # bump hook repo revisions in .pre-commit-config.yaml to latest
    pre-commit uninstall           # remove the installed git hook
