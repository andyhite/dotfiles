# AGENTS.md

This repo *is* the running config: everything under `$HOME` is a symlink back here, so
editing a tracked file changes the live machine immediately. No build, no copy step, no
staging environment.

`README.md` is the reference for *why* each tool is configured the way it is — one section
per tool, plus an inventory table of every tracked path. This file covers *how to change
things here*.

## Verify before yielding

Run what CI runs (`.github/workflows/ci.yml`). All of it works locally; nothing needs a VM.

```sh
bash -n install.sh
shellcheck -S warning -e SC2088,SC2206 install.sh   # both exclusions are deliberate
for f in zshrc zshenv zshrc.local.example; do zsh -n "$f"; done
```

The real smoke test links the whole tree into a throwaway `HOME`, twice — in a subshell,
so the agent's own `HOME` is never reassigned:

```sh
( export HOME="$(mktemp -d)"
  ./install.sh --only configs --yes >/dev/null
  ./install.sh --only configs --yes | grep 'backed up to' && echo 'NOT IDEMPOTENT' )
```

The second run must report every link as already correct and back nothing up. Touching
argument handling or step dispatch? Also check `./install.sh --help`, that
`./install.sh --only nosuchstep --yes` fails, and that a bare `--only` explains itself.

## Adding a config file

Three edits:

1. The file, under its tool's directory in `config/` (or the repo root for a `$HOME`
   dotfile).
2. An entry in the `links` array inside `link_configs` (`install.sh`), with a comment
   saying *why that granularity*. Link a directory when new content should land in this
   repo automatically; link per-file when the target directory also holds secrets,
   databases, or state another tool writes (`~/.ssh`, `~/.omp/agent`, `~/.paseo`).
3. A row in README's inventory table.

A file the installer *reads* rather than links (`Brewfile`, `herdr_plugins.txt`,
`omp_plugins.txt`, `agent_skills.txt`) gets the table row and its consumer, not a `links`
entry.

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
`retry.fallbackChains` may name built-in providers only: `anthropic`, `openai`,
`openai-codex`, `cursor`. CI enforces it. A built-in provider the machine can't
authenticate is skipped silently; a custom provider id warns once per role at every
startup on every machine that doesn't define it. Machine-specific providers go in
`~/.omp/agent/models.yml`, whose tracked template stays inert (`providers: {}` — trimming
it to pure comments parses as null and omp rejects that on launch).

## install.sh step order is load-bearing

The `run_step` block at the bottom is ordered by real dependencies, each spelled out in
the comment above it. A new step means placing it against those constraints and adding it
to `STEPS`.

## Comments carry the why

Every non-obvious line in `install.sh`, `ci.yml`, `.gitignore` and the configs is
commented with the failure mode it prevents, not with what it does. Match that: write the
sentence that stops the next reader from "simplifying" the line back into the bug. Prose
wraps at 95 columns.

## Commits

Conventional Commits, one line, all lowercase, imperative mood, no trailing period, under
100 characters: `<type>(<scope>): <description>`.

- Types in use: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `ci`, `chore`,
  `revert`.
- Scope is the tool or config area (`omp`, `herdr`, `nvim`, `zsh`, `paseo`, `fleet`,
  `ssh`, `ghostty`, `starship`, `atuin`, `brewfile`, `ci`, `setup`); omit it for
  repo-wide changes.
- Add a body only when the reasoning is worth recording.

Changes normally land as a direct push to `main`; CI runs on every push either way. When
a change does warrant a branch, name it with a short kebab-case slug led by a verb, no
type prefix and no issue number: `add-nvchad`, `fix-paseo-host-allowlist`.
