## mise — version manager for node, python, go, bun and pnpm

Replaces asdf: one binary instead of a plugin per language, and it activates
by rewriting `PATH` on every prompt (`eval "$(mise activate zsh)"` in
`zshrc`) instead of installing shims — so a version change takes effect in
the shell you're standing in, with no `reshim` step to remember.

Pins live in this repo's `tool-versions`, symlinked to `~/.tool-versions`.
mise walks UP from the current directory to `$HOME` and beyond, so that file
is the global default for everything under `$HOME` — but a project's own
`.tool-versions` or `mise.toml` still wins whenever one exists, taking the
nearest file rather than this one.

    mise install                          # install every pin from this repo's tool-versions
    mise ls --current                     # show what's active here and where each pin comes from
    mise use node@22                      # pin THIS project only (writes ./mise.toml, wins locally)
    mise exec python@3.11 -- python -V    # run one command against a version without writing a pin
    mise trust                            # trust a project's mise.toml so its tasks/templates can run
    mise doctor                           # diagnose PATH/activation when a version isn't taking effect

Gotcha: `mise use --global` does not touch this repo's `tool-versions` — it
writes a *second* global config at `~/.config/mise/config.toml`. To change
the machine-wide default, edit `tool-versions` in this repo directly and
rerun `mise install`; that keeps one file as the source of truth instead of
two global configs that can disagree.

## node — javascript/typescript runtime

Pinned at 26.7.0 in `tool-versions`. mise's canonical tool name is `node`,
not asdf's `nodejs`.

    node --version                 # confirm the pinned mise version is active
    node script.js                 # run a script directly
    node --watch server.js         # restart automatically on file change
    node --env-file=.env app.js    # load environment variables without a separate loader
    node --experimental-strip-types app.ts   # run a plain .ts file with no build step

## pnpm — node package manager

Pinned at 11.20.0 in `tool-versions`; `zshrc` derives `PNPM_HOME` per-OS and
puts it on `PATH` when it exists.

    pnpm install                   # install a project's dependencies
    pnpm add <pkg>                 # add a dependency
    pnpm run <script>              # run a package.json script
    pnpm dlx <pkg>                 # fetch and run a package without adding it as a dependency
    pnpm up                        # update dependencies within their declared ranges

## bun — fast js runtime, bundler and test runner

Pinned at 1.3.14 in `tool-versions`. `zshrc` sources `~/.bun/_bun` for
completions and puts `~/.bun/bin` on `PATH`.

    bun run ./script.ts            # execute a file directly, no separate ts-node step
    bun install                    # install dependencies (drop-in for npm/pnpm install)
    bun test                       # run the built-in test runner
    bun --watch run dev            # restart on file change
    bunx <pkg>                     # run a package binary, installing it if needed

## python — CPython runtime

Pinned at 3.14.7 in `tool-versions` — the normal GIL build. A trailing `t`
(e.g. `3.14.7t`) would instead select the free-threaded build; that's a
different, opt-in variant, not a typo, so don't "fix" it if you see it pinned
that way in a project.

    python3 --version              # confirm the pinned mise version is active
    python3 -m venv .venv          # create a plain stdlib virtualenv
    python3 -m http.server         # quick static file server for local testing
    python3 -i script.py           # run a script, then drop into a REPL with its state

For anything beyond the stdlib basics above, reach for `uv` — see below.

## uv — fast python package and project manager

Astral's single binary for Python packaging: replaces `pip` + `venv` +
`pip-tools` + (per below) `pipx` with one dependency resolver written in
Rust. Not pinned by mise; installed via the official installer
(`curl -LsSf https://astral.sh/uv/install.sh | sh`), which drops it and its
env script into `~/.local/bin`.

    uv run script.py               # run a script, auto-creating/reusing its own environment
    uv add <pkg>                   # add a dependency to the current project's pyproject.toml
    uv sync                        # install a project's environment to match its lockfile exactly
    uv venv                        # create a virtual environment (uv's replacement for python -m venv)
    uv pip install <pkg>           # pip-compatible interface, for scripts that still expect pip
    uv tool install <pkg>          # install a CLI tool into its own isolated environment, on PATH
    uvx <pkg>                      # run a tool once without installing it (uv's pipx run / npx)
    uv python install 3.13         # download a Python build uv manages itself, independent of mise

`uv tool install`/`uvx` supersede pipx here — for a new tool, install it with
uv, not pipx.

## pipx — isolated python CLI installs (legacy)

Still on the Brewfile only so tools it already installed keep working; see
`uv` above, which supersedes it for anything new.

    pipx list                      # see what's still installed through pipx
    pipx upgrade <pkg>             # upgrade one pipx-managed tool
    pipx uninstall <pkg>           # remove a pipx-managed tool
    pipx ensurepath                # make sure ~/.local/bin is on PATH (mise/zshrc already do this)

## go — go runtime and toolchain

Pinned at 1.26.5 in `tool-versions`. `zshrc` puts `$GOBIN` (or
`$GOPATH/bin`, defaulted to `~/go/bin` without shelling out to `go env`) on
`PATH` whenever `go` is present.

    go run .                       # build and run the current package
    go build ./...                 # build every package in the module
    go test ./...                  # run tests across the module
    go install <pkg>@latest        # install a binary to $GOBIN/$GOPATH/bin
    go mod tidy                    # sync go.mod/go.sum with actual imports

## rust — rustc and cargo toolchain (Homebrew on macOS, rustup on Linux)

Installed via the Brewfile's plain `rust` formula on macOS, which provides
`rustc` and `cargo` but not the `rustup` toolchain manager, and via `rustup`
on Linux (`ensure_rustup` in `install.sh`, which only runs when `cargo`
isn't already on `PATH` — so it never fires on macOS, where Homebrew already
put `cargo` there). Not mise-managed: cargo has to exist before any
cargo-installed tool can be built, so on Linux it doubles as a bootstrap
dependency, not just a dev tool — `install.sh` falls back to
`cargo install --locked` for any tool with no apt package (delta,
difftastic, git-absorb, sd, tealdeer, hyperfine, fd, jj; see `cargo` below
for the commands that come with either install path).

    rustc --version                      # confirm the compiler version — works on both platforms
    cargo --version                      # confirm the cargo version — works on both platforms
    rustup show                          # Linux only: which toolchain is active/installed
    rustup update                        # Linux only: update the active toolchain
    rustup component add rust-analyzer   # Linux only: add a component the LSP/editor needs
    rustup target add <target>           # Linux only: add a cross-compilation target

Gotcha: every `rustup ...` command above fails with "command not found" on
macOS — the Brewfile's `rust` formula installs the compiler and Cargo, not
rustup itself. Need rustup on a Mac (a second toolchain, a cross target)?
Install it separately; it doesn't come along with `brew install rust`.

## cargo — rust's package manager and build tool

Rust's package manager and build tool, bundled with whichever install path
the `rust` entry above describes — the Brewfile's plain formula on macOS,
`rustup` on Linux — so it's present anywhere `rustc` is, with no separate
cargo install step of its own. It's also this bootstrap's fallback package
manager: `cargo install --locked` is exactly what `install.sh` runs to
build any tool that has no apt package on Linux.

    cargo build                    # compile the current package
    cargo run                      # build and run the current package's binary
    cargo test                     # run tests
    cargo add <crate>              # add a dependency to Cargo.toml
    cargo install --locked <crate> # install a binary crate, pinned to its lockfile's versions
    cargo check                    # type-check without producing binaries, faster than build

## cmake — cross-platform build system generator

Pulled in for whatever C/C++ project needs it; nothing in this repo depends
on it directly.

    cmake -S . -B build            # configure a build directory from a source tree
    cmake --build build            # build using whichever generator was configured
    cmake --build build --target <name>   # build a single target
    cmake --build build -j         # parallel build across available cores
    cmake -LAH                     # list every cached variable with its help text
    ccmake .                       # interactive curses config editor, if installed alongside

## make — build automation, aliased to a modern `gmake` on macOS

macOS ships GNU make 3.81 (2006) as both `make` and `gnumake` — the obvious
`alias make=gnumake` is a no-op. Homebrew's make installs as `gmake` (4.x)
instead, so `zshrc` aliases `make` to `gmake` on Darwin when it's present;
Linux gets a modern make from apt directly.

    make                            # run the default target
    make <target>                   # run a specific target
    make -n <target>                # dry run, print the commands without running them
    make -j4                        # run independent targets in parallel
    make -k                         # keep going past a failed target instead of stopping
    make -C <dir> <target>          # run against another directory's Makefile without cd'ing

## shellcheck — shell script static analysis

A config dependency, not merely a CLI convenience: `AGENTS.md`'s verify step
runs it against `install.sh`, and `config/nvim/lua/configs/lint.lua` wires it
as the linter for `sh`/`bash` filetypes via nvim-lint.

    shellcheck script.sh            # lint a script
    shellcheck -S warning script.sh # only report warning severity and above
    shellcheck -f diff script.sh    # emit a patch-style diff of suggested fixes
    shellcheck -x script.sh         # follow `source` statements outside the given files
    shellcheck -e SC2088 script.sh  # exclude a specific check by code

## shfmt — shell script formatter

Formats the same scripts shellcheck lints. `config/nvim/lua/configs/conform.lua`
wires it as the formatter for `sh`/`bash` filetypes.

    shfmt -l script.sh              # list files whose formatting would change
    shfmt -d script.sh              # show a diff instead of rewriting
    shfmt -w script.sh              # rewrite the file in place
    shfmt -i 2 -w script.sh         # rewrite with 2-space indent instead of tabs
    shfmt -s -w script.sh           # simplify redundant syntax while rewriting
    shfmt -p -d script.sh           # check against POSIX sh instead of bash

## golangci-lint — go linter aggregator

Runs many individual Go linters (vet, staticcheck-style checks, and more)
through one config and one invocation.

    golangci-lint run                # lint the current module
    golangci-lint run ./...          # lint every package explicitly
    golangci-lint run --fix          # apply auto-fixes where a linter supports them
    golangci-lint linters            # list which linters are enabled by the current config
    golangci-lint fmt                # format go source files

## clang-format — C/C++/Objective-C formatter

Sits in the Brewfile the same way `cmake` does: a general-purpose
formatter for whatever C/C++/Objective-C project needs it, with nothing in
this repo's own config wiring it into an editor or a lint step the way
`shfmt`/`shellcheck` are wired for shell scripts.

    clang-format -i file.c           # rewrite a file in place
    clang-format --dry-run file.c    # print without writing, exit non-zero if it would change
    clang-format --style=file file.c # use the nearest .clang-format instead of the LLVM default
    clang-format --Werror file.c     # fail instead of warn when formatting would change the file
    clang-format --assume-filename=x.h - < file  # format stdin, guessing language from a name

## nvim — neovim, configured as NvChad v2.5

`config/nvim` is a full NvChad v2.5 config: `chadrc.lua` sets the base46
theme (`onedark`); `mappings.lua` layers this repo's bindings on top of
NvChad's own; `plugins/init.lua` wires conform.nvim, nvim-lspconfig,
nvim-lint and a telescope override on top of NvChad's plugin set.

Leader is `<Space>` (NvChad's default, unchanged here). Bindings added in
`mappings.lua`: `;` enters command mode (`:`), and `jk` in insert mode is
`<ESC>`. `herdr-nav` loads last so its `<C-h/j/k/l>` window navigation wins
inside a herdr pane, replacing NvChad's own `<C-w>h/j/k/l` mappings there.

LSP servers enabled in `lspconfig.lua`: html, cssls, ts_ls, eslint, oxlint,
tailwindcss, basedpyright, ruff (project-gated — only starts where a
`ruff.toml`/`[tool.ruff]` is found), gopls, rust_analyzer, yamlls, jsonls,
taplo, sqls, dockerls, marksman, bashls. `:MasonInstallAll` is what actually
installs them — run it after any change to that list.

    :MasonInstallAll                 # install every LSP server named in lspconfig.lua
    :LspInfo                         # see which servers are attached to the current buffer
    :ConformInfo                     # see which formatter conform.nvim picked for this buffer
    :DiffviewOpen                    # open the diffview.nvim status view for the current repo
    :DiffviewClose                   # close it
    :DiffviewFileHistory %           # file history for the current buffer
    :DiffviewFileHistory             # file history for the whole repo
    <leader>gd                       # diffview: open against the index (mappings.lua)
    <leader>gc                       # diffview: close
    <leader>gh                       # diffview: file history for the current file
    <leader>gH                       # diffview: file history for the whole branch

Formatters live in `configs/conform.lua`: stylua for lua, prettier for the
web/JSON/YAML/markdown filetypes (resolved from each project's own
`node_modules/.bin`, so a project's own `.prettierrc` and plugins apply),
shfmt for sh/bash, and a project-sniffing picker for python that chooses
`ruff_organize_imports`/`ruff_format` where a project uses ruff and
`isort`/`black` otherwise. Format-on-save is currently commented out (the
`format_on_save` block in `conform.lua`, and the `event = 'BufWritePre'`
line in `plugins/init.lua`'s conform.nvim spec) — uncomment both to turn it
on; format-on-demand still works either way via `:ConformInfo` /
the format keymap NvChad wires by default.

Linters live in `configs/lint.lua`: markdownlint for markdown, shellcheck
for sh/bash. They run on `BufReadPost`/`BufWritePost`/`InsertLeave`, not
continuously — nvim-lint only lints when asked, which those autocmds do for
you.

The telescope git_status picker gets one override in `plugins/init.lua`:
`<C-g>` (not the reserved `<C-r>` prefix) closes and reopens the picker to
force a re-scan, because `git_status` builds its list once at open and never
notices later edits.

NvChad core bindings worth knowing day to day: `<leader>th` opens the theme
picker, `<C-n>` toggles the file tree, `<leader>ff`/`<leader>fw` open
telescope find-files/live-grep, and the tabufline along the top switches
buffers with `<leader>x` to close one and `Tab`/`Shift-Tab` (or the mouse) to
move between them.

## tree-sitter — parser generator CLI

NvChad needs the `tree-sitter` CLI on `PATH` for `:TSInstall` and highlight
queries beyond what the bundled runtime provides; `install.sh`'s
`ensure_tree_sitter_cli` fetches it from GitHub releases where no package
manager ships it, and `ensure_completions` generates its zsh completion file
since upstream provides none.

    tree-sitter generate            # regenerate a parser's C sources from grammar.js
    tree-sitter parse file.ext      # parse a file and print its syntax tree
    tree-sitter test                # run a parser's corpus tests
    tree-sitter build               # compile a parser to a loadable library
    tree-sitter highlight file.ext  # print syntax highlighting using the grammar's queries

## zed — GUI editor

`config/zed/settings.json` sets: `disable_ai` true (agents run from the
terminal via omp, not inside the editor), vim mode with the VSCode base
keymap, One Dark/One Light themes matching the rest of this repo's palette,
Monaspace Neon as the buffer font (from the Brewfile's `font-monaspace`
cask), the material-icon-theme extension force-installed, telemetry off, and
per-language TypeScript formatting through `npx prettier` plus ESLint/
organize-imports code actions on save.

Gotcha: `ssh_connections` is deliberately absent from the tracked file. Zed
rewrites that key into `settings.json` on every remote connect, and this
file is symlinked straight into a public repo — so without a filter, real
hostnames and work project paths would land in git history. `.gitattributes`
marks `config/zed/settings.json filter=zed-local`, and `install.sh`'s hooks step registers
that filter (`git config filter.zed-local.clean 'awk -f bin/zed-settings-clean'`)
so `ssh_connections` is stripped on the way into the index, not on disk —
the live file on your machine keeps the key, only what git sees is cleaned.

    zed .                            # open the current directory
    zed --wait file.txt              # block until the buffer is closed (for $EDITOR-style use)
    zed -n path/to/file              # open a file/folder in a new window
    zed path/to/file:42:5            # open a file at a given line:column
    zed: open default settings       # command palette entry to diff against your overrides

## docker — container runtime (Docker Desktop)

Newly tracked via `cask "docker-desktop"` in the Brewfile, with
`args: { adopt: true }` so `brew bundle` adopts an existing
`/Applications/Docker.app` instead of aborting because it's already there.
`zshrc` adds `~/.docker/completions` to `fpath` when present. dive and ctop
below were already in the Brewfile but useless without a container runtime
on the machine — docker is what makes them do anything.

    docker ps                        # list running containers
    docker run -it <image> sh        # run a container interactively
    docker build -t <tag> .          # build an image from a Dockerfile
    docker exec -it <container> sh   # shell into a running container
    docker compose up                # bring up a compose stack
    docker system prune              # reclaim disk space from stopped containers/dangling images

## dive — docker image layer explorer

Walks an image's layers to show what each one added and estimates wasted
space (files overwritten or deleted by a later layer, still taking up disk).

    dive <image>                     # open the interactive TUI for an image
    dive build -t <tag> .            # build a Dockerfile then immediately analyze the result
    dive --ci <image>                # non-interactive, exits non-zero past the efficiency threshold
    dive --json out.json <image>     # skip the TUI, write layer/waste stats to a file
    dive --source podman <image>     # analyze an image pulled through podman instead of docker

## ctop — live container metrics TUI

`top`, but for containers: per-container CPU, memory, network and I/O in one
scrolling view instead of `docker stats`'s fixed columns.

    ctop                             # show every container
    ctop -a                          # active containers only
    ctop -f <name>                   # filter to containers matching a name
    ctop -s cpu                      # sort by CPU usage
    ctop -r                          # reverse the current sort order
    ctop -i                          # invert colors, for a light terminal theme

## dstack — GPU-cloud task/dev-environment orchestrator

Installed via `uv tool install dstack` on both OSes (no Homebrew formula, no
apt package). Backend credentials (RunPod, here) live in
`~/.dstack/server/config.yml`, templated from `dstack/server/config.yml.example`
— see README's `*.local` templates section — because that file holds a real
API key. The client config `~/.dstack/config.yml` (project token + server
URL) is left untracked: `dstack server` regenerates it, so there's nothing
meaningful to template.

    dstack server                    # start the local control-plane server
    dstack apply -f .dstack.yml      # provision a run from a task/dev-environment spec
    dstack ps                        # list current runs and their status
    dstack stop <run-name>           # stop a run
    dstack fleet list                # list configured fleets (backends, SSH)

`install.sh`'s `services` step enables `dstack server` to start at login and
run in the background — a launchd `LaunchAgent` on macOS
(`~/Library/LaunchAgents/ai.dstack.server.plist`), a systemd `--user` unit on
Linux (`~/.config/systemd/user/dstack-server.service`). Re-run it directly
with `./install.sh --only services`. Manual equivalents:

    launchctl load -w ~/Library/LaunchAgents/ai.dstack.server.plist   # macOS: start now + at login
    launchctl unload -w ~/Library/LaunchAgents/ai.dstack.server.plist # macOS: stop + disable
    systemctl --user enable --now dstack-server                      # Linux: start now + at login
    systemctl --user disable --now dstack-server                     # Linux: stop + disable

## op — 1Password CLI

Installed via the Brewfile's `1password-cli` cask, but not currently wired
into any tracked config — no tracked file shells out to it today. It's
documented here for the one real integration point this repo's own
comments already call out:

`omp/agent/models.yml.example` shows the pattern for a provider header that
needs a secret without ever writing the secret to disk:
`x-api-key: "!op read op://vault/item/field"` — the leading `!` tells omp to
run the command and use its output as the header value.

    op signin                        # authenticate this shell against your account
    op read op://vault/item/field    # print one secret value, for use in a command substitution
    op run --env-file .env -- <cmd>  # run a command with secret references resolved into its env
    op item get <name>               # fetch full item details (fields, not just one value)
    op whoami                        # confirm which account/vault you're signed into

## tailscale — mesh VPN CLI

`bin/tailscale` in this repo is a shim, not a plain wrapper: the Mac App
Store build of Tailscale hides its CLI inside the app bundle instead of
putting it on `PATH`, and a plain symlink doesn't work around that either —
the binary resolves its own app bundle from `argv[0]`, so invoking it
through a symlink named `tailscale` fails at runtime. The shim `exec`s the
absolute path inside `Tailscale.app` instead, which keeps `argv[0]` pointed
at the real bundle.

    tailscale status                 # show connection state and every peer on the tailnet
    tailscale ip                     # print this machine's tailnet IP addresses
    tailscale ping <host>            # check reachability and see how traffic is routed to a peer
    tailscale ssh <host>             # SSH to a tailnet machine using Tailscale's own auth
    tailscale up                     # connect (and log in, if needed)
    tailscale netcheck               # diagnose local network conditions (NAT, DERP relay, etc.)

## caddy — local HTTPS for internal-only dev hostnames

Base Caddyfile `caddy/Caddyfile` is just `local_certs` plus an `import` of
`/opt/homebrew/etc/Caddyfile.local` — machine-local, created once from
`caddy/Caddyfile.local.example`, never tracked, since real site blocks
name real internal hostnames and IPs. `local_certs` mints certs from Caddy's
own built-in CA instead of Let's Encrypt, which could never issue for a
non-public hostname. See the README's Caddy section for the full recipe,
including a regex-matched wildcard block for `<service>-<port>` hostnames.

    brew services start caddy                                # start it (not automatic — install.sh only lays down config)
    caddy trust --config /opt/homebrew/etc/Caddyfile          # one-time: install the local CA into your keychain
    caddy reload --config /opt/homebrew/etc/Caddyfile         # apply edits to Caddyfile.local, no dropped connections

## dnsmasq — wildcard local DNS via macOS's per-domain resolver

Base config `dnsmasq/dnsmasq.conf` binds loopback-only on port 5453 (not 53, so
`brew services start dnsmasq` never needs root) and reads the actual domain
records from `/opt/homebrew/etc/dnsmasq.local.conf` — machine-local, created
once from `dnsmasq/dnsmasq.local.conf.example`, never tracked. Pair a domain
there with a matching `/etc/resolver/<domain>` file so macOS sends only that
domain's lookups to dnsmasq; every other query keeps using normal DNS. See
the README's dnsmasq section for the full two-file recipe.

    brew services start dnsmasq       # start it (not automatic — install.sh only lays down config)
    brew services restart dnsmasq     # reload after editing dnsmasq.local.conf
    dig @127.0.0.1 -p 5453 <host>     # check what dnsmasq itself resolves a name to
    dscacheutil -q host -a name <host> # check what apps/browsers actually resolve it to

Plain `dig <host>` (no `@server`) reads `/etc/resolv.conf` directly and skips
macOS's `/etc/resolver/<domain>` split-DNS entirely, so it can go to whatever
your default resolver is (Tailscale's, if that's active) and report
`NXDOMAIN` even when everything is actually configured correctly.
`dscacheutil` uses the same resolution path apps do — trust that one.
