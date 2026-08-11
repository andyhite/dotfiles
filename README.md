# dotfiles

Shell and terminal config, synced between my Mac (Ghostty) and remote dev VMs. One Dark
theme everywhere, zsh with antidote instead of oh-my-zsh, starship for the prompt,
NvChad for editing.

## What's in here

| Path | Links to | What it is |
|---|---|---|
| `zshrc` | `~/.zshrc` | zsh config: completion, antidote plugin load, history, aliases, tool init hooks |
| `tool-versions` | `~/.tool-versions` | mise runtime pins (node, python, go, bun, pnpm) — mise walks up from the current directory to find this, so the symlink is the global default under `$HOME`; see [mise](#mise) below |
| `zsh_plugins.txt` | `~/.zsh_plugins.txt` | antidote's plugin list (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, zsh-vi-mode) |
| `tmux.conf` | `~/.tmux.conf` | tmux config, plugins managed by TPM |
| `config/starship.toml` | `~/.config/starship.toml` | prompt — One Dark Pro preset, hostname shown only over SSH |
| `config/ghzinga/config.toml` | `~/.config/ghzinga/config.toml` | [ghzinga](https://github.com/osolmaz/ghzinga) — GitHub issue/PR viewer TUI that the herdr plugin shells out to |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr (agent terminal workspace manager), `one-dark` theme + accent/border overrides |
| `config/herdr/palette` | `~/.config/herdr/palette` | the `prefix+p` command palette — an fzf script run by a `type = "popup"` keybinding, plus the MIT notice of the plugin it's derived from |
| `herdr_plugins.txt` | (not linked — read by `install.sh`) | Herdr plugin list, one `owner/repo[@ref]` per line; `install.sh` installs/updates each one |
| `config/herdr/plugins/config` | `~/.config/herdr/plugins/config` | per-plugin Herdr config, one directory per plugin id — the whole tree is linked, so new plugins land here on install |
| `config/ghostty/config` | `~/.config/ghostty/config` | Ghostty terminal: `One Dark Two` theme, shell integration — same path on macOS and Linux |
| `config/atuin/config.toml` | `~/.config/atuin/config.toml` | Atuin (shell history): overrides only — daemon, fuzzy search, full-style UI, vi keymap, tmux popup, `atuin ai`. Also the answers `atuin setup` would otherwise re-ask on every install |
| `config/atuin/themes/one-dark.toml` | `~/.config/atuin/themes/one-dark.toml` | One Dark for Atuin; foreground colors only, background comes from Ghostty |
| `config/lazygit/config.yml` | `~/Library/Application Support/lazygit/config.yml` (macOS), `~/.config/lazygit/config.yml` (Linux) | Lazygit: One Dark theme, Nerd Font v3 icons, fuzzy filtering, and nvim integration; `zshrc` exposes it as `lg`, while the OS-specific destinations are Lazygit's native defaults |
| `config/nvim` | `~/.config/nvim` | [NvChad](https://nvchad.com) starter — vendored once, `.git` stripped, fully mine to edit from here |
| `config/zed/settings.json` | `~/.config/zed/settings.json` | Zed editor settings — `disable_ai: true` since agents run from the terminal via omp, not inside the editor, so the `agent`/`agent_servers` keys go undefined rather than tracked as dead config. `ssh_connections` never reaches the index: Zed rewrites it through this symlink on every remote connect, so a git clean filter strips it on the way in — see [below](#zeds-ssh_connections-is-stripped-by-a-clean-filter) |
| `gitconfig` | `~/.gitconfig` | tracked git identity, LFS/xet filter wiring, and defaults meant to hold on every machine; anything that varies per machine layers in through `gitconfig.local.example` below |
| `gitconfig.local.example` | (copy, not linked) | template for `~/.gitconfig.local` — work identity via `includeIf "gitdir:…"`, private-registry credentials. `gitconfig`'s trailing `[include]` applies last, so anything set here wins over every default in the tracked file |
| `config/git/ignore` | `~/.config/git/ignore` | global gitignore — git's own default `core.excludesFile` location when that setting is unset, so machine-tool droppings (`.DS_Store`, `.idea/`) never have to live in a project's own `.gitignore` |
| `config/gh/config.yml` | `~/.config/gh/config.yml` | gh CLI defaults and aliases; `git_protocol: https` is deliberate — `ssh/config` maps `github.com` to the work SSH key, so an ssh remote here would silently authenticate as the wrong account |
| `ssh/config` | `~/.ssh/config` | portable ssh identity config — per-key `Host` blocks for github.com (`IdentitiesOnly yes` so the agent can't offer the wrong key first), github.com-personal, hf.co, runpod.io; machine-specific hosts live in `~/.ssh/config.local` instead |
| `ssh/config.local.example` | (copy, not linked) | template for `~/.ssh/config.local` — dstack's generated `Include`, throwaway test hosts. `ssh/config`'s first real line is `Include ~/.ssh/config.local`, because ssh takes the first value it finds for any option and this is the only way the local file can override rather than be shadowed |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | [omp](https://omp.sh) coding agent settings — besides this file and `rules/output-style.md` below, the rest of `~/.omp/agent` is databases, sessions, and a secrets key |
| `omp/agent/extensions/atuin.ts` | `~/.omp/agent/extensions/atuin.ts` | records omp's `bash` commands into Atuin history as `--author pi` (a `KNOWN_AGENTS` name, so `$all-user` hides them), with omp's intent string as `--intent`. Hand-maintained: `atuin hook install` has no omp target |
| `omp/agent/rules/output-style.md` | `~/.omp/agent/rules/output-style.md` | `alwaysApply: true` rule that shapes every omp response for an ADHD reader — answer first, numbered steps, one next action, no preamble or recap |
| `config/paseo/config.json` | (not linked — **merged** into `~/.paseo/config.json`) | [Paseo](https://paseo.sh) daemon settings: which agent providers are enabled, MCP/browser-tool flags, relay off. Merged rather than symlinked because Paseo rewrites this file atomically and would replace the link, and because the live file also holds secrets; see [Paseo](#paseo) below |
| `config/paseo/orchestration-preferences.json` | `~/.paseo/orchestration-preferences.json` | which provider/model each delegated role gets (`impl`, `ui`, `research`, `planning`, `audit`). Read by Paseo's four orchestration skills, never by Paseo itself — which is what makes this one safe to link when its neighbour isn't |
| `config/paseo/paseo.service` | (copied to `~/.config/systemd/user/`) | `systemd --user` unit that supervises the Paseo daemon on Linux. Paseo ships no unit of its own. Unused on macOS, where the desktop app supervises its own daemon |
| `config/paseo/daemon.env.example` | (copy, not linked) | template for `~/.config/paseo/daemon.env`, the unit's `EnvironmentFile` — this box's `PASEO_LISTEN`, `PASEO_HOSTNAMES`, and the plaintext `PASEO_PASSWORD`. The per-machine half of Paseo's config, kept out of the tracked file above |
| `Brewfile` | (not linked — read by `install.sh`) | macOS formulae + casks for every tool this config drives, applied with `brew bundle` — replaced the old hand-maintained `brew_ensure`/`brew_ensure_cask` loop |
| `bin/tailscale` | `~/.local/bin/tailscale` | PATH shim for the Mac App Store build of Tailscale — `exec`s the bundled CLI directly, since a plain symlink to it fails at runtime (see the file itself for why). Linked only on macOS, and only when the App Store app is actually installed |
| `agent_skills.txt` | (not linked — read by `install.sh`) | cross-agent skill manifest, one `<owner>/<repo> --skill <name>` per line; `install.sh` runs `npx skills add … -g -y` for each |
| `zshrc.local.example` | (copy, not linked) | template for machine-local secrets — never committed |
| `install.sh` | — | installs/updates every tool below, then symlinks all the config above into place — locally, or on another machine with `--host` |

## Bootstrap a new machine

```sh
git clone https://github.com/andyhite/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` runs nine steps, and is safe to re-run any time (installs what's missing,
updates what's already there). With a terminal attached each step asks first and Enter
accepts; without one, or with `--yes`, it runs everything unattended:

```sh
./install.sh --yes                 # unattended, everything
./install.sh --only configs        # just re-link the dotfiles
./install.sh --skip tools,nvim     # skip the slow parts
./install.sh --verbose             # show each installer's own output
./install.sh --host vm             # install on another machine over ssh
./install.sh --help                # list steps and flags
```

Output is one line per item: `✓` already correct, `+` created, `↑` updated, `·` skipped,
`!` needs your attention, `✗` failed — then a tally. Installer output is suppressed unless
something fails, in which case the last 12 lines are replayed under the failure; `--verbose`
shows it all. A failed step reports and the run continues, so one broken formula doesn't
cost you the rest; the script exits non-zero if anything failed. Colour follows `NO_COLOR`
and `TERM`, and the glyphs fall back to ASCII outside a UTF-8 locale.

The steps, in order — the order is load-bearing, which is why `--only` exists but
reordering doesn't:

1. **Installs/updates the tools this config drives**: starship, zoxide, atuin,
   fzf, eza, bat, direnv, tmux, lazygit, antidote, TPM, the JetBrains Mono Nerd
   Font, neovim, ripgrep, tree-sitter-cli, mise, omp, and NvChad. macOS applies
   `Brewfile` with `brew bundle` (formulae + casks, including Ghostty and Paseo
   themselves); Linux goes through `apt` where a package exists, and falls back
   to each tool's official installer otherwise:
   - `brew bundle check --file Brewfile` runs first and is the common path on a
     repeat install: it exits clean only when every formula/cask is already
     installed and current, so the slower `brew bundle install` runs only when
     there's real work outstanding. `brew bundle` itself only ever adds — dropping
     a line from `Brewfile` never uninstalls anything already on the machine; that
     takes a manual `brew bundle cleanup`.
   - starship/atuin ship curl-able install scripts.
   - eza predates its Ubuntu packaging (24.04+), so on older releases it's built from
     source via `cargo` — bootstrapping `rustup` first if needed, and only rebuilding
     when crates.io actually has a newer version than what's installed.
   - lazygit: Linux pulls upstream's architecture-specific release binary into
     `~/.local/bin`, avoiding distro-version gaps and stale package transitions.
   - neovim: Ubuntu's apt package (0.9.5 on 24.04) is below NvChad's 0.11 floor, so this
     pulls the official release tarball instead and merges it into `~/.local`, which is
     already on `PATH`.
   - tree-sitter-cli: **not** `cargo install tree-sitter-cli` — that pulls in
     `rquickjs-sys`, which needs bindgen/clang to resolve its resource-dir correctly and
     fails to build on stock Ubuntu (`fatal error: 'stdbool.h' file not found`). Uses
     tree-sitter's own prebuilt release binary instead.
   - mise: macOS gets it from `Brewfile` like everything above it; Linux has no
     equally universal package for it, so this runs the upstream `mise.run` installer,
     which drops a single binary into `~/.local/bin` — already on `PATH` via `zshrc`.
   - The Nerd Font is fetched straight from its GitHub release and installed under
     `~/.local/share/fonts`.
   - NvChad: clones `NvChad/starter` straight into this repo the first time
     (`config/nvim`), strips its `.git` immediately per NvChad's own docs, then
     symlinks it like everything else — so all my NvChad customization lives here too,
     not in some separate untracked directory.
   - omp: install-only, via the installer at [omp.sh](https://omp.sh) — the binary is
     ~120MB and ships its own `omp update`, so re-running this script skips it rather
     than re-downloading.

   Ghostty itself is only installed on macOS — it's a local GUI app, so there's nothing
   to install on a headless remote box, though its config still gets symlinked in case
   that box ever runs Ghostty directly.
2. **Generates zsh completions** into `~/.local/share/zsh/site-functions`, which `zshrc`
   prepends to `fpath`. Homebrew already drops completions for many of these tools into
   its own `site-functions`, but that covers nothing on a Linux box, and tools installed
   outside a package manager (`omp`, `herdr`, `tree-sitter`) are uncovered on both. Each
   file is generated by the binary itself, so it can never drift from the installed
   version. See [Completions](#completions) below.
3. **Symlinks every config file** in the table above into place. Backs up
   (`.bak.<timestamp>`) anything real that's already sitting where a symlink needs to
   go. Also copies `zshrc.local.example`, `gitconfig.local.example`, and
   `ssh/config.local.example` to their `~/.*.local` targets at mode 600 the first time
   only — a re-run never overwrites an already filled-in file. See [The `*.local`
   templates](#the-local-templates) below.
4. **Installs the language runtimes pinned in `~/.tool-versions`**, via `mise install`.
   Runs right after the symlinks step and not before: mise reads its pins by walking up
   from wherever it's invoked, and `~/.tool-versions` is the symlink the configs step
   above just created — swap the order and this step runs against nothing on a fresh
   machine. See [mise](#mise) below.
5. **Sets up Paseo**: merges `config/paseo/config.json` into `~/.paseo/config.json`,
   makes sure the `paseo` CLI is on `PATH` — a symlink to the cask's bundled binary on
   macOS, `npm install -g --prefix ~/.local @getpaseo/cli` on Linux — and on Linux
   installs and enables the `systemd --user` unit that keeps the daemon up. After the
   configs step because the unit reads `~/.config/paseo/daemon.env`, which that step
   creates from its template; after runtimes because the Linux CLI is an npm package.
   See [Paseo](#paseo) below.
6. **Installs/updates every Herdr plugin** listed in `herdr_plugins.txt`. Skipped with
   a note if `herdr` isn't on `PATH` — this repo configures Herdr but doesn't install it.
7. **Installs cross-agent skills**, from two sources. `agent_skills.txt` first — one
   `npx skills add <owner>/<repo> --skill <name> -g -y` per line — which needs the
   `runtimes` step above to have already put node on `PATH`, hence the ordering. Then
   any skill an installed Herdr plugin ships in its own `skills/` directory, symlinked
   into `~/.omp/agent/skills` — unchanged from before, and run after Herdr because a
   link made before a plugin's first install would point at a path that doesn't exist
   yet.
8. **Headlessly syncs NvChad's plugins** (`nvim --headless "+Lazy! sync" +qa`) once
   neovim and the config are both in place.

### Remote installs — `--host`

`--host <ssh-host>` redirects the whole run to another machine instead of adding to it:
this box installs nothing. For each host it ssh's in, clones the repo at `--remote-path`
(default `~/.dotfiles`) or fast-forwards it if it's already there, and then runs *that
copy's* `install.sh` with every other flag passed through.

```sh
./install.sh --host vm                        # prompts per step, as if you were sitting there
./install.sh --host vm --yes --only configs   # unattended, one step
./install.sh --host vm,box --yes              # two hosts in turn
./install.sh --host vm --remote-path ~/src/dotfiles
```

Five things worth knowing:

- **The remote pulls from origin, not from this working copy.** Commit and push first —
  the driver prints a warning when the local tree is dirty or ahead of `origin`, because
  a run that silently installs the previous commit is the one failure mode here that
  looks like success.
- **The remote's own `install.sh` is what runs.** Nothing is piped over the wire, so the
  box always ends up in a state some git ref actually describes.
- **A dirty remote worktree is installed as-is**, with a warning and no update — that's
  how you try a change on the remote before committing it, and resetting someone's edits
  to match origin isn't this script's call to make.
- **The first clone uses the public https URL.** The tracked `origin` is
  `git@github.com-personal:…`, a `Host` alias from this repo's own `ssh/config` that a
  machine being bootstrapped doesn't have yet (nor the key it names), so the alias is
  resolved through `ssh -G` and the `https://github.com/…` form is handed over instead.
  `DOTFILES_REPO=<url>` overrides it. An existing clone keeps whatever origin it has.
- **A tty is forwarded only when you have one.** With a terminal on this end, `ssh -t`
  makes the remote's per-step prompts work normally; without one it runs unattended
  rather than sitting out a read timeout per step. One host failing doesn't cancel the
  rest, and the exit status still reflects it.

`ssh` runs a non-login, non-interactive shell, so the bootstrap re-adds what `zshrc`
would have: `~/.local/bin`, `~/.cargo/bin`, mise's shims (node), and Homebrew on a macOS
host. Without that every `command -v` guard in `install.sh` would decide its tool is
missing and reinstall it — the right result, reached the slowest possible way.

### Completions

`zshrc` puts `~/.local/share/zsh/site-functions` first on `fpath` so a completion
generated from the installed binary beats a distro's stale copy. `install.sh` writes one
per tool that has a generator:

| Tool | Generator |
|---|---|
| starship | `starship completions zsh` |
| atuin | `atuin gen-completions --shell zsh` |
| bat | `bat --completion zsh` |
| ripgrep | `rg --generate complete-zsh` |
| omp | `omp completions zsh` |
| herdr | `herdr completion zsh` |
| tree-sitter | `tree-sitter complete --shell zsh` |
| mise | `mise completion zsh` |

Deliberately absent, because generating a file would be worse than what already works:
`eza` and `zoxide` have no generator (Homebrew ships `_eza`/`_zoxide`); `direnv` and
`nvim` publish no zsh completion at all; `fzf` comes from the `fzf --zsh` eval in
`zshrc`; and zsh itself ships `_tmux`, `_jq` and `_vim`.

Two details worth knowing. Generation goes through a temp file and only replaces the
target when the output is non-empty, so a tool that starts erroring can't blank a working
completion. And because `zshrc` runs `compinit -C` — which trusts a cached dump rather
than rescanning `fpath` on every shell start — `install.sh` deletes `~/.zcompdump*`
whenever it writes something new, so the next shell rebuilds once.

### The `*.local` templates

Five tracked templates, one convention: `zshrc.local.example`, `gitconfig.local.example`,
`ssh/config.local.example`, `config/paseo/daemon.env.example` and
`omp/agent/models.yml.example` are copied — never linked — to their targets at mode 600 the
first time `install.sh` runs, and left alone on every run after that, so a filled-in file is
never clobbered. Each one holds real secrets or per-machine values that have no business in
a public repo.

The two config templates exist because of how their tracked file reads the copy back, not
just as a place to dump overrides:

- `gitconfig` ends with `[include]` / `path = ~/.gitconfig.local`. Git applies repeated
  keys in file order, so an include at the very end wins over every default set above it
  — `~/.gitconfig.local` doesn't need to know what it's overriding, it just wins by
  coming last.
- `ssh/config` *starts* with `Include ~/.ssh/config.local`, before any `Host` block. ssh
  takes the first value it finds for a given option, so the include has to come first or
  a later `Host github.com` block would shadow it instead of losing to it. A missing
  include target isn't an error in `ssh_config`, so this line is safe on a machine that
  hasn't run `install.sh` yet.

`zshrc.local.example` needs no such trick — `zshrc` just sources `~/.zshrc.local` near
the top, before the tool blocks that read values like `AWS_PROFILE`.

The last two don't land at `~/.*.local` like the first three.
`config/paseo/paseo.service` names `~/.config/paseo/daemon.env` as an `EnvironmentFile` and
systemd resolves that path itself; `models.yml` has to sit in `~/.omp/agent/` where omp
looks for it. omp's is also the one template that ships inert rather than empty — it carries
a literal `providers: {}`, because omp validates the file's root as an object and a copy
trimmed to pure comments parses as null and warns on every startup. See
[the omp section](#omp--one-tracked-config-two-machines-different-accounts) for what goes in
it.

### mise

Replaces the old per-language version manager: one binary instead of a plugin per
language (no `plugin add node`/`plugin add golang` to run on every machine), and it
activates by rewriting `PATH` on every prompt instead of installing shims — a version
change in `~/.tool-versions` is live in the shell you're already sitting in, with no
`reshim` step.

`tool-versions` pins exact versions on purpose — `node 26.7.0`, not "latest" — so a
machine doesn't silently drift to whatever happened to be current the day someone ran
`install.sh`. mise resolves `.tool-versions`/`mise.toml` by walking up from the current
directory to `$HOME` and beyond, which is exactly what makes the `~/.tool-versions`
symlink the global default everywhere that doesn't have its own: mise takes the nearest
file, so a project with its own pins still wins inside that project.

A trailing `t` on a python version — `3.14.7t` versus the `3.14.7` pinned here — selects
the free-threaded (no-GIL) build. That's a distinct, opt-in variant, not a typo, so don't
"fix" it if it turns up somewhere else.

### `make` on macOS — `gmake`, not `gnumake`

Apple ships GNU make 3.81, from 2006, as *both* `make` and `gnumake` — so the obvious
`alias make=gnumake` looks like an upgrade but is a silent no-op, still 3.81. Homebrew's
`make` formula installs GNU make 4.x as `gmake` instead, specifically to dodge that name
clash, so `zshrc`'s macOS block aliases `make` to `gmake` once it finds Homebrew's copy —
`gnumake` was never the one worth reaching for.

### Shells with no line editor — `TERM=dumb`, or no tty

A coding agent shelling out, an editor's shell mode, a `zsh -ic` from a script: all
interactive zsh, none of them running zle. `zshrc` sets `_no_zle` when `TERM` is `dumb`,
the shell isn't interactive, or stdin isn't a terminal, and skips the prompt and the fzf
key-binding/completion scripts for the rest of the file.

It's a correctness fix, not a speedup. Both of those write to the caller's stderr before
its command has produced a byte:

```
[ERROR] - (starship::print): Under a 'dumb' terminal (TERM=dumb).
(eval):1: can't change option: zle
(eval):1: can't change option: zle
```

starship refuses to render into a terminal with no capabilities, and fzf's two scripts
snapshot `$options` and restore the array wholesale on the way out — which tries to set
`zle` back on, and zsh won't allow that where it turned it off. Everything that isn't
the interactive layer still runs: `PATH`, mise, `compinit`, aliases, zoxide, direnv and
atuin all load exactly as before, so a scripted shell resolves the same commands an
interactive one does.

## Notes by tool

### Zed's `ssh_connections` is stripped by a clean filter

`config/zed/settings.json` is symlinked into `~/.config/zed`, and Zed rewrites
`ssh_connections` every time you connect to or disconnect from a remote host. So the
moment you open a project on a remote box, its hostname and absolute project paths are
written straight into a tracked file in a public repo. Deleting the key by hand fixes it
until the next connect, which is to say it doesn't fix it.

`.gitattributes` routes the file through a clean filter — `bin/zed-settings-clean`, run by
git on the way into the index, leaving the working file exactly as Zed wrote it:

```
config/zed/settings.json filter=zed-local
```

Three choices worth naming. It's a filter rather than `update-index --skip-worktree`,
which hides *every* change to a file — and the reason this one is tracked at all is that
settings changed in Zed's UI should show up as diffs here. It's a line filter rather than
`jq`, because the file is JSONC with `//` comments in its header *and* through its body,
which jq can't read and any reformatting pass would throw away. And there's no smudge
half: the filter only ever removes machine state on the way in, so reversing it on
checkout would mean writing one machine's hosts into another's file.

The filter definition can't be committed — it names an absolute path, and this repo sits
somewhere different on every machine — so `install.sh`'s configs step registers it with
`git config filter.zed-local.clean`. Until that runs, git treats an unknown filter as a
pass-through: nothing errors, and nothing is stripped either. That gap is real — clone
onto a new machine, open a remote project in Zed before running `install.sh`, and the
hostnames commit exactly as they used to. CI closes it from the other end by grepping
committed content for work identifiers, so a leak through any unfiltered path fails the
build instead of shipping.

### omp — one tracked config, two machines, different accounts

`omp/agent/config.yml` is symlinked to `~/.omp/agent/config.yml` and shared by every
machine, and the model routing in it is identical everywhere: same `modelRoles`, same
`retry.fallbackChains`. Only the accounts differ. The Mac runs on personal subscriptions;
the Linux box bills work API accounts:

| | Anthropic | OpenAI | Cursor |
| --- | --- | --- | --- |
| Mac | subscription | subscription (`openai-codex`) | subscription |
| Linux | API key (`anthropic`) | API key (`openai`) | subscription |

Two questions hide in that table, and conflating them is what makes this look harder than
it is.

**Which account pays — an auth question.** The provider name doesn't change: `anthropic`
is `anthropic` on both boxes, reached with a subscription OAuth token on one and a work
API key on the other. Setting `ANTHROPIC_API_KEY` alone does not force the second because
omp resolves credentials in this order:

```
1  --api-key (runtime)          5  provider env var, incl. .env files
2  models.yml apiKey            6  other stored API key
3  stored OAuth credential      7  models.yml custom-provider resolver
4  login-sourced stored key
```

For OpenAI, a `models.yml` `apiKey` pins the API account above stored OAuth. Anthropic
needs one extra constraint: API keys authenticate with `x-api-key`, while bearer auth is
for OAuth/WIF tokens. On omp 17.2.13, the `apiKey` form produced bearer-auth 401s in fresh
interactive sessions; the explicit `x-api-key` form below passed. The internal cause is
not yet confirmed.

```yaml
# ~/.omp/agent/models.yml — work box only
providers:
  anthropic:
    auth: none
    headers:
      x-api-key: "!sh -c '. \"$HOME/.omp/agent/.env\"; printf %s \"$ANTHROPIC_API_KEY\"'"
  openai:
    apiKey: OPENAI_API_KEY
```

Both entries are override-only: with no `models` list they change auth without
redeclaring the built-in catalogs. `auth: none` skips provider credential lookup, and the
explicit header uses the authentication form Anthropic documents.
`config.yml` needs no change; `modelRoles` still use the built-in provider ids.

Header and `apiKey` values support `!command` secret resolution, but those commands do
not inherit values loaded by omp's dotenv loader. The Anthropic command therefore sources
`~/.omp/agent/.env` itself. Only enable it where the key exists and verify it with a live
model request; `auth: none` keeps the provider selectable even if the command fails. A
secret store can replace the shell command with `!op read op://work/anthropic/api-key`.

The values go in `~/.omp/agent/.env`, not `~/.zshrc.local`. That distinction matters on
the Linux box: the Paseo daemon runs under systemd and sources no login shell. The
Anthropic header resolver explicitly sources this file, while omp resolves OpenAI's
`apiKey` from it through the normal dotenv path.

**Which models each role resolves to — a config question.** None of it differs. Pattern 1
changes *who is billed for* `anthropic/claude-opus-5`, not *which model that name resolves
to*, so `modelRoles` and `retry.fallbackChains` are tracked and shared verbatim.

The one asymmetry is OpenAI. Its two surfaces are separate provider ids — `openai-codex`
for the ChatGPT subscription, `openai` for API keys — so the shared chain names both:

```yaml
default:
  - openai-codex/gpt-5.6-sol:high # Mac authenticates this
  - openai/gpt-5.6:high # Linux authenticates this
  - cursor/cursor-grok-4.5-high # both; Cursor-owned usage bucket
  - cursor/composer-2.5 # both; Cursor-owned usage bucket
```

Each machine silently skips the entry it has no credentials for, because **omp validates
chain entries against the model catalog, not against credentials**, and every provider
above is built-in. A sandbox with no auth store at all warns about none of them. What does
warn, once per role on every launch, is a provider id that is not in the catalog:

```
Warning: Fallback chain for role 'default' references unknown model: nonesuch/some-model
```

That is the whole rule, and it is why the tracked chains name only built-in providers. A
custom `models.yml` provider — a second Anthropic id holding a second credential, say —
exists only on the machine that defines it, so putting one in the shared chains means that
warning on every other box. CI asserts against it.

Cross-tier fallback is deliberately absent: neither machine falls from a subscription to an
API account. Each has one account per provider, and the chain moves to the next *provider*
rather than to another way of paying for the same one.

A second provider id for the same upstream — a twin holding a second Anthropic credential
alongside the subscription — is what `models.yml` makes possible and what this setup
deliberately does not use. It buys overflow capacity at the cost of a provider id that
exists on one machine only, which is precisely the thing the shared chains cannot name.
`omp/agent/models.yml.example` documents the shape if that tradeoff ever becomes worth it.

`~/.omp/agent/models.yml` is created from `omp/agent/models.yml.example` on every machine,
so the mechanism is discoverable where it isn't used. The shipped copy is inert but not
empty — it carries a literal `providers: {}`, because omp validates the root as an object
and a file trimmed to pure comments parses as null and prints a validation warning on every
startup.

That leaves nothing per-machine in `config.yml` at all, which is the point: one tracked
file, two machines, and the only difference is which credential answers for a provider id
both of them already have.

### Paseo

[Paseo](https://paseo.sh) is a daemon that supervises coding agents — it launches Claude,
Codex and omp as child processes, keeps their sessions, and exposes them over an HTTP/WS
API that a desktop, mobile, web or CLI client drives. This repo's two machines use it from
opposite ends: **the Mac runs the GUI app as a client, the Linux VM runs the daemon** the
Mac connects to. Everything under `config/paseo/` is written to do the right thing on
either, and `install.sh`'s `paseo` step branches on the OS rather than on which role the
box happens to play.

How the binary arrives differs by platform, because upstream ships two very different
artifacts. macOS gets `cask "paseo"` — the Electron desktop app, which bundles the daemon
*and* a CLI at `Paseo.app/Contents/Resources/bin/paseo`. Linux gets
`npm install -g --prefix ~/.local @getpaseo/cli`, which is what upstream's own docs point
headless machines at; despite the name it isn't a thin client, since `@getpaseo/cli`
depends on `@getpaseo/server` and so carries the whole daemon. The DEB/RPM/AppImage
downloads are the Electron app again, which is the wrong artifact for a box with no
display.

Two details in that Linux install are deliberate. `--prefix ~/.local` rather than a bare
`npm install -g`: a plain global install lands inside whichever node mise currently has
active and vanishes the next time `tool-versions` bumps node, whereas `~/.local/bin` is
where every other manually-installed tool here already lives and is already on `PATH`.
And on macOS `install.sh` makes the `~/.local/bin/paseo` symlink itself rather than
relying on the app's first-run hook to do it — that hook only fires once the GUI has been
opened, and `brew bundle` never opens anything, so on a fresh machine `paseo` would be
missing from `PATH` until someone double-clicked the icon.

#### `config.json` is merged, not symlinked

This is the one place Paseo breaks the pattern the rest of this repo follows, and it's
worth spelling out because the symlink *looks* like it works right up until it doesn't.

Paseo saves its config atomically. `savePersistedConfig` calls
`writePrivateFileAtomicSync`, which writes a sibling tempfile and `renameSync()`s it over
the target — and rename **replaces a symlink with a real file**. So a symlinked
`~/.paseo/config.json` survives exactly until the first settings change made in the app,
at which point the link is silently gone: the repo still shows a tracked config, git still
shows it clean, and it no longer has any effect on anything. Nothing warns you.

There's a second, independent reason. The live file legitimately holds things that must
never be committed — `paseo daemon set-password` writes a bcrypt hash into `daemon.auth`,
and custom providers keep API keys under `agents.providers.*.env`.

A merge answers both. `install.sh` runs `jq -s '.[0] * .[1]' <live> <tracked>`, a
recursive object merge with the right side winning, so the tracked file is authoritative
for the keys it names and every other key in the live file — secrets and per-machine
settings alike — is left exactly as Paseo wrote it. It's idempotent, and the comparison
before writing is semantic rather than textual (`jq -e '. == $want[0]'`) because the daemon
rewrites the file with its own key order, and a byte diff would otherwise report drift on
every single run.

The step never restarts the daemon to apply what it merged, it just prints the command.
Config is read at startup, but a restart kills every agent running under the daemon —
including, when an agent is the thing running `install.sh`, itself.

`config/paseo/orchestration-preferences.json` *is* symlinked, and the difference is the
point: grepping `getpaseo/paseo` for that filename turns up only the five shipped
`SKILL.md` files. Paseo itself never reads or writes it, so nothing can replace the link
behind your back. It's the dial that decides which provider/model each delegated role gets
— `impl`, `ui`, `research`, `planning`, `audit` — and the values are `provider/model`
pairs split on the *first* slash, where the provider half comes from `paseo provider ls`
and the model half from `paseo provider models <provider>`. A bare provider id is rejected:
`create_agent`'s schema refuses any value without a slash. (That first-slash-only split is
what lets omp's own slash-containing model ids, like
`omp/amazon-bedrock/anthropic.claude-opus-5`, work at all.)

#### Per-machine settings live outside the tracked file

One tracked `config.json` shared by two machines can't hold anything that has to differ
between them, and Paseo's config precedence — defaults < `config.json` < env < CLI flags —
is the escape hatch. So `config/paseo/config.json` carries only portable policy (which
providers are enabled, MCP and browser-tool flags, relay off, CORS), and the rest goes in
environment variables:

| Where | Holds | Read by |
|---|---|---|
| `~/.config/paseo/daemon.env` (mode 600, from `config/paseo/daemon.env.example`) | `PASEO_LISTEN`, `PASEO_HOSTNAMES`, `PASEO_PASSWORD` | the Linux daemon, via the unit's `EnvironmentFile` |
| `~/.zshrc.local` | `PASEO_HOST`, `PASEO_PASSWORD` | the Mac's `paseo` CLI, to drive the Linux daemon |

The Mac's *app* isn't in that table on purpose: it keeps its list of remote hosts in app
storage under the `@paseo:daemon-registry` key, not in any config file, so adding the Linux
box is a one-time **Settings → Add host → Direct connection** and there's nothing here to
track.

#### Reaching the Linux daemon from the Mac

The daemon binds `127.0.0.1:6767` by default, which no other machine can reach. Set
`PASEO_LISTEN` to this box's **Tailscale** address (`tailscale ip -4`) rather than
`0.0.0.0`, which would also publish it on every LAN and coffee-shop Wi-Fi the box ever
joins. Bare IP literals are accepted unconditionally, so `PASEO_HOSTNAMES` is only needed
when a client connects by MagicDNS name; a leading dot there is a suffix match — the daemon
tests `host === base || host.endsWith('.' + base)` — so `.your-tailnet.ts.net` covers every
host in the tailnet.

Then set `PASEO_PASSWORD`. Tailscale encrypts the transport and its ACLs gate who can route
to the box, but Paseo does no authentication of its own: anything that can reach the listen
address can drive every agent on that machine. Supply it as plaintext in `daemon.env`
rather than running `paseo daemon set-password`, which writes a bcrypt hash into the very
file `install.sh` merges from this repo.

No relay needed for any of this — `daemon.relay.enabled` is `false` in the tracked config,
because a direct Tailscale connection is already end-to-end. Relay is for reaching the box
from *outside* the tailnet. Note that setting `PASEO_RELAY_ENABLED` pins the value as a
launch override, and Paseo then refuses to let the app change relay at runtime until the
override is gone.

#### The systemd unit, and why it's needed at all

Paseo ships no unit: there's no systemd artifact anywhere in `getpaseo/paseo`, and
`paseo daemon` exposes only `start`/`pair`/`status`/`stop`/`restart`/`set-password` with no
service installer. So `config/paseo/paseo.service` is maintained here, copied (not
symlinked — systemd resolves unit paths itself and `daemon-reload` is what publishes a
change) to `~/.config/systemd/user/`.

Three things in it are load-bearing:

- **`--foreground`.** `paseo daemon start` *daemonizes by default*; the launcher spawns the
  supervisor `detached: true` and `unref()`s it. Without the flag systemd would watch the
  launcher exit immediately and declare the service dead while the real daemon kept running
  unsupervised.
- **No `PIDFile=`.** `$PASEO_HOME/paseo.pid` is JSON, not the bare integer systemd expects.
- **An explicit `Environment=PATH=`, and `mise exec`.** systemd never sources `~/.zshrc`, so
  neither the pinned node the npm launcher's `env -S node` shebang needs, nor the agent CLIs
  the daemon launches, would otherwise be findable.

A `--user` unit rather than a system one, because the daemon runs agent CLIs that read
per-user credentials (`~/.claude`, `~/.codex`, `~/.omp`). The catch is that user units
normally start at *login*, which never happens on a box only reached over ssh — so the step
offers to run `loginctl enable-linger`, which is what brings the user manager up at boot.
It asks rather than assumes, since that needs root and a box where the daemon only has to
run while you're logged in doesn't need it. The unit is `enable`d but not started: starting
it would be a surprise on a box already running a daemon under different launch overrides,
and `restart` on an active unit kills its agents.

#### The four skills come from the manifest, not the app

`agent_skills.txt` lists Paseo's four orchestration skills (`paseo`, `paseo-advisor`,
`paseo-committee`, `paseo-handoff`) from `getpaseo/paseo`. The macOS app also
copies them into `~/.agents/skills` on first GUI launch, but that hook is useless here
twice over: it never fires on the Linux box, which has no desktop app at all, and on the
Mac it only fires once someone opens the app, which `brew bundle` never does. Going through
the manifest means both machines get them from `install.sh` alone, and they update on the
same schedule as everything else rather than whenever the app is next launched.

A fifth, `paseo-loop`, was dropped: upstream removed agent loops (and the skill) in
`getpaseo/paseo#3053`, and `skills add` exits 1 on a skill name the repo no longer ships,
which failed the whole skills step.

One dial deliberately left off: `daemon.mcp.injectIntoAgents` stays `false`. Turning it on
gives every agent Paseo launches the full `create_agent`/`create_workspace` tool surface,
which is what those skills drive — but it's a behaviour change to every agent on the
machine, so it's a decision to make on purpose rather than something a dotfiles install
flips for you.

### Atuin

`config/atuin/config.toml` holds overrides only; run `atuin default-config` to see the
full annotated template. It exists mainly so `atuin setup` never runs: that wizard is
what asks about Atuin AI and the daemon, and the upstream installer re-ran it on every
single `install.sh`. With the answers committed, `install.sh` passes `--non-interactive`
and the wizard has nothing left to decide.

Sync is never configured: this history stays on the machine, so there's no account state
to set up and nothing `install.sh` has to prompt for. `--non-interactive` also skips the
installer's own sync-signup prompt.

`omp/agent/extensions/atuin.ts` records commands omp runs through its `bash` tool into
the same history, tagged `--author pi` — omp is a distribution of pi, and "pi" is one of
the five names in Atuin's `KNOWN_AGENTS`, which is what makes the agent pseudo-filters
work:

```sh
atuin search --author pi            # just the agent
atuin search --author '$all-agent'  # any known agent
atuin search --author '$all-user'   # just me
```

`$all-user` is applied to every interactive search, so agent rows stay out of `Ctrl+R`
and out of the up-arrow list without any configuration. The one gap is a *typed* `Ctrl+R`
query: it's answered by the daemon's index, which has no author column, so agent rows
reappear there. The up-arrow search is exempt because it's pinned to the sqlite engine
(`search_mode_shell_up_key_binding`).

Rows recorded before this switch keep `--author omp` and behave like hand-typed commands.
Retagging them isn't worth it: `history.db` is a projection of the record store, so a
sqlite `UPDATE` would be reverted by the next `atuin store rebuild history`.

Two things had to be fixed for Atuin to behave under `zsh-vi-mode`, and both fail
silently, so they're worth knowing about if either ever regresses.

**Ctrl+R.** Being last in `zshrc` isn't enough to own it. `zsh-vi-mode` rebuilds the
`viins`/`vicmd` keymaps during its own init, which runs on the first `precmd` — after
every line of `zshrc` — and its insert mode re-binds `^R` to zsh's builtin
`history-incremental-search-backward`. The binding Atuin installed survived only in the
`emacs` keymap, which vi mode never uses, so `Ctrl+R` was the builtin search. `zshrc`
now defers `atuin init zsh` into `zvm_after_init_commands` (still binding inline when the
plugin isn't loaded) and adds the `vicmd` `^R` that Atuin itself leaves to `fzf`. Check
it with:

```sh
for m in emacs viins vicmd; do bindkey -M $m "^R"; done   # all three -> atuin-search*
```

**Keymap mode.** The widgets Atuin installs pass `--keymap-mode=vim-insert`/`vim-normal`,
but config beats that flag for every value except `auto`, and the default is `emacs` —
so the search opened in emacs keymap and threw the shell's actual mode away. Hence
`keymap_mode = "auto"` in the config.

**The tmux popup is latched into the environment.** `[tmux] enabled` is read by
`atuin init`, which exports `ATUIN_TMUX_POPUP_WIDTH`/`_HEIGHT` when it's on and
`ATUIN_TMUX_POPUP=false` when it's off — and the popup check honors that variable over
the config. So flipping it needs a new shell, and any shell started before the flip
keeps exporting the old answer into everything it spawns. If `Ctrl+R` draws inline
inside tmux when it shouldn't, that stale export is why:

```sh
printenv ATUIN_TMUX_POPUP   # prints nothing when the popup is live
```

### Herdr plugins — the list is tracked, herdr's registry isn't

Herdr keeps its installed-plugin state in `~/.config/herdr/plugins.json`, which it
rewrites on every install: absolute paths, resolved commit SHAs, install timestamps.
That's generated state, not config, so it stays out of this repo — the same call
antidote's generated `zsh_plugins.zsh` gets. `herdr_plugins.txt` is the tracked source
of truth instead:

```
persiyanov/herdr-reviewr          # default branch at install time
someone/their-plugin@v1.2.0       # pinned to a tag, branch, or commit
```

To add a plugin, add the line and re-run `install.sh` — or run
`herdr plugin install <owner>/<repo> --yes` now and add the line so the other machine
picks it up. (Flags go *after* the repo argument; `herdr plugin install --yes <repo>`
is a usage error.) To remove one, delete the line and run
`herdr plugin uninstall <plugin-id>` — nothing prunes plugins automatically, since
removing a plugin also throws away whatever config it had.

Four plugins used to be listed here and aren't any more. `ribbons-digital/pi-herd`
hardcoded `--name` and `--session-id` into every harness launch, and omp — the agent
this setup drives — hard-errors on `unknown flags: --name, --session-id`; it also
shipped a Pi-only extension. It couldn't drive omp without patching, so it was dropped
from `herdr_plugins.txt` rather than carried as permanently broken.

`AltanS/collie` — a mobile web UI for the herd, served over Tailscale — was removed
because it wasn't wanted, not because it was broken. Worth recording is that taking it
out was three steps, not one: a plugin that installs a service owns state herdr knows
nothing about. `herdr plugin action invoke uninstall --plugin herdr.collie` came first,
to pull the `herdr.collie` LaunchAgent and the `tailscale serve` mapping the bridge had
published to the tailnet; then `herdr plugin uninstall herdr.collie`; then its config
directory, which `herdr plugin uninstall` leaves behind and which held a `.env` of VAPID
push keys. Uninstalling the plugin alone would have left a service running against a
plugin that no longer existed.

`razajamil/herdr-plugin-workspace-manager` — declarative tab/pane layouts applied to
each new worktree — went the same way once `fleet` started building the workspaces it
dispatches into itself. Two things arranging one fresh worktree is the same race that
got reviewr's `auto_open` turned off, and the plugin only ever won it on a repo it had
a YAML layout for; every other worktree got the bare pane anyway. Removal was two
steps: `herdr plugin uninstall herdr-plugin-workspace-manager` on each machine, then
its config directory — which lives in this repo, so deleting
`config/herdr/plugins/config/herdr-plugin-workspace-manager` here clears it everywhere
the tree is linked. The one capability lost with it is `remove-gone`, which previewed
and cleared worktrees whose upstream branch had been deleted; `herdr worktree list`
then `herdr worktree remove --workspace <id>` is the manual form.

`nikok6/herdr-mirror` — a remote herdr's workspaces mirrored into this one's sidebar
over ssh, remote panes streaming into local ones — was removed because it wasn't
wanted. It took the `# local-only` manifest marker with it: mirror was the only spec
that ever carried one and the marker existed *for* it, so `install.sh` no longer
captures a line's trailing comment or looks at `$SSH_CONNECTION` at all. Removal was
four steps, and collie is the reason to expect that: a plugin that runs a daemon owns
state herdr knows nothing about. `herdr plugin action invoke teardown --plugin mirror`
came first, closing every mirrored workspace and pausing autostart; then `herdr plugin
uninstall mirror` — no `--yes` there, uninstall rejects that flag as a usage error
where install requires it; then `config/herdr/plugins/config/mirror`, which lives in
this repo, so deleting it here clears it everywhere the tree is linked. The fourth is
the one teardown doesn't do: `~/.local/state/herdr-mirror` held a per-host ssh
ControlMaster started with `ControlPersist=yes`, so an `ssh -N` to the remote outlived
the daemon, the plugin and the uninstall. Closing it takes
`ssh -S ~/.local/state/herdr-mirror/<host>.ctl -O exit <host>`; then the state
directory goes, along with the empty
`~/.config/herdr-mirror` that pre-dated the move of `hosts.toml` into this repo. Only
the laptop needed any of it, since local-only meant mirror was never installed
anywhere else. `prefix+alt+n`, `prefix+alt+c`, `prefix+alt+v` and `prefix+alt+s` are
free again, and the palette lost ten of its thirty-three actions with it.

With ten plugins and twenty-three registered actions between them, keybindings stopped
being a per-plugin question and became one decision: `config/herdr/palette/palette.sh`,
bound to `prefix+p` — free because this config moved herdr's own `previous_tab` off it
and onto `prefix+shift+tab` — builds its fzf list at run time from `herdr plugin action
list`, so every action of every installed plugin is one fuzzy search away whether or not
it has a key. Only the ones reached for constantly earn a `[[keys.command]]` entry;
ghzinga's click-driven `open` and worktree-setup's total absence of actions all stay
reachable through the palette instead of crowding the keymap.

That palette started as the `JanTvrdik/herdr-command-palette` plugin and is now a script
in this repo, for two reasons that are really one. fzf needs a TTY; a herdr plugin action
runs on the server without one, so the plugin had to host the picker in an `overlay`
plugin pane, and an overlay covers the whole canvas — a command palette that takes the
screen is a tab, not a palette. A `type = "popup"` keybinding gets a TTY directly and is
session-modal, so the plugin's only job disappeared along with the full-screen overlay.
The fork also rewrote the rows: upstream led each one with a `plugin.action` id up to 42
characters wide, which buried the words you actually read behind an id and left the
titles in a ragged column. Titles come first now, in a fixed column, with the plugin id
trailing and dimmed. It stays visible rather than hidden in the invoke-only field
because fzf matches against what it displays, so a hidden field can't be searched.

Herdr's packed sidebar renders only the tokens named in a `[ui.sidebar.agents]`/
`[ui.sidebar.spaces]` row — a plugin can write a custom token correctly and still be
invisible if nothing names it. Two plugins depend on this: `herdr-agent-inbox`
contributes `$title`, `$flag`, `$age`, `$since`, and the workspace-level `$agents`/
`$busy`; `gh-pr` contributes `$pr`, the branch's PR state as `#123 ✓`. Both rows are
named in `config/herdr/config.toml` — miss one and its plugin looks broken when it's
actually just unrendered.

`worktree.created` fires on a new worktree and `worktree-setup` makes the checkout
usable — copies `.env*` from the main checkout, `mise trust`, `direnv allow`, installs
deps. Nothing else runs at that moment, by design: arranging the workspace belongs to
whoever asked for the worktree. `fleet` builds its own tabs and panes and starts the
agent itself via `herdr agent start`, which blocks until herdr detects it's ready; a
worktree created by hand stays one bare pane until you shape it. `reviewr` could
auto-open here too and deliberately doesn't — a branch cut seconds ago is a zero-line
diff, and on a fleet worktree the pane would land on top of the layout fleet just
declared. `prefix+alt+r` opens it when there is finally something to read.

### Herdr plugin keybindings — `[keys]` only knows herdr's own actions

herdr's `[keys]` table takes only its own built-in action names — there's no field in
it that names a plugin action. The only way to bind one to a key is `[[keys.command]]`,
which shells back out to the herdr CLI instead of naming the action in config:

```toml
[[keys.command]]
key = "prefix+i"
type = "shell"
command = "herdr plugin action invoke settle --plugin herdr-agent-inbox"
```

`type` controls how the command surfaces: `shell` runs it detached in the background,
`pane` opens a temporary pane that closes when the command exits, `popup` opens a
session-modal terminal. Plugin actions invoked this way are short control commands with
no output worth watching, so `shell` is the right call almost every time.

Several plugin READMEs (reviewr, vim-herdr-navigation, token-dashboard) still
document `type = "plugin_action"` with a combined `<plugin>.<action>` command string
instead of this. That form is stale: `herdr --default-config` on 0.8.0 documents only
`shell`/`pane`/`popup`, and `plugin_action` isn't one of them. Use the `shell`-plus-CLI
form above regardless of what a given plugin's own docs say.

### Agent skills — the list is tracked, the lockfile isn't

Same shape as Herdr plugins above: `agent_skills.txt` is the tracked source of truth, one
`<owner>/<repo> --skill <name>` per line, and the state the CLI generates alongside it —
`~/.agents/.skill-lock.json`, content hashes and install/update timestamps — stays
untracked.

`install.sh` runs `npx skills add <owner>/<repo> --skill <name> -g -y` for each line.
`-g` writes one canonical copy of the skill into `~/.agents/skills` and symlinks every
agent the CLI detects at that tree, instead of installing into a single project; `-y`
accepts its prompts so this can run with no tty attached. omp needs no install target of
its own here — it picks skills up through its `agents` skill provider, reading
`~/.agents/skills` directly rather than needing anything copied into
`~/.omp/agent/skills`.

(`~/.omp/agent/skills` is a separate, narrower thing: the same `skills` step also
symlinks any skill an installed Herdr plugin ships in its own `skills/` directory there —
unrelated to `agent_skills.txt`, and the one part of this step that isn't new.)

Paseo's four orchestration skills come through this manifest rather than through the
desktop app's own copy hook, which can't reach either machine reliably — see [The four
skills come from the manifest, not the
app](#the-four-skills-come-from-the-manifest-not-the-app).

### `fleet` — dispatching agents herdr can reach, because omp can't

`fleet` dispatches peer coding agents into herdr worktree workspaces: each worker is a
separate `omp` in its own pane, worktree, and branch, rather than an in-process `task`
subagent. It moved to [andyhite/foreman](https://github.com/andyhite/foreman), which
keeps the transport, lifecycle, and workspace-ownership rationale with the implementation.

The CLI now arrives through Foreman's herdr plugin, listed in
`herdr_plugins.txt`; its startup hook puts `fleet` on `PATH`. The agent-facing procedure
(`skill://fleet` and `/fleet:*`) is a separate omp plugin from the same repository,
installed through omp's marketplace. This checkout retains only the general worktree rule
below.

### The worktree rule was wrong in a way `fleet` made visible

`omp/agent/rules/herdr-worktrees.md` used to say, with `alwaysApply: true`, that inside
herdr you always use `herdr worktree` and never `git worktree`. Writing `fleet` on top of
it exposed the flaw: **an agent cannot move itself into the worktree it just created.** An
omp process keeps the directory it launched in, and `herdr pane move` relocates a pane's
display rather than its shell's cwd. So for an agent's own use — building another ref,
diffing two versions — `herdr worktree create` buys a sidebar entry, a tab and a pane it
did not want.

The rule is now organised around who will occupy the worktree. Someone else will sit in
it, human or agent: `herdr worktree create`, which is the only path that runs
`tdi.worktree-setup` (the `.env*` copy, `mise trust`, `direnv allow`).
Nobody will, and you only need the files: plain `git worktree add` in a temp directory,
plain `git worktree remove` after. Removal has to match creation — `git worktree remove`
on a herdr-created worktree orphans the workspace, leaving a sidebar entry pointing at
nothing.

One measured trap, on 0.8.0: `herdr worktree open` is *not* a way to promote a plain
`git worktree add` into a real workspace. `tdi.worktree-setup` hooks `worktree.created`
only, so an opened worktree never gets its `.env*`, its `mise trust` or its installed
deps — you get a workspace wrapped around a checkout that is still unusable.

### The orchestrator is opt-in

Dropping `alwaysApply` was also what kept `fleet` from becoming ambient. An always-on rule
about worktrees is one short step from every session deciding to dispatch a fleet at its
own discretion. The rule is now a rulebook entry — it keeps its `description`, and the
model reads it through `rule://herdr-worktrees` when it is actually about to touch a
worktree. Orchestration is a separate, deliberate opt-in: `/fleet:boss <objective>`, a
command from Foreman's omp plugin, which adopts the role and points at `skill://fleet`
for the procedure. Nothing loads that skill on its own; a session that never asks for a
fleet never hears about one.

Worth being clear about what is *not* doing the gating here, because all three look like
they should. Rules have no per-agent scoping — there is no frontmatter field binding one
to an agent, and `scope:` scopes TTSR stream surfaces, not agents. Skills are session-wide
for the same reason: every documented filter (`ignoredSkills`, `disabledExtensions`,
the per-source toggles) applies to the whole session. And omp has no `--agent` flag, so a
task-agent definition can't back a top-level session either. The launch is identical for
orchestrator and worker; the only difference is that one of them was told to be one.

### NvChad's Mason/Treesitter setup — do this yourself, on purpose

NvChad's own quickstart docs say to run `:MasonInstallAll` and `:TSInstallAll` after the
first sync. Neither does what the docs imply on the current starter: `MasonInstallAll`
isn't a real command in `mason.nvim`, and `TSInstallAll` silently no-ops — the actual
command is `:TSInstall <lang>`, and `:TSInstall all` grabs *every* language
nvim-treesitter supports, which is not a sane default for anyone. Neither Mason nor
Treesitter auto-installs on first file-open in this config either. `install.sh`
deliberately does not paper over this with a guessed default set — install what you
actually use:

```
:MasonInstall pyright lua-language-server   " example, not a real default
:TSInstall python lua bash
```

or declare an `ensure_installed` list in `lua/configs/mason.lua` /
`lua/configs/treesitter.lua` once you know what those are.

### Ghostty over SSH — `TERM=xterm-ghostty` doesn't exist on most remotes

Ghostty's `TERM` is `xterm-ghostty`, and most remote hosts don't have that terminfo
entry — without a fix, anything that opens a real terminal (`nvim` included) fails with
`Error opening terminal: xterm-ghostty` the moment you SSH in. `config/ghostty/config`
sets:

```
shell-integration-features = cursor,sudo,title,ssh-env,ssh-terminfo
```

`ssh-terminfo` makes Ghostty's shell integration wrap interactive `ssh` calls, install
Ghostty's terminfo entry on the remote via `tic` the first time you connect (cached
after that, keyed by `user@host`), and fall back to `TERM=xterm-256color` automatically
if the install fails (no `tic` on the remote, etc.). `ssh-env` separately forwards
`COLORTERM`/`TERM_PROGRAM` so the remote shell can detect it's inside Ghostty — it does
**not** touch `TERM` on its own, so `ssh-terminfo` is the one actually preventing the
crash.

The wrapper is a shell function, so it only covers plain interactive `ssh` typed at a
prompt — not scripts run non-interactively, and not wrapper tools that spawn `ssh`
themselves (`mosh`, `gcloud compute ssh`, `git`/`rsync` over ssh, etc.). For those, or as
a one-off manual fix on a host you don't want Ghostty auto-installing terminfo onto:

```sh
infocmp -x xterm-ghostty | ssh host -- tic -x -
```

After that:

- Fill in secrets. The installer copies `zshrc.local.example`, `gitconfig.local.example`,
  and `ssh/config.local.example` to their `~/.*.local` targets (mode 600) if they don't
  already exist. Edit those files with real values — `zshrc`/`gitconfig`/`ssh/config`
  each source or include the copy automatically, and all three are git-ignored, so
  secrets never end up in this repo or its history. See [The `*.local`
  templates](#the-local-templates) below.
- Restart your shell (or `exec zsh`). Antidote clones its plugins on first run.
- Open tmux and press `prefix+I` to have TPM install its plugins on first run.

## Making changes

Edit the files in this repo directly — they're the real config, not copies, since
everything under `$HOME` is a symlink back here. Commit and push like normal, then run
`install.sh` (or just `git pull`) on the other machine to pick it up.

`main` is protected — push a branch and open a PR rather than pushing directly.
