---
description: Generate or repair this project's paseo.json — worktree setup/teardown, workspace scripts, and commit/branch conventions for Paseo's metadata generation
argument-hint: "(empty = the current project; a path = generate for that project instead)"
---

Read `skill://paseo-config-authoring`, then run its procedure exactly against
$ARGUMENTS (the current project's repo root when empty): detect the package
manager and the project's own real install/build/dev/test/lint/check
commands (from its CI config and its own contributor docs, not a generic
guess) for `worktree.setup`/`worktree.teardown` and `scripts`, decide for
each script whether it's safe to mark `"type": "service"` per the skill's
rule (only when the process is confirmed to bind `$PORT` — never guessed),
and detect the project's real commit-message and branch-naming conventions
(commitlint config, git hooks, CONTRIBUTING/AGENTS docs, or as a last resort
empirical branch/commit history) to write as plain-English
`metadataGeneration.branchName.instructions` and
`metadataGeneration.commitMessage.instructions` overrides — plus
`metadataGeneration.pullRequest`/`title` only when there's real evidence for
them.

If `paseo.json` already exists, treat this as a repair pass: keep every
value that looks like a deliberate hand-edit, and only fill genuine gaps or
fix values that are demonstrably stale — never blindly overwrite.

Finish with a summary table: every field you wrote, and for each one whether
it was **detected** (cite the file), **inferred**, or intentionally **left
out** for lack of evidence. Never present a guess as a detected fact.
