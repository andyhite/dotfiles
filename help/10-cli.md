## rg — ripgrep, the grep this repo's tools actually shell out to

A `grep` replacement that's `.gitignore`-aware by default, recurses automatically, and is fast
enough to search a whole monorepo without a `find` in front of it. It pairs with `fd` below —
same author, same `.gitignore`-respecting defaults, same ignore-file format — and nvim's
telescope `live_grep` picker shells out to it directly, so whatever `rg` finds on the command
line is exactly what telescope finds inside the editor.

    rg pattern                       # search recursively from the cwd, skipping .gitignore'd files
    rg -i pattern                    # case-insensitive
    rg -tpy pattern                  # restrict to one filetype (here, Python)
    rg -g '!vendor' pattern          # exclude a path glob without editing .gitignore
    rg -l pattern                    # list matching filenames only, no content
    rg -n -C3 pattern                # line numbers plus 3 lines of context on each side
    rg -e foo -e bar                 # match either of two patterns in one pass
    rg --hidden --no-ignore pattern  # search dotfiles and .gitignore'd content too

## fd — find, but fast and .gitignore-aware, pairs with rg

A `find` replacement with the same philosophy as `rg`: recurse from the cwd, respect
`.gitignore` by default, and use a sane simple syntax instead of `find`'s positional
predicates. It's what backs `FZF_DEFAULT_COMMAND` in this setup (see the shell help file's fzf
section), so `Ctrl+T`'s file list and telescope's `find_files` picker both walk the same
ignore-aware file set `fd` would print on its own.

    fd pattern         # find files/dirs whose name matches pattern, skipping .gitignore'd ones
    fd -e md           # restrict to one extension
    fd -t f pattern    # files only (-t d for directories, -t l for symlinks)
    fd -H pattern      # include hidden files (still skips .gitignore'd ones)
    fd -I pattern      # include .gitignore'd files too
    fd -d 2 pattern    # cap recursion depth
    fd -x rm {}        # execute a command per match, {} substitutes the path
    fd . -e log -X rm  # batch every match into a single command invocation

Gotcha: Debian/Ubuntu's `fd-find` package installs the binary as `fdfind`, not `fd` — if bare
`fd` comes back "command not found" on a Linux box, that's the package naming clash, not a
broken install.

## sd — find and replace, without sed's escaping tax

A `sed`-alternative built around one idea: find/replace shouldn't require memorizing which
characters need a backslash. `sd 's/old/new/' file` in sed becomes `sd old new file` — no
delimiter character to pick, so nothing inside the pattern or replacement ever needs escaping
because it happens to collide with `/`.

Its default match mode is still a real regex (Rust's `regex` crate, closer to PCRE than sed's
POSIX BRE/ERE dialects), so patterns with regex metacharacters behave like you'd expect from a
modern regex engine. Pass `-F`/`--fixed-strings` to treat the search term as a plain literal
instead — the sd equivalent of `grep -F` — which is the move when the string itself contains
regex-special characters you don't want interpreted.

    sd old new file            # regex replace (default mode), first arg is a pattern
    sd 'foo(bar)?' 'baz' file  # regex groups/quantifiers work with no delimiter to escape
    sd -F '(unread)' '' file   # --fixed-strings: treat the search term as a literal
    sd -i old new file         # in-place edit
    fd -e rs -x sd old new     # combine with fd: replace across every matching file
    echo 'a/b/c' | sd '/' '-'  # no delimiter clash — sed needs `s#/#-#` or an escape here

## jq — JSON query/transform, used by this repo's own scripts

A filter language for JSON: slice, map, and reshape a document from the command line instead of
round-tripping through a script. Listed in the Brewfile explicitly as a dependency of this
repo's own tooling, not just a nicety.

    jq '.' file.json            # pretty-print and validate
    jq -r '.field' file.json    # raw string output, no surrounding quotes
    jq '.[] | select(.x > 1)'   # filter an array by a field condition
    jq -c '.'                   # compact, one-object-per-line output
    jq 'keys'                   # list an object's top-level keys
    jq -n '{a: 1, b: 2}'        # build JSON from scratch, no input needed
    curl ... | jq '.data[].id'  # classic pipeline: pull ids out of an API response

## yq — jq for YAML, same filter syntax, YAML/JSON aware

The Go `yq` (mikefarah/yq), listed alongside `jq` as a Brewfile dependency of this repo's own
scripts. Same `jq`-style filter expressions, but reads and writes YAML natively — including
editing a file's formatting/comments in place rather than round-tripping it through JSON and
losing both.

    yq '.key' file.yaml                                 # read a value
    yq -i '.key = "value"' file.yaml                    # edit in place, preserving the rest of the file
    yq -o=json file.yaml                                # convert YAML to JSON
    yq -p=json -o=yaml file.json                        # convert JSON to YAML
    yq '.foo.bar[0]' file.yaml                          # index into nested maps/arrays, same syntax as jq
    yq ea '. as $i ireduce ({}; . * $i)' a.yaml b.yaml  # deep-merge two YAML files

## tree — directory tree listing, the real binary behind eza's alias

The plain `tree` binary, installed alongside eza in the Brewfile. Worth knowing it exists as
its own thing: this repo's `zshrc` aliases the *name* `tree` to `eza --tree --icons` (see the
shell help file's eza section), so typing `tree` at this repo's prompt runs eza, not this.
Reach for the real one with `command tree` when you specifically want its output or flags eza
doesn't have.

    command tree                         # bypass the eza alias, run the real tree binary
    command tree -L 2                    # limit depth to 2 levels
    command tree -a                      # include hidden (dotfile) entries
    command tree -d                      # directories only, no files
    command tree -I 'node_modules|.git'  # exclude paths matching a pattern
    command tree -C                      # force color even when output isn't a tty

## btop — full-screen resource monitor, replaces top/htop

A `top`/`htop` replacement with per-core CPU graphs, memory/swap/disk/network panels, and a
searchable, sortable, killable process tree, all mouse- and keyboard-driven. Nothing in this
repo configures it — it's a Brewfile install, used at its defaults.

    btop              # launch the full-screen monitor
    btop --utf-force  # force UTF8 box-drawing on a terminal that mis-detects locale
    f                 # in-app: filter the process list by name
    k                 # in-app: send a signal to the selected process
    t                 # in-app: toggle tree view of the process list
    + / -             # in-app: zoom a panel in/out
    q                 # in-app: quit

## ncdu — interactive disk usage, find what's eating space

`du` with a navigable TUI on top: scans a directory tree once, then lets you drill into the
biggest offenders and delete right from the list — the tool for "why is this disk full" instead
of squinting at `du -sh */` output.

    ncdu                     # scan and browse the current directory
    ncdu /                   # scan from root (needs sudo to see everything)
    ncdu -x /                # stay on one filesystem, skip mounted volumes
    ncdu -o scan.ncdu /path  # export a scan to reopen later, without re-scanning
    ncdu -f scan.ncdu        # browse a previously exported scan
    d                        # in-app: delete the selected file/directory — irreversible

Gotcha: `d` deletes immediately with no confirmation prompt in some builds — know what's
selected before pressing it.

## hyperfine — command-line benchmarking with statistics, not a stopwatch

Runs a command repeatedly, warms it up, and reports mean/stddev/min/max instead of the single
noisy number `time` gives you — the difference between "cmd A looked faster" and "cmd A is
faster, here's the confidence interval."

    hyperfine 'cmd'                                   # benchmark one command, auto-picks a run count (min 10)
    hyperfine 'cmd1' 'cmd2'                           # benchmark two commands and rank them
    hyperfine --warmup 3 'cmd'                        # discard cache-cold runs before timing starts
    hyperfine --min-runs 20 'cmd'                     # force at least 20 timed runs
    hyperfine --prepare 'make clean' 'make'           # run a setup command before every timed run
    hyperfine --export-markdown out.md 'cmd1' 'cmd2'  # write a results table for a PR/doc

## tldr — example-first man pages, via the tealdeer client

`man`, but example-first: a handful of the commands people actually run instead of a full flag
reference. `tealdeer` is the Rust client (binary `tldr`) — fast, local cache, no network round-
trip once seeded.

    tldr tar           # example-first cheatsheet for a command
    tldr -u            # update the local page cache
    tldr -l            # list every page in the cache
    tldr -c            # clear the local cache
    tldr -p linux tar  # force a specific platform's page instead of auto-detecting
    tldr --show-paths  # show where tealdeer keeps its cache and config

## watchexec — rerun a command when files change

Watches a path (or the cwd) and reruns a command on every filesystem change — a generic
"rebuild/retest on save" that doesn't care what language or build tool is on the other end.

    watchexec -- cargo test                # rerun on any change under the cwd
    watchexec -e rs,toml -- cargo build    # restrict to specific extensions
    watchexec -w src -- npm run build      # watch a specific directory instead of the cwd
    watchexec --restart -- node server.js  # SIGTERM + restart a long-running process on change
    watchexec -c -- pytest                 # clear the screen before each run

## fswatch — low-level filesystem event stream, feeds shell pipelines

Prints filesystem events (or a trigger token) to stdout instead of running a command itself —
the building block for a custom watch pipeline when `watchexec`'s built-in command-running
isn't the right shape.

    fswatch -o . | xargs -n1 make  # -o batches events into one trigger per xargs call
    fswatch -r dir                 # recurse into subdirectories
    fswatch -x .                   # print event flags (Created, Updated, Removed, Renamed, ...)
    fswatch -e '\.git/' .          # exclude a path pattern from triggering events
    fswatch -l 0.5 .               # set the event-batching latency in seconds

## just — the Justfile is this repo's single source of truth for checks

A `make`-like command runner with none of make's file-target semantics — recipes are just named
shell scripts. This repo's `Justfile` is what CI actually calls, so it's also the fastest way
to run any single check locally instead of re-deriving the right `shellcheck`/`zsh -n`/smoke-
test invocation from `AGENTS.md` by hand.

    just                # no recipe given — lists every recipe (the default)
    just check          # run every check below, in order — what CI calls
    just parse          # bash -n install.sh
    just shellcheck     # shellcheck -S warning -e SC2088,SC2206 install.sh
    just zsh-syntax     # zsh -n over zshrc, zshenv, zshrc.local.example
    just templates      # sanity-check the *.example templates install.sh copies
    just leakguard      # grep committed content for the work-identifier patterns CI blocks on
    just zed-filter     # verify the git clean filter that strips Zed's ssh_connections works
    just help-coverage  # verify every tracked tool has a section under help/
    just smoke          # link the whole tree into a throwaway HOME twice, check idempotency
    just cli-checks     # install.sh --help, --only nosuchstep fails, bare --only self-explains


## glow — terminal markdown renderer for dotfiles-help

Charm's markdown renderer. `dotfiles-help` pipes each section through `glow -s dark -w 0` so
headings, emphasis, and comments on indented command examples read like a doc instead of raw
source. `bat` only syntax-highlights markdown when glow is absent; set `NO_COLOR` to force plain
text.

    glow README.md                   # render a file in the terminal
    glow -s dark -w 0 -              # read markdown from stdin; -w 0 keeps examples from reflowing
    dh fd                            # dotfiles-help uses glow automatically when on PATH

## dotfiles-help — this command; what every tool here is for

The front door to this whole toolchain, and the thing you are reading right now. It renders the
`help/*.md` corpus in this repo through `glow` when installed (falls back to `bat` or plain text),
which carries one section per tracked tool explaining what it is, why it is installed HERE, and
the handful of commands worth knowing. `bin/dotfiles-help` is
symlinked onto `PATH` by `install.sh`'s configs step and resolves its own real path back to the
corpus, so it works from anywhere.

    dotfiles-help                  # fzf picker over every tool, with the section as a preview
    dh                             # the zshrc alias for the same thing
    dotfiles-help fd               # print one tool's section; substring match if no exact hit
    dotfiles-help --list           # grouped by category (A–Z), tools A–Z within each
    dotfiles-help --all            # the whole corpus, in curated order
    dotfiles-help --search rebase  # search every section body, list the sections that matched
    just help-coverage             # fail if a Brewfile entry has no matching help section

Gotcha: the corpus format is load-bearing, not cosmetic. A section is `## <name> — <tagline>`
with a real em dash, and its examples are indented by exactly four spaces. Reflow a heading or
convert the examples to a fenced code block and the parser silently stops seeing that tool.

## cloc — count lines of code, by language

Counts code/comment/blank lines per language across a tree, correctly excluding generated and
vendored files it recognizes — the tool for "how big is this codebase, really" instead of a raw
`wc -l **/*`.

    cloc .                                  # count everything under the cwd, broken down by language
    cloc --exclude-dir=node_modules,.git .  # drop directories that would skew the count
    cloc --by-file .                        # per-file breakdown instead of per-language totals
    cloc --diff old/ new/                   # lines added/removed/modified between two trees
    cloc --vcs=git .                        # let git list the files instead of walking the tree directly

## rsync — the copy tool that only transfers what changed

Compares source and destination and transfers only the diff, so a repeat run of the same
command is fast and safe to re-issue after a network drop. Three flag combinations are worth
having memorized rather than looked up each time:

    rsync -avz src/ dst/                    # archive (recurse+perms+times+links+owner) + verbose + compress
    rsync -avzn src/ dst/                   # dry run first — see exactly what -a would do, nothing moves yet
    rsync -avz --delete src/ dst/           # mirror: dst becomes byte-identical, deleting what src lost
    rsync -avzP src/ dst/                   # adds partial+progress — resumable, with a live transfer meter
    rsync -avz -e ssh src/ user@host:dst/   # same guarantees, over ssh instead of local paths
    rsync -avz --exclude='.git/' src/ dst/  # skip a path pattern entirely

Gotcha: the trailing slash on the source is load-bearing. `src/` copies src's *contents* into
dst; `src` (no slash) copies the `src` directory itself into dst, one level deeper than you
probably meant. `-n`/`--dry-run` is the way to check before trusting `--delete`.

## wget — non-interactive downloader, resumable and scriptable

A plain HTTP(S)/FTP downloader built for scripts and unattended runs: resumable transfers,
recursive mirroring, no interactivity required. `install.sh`'s Linux branch uses it as one of
its own download tools.

    wget <url>                              # download to the current directory, filename from the URL
    wget -O out.tar.gz <url>                # save under a specific name
    wget -c <url>                           # resume a partial download instead of restarting it
    wget -q <url>                           # quiet — no progress output, useful inside a script
    wget -r -np -nH <url>                   # recursive mirror, no parent dir traversal, no host-dir prefix
    wget --mirror -p --convert-links <url>  # full-site mirror with working local links

## moreutils — small unix tools that plug real pipeline gaps

A grab-bag package, not one command — each of these fills a specific hole in the standard
toolset rather than replacing anything.

    cmd file | sponge file   # sponge: soak up all of stdin, then write it — safe to read+rewrite one file
    cmd | ts                 # ts: timestamp every line of piped output as it arrives
    cmd | vipe | cmd2        # vipe: pause a pipeline, edit the in-flight data in $EDITOR, resume
    cmd | ifne wc -l         # ifne: only run the next command if stdin actually produced output
    errno ENOENT             # errno: look up an errno name/number and its strerror message
    combine a.txt and b.txt  # combine: set operations (and/or/not/xor) between two files' lines

## coreutils — GNU coreutils on macOS, installed g-prefixed

macOS ships BSD's `ls`/`date`/`sed`/`stat`/`readlink`, which differ from GNU's in flags and
sometimes behaviour. Homebrew's `coreutils` formula installs the GNU versions g-prefixed
(`gls`, `gdate`, `gsed`, `gstat`, `greadlink`, ...) rather than shadowing the system binaries
outright — the same reasoning `zshrc` already applies to `make`/`gmake` (see the shell help
file). This repo doesn't put coreutils' `gnubin` directory on `PATH`, so BSD's tools stay the
defaults; reach for the GNU one by its g-prefixed name when you need a GNU-only flag.

    gdate -d '1 day ago'       # GNU date's relative-time parsing — BSD date needs -v-1d instead
    gsed -i 's/foo/bar/' file  # GNU sed's real in-place edit, no macOS -i '' quirk
    greadlink -f path          # GNU readlink's -f (resolve symlinks) — macOS readlink has no -f
    gstat --format='%s' file   # GNU stat's --format, not macOS stat's -f
    gls --color=auto -la       # GNU ls long-listing, if the eza-backed ls alias is ever bypassed
