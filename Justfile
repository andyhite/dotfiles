# Single source of truth for the checks ci.yml runs. Recipes assume their
# dependencies (chezmoi, shellcheck, jq, zsh) are already on PATH — they
# install nothing, same as a CI runner's steps after its setup lines.
#
# Multi-line recipes below are `#!/usr/bin/env bash` scripts rather than
# plain recipe bodies: `just` runs each body line as its own separate shell
# invocation unless it's a shebang recipe, and a `for`/`if` block split across
# lines like that fails with "unexpected end of file" on the first line
# alone. A shebang recipe is written to a temp file and run as one script, so
# state and control flow carry across lines the way they read.
#
# Each shebang script sets its own `set -euo pipefail` — GitHub Actions runs
# `run:` steps under bash with exactly that, and these scripts were written
# against that behaviour. The one-liner recipes below use this shell setting
# instead.
#
# Each recipe carries a `[doc(...)]` attribute as well as its comment block.
# `just --list` renders only the LAST comment line above a recipe, so the
# multi-line why-comments here would otherwise render as sentence fragments
# in the listing. The attribute wins over the comment, which keeps the
# listing readable without shortening the comments down to something that no
# longer explains anything.
#
# `--source "$PWD"` is correct on every recipe below even though the source
# state lives in home/: chezmoi reads .chezmoiroot from the directory given
# to --source and redirects itself there.
set shell := ["bash", "-euo", "pipefail", "-c"]

# No arguments -> list what's runnable instead of doing nothing silently.
[doc("List every runnable recipe")]
default:
    @just --list

# The schema gate for the unified manifest. A typo in `via` would otherwise
# render an entry silently absent on one platform rather than failing, and a
# duplicate `name` would silently produce two installs or two completion
# files.
[doc("packages.yaml parses and every entry is well-formed")]
data:
    #!/usr/bin/env bash
    set -euo pipefail
    chezmoi execute-template --source "$PWD" '{{"{{"}} .packages | toJson {{"}}"}}' \
      | jq -e '
          def specs: [.all, .darwin, .linux] | map(select(. != null));
          def binary_managers: ["mise","brew","cask","apt","uv","installer"];
          def agent_managers:  ["herdr","omp","gh","skill"];
          (length > 0)
          and (map(.name) | length == (unique | length))
          and all(.[];
                (.name | type) == "string" and (.name | length) > 0
            and (specs | length) > 0
            and all(specs[];
                  (.via | IN(binary_managers[], agent_managers[]))
              and (if .via == "installer" then (has("url") and has("shell")) else true end)
              and (if .via != "mise"      then (has("version") | not)         else true end)
              and (if .via != "cask"      then (has("args")    | not)         else true end))
            # a `/` in a name means "not an executable", and only the four
            # agent-artifact managers may use one
            and ((.name | test("/")) == (specs | any(.via | IN(agent_managers[]))))
            and all((.postInstall // [])[];
                  (keys == ["zshCompletion"])
              and (.zshCompletion | type) == "array"
              and (.zshCompletion | length) > 0))
        ' >/dev/null
    echo "ok  packages.yaml"

# Every *.tmpl under home/ renders without error, for both platforms a
# machine actually runs this on — the check today's single-OS CI runner
# cannot do any other way. --override-data, not --promptString: chezmoi
# matches --promptString pairs against the prompt's third-argument label
# text, not the promptStringOnce variable name (a documented chezmoi
# gotcha — twpayne/chezmoi#3834), so overriding the data directly is the
# only reliable way to simulate "answered blank" here.
[doc("Every chezmoi template renders for both darwin and linux")]
templates:
    #!/usr/bin/env bash
    set -euo pipefail
    while IFS= read -r -d '' f; do
      for os in darwin linux; do
        # home/.chezmoi.toml.tmpl is chezmoi's own config template — it uses
        # promptStringOnce, only defined under --init, and is never rendered
        # through a plain execute-template call in real use.
        # Plain scalar, not an array: bash 3.2 (macOS system bash, still what
        # `/usr/bin/env bash` finds on a fresh machine before Homebrew's own
        # bash is installed) raises "unbound variable" on `${arr[@]}` for an
        # empty array under `set -u` — fixed only in bash 4.4+. The value is
        # always either empty or the literal `--init`, so unquoted expansion
        # below is safe.
        init_flag=
        [ "$f" = "home/.chezmoi.toml.tmpl" ] && init_flag=--init
        chezmoi execute-template --source "$PWD" ${init_flag:+"$init_flag"} \
          --override-data "{\"chezmoi\":{\"os\":\"$os\"},\"workName\":\"\",\"workEmail\":\"\",\"workGitDir\":\"\"}" \
          < "$f" >/dev/null
      done
      echo "ok  $f"
    done < <(find home -name '*.tmpl' -print0)

# A guarded-out platform-specific script renders to an empty body, which
# shellcheck rejects as a missing shebang — that's expected, not a bug, so
# empty renders are skipped rather than failed.
[doc("Every provisioning script renders and passes shellcheck")]
scripts:
    #!/usr/bin/env bash
    set -euo pipefail
    for f in home/.chezmoiscripts/*.sh.tmpl; do
      for os in darwin linux; do
        rendered="$(chezmoi execute-template --source "$PWD" \
          --override-data "{\"chezmoi\":{\"os\":\"$os\"}}" < "$f")"
        [ -n "$rendered" ] || continue
        printf '%s\n' "$rendered" | shellcheck -S warning -
      done
      echo "ok  $f"
    done

[doc("Syntax-check dot_zshenv, dot_zshrc and the rendered zshrc.local")]
zsh-syntax:
    #!/usr/bin/env bash
    set -euo pipefail
    for f in home/dot_zshenv home/dot_zshrc; do
      zsh -n "$f" && echo "ok  $f"
    done
    chezmoi execute-template --source "$PWD" < home/create_private_dot_zshrc.local \
      | zsh -n /dev/stdin && echo "ok  home/create_private_dot_zshrc.local"

# The filter this used to depend on is gone (step 12 of the migration):
# ssh_connections now lives in Zed's project-local settings, never the
# user-level file this repo tracks, so this grep is the only thing left that
# catches a regression.
[doc("Reject work identifiers and ssh_connections in committed content")]
leakguard:
    #!/usr/bin/env bash
    set -euo pipefail
    pattern='circuit''[-.]ai|andyhite''-fab|mole''cula|OXY''GEN|"ssh_connections"[[:space:]]*:'
    if git grep -nIi -E "$pattern" -- . \
        ':!README.md' \
        ':!.github/workflows/ci.yml' \
        ':!Justfile'; then
      echo "::error::work identifier or ssh_connections block found in committed content — see the matches above"
      exit 1
    fi
    echo "ok  no work identifiers committed"

# There is no tracked Brewfile any more, so this is the only way to read
# what `brew bundle` will actually be handed.
[doc("Print the Brewfile generated from packages.yaml")]
brewfile:
    @chezmoi execute-template --source "$PWD" --override-data '{"chezmoi":{"os":"darwin"}}' \
      < home/.chezmoiscripts/run_onchange_after_20-brew-bundle.sh.tmpl

# Not part of `check`: it rewrites files, and `check` only ever reports.
# .markdownlint.yaml at the repo root is the shared rule config with nvim's
# own "markdownlint" linter — MD013/MD041 off, everything else on.
[doc("Auto-fix markdown lint issues across the repo")]
fix-md:
    markdownlint-cli2 --fix "**/*.md"

# Everything fast enough to run on every commit. smoke is deliberately not a
# dependency here: it does real filesystem work, so it's a separate, slower
# step rather than baked into the default gate.
[doc("Every check fast enough to run on every commit")]
check: data templates scripts zsh-syntax leakguard

# --exclude scripts,externals is mandatory: without it a smoke run would
# execute brew bundle and sudo apt-get install against the real machine.
# Runs apply twice into the same throwaway destination; the second run must
# leave `chezmoi verify` clean — a target that flip-flops or a step that
# isn't idempotent shows up here instead of on someone's second bootstrap.
# --override-data, not --promptString: see the templates recipe above for
# why, and note chezmoi apply/verify don't accept --promptString at all —
# only execute-template and init do.
[doc("Apply the whole tree into a throwaway destination twice and assert idempotency")]
smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="$(mktemp -d)"
    data='{"workName":"","workEmail":"","workGitDir":""}'
    chezmoi apply --source "$PWD" --destination "$dest" \
      --exclude scripts,externals --force --override-data "$data"
    chezmoi apply --source "$PWD" --destination "$dest" \
      --exclude scripts,externals --force --override-data "$data"
    chezmoi verify --source "$PWD" --destination "$dest" \
      --exclude scripts,externals --override-data "$data"
    echo "ok  idempotent apply, chezmoi verify clean"

[doc("Apply this repo's tree onto the real machine. Set CHEZMOI_VERBOSE=1 for raw installer output")]
apply:
    chezmoi apply --source "$PWD"

# Replaces the old --host driver. The remote pulls from origin, not this
# working copy: a run that silently installs the previous commit is the
# failure mode here that looks like success.
#
# `init` runs unconditionally, even when `~/.dotfiles/.git` already exists
# from a pre-chezmoi clone (or a prior run here) — per `chezmoi init --help`,
# it only clones when the source dir has no `.git`, so on an existing repo it
# just (re)generates `~/.config/chezmoi/chezmoi.toml` from `.chezmoi.toml.tmpl`.
# That config is what makes `workGitDir` et al. resolve; skipping `init`
# because `.git` already existed (the old branch here) left it missing and
# broke every template that reads `.workGitDir`. `promptStringOnce` reads the
# answers back out of the previous config, so re-running `init` on later
# calls never re-prompts.
[doc("Apply this repo's chezmoi state on a remote host over ssh")]
remote host:
    #!/usr/bin/env bash
    set -euo pipefail
    git diff --quiet && git diff --cached --quiet \
      || echo "warning: local tree is dirty — the remote installs origin's commit" >&2
    ssh -t "{{host}}" 'set -eu
      export PATH="$HOME/.local/bin:$PATH"
      command -v chezmoi >/dev/null 2>&1 \
        || sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
      chezmoi init --source "$HOME/.dotfiles" https://github.com/andyhite/dotfiles.git
      chezmoi --source "$HOME/.dotfiles" update --apply'
