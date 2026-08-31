# Single source of truth for the checks ci.yml runs. Recipes assume their
# dependencies (zsh, pyyaml, node, shellcheck) are already on PATH — they
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
# against that behaviour (e.g. leakguard's `if git grep ...; then exit 1; fi`
# relies on -e not firing inside an `if` condition). The one-liner recipes
# below use this shell setting instead.
#
# Each recipe carries a `[doc(...)]` attribute as well as its comment block.
# `just --list` renders only the LAST comment line above a recipe, so the
# multi-line why-comments here rendered as sentence fragments ("...fresh
# machine needs bootstrapping.") in the recipe listing. The attribute wins
# over the comment, which keeps the listing readable without shortening the
# comments down to something that no longer explains anything.
set shell := ["bash", "-euo", "pipefail", "-c"]

# No arguments -> list what's runnable instead of doing nothing silently.
[doc("List every runnable recipe")]
default:
    @just --list

# Two seconds, and it catches the class of bug this repo is most exposed to:
# a quoting or `set -e` mistake in 1700 lines of bash that nobody runs until a
# fresh machine needs bootstrapping.
[doc("Syntax-check install.sh with bash -n")]
parse:
    bash -n install.sh

# Three warnings are expected and deliberate — SC2088 on the literal `~` in
# REMOTE_DIR (only the remote knows its own $HOME) and SC2206 twice on the
# --host comma split, where the word splitting is the point. Each is
# commented at its site. A fourth warning is the actual signal, so those
# three are excluded by code rather than the whole check downgraded.
[doc("Lint install.sh with shellcheck")]
shellcheck:
    shellcheck -S warning -e SC2088,SC2206 install.sh

[doc("Syntax-check zshrc, zshenv and the zshrc template")]
zsh-syntax:
    #!/usr/bin/env bash
    set -euo pipefail
    for f in zshrc zshenv zshrc.local.example; do
      zsh -n "$f" && echo "ok  $f"
    done

# omp parses models.yml at startup, and it validates the root as an object —
# so this checks more than syntax. A template edited down to pure comments
# parses as null, which omp rejects with a validation warning on every single
# launch; the mapping assertion is what keeps the shipped copy inert rather
# than broken.
#
# The routing assertion guards the shared config: omp validates every
# fallback-chain entry against the model catalog, so a built-in provider is
# fine on a machine that cannot authenticate it — the entry is just skipped —
# while a custom models.yml provider id warns once per role at every startup
# on every machine that doesn't define it (observed on the andyhite-fab VM
# before it had one). Tracked routing may therefore only name omp's built-in
# providers, plus `anthropic-api`: every machine this config runs on defines
# that one locally (see omp/agent/models.yml.example) as a second Anthropic
# identity billed by API key instead of the subscription OAuth login behind
# the built-in `anthropic` id — that's what lets one fallback chain list both
# as distinct tiers.
[doc("Assert the tracked omp YAML parses and names built-in providers only")]
templates:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 - <<'PY'
    import yaml

    f = "omp/agent/models.yml.example"
    d = yaml.safe_load(open(f))
    assert isinstance(d, dict), f"{f}: root must be a mapping, got {type(d).__name__}"
    assert set(d) <= {"providers"}, f"{f}: unknown root keys {set(d) - {'providers'}}"
    assert not d.get("providers"), f"{f}: must ship with no active providers"
    print(f"ok  {f}")

    # Built-in ids, plus anthropic-api: not an omp built-in, but a custom
    # provider every machine running this config is required to define
    # locally (unlike an ad hoc custom id, which would warn on any machine
    # that hasn't defined it).
    builtin = {"anthropic", "openai", "openai-codex", "cursor", "anthropic-api"}
    f = "omp/agent/config.yml"
    d = yaml.safe_load(open(f))

    roles = d.get("modelRoles", {})
    chains = d.get("retry", {}).get("fallbackChains", {})
    assert roles, f"{f}: modelRoles went missing"
    assert chains, f"{f}: fallback chains went missing"

    selectors = [(f"modelRoles.{r}", s) for r, s in roles.items()]
    selectors += [
        (f"retry.fallbackChains.{role}", entry)
        for role, chain in chains.items()
        for entry in chain
    ]
    foreign = sorted(
        {
            f"{where} -> {sel}"
            for where, sel in selectors
            if sel.split("/", 1)[0] not in builtin
        }
    )
    assert not foreign, (
        f"{f}: non-built-in provider in tracked routing:\n  "
        + "\n  ".join(foreign)
        + "\nMove machine-specific providers out of the shared config."
    )
    print(f"ok  {f} ({len(roles)} roles, {len(chains)} chains, built-in providers only)")
    PY

# The filter (zed-filter, below) protects the path through `git add`. This
# protects the committed result, which is not the same thing: a clone that
# hasn't run install.sh has no filter registered, git passes settings.json
# straight through, and nothing fails. New machine, clone, open a remote
# project in Zed, commit — that's the realistic leak, and only a check on
# committed content catches it.
#
# Matching the JSON key form `"ssh_connections":` rather than the bare word
# leaves explanatory prose alone. The workflow, filter source, and this
# Justfile are excluded because they deliberately carry test fixtures for
# that key (or, for this file, the pattern itself). Split the work names
# across shell string literals so the guard itself doesn't put the values it
# rejects back into git history.
[doc("Reject work identifiers and ssh_connections in committed content")]
leakguard:
    #!/usr/bin/env bash
    set -euo pipefail
    pattern='circuit''[-.]ai|andyhite''-fab|mole''cula|OXY''GEN|"ssh_connections"[[:space:]]*:'
    if git grep -nIi -E "$pattern" -- . \
        ':!README.md' \
        ':!bin/zed-settings-clean' \
        ':!.gitattributes' \
        ':!.github/workflows/ci.yml' \
        ':!Justfile'; then
      echo "::error::work identifier or ssh_connections block found in committed content — see the matches above"
      exit 1
    fi
    echo "ok  no work identifiers committed"

# The clean filter is the only thing standing between Zed and a public repo:
# it runs on every `git add` of settings.json, and if it silently stopped
# matching the key, nothing would fail — the hostnames would just start
# getting committed again.
[doc("Prove the Zed clean filter strips, repairs and passes through")]
zed-filter:
    #!/usr/bin/env bash
    set -euo pipefail
    # Present: the key goes, everything else stays, JSON stays valid.
    out="$(awk -f bin/zed-settings-clean < config/zed/settings.json)"
    printf '%s' "$out" > /tmp/clean.json

    printf '{\n  "a": 1,\n  "ssh_connections": [\n    { "host": "secret-box" }\n  ],\n  "b": 2\n}\n' > /tmp/mid.json
    awk -f bin/zed-settings-clean < /tmp/mid.json > /tmp/mid.out
    if grep -q 'ssh_connections\|secret-box' /tmp/mid.out; then
      echo "::error::filter left ssh_connections in the output"; exit 1
    fi
    node -e 'JSON.parse(require("fs").readFileSync("/tmp/mid.out","utf8"))'

    # Last key: removing it strands a comma, and `,}` is invalid JSON.
    printf '{\n  "a": 1,\n  "ssh_connections": [\n    { "host": "x" }\n  ]\n}\n' > /tmp/last.json
    awk -f bin/zed-settings-clean < /tmp/last.json > /tmp/last.out
    node -e 'JSON.parse(require("fs").readFileSync("/tmp/last.out","utf8"))'

    # Absent: must be a byte-for-byte pass-through, or every unrelated Zed
    # setting would show up as spurious diff noise.
    printf '{\n  "a": 1,\n  "b": 2\n}\n' > /tmp/none.json
    awk -f bin/zed-settings-clean < /tmp/none.json > /tmp/none.out
    cmp /tmp/none.json /tmp/none.out
    echo "ok  filter strips, repairs, and passes through"

# Every `brew`/`cask` line in the Brewfile needs a matching `## <command> —`
# section in help/*.md, or `dotfiles-help` silently has nothing to say about
# it the day someone forgets what a newly-added tool does.
[doc("Assert every Brewfile entry has a dotfiles-help section")]
help-coverage:
    #!/usr/bin/env python3
    import glob
    import re
    import sys

    # Formula name -> the command name its help section is titled under.
    # Kept as an explicit map rather than fuzzy-matched (stripping prefixes/
    # suffixes, case-folding, etc.): fuzzy matching would let a genuinely
    # undocumented tool slip through by coincidentally matching something
    # unrelated, which defeats the point of this check.
    ALIASES = {
        "git-delta": "delta",
        "tealdeer": "tldr",
        "ripgrep": "rg",
        "neovim": "nvim",
        "1password-cli": "op",
        "aaronkwhite/tap/lin": "lin",
    }

    # Casks/fonts that install a GUI app or an asset, not a command that
    # could ever have a `## name —` help section.
    EXEMPT = {
        "font-geist",
        "font-geist-mono",
        "font-geist-mono-nerd-font",
        "docker-desktop",
    }

    brewfile = open("Brewfile").read()
    names = re.findall(r'^(?:brew|cask) "([^"]+)"', brewfile, re.MULTILINE)
    names = [n for n in names if n not in EXEMPT]

    documented = set()
    for path in glob.glob("help/*.md"):
        documented.update(re.findall(r"^## (\S+) — ", open(path).read(), re.MULTILINE))

    missing = sorted(name for name in names if ALIASES.get(name, name) not in documented)

    if missing:
        print("help-coverage: missing help/*.md sections for:")
        for name in missing:
            wanted = ALIASES.get(name, name)
            print(f"  {name} (section should be titled '## {wanted} — ...')")
        sys.exit(1)

    print(f"ok  {len(names)} Brewfile entries all have help/*.md sections")

# Not part of `check`: it rewrites files, and `check` only ever reports.
# `.markdownlint.yaml` at the repo root is the shared rule config with
# nvim's own "markdownlint" linter — MD013/MD041 off, everything else on.
[doc("Auto-fix markdown lint issues across the repo")]
fix-md:
    markdownlint-cli2 --fix "**/*.md"

# Runs the whole tree link end to end, twice, so it must never touch the
# calling shell's real HOME: an explicit subshell reassigns HOME for the two
# installs and nothing outside it. The second run must report every link as
# already correct and back nothing up — a symlink target that flip-flops or a
# step that isn't idempotent shows up here instead of on someone's second
# bootstrap.
[doc("Link the whole tree into a throwaway HOME twice and assert idempotency")]
smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    (
      export HOME="$(mktemp -d)"
      ./install.sh --only configs --yes >/dev/null
      ./install.sh --only configs --yes | tee /tmp/dotfiles-smoke-second.log
      if grep -q 'backed up to' /tmp/dotfiles-smoke-second.log; then
        echo "::error::re-running --only configs backed a file up; it should be a no-op"
        exit 1
      fi
    )

# A failing step must not take the rest of the run down with it, and a flag
# with no value must fail loudly. Both were real bugs: on a Mac without
# Homebrew the whole script used to abort after the tools step, and bare
# `--only` exited 1 with no message at all.
[doc("Assert install.sh argument handling still fails loudly")]
cli-checks:
    #!/usr/bin/env bash
    set -euo pipefail
    ./install.sh --help >/dev/null

    if ./install.sh --only nosuchstep --yes 2>/dev/null; then
      echo "::error::unknown step name was accepted"; exit 1
    fi

    out="$(./install.sh --only 2>&1 || true)"
    case "$out" in
      *"needs a value"*) echo "ok  bare --only explains itself" ;;
      *) echo "::error::bare --only failed without a message: '$out'"; exit 1 ;;
    esac

# Everything fast enough to run on every commit. smoke is deliberately not a
# dependency here: it mutates a temp HOME and does real filesystem work, so
# it's a separate, slower step rather than baked into the default gate.
[doc("Every check fast enough to run on every commit")]
check: parse shellcheck zsh-syntax templates leakguard zed-filter help-coverage
