## zsh — the shell itself, configured in zshrc and zshenv

The interactive shell everywhere this repo is linked. `zshenv` carries only PATH — it's read by
every zsh, interactive or not, including one-shot `ssh host 'cmd'` runs and git hooks, so
anything heavier than PATH setup has no business living there. `zshrc` carries everything else:
completion, antidote's plugin load, history, aliases, and every tool init hook below.

History is tuned for a machine that runs many concurrent shells (tmux panes, agent sessions):
`SHARE_HISTORY` writes and re-reads the histfile live instead of only at exit, so a command
from one pane shows up in another pane's search right away. `HIST_IGNORE_ALL_DUPS` drops older
duplicates rather than just adjacent ones, so a frequently repeated command stops cluttering
`Ctrl+R`. `HIST_IGNORE_SPACE` means a leading space keeps a command out of history entirely —
the escape hatch for a one-off with a secret in it. `HIST_VERIFY` expands a recalled history
line into the buffer for a second look instead of running it blind, which matters most for the
destructive command you edited slightly wrong.

`AUTO_CD` means typing a bare directory name (`..`, `~/dotfiles`) `cd`s into it — no `cd`
needed. `EXTENDED_GLOB` turns on `~`/`^`/`#` glob qualifiers (`rm ^*.keep`, `ls *.log(.)`),
which several completion and plugin scripts assume are available.

    setopt SHARE_HISTORY         # cross-pane history, written and read live
    setopt HIST_IGNORE_ALL_DUPS  # keep only the newest copy of a repeated command
    setopt HIST_IGNORE_SPACE     # a leading space keeps that command out of history
    setopt HIST_VERIFY           # recalled history expands into the buffer, doesn't run blind
    setopt AUTO_CD               # bare `../dir` or `~/project` changes directory
    setopt EXTENDED_GLOB         # enables `~`/`^`/`#` glob qualifiers
    zsh -n path/to/script.zsh    # check a script for syntax errors without running it
    zsh -f                       # start without zshrc/zshenv — isolate a config-load bug
    history | grep <cmd>         # grep the histfile directly, bypassing atuin
    fc -e - <cmd>                # edit and rerun the last command matching <cmd>

Gotcha: `HIST_IGNORE_SPACE` only hides a command going forward — it's not retroactive, and it
doesn't touch atuin's own database (atuin records everything zsh runs, leading space or not;
see the atuin section below for its own filters).

## antidote — the zsh plugin manager, replacing oh-my-zsh

A static-file plugin manager: `zsh_plugins.txt` (symlinked to `~/.zsh_plugins.txt`) lists one
`owner/repo` per line, and `zshrc` sources antidote then runs `antidote load
~/.zsh_plugins.txt` once compinit has already run. No plugin framework, no lazy-load DSL, no
config beyond that one file — antidote clones each repo under `~/.antidote` and sources it, in
file order, every shell start.

Currently four plugins: zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, and zsh-vi-mode
— each gets its own section below. Order in the file matters for a couple of these (syntax-
highlighting wants to load after anything that wraps widgets, vi-mode wants to load last so its
`precmd` hook is the final say on keymaps).

    $EDITOR zsh_plugins.txt           # add a plugin — one `owner/repo` per line
    exec zsh                          # reload so antidote clones and sources the new line
    antidote load ~/.zsh_plugins.txt  # what zshrc runs — (re)load every plugin in the file
    antidote list                     # show every plugin antidote currently has loaded
    antidote bundle owner/repo        # clone+source one plugin ad hoc, outside the file
    antidote path owner/repo          # print a plugin's local clone path under ~/.antidote
    rm -rf $(antidote path owner/repo)  # force that plugin to re-clone on the next shell

## zsh-autosuggestions — ghost-text suggestions from history as you type

Suggests the rest of a line as dim grey text, sourced from history and completions, the moment
you start typing. One of antidote's four plugins in `zsh_plugins.txt` — no local config beyond
that.

    →                               # accept the whole suggestion
    End                             # same as →, from anywhere on the line
    Ctrl+→                          # accept just the next word of the suggestion
    Ctrl+G                          # dismiss the current suggestion
    (keep typing)                   # suggestion narrows or disappears as it stops matching
    echo $ZSH_AUTOSUGGEST_STRATEGY  # show the active strategy (default: history)

## zsh-syntax-highlighting — live syntax coloring of the command line

Colors the command line as you type it — green for a command that resolves on `PATH`, red for
one that doesn't, quoting/bracket matching, and so on — the same trust-your-eyes signal fish
gives before you ever hit Enter. Another of antidote's four plugins, no local config.

    (type a real command)             # renders green once the binary resolves on PATH
    (type a typo'd command)           # renders red — a signal to check the name before Enter
    (type a quoted string)            # highlights matching quotes/brackets as you close them
    (type an existing path)           # underlines a path once it actually resolves on disk
    echo $ZSH_HIGHLIGHT_HIGHLIGHTERS  # show which highlighters are active (default: main)

Gotcha: it must load after any plugin that wraps `zle` widgets (it re-wraps them itself to hook
redraws), which is part of why it sits ahead of zsh-vi-mode in the plugin file rather than
after it.

## fzf-tab — replaces zsh's tab-completion menu with an fzf popup

Aloxaf/fzf-tab, one of antidote's four plugins. It doesn't add completions of its own — it
intercepts whatever zsh's completion system (`compinit`) already generated and renders the
candidate list through fzf instead of the built-in menu, so every existing `_git`, `_docker`,
`_ssh`, and (once wired in) carapace-fed completion gets fuzzy filtering and a live preview for
free.

`compinit` has to run before antidote loads plugins for this to have anything to hook — `zshrc`
orders it that way deliberately (see the fpath/compinit block ahead of the antidote block).

    <cmd> <Tab>       # open the fzf-tab popup instead of zsh's completion menu
    (type to filter)  # fuzzy-filter the candidate list, same as any fzf prompt
    Tab / Shift+Tab   # move the selection down/up inside the popup
    Ctrl+Space        # multi-select several candidates before accepting
    → / Enter         # accept the highlighted candidate(s)
    Ctrl+G / Esc      # cancel and fall back to what you'd already typed

## zsh-vi-mode — vim-style modal line editing for zsh

jeffreytse/zsh-vi-mode, the last plugin loaded from `zsh_plugins.txt`. It replaces zsh's
default emacs-style line editor with vim modes: normal (`n`), insert (`i`), visual (`v`), and
visual-line (`V`), each with its own cursor shape so you can tell which one you're in without
looking at the prompt.

The trap: it finishes building the `viins`/`vicmd` keymaps during its own init, which runs on
the *first `precmd`* — that is, after every single line of `zshrc` has already executed. Its
insert-mode init re-binds `^R` to zsh's builtin `history-incremental-search-backward`, silently
displacing anything `zshrc` bound to `Ctrl+R` earlier in the file. That's why atuin's binding
(see below) isn't a plain `eval "$(atuin init zsh)"` call — it's deferred into
`zvm_after_init_commands`, an array zsh-vi-mode drains once its own keymaps are final, which is
the one place late enough to stick. `zshrc` falls back to binding inline only if the plugin
didn't load at all.

    Esc           # insert or visual mode -> normal mode
    i / a         # normal mode -> insert mode, before/after the cursor
    v             # normal mode -> visual (character) mode
    V             # normal mode -> visual-line mode
    dw / cw / yw  # normal-mode vim operators: delete/change/yank a word
    0 / $ / %     # start of line / end of line / matching bracket
    u             # undo the last change, vim-style

Gotcha: if a key bound earlier in `zshrc` ever stops working in insert or normal mode but still
works in `emacs` mode, this is why — check `for m in emacs viins vicmd; do bindkey -M $m "^X";
done` to see where a binding actually landed, and rebind it from `zvm_after_init_commands`
rather than from `zshrc` directly.

## starship — the prompt, one dark palette via config/starship.toml

Cross-shell prompt, configured entirely by `config/starship.toml`: the `one_dark` palette
(matching Ghostty, atuin, and nvim), OS/user segments, a directory segment truncated to 3 path
components, git branch/status, per-language version segments, a docker-context segment, and a
right-aligned time/battery block. `zshrc` skips `starship init` outright in a shell with no
line editor (`TERM=dumb`, non-interactive, no tty) — starship refuses to render there anyway
and only adds a startup error.

The hostname segment is `ssh_only = true`: it's invisible on the local machine and appears only
once you've SSH'd somewhere, which is the one time knowing which box you're on actually
matters.

    starship init zsh           # print the shell-integration code — what zshrc sources
    starship explain            # show which modules rendered and why, right now
    starship module git_status  # print a single module in isolation
    starship config             # open config/starship.toml in $EDITOR
    starship print-config       # dump the fully resolved config as TOML
    starship timings            # per-module render time — find what's making the prompt slow
    starship toggle time off    # flip a module off for this session only
    starship completions zsh    # regenerate the zsh completion script
    starship bug-report         # open a pre-filled GitHub issue with your config attached

## atuin — shell history, sqlite-backed, config/atuin/config.toml

Replaces zsh's plain histfile search. `Ctrl+R` is bound to atuin's own search widget in both
`viins` and `vicmd` keymaps (see zsh-vi-mode's Gotcha above for why that binding has to be
deferred), and up-arrow is atuin's session-scoped search rather than zsh's builtin.
`config/atuin/config.toml` is overrides-only — everything not set there is upstream's default,
so `atuin default-config` prints the full annotated template.

Sync isn't turned on here. The config file's own header is explicit about it: this history
stays local to the machine, so there's no account to log into and nothing for `install.sh` to
prompt for — `atuin login`/`atuin sync` are what would light it up if that ever changes. What
*is* configured is search behaviour: `daemon-fuzzy` search for `Ctrl+R`, sqlite for the up-
arrow binding, a `workspace` filter scoped to the current git repo, and a tmux popup (needs
tmux 3.2+) instead of repainting the pane.

    Ctrl+R                             # open atuin search — daemon-fuzzy, floats in a tmux popup
    (up arrow)                         # session-scoped search: this session's commands, newest first
    Tab                                # inside search, cycle the filter: global/session/session-preload/workspace/directory
    atuin search foo                   # search from the command line instead of the widget
    atuin search --author pi           # just the commands omp ran through its bash tool
    atuin search --author '$all-user'  # hide every known-agent row, just what you typed
    atuin stats day                    # today's most-run commands and subcommands
    atuin stats week                   # same, over the last 7 days

## zoxide — frecency-ranked `cd`

A `cd` replacement that learns: every directory you visit gets a frecency score (frequency +
recency), and `z <partial-name>` jumps to the highest-ranked match without typing the full
path. `zshrc` hooks it with `zoxide init zsh` unconditionally — unlike starship and fzf it
stays useful even in a scripted, non-interactive shell.

    z dotfiles             # jump to the highest-ranked directory matching "dotfiles"
    z foo bar              # match against multiple space-separated fragments at once
    zi dotfiles            # interactive: fzf-pick among every matching directory
    z -                    # jump back to the previous directory
    zoxide query dotfiles  # print the match without cd'ing — useful in scripts
    zoxide add .           # manually seed the database with the current directory
    zoxide remove <path>   # drop a stale entry (deleted/renamed directory)

## direnv — per-directory environment variables

Loads and unloads environment variables as you `cd` in and out of a directory that has an
`.envrc`. `zshrc` hooks it with `direnv hook zsh`, guarded the same way as zoxide — it works in
a non-interactive shell too, since env loading has nothing to do with the line editor.

    echo 'export FOO=bar' > .envrc  # declare a directory-scoped variable
    direnv allow                    # trust this .envrc — required once before direnv will load it
    direnv edit .                   # open .envrc in $EDITOR, re-checking trust on save
    direnv reload                   # re-source the current directory's .envrc right now
    direnv deny                     # revoke trust for the current .envrc
    direnv status                   # show what's currently loaded and from which file

Gotcha: an untrusted `.envrc` loads nothing and prints a one-line warning instead of erroring —
easy to miss in a busy prompt. If a variable you expect isn't set, `direnv status` first.

## fzf — fuzzy finder powering ctrl-t, alt-c, and fzf-tab completion

The fuzzy-matching engine everything else in this file borrows: fzf-tab's completion popup,
tmux's `prefix+F` fuzzy switcher, and (once wired in) carapace's completions all render through
fzf. `zshrc` sources it with `fzf --zsh` on a modern build (0.48+); on an older distro fzf
(Debian/Ubuntu LTS ship 0.29) it falls back to sourcing the key-bindings/completion shell
scripts from disk directly.

`FZF_DEFAULT_COMMAND` is fd-backed in this setup, so every one of the bindings below — and the
default file list `fzf` itself searches when piped no input — already respects `.gitignore` and
skips hidden/ignored churn the way `fd` does, instead of walking every file with `find`.

    Ctrl+T             # fuzzy-pick file(s) under the cwd, insert the path(s) at the cursor
    Alt+C              # fuzzy-pick a directory, cd into it
    **<Tab>            # trigger fzf completion for the word before the cursor (vim **<Tab>)
    Ctrl+R             # taken over by atuin in this setup — see the atuin section above
    fzf                # run it standalone, piping any list on stdin through the fuzzy filter
    git branch | fzf   # classic ad hoc use: pipe any command's output through fzf
    fzf -q 'query'     # start already filtered to a query instead of typing it interactively
    ps aux | fzf -m    # multi-select mode — Shift+Tab marks several lines before accepting

Gotcha: `Ctrl+R` is fzf's default history search everywhere fzf is documented, but atuin claims
it here in both `viins` and `vicmd` (see zsh-vi-mode above) — don't go looking for fzf's
history popup, it's atuin's.

## carapace — multi-shell completion engine feeding fzf-tab

A single binary that generates argument completions for roughly a thousand CLIs — git, docker,
kubectl, cargo, and most of the tools in this file — from built-in specs, so no per-tool
`_<cmd>` completion script has to exist for it to work. It plugs into zsh's own completion
system (`compinit`), which means fzf-tab renders its results the same way it renders everything
else: a fuzzy-filterable popup instead of a menu.

`CARAPACE_BRIDGES` is the fallback path for a command carapace has no built-in spec for: a
comma-separated list of other completion systems (`zsh`, `bash`, `fish`, `carapace`) it tries
in order once its own completers come up empty, so a tool with only a hand-written zsh
`_function` still completes instead of falling back to bare filename completion.

    source <(carapace _carapace)                    # the zsh init line — generates and sources completions
    carapace --list                                 # list every command carapace ships a built-in completer for
    export CARAPACE_BRIDGES=zsh,fish,bash,inshellisense  # what zshrc sets — fallback order once carapace has no spec
    <cmd> <Tab>                                      # completion renders through fzf-tab, same popup as everything else
    carapace <cmd> zsh                                # print the raw zsh completion function carapace generates for <cmd>
    carapace --version                                # show carapace's own version

## eza — modern `ls`, aliased as ls/ll/tree

A Rust rewrite of `ls` with icons, git-aware coloring, and a built-in tree view. `zshrc`
aliases three names to it once it's on `PATH`: `ls` to `eza --icons --group-directories-first`,
`ll` to the same plus `-l` for a long listing, and `tree` to `eza --tree --icons`. The plain
`tree` binary used to sit alongside this as a Brewfile install of its own; it was cut once
nothing here (or in practice) ever reached past the alias for it — `-T`/`-L`/`-D`/`-I` cover
everything `tree` did except JSON/XML output, which nothing here needs either.

    ls                    # -> eza --icons --group-directories-first
    ll                    # -> eza -l --icons --group-directories-first
    tree                  # -> eza --tree --icons
    eza -la               # long listing including dotfiles, bypassing the ll alias's flags
    eza --tree --level=2  # tree view capped at 2 levels deep
    eza -l --git          # long listing with a per-file git status column
    eza -TD               # tree view, directories only
    eza --git-ignore      # skip files eza would otherwise list but git ignores

## bat — modern `cat`, aliased as cat, with syntax highlighting

A `cat` replacement with syntax highlighting, line numbers, and git-modified markers in the
gutter. `zshrc` aliases `cat` to `bat` when it's on `PATH`, or to `batcat` as a fallback —
Debian/Ubuntu's package ships the binary as `batcat` because the name `bat` already belongs to
an unrelated package there.

    cat file.rs              # -> bat file.rs, syntax-highlighted with line numbers
    bat -A file              # show non-printable characters (tabs, trailing whitespace, EOL)
    bat -p file              # plain output, no decorations — closest thing to real cat
    bat --diff file          # highlight only the lines changed against git's index
    bat -H 40:50 file        # highlight a line range with a background color
    bat --list-languages     # show every syntax bat can detect and highlight
    git diff | bat -l diff   # pipe arbitrary input through bat's highlighter

## tmux — terminal multiplexer, tmux.conf, plugins via tpm

`tmux.conf` tunes it for coding-agent TUIs and SSH resilience: `escape-time 10` so `Esc` feels
instant in vim/agent panes, `focus-events`/`allow-passthrough` for TUIs that care about pane
focus and raw escape sequences, `set-clipboard on` so a copy inside tmux over SSH lands in the
local clipboard via OSC 52, and an `SSH_AUTH_SOCK` refresh on every new pane so a reconnect
doesn't leave old panes pointing at a dead forwarded agent socket. Prefix is tmux's default,
`Ctrl+b`.

    tmux new -s name         # start a new named session
    tmux ls                  # list existing sessions
    tmux attach               # attach to the most recently used session
    prefix d                  # detach from the current session
    prefix r                  # reload tmux.conf in place, no detach needed
    prefix h/j/k/l            # select the pane left/down/up/right (repeatable — hold within 500ms)
    prefix F                  # tmux-fzf: fuzzy-pick a session/window/pane instead of the prefix+s tree
    prefix I                  # TPM: install every plugin listed in tmux.conf, first run
    prefix Ctrl-s / Ctrl-r    # tmux-resurrect: save / restore the whole session layout
    prefix Tab                # extrakto: fuzzy-grab a path/line/word/url out of the pane's scrollback
    y (in copy-mode)          # tmux-yank: copy the selection to the system clipboard

Gotcha: continuum autosaves every 15 minutes and auto-restores the last save when the server
starts, so a `kill -9`'d tmux server or a reboot comes back with your panes intact — but that
also means a session you *meant* to leave closed reappears on the next tmux start unless you
kill it again.

## ghostty — the terminal, config/ghostty/config, one dark two theme

`config/ghostty/config` sets the `One Dark Two` theme, JetBrains Mono Nerd Font at 14pt, 10px
window padding, and `shell-integration = detect` with `shell-integration-features =
cursor,sudo,title,ssh-env,ssh-terminfo` — the last of which is what keeps a plain `ssh` to a
box with no `xterm-ghostty` terminfo entry from breaking `nvim` and anything else that opens a
real terminal on the far end (it installs the terminfo entry via `tic` on first connect, caches
it per `user@host`, and falls back to `xterm-256color` if that fails).

One keybinding is set explicitly: a global show/hide toggle that works even when Ghostty isn't
the focused app. macOS needs Accessibility permission granted once; Linux needs a desktop
environment implementing the XDG Global Shortcuts protocol (GNOME 48+, KDE 5.27+) and silently
no-ops otherwise.

    Ctrl+Enter                             # global show/hide toggle — works unfocused, needs OS permission (see above)
    ghostty +show-config                   # print the fully resolved config, including inherited defaults
    ghostty +show-config --default --docs  # print every default option with its doc comment
    ghostty +list-themes                   # browse/preview every built-in theme in a TUI
    ghostty +list-fonts                    # list every font Ghostty can see on this machine
    ghostty +list-keybinds                 # show every keybind currently in effect
    ghostty +list-actions                  # list every action a keybind can trigger
    ghostty +validate-config               # check config/ghostty/config for errors before reloading
