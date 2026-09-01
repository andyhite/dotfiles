# AGENTS.md

This repo is a chezmoi source state, applied with `chezmoi apply`. Editing a tracked file
under `home/` does **not** change the live machine — chezmoi copies on apply, it doesn't
symlink. The one exception is `linked/`: those trees are live-symlinked into `$HOME`, so
editing them changes the running config immediately, the same way this whole repo used to.
See "Copy mode vs. `linked/`" below for which is which.

`README.md` is the reference for *why* each tool is configured the way it is — one section
per tool, plus an inventory table of every tracked path. This file covers *how to change
things here*.

## Editing a tracked file

Two ways, same result:

- `chezmoi edit --apply <target>` — opens the *source* file for a `$HOME` target in
  `$EDITOR`, then applies it immediately. Fastest for a one-line tweak to something already
  applied (e.g. `chezmoi edit --apply ~/.zshrc`).
- Edit the file directly under `home/` (or `linked/` — see below), then `chezmoi apply`.
  This is the only option for a file that doesn't exist in `$HOME` yet, and the natural one
  when editing several files before applying any of them.

Either way, run `just check` before committing — templates that only render for one OS are
the class of bug a plain edit won't catch locally.

## Copy mode vs. `linked/`

Everything under `home/` is copy-on-apply: chezmoi writes a plain file (or, for `create_`
entries, a private file written once and never touched again) into `$HOME`. Nothing under
`home/` is ever symlinked into `$HOME`.

A tree lives in `<repo>/linked/` instead — outside the chezmoi source root, so chezmoi
never manages its content, only a `symlink_` entry pointing at it — when either is true:

- **The tool writes into it.** `linked/nvim` (NvChad rewrites `lazy-lock.json` on `:Lazy
  sync`); `linked/herdr-plugin-config` (herdr creates a config directory per newly
  installed plugin).
- **It's code developed in place, headed for its own repo eventually.**
  `linked/herdr-plugins/ticket-worktree`, `linked/omp-extensions/*.ts`.

Everything else is copied. When in doubt: if nothing but a human ever writes to it, it's
copied; if a running program writes to it, it's linked.

## Verify before yielding

Run what CI runs — `just check` and `just smoke`. All of it works locally; nothing needs a
VM, and nothing touches the real `$HOME`.

`just check` is the fast gate (`data`, `templates`, `scripts`, `zsh-syntax`, `leakguard`).
It deliberately excludes `smoke`: that recipe does real filesystem work against a throwaway
destination, so it stays a separate, slower step rather than baked into every commit.

`just smoke` applies the whole tree into a throwaway destination directory, twice, with
`--exclude scripts,externals` so it never touches Homebrew, apt, or the real network. The
second `chezmoi apply` plus a `chezmoi verify` must report no changes — a target that
flip-flops or a `create_`/`run_once_` entry that isn't idempotent shows up here instead of
on someone's second bootstrap.

## Justfile

The `Justfile` is the single source of truth for checks; `.github/workflows/ci.yml` invokes
its recipes and nothing more. A new check goes in the Justfile and gets a one-line CI
step — never a command pasted into `ci.yml`, and never a third copy here. Recipes carry a
`[doc("...")]` attribute because `just --list` renders only the last comment line above a
recipe, so the multi-line why-comments would otherwise show up as sentence fragments in the
listing.

## Adding anything installable

One edit: an entry in `home/.chezmoidata/packages.yaml`, with a `via` per platform and a
comment saying why it's here. That covers a CLI, a language runtime, a Homebrew cask, an
apt package, a herdr plugin, a `gh` extension, and a cross-agent skill — every one of them
is a `packages` list entry, never a second manifest file, a Brewfile line, or a hand-edited
Linux branch somewhere else. Nothing else to touch:

- The mise config, the generated Brewfile, the apt install script, the uv-tools script, the
  upstream-installer script, the completions script, and the agents script all filter this
  one list — nothing consumes a tool's name from anywhere else.
- For a CLI, check `mise registry | awk '$1=="<tool>"'` first. If it's there, the entry is
  `{ name: <tool>, all: { via: mise } }` and needs no per-OS split at all.
- A shell completion is a `postInstall: [{ zshCompletion: [<argv>] }]` on that same entry,
  never a second entry.
- Names must be globally unique across the whole list (`just data` enforces it). Anything
  that isn't an executable — a herdr plugin, an omp plugin, a gh extension, a skill — is
  prefixed with its kind: `herdr/`, `omp/`, `gh/`, `skill/`.
- A row in README's inventory table if it's substantial enough to warrant its own
  "Notes by tool" section; most entries don't need one.

## Adding a config file

One edit: the file under `home/` in chezmoi source naming (`dot_`, `private_`,
`create_private_`, `symlink_`, `.tmpl` — see chezmoi's own naming reference), or under
`linked/` when its tool writes into it (see "Copy mode vs. `linked/`" above). There is no
`links` array anywhere to keep in sync — the source path *is* the target mapping, and
`.chezmoiroot` (`home`) is what keeps everything outside `home/` and `linked/` out of the
target state entirely.

## Secrets

Nothing machine-specific or credential-bearing is tracked. The escape hatch is a
`create_private_` source entry: chezmoi writes it at mode 0600 the first time `chezmoi
apply` runs, and never touches it again — so a re-apply can never clobber a filled-in file.
The six that exist today: `create_private_dot_zshrc.local`,
`create_private_dot_gitconfig.local`, `private_dot_ssh/create_private_config.local`,
`dot_omp/agent/create_private_models.yml`, `dot_omp/agent/create_private_config.local.yml`,
`dot_dstack/server/create_private_config.yml`. `create_private_dot_gitconfig-work.tmpl` is
the seventh, but it's templated rather than hand-filled — see "omp model routing" below for
the pattern and "Work identity" for this specific one.

CI greps committed content for work identifiers and for Zed's `ssh_connections` key
(`just leakguard`), and fails the build on a match. Real hostnames, work domains, and
employer names belong in a `create_private_` target once it's applied — never in a comment,
a template default, or a commit message. `~/.config/chezmoi/` (chezmoi's own config, which
holds the three `promptStringOnce` answers below) is never tracked either.

## Work identity

`workName`, `workEmail`, and `workGitDir` are the one machine-local facts that aren't
secrets, so they're prompted once (`promptStringOnce` in `home/.chezmoi.toml.tmpl`) rather
than hand-filled in a template. Answers persist in `~/.config/chezmoi/chezmoi.toml`,
outside the repo. A blank `workGitDir` means "no work identity on this machine" — chezmoi's
`.chezmoiignore` then excludes `.gitconfig-work` entirely, and `dot_gitconfig.tmpl`'s
`includeIf "gitdir:..."` block never renders.

## omp model routing

`home/dot_omp/agent/config.yml` is shared by every machine, so `modelRoles` and
`retry.fallbackChains` in it deliberately name only `anthropic` and `cursor` — the two
built-in provider ids every machine is expected to authenticate — not `openai`/
`openai-codex`, which not every machine does. A built-in id the machine can't authenticate
is skipped silently; a custom provider id in the shared config would warn once per role at
every startup on any machine that doesn't define it, which is exactly why custom providers
never go there.

A machine's own routing lives outside the shared file, in two `create_private_` targets:
`~/.omp/agent/models.yml` (credentials and custom provider ids — trial models, self-hosted
endpoints, a second identity for an existing account) and `~/.omp/agent/config.local.yml`
(a `modelRoles`/`retry.fallbackChains` overlay `zshrc` loads via `PI_CONFIG_FILES`,
deep-merged on top of the shared config). Both ship inert (`providers: {}` and `{}`)
because omp validates each file's root as an object — a copy trimmed to pure comments
parses as null, which is a startup warning for `models.yml` and a hard startup error for
`config.local.yml`. See the two `create_private_` source files themselves for the patterns.

## packages.yaml is load-bearing

`home/.chezmoidata/packages.yaml`'s `packages` list is the one manifest every provisioning
script, the mise config, and the generated Brewfile read. `just data` is the schema gate:
every entry needs a `name`, at least one platform spec (`all`/`darwin`/`linux`) with a
valid `via`, and names must be globally unique. Getting this wrong doesn't fail loudly on
its own — a typo'd `via` renders an entry silently absent on one platform — which is exactly
why the check exists; run it after every manifest edit, not just before committing.

## Comments carry the why

Every non-obvious line in the `.chezmoiscripts/*.sh.tmpl` scripts, `packages.yaml`,
`ci.yml`, `.gitignore`, and the configs is commented with the failure mode it prevents, not
with what it does. Match that: write the sentence that stops the next reader from
"simplifying" the line back into the bug. Prose wraps at 95 columns.

## Pre-commit hooks

`.pre-commit-config.yaml` runs gitleaks plus the local `just leakguard` hook.
`run_once_after_90-repo-hooks.sh.tmpl` runs `pre-commit install` on `chezmoi apply`, so a
fresh clone gets them after its first apply. A commit can be rejected by a hook — fix the
finding, never pass `--no-verify`.

## Commits

Conventional Commits, one line, all lowercase, imperative mood, no trailing period, under
100 characters: `<type>(<scope>): <description>`.

- Types in use: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `ci`, `chore`,
  `revert`.
- Scope is the tool or config area (`omp`, `herdr`, `nvim`, `zsh`, `ssh`,
  `ghostty`, `starship`, `atuin`, `chezmoi`, `mise`, `ci`, `setup`); omit it for
  repo-wide changes.
- Add a body only when the reasoning is worth recording.

Changes normally land as a direct push to `main`; CI runs on every push either way. When
a change does warrant a branch, name it with a short kebab-case slug led by a verb, no
type prefix and no issue number: `add-nvchad`, `fix-ssh-host-allowlist`.
