# AGENTS.md

This repo *is* the running config: everything under `$HOME` is a symlink back here, so
editing a tracked file changes the live machine immediately. No build, no copy step, no
staging environment.

`README.md` is the reference for *why* each tool is configured the way it is — one section
per tool, plus an inventory table of every tracked path. This file covers *how to change
things here*.

## Verify before yielding

Run what CI runs — `just check` and `just smoke`. All of it works locally; nothing needs
a VM.

`just check` is the fast gate (parse, shellcheck, zsh syntax, template YAML, leakguard,
zed-filter, help-coverage). It deliberately excludes `smoke`: that recipe mutates a
throwaway `HOME` and does real filesystem work, so it stays a separate, slower step rather
than baked into every commit.

`just smoke` links the whole tree into a throwaway `HOME`, twice — in a subshell, so the
agent's own `HOME` is never reassigned. The second run must report every link as already
correct and back nothing up.

Touching argument handling or step dispatch? Also run `just cli-checks` — it asserts
`--help`, that an unknown `--only` step fails, and that a bare `--only` explains itself.

## Justfile

The `Justfile` is the single source of truth for checks; `.github/workflows/ci.yml` invokes
its recipes and nothing more. A new check goes in the Justfile and gets a one-line CI
step — never a command pasted into `ci.yml`, and never a third copy here. Recipes carry a
`[doc("...")]` attribute because `just --list` renders only the last comment line above a
recipe, so the multi-line why-comments would otherwise show up as sentence fragments in the
listing.

## Adding a config file

Three edits:

1. The file, under its tool's directory in `config/` (or the repo root for a `$HOME`
   dotfile).
2. An entry in the `links` array inside `link_configs` (`install.sh`), with a comment
   saying *why that granularity*. Link a directory when new content should land in this
   repo automatically; link per-file when the target directory also holds secrets,
   databases, or state another tool writes (`~/.ssh`, `~/.omp/agent`).
3. A row in README's inventory table.

A file the installer *reads* rather than links (`Brewfile`, `herdr_plugins.txt`,
`omp_plugins.txt`, `agent_skills.txt`, `gh_extensions.txt`) gets the table row and its
consumer, not a `links` entry.

## Adding a tool

Four edits:

1. A `brew`/`cask` line in `Brewfile`, with a comment saying *why this tool*.
2. A Linux equivalent in `install.sh`'s apt/cargo/release path.
3. A row or section in README's inventory.
4. A `## <name> — <tagline>` section in the right `help/*.md`. The parser depends on the
   em-dash separator, 4-space-indented command examples, and the command name in the heading
   being what you TYPE — which is why `just help-coverage` carries an explicit alias map
   for the six Brewfile names that differ (`git-delta`/`delta`, `difftastic`/`difft`,
   `tealdeer`/`tldr`, `ripgrep`/`rg`, `neovim`/`nvim`, `1password-cli`/`op`) and an exempt
   set for casks that install an app rather than a command.

## Secrets

Nothing machine-specific or credential-bearing is tracked. The escape hatch is a
`*.example` template: add it to the template loop at the end of `link_configs`, plus a
`case` arm when its target isn't `~/.<name>`. Templates are **copied** at mode 600, never
linked, and only when absent — a re-run must never overwrite a filled-in file.

CI greps committed content for work identifiers and for Zed's `ssh_connections` key, and
fails the build on a match. Real hostnames, work domains, and employer names belong in
the machine-local file — not in a comment, an example, or a commit message.

## omp model routing

`omp/agent/config.yml` is shared by every machine, so `modelRoles` and
`retry.fallbackChains` may only name omp's built-in providers — `anthropic`,
`openai`, `openai-codex`, `cursor` — plus `anthropic-api`, a second Anthropic
identity every machine running this config is required to define locally
(billed by API key, distinct from the subscription OAuth login behind the
bare `anthropic` id; see `omp/agent/models.yml.example`). CI enforces both
halves of that rule. A built-in provider the machine can't authenticate is
skipped silently; any other custom provider id warns once per role at every
startup on every machine that doesn't define it. Machine-specific providers
go in `~/.omp/agent/models.yml`, whose tracked template stays inert
(`providers: {}` — trimming it to pure comments parses as null and omp
rejects that on launch). A machine that should only ever bill API accounts
needs no `config.yml` divergence at all: define `anthropic-api`, export its
API keys, and simply never authenticate the subscription providers there —
unresolvable built-in ids drop out of every role's fallback order on their
own.

## install.sh step order is load-bearing

The `run_step` block at the bottom is ordered by real dependencies, each spelled out in
the comment above it. A new step means placing it against those constraints and adding it
to `STEPS`.

## Comments carry the why

Every non-obvious line in `install.sh`, `ci.yml`, `.gitignore` and the configs is
commented with the failure mode it prevents, not with what it does. Match that: write the
sentence that stops the next reader from "simplifying" the line back into the bug. Prose
wraps at 95 columns.

## Pre-commit hooks

`.pre-commit-config.yaml` runs gitleaks plus the local `just leakguard` hook.
`install.sh`'s hooks step runs `pre-commit install`, so a fresh clone gets them. A commit
can be rejected by a hook — fix the finding, never pass `--no-verify`.

## Commits

Conventional Commits, one line, all lowercase, imperative mood, no trailing period, under
100 characters: `<type>(<scope>): <description>`.

- Types in use: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `ci`, `chore`,
  `revert`.
- Scope is the tool or config area (`omp`, `herdr`, `nvim`, `zsh`, `foreman`,
  `ssh`, `ghostty`, `starship`, `atuin`, `brewfile`, `ci`, `setup`); omit it for
  repo-wide changes.
- Add a body only when the reasoning is worth recording.

Changes normally land as a direct push to `main`; CI runs on every push either way. When
a change does warrant a branch, name it with a short kebab-case slug led by a verb, no
type prefix and no issue number: `add-nvchad`, `fix-ssh-host-allowlist`.
