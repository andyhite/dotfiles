# Homebrew formulas and casks for this repo's configs and install.sh's tools
# step. `brew bundle install --file Brewfile` (or the bare `brew bundle` when
# run from this directory) installs/upgrades everything below.
#
# macOS only — the Linux branch of install.sh uses apt plus a handful of
# native installers (rustup, cargo, GitHub releases) instead, because none of
# this has a single cross-distro package name.
#
# `brew bundle` never uninstalls anything absent from this file, so trimming a
# line here doesn't remove the formula from a machine that already has it —
# that's a manual `brew uninstall` if you actually want it gone.
#
# Deliberately excluded: anything work/project-specific (AWS, k8s, terraform,
# postgres clients) and QMK/hardware-flashing tools. Those belong to whichever
# project needs them, not to every fresh machine this repo bootstraps.
#
# antidote is also absent on purpose: install.sh git-clones it to
# ~/.antidote instead of installing it via brew, so Linux and macOS share the
# exact same install path rather than diverging into brew-vs-git.

# ── Config dependencies ──────────────────────────────────────────────────────
# Each of these is loaded or shelled out to by a tracked config, not merely
# nice to have: starship (config/starship.toml + zshrc's prompt init), zoxide
# and direnv (zshrc's shell hooks), atuin (config/atuin/config.toml + zshrc's
# ^R binding), fzf (zshrc's completion/keybinding source and tmux.conf's
# prefix+F switcher), eza and bat (zshrc's ls/cat aliases), tmux (tmux.conf),
# neovim (config/nvim) and ripgrep (nvim's telescope live-grep pickers). fd is
# ripgrep's other half: telescope's find_files and fzf's CTRL-T/ALT-C prefer
# it and silently fall back to plain `find` without it, so a missing fd never
# errors — it just gets slower and loses .gitignore awareness.
brew "starship"
brew "zoxide"
brew "atuin"
brew "fzf"
brew "eza"
brew "bat"
brew "glow"
#
# dotfiles-help renders the help/ corpus through glow; bat only syntax-
# highlights the markdown source when glow is absent.
brew "direnv"
brew "tmux"
brew "neovim"
brew "ripgrep"
brew "fd"

# ── Version manager ───────────────────────────────────────────────────────────
# mise reads the tracked ~/.tool-versions (this repo's `tool-versions`) and
# replaced asdf: one binary instead of a plugin per language, PATH activation
# instead of shims, and no per-tool `plugin add` step to keep in sync here.
brew "mise"

# ── Git + GitHub ─────────────────────────────────────────────────────────────
# The tracked gitconfig names `gh` as its credential helper and declares a
# `filter "lfs"` block, while config/lazygit/config.yml drives the lazygit TUI.
# These are config dependencies, not optional conveniences.
brew "git"
brew "gh"
brew "git-lfs"
brew "lazygit"

# gitconfig sets diff.algorithm = histogram, colorMoved = default and
# diff.renames = copies, but never configured a pager — all of that rendered
# through plain `less`. delta is the pager that actually shows it: side-by-
# side, syntax-highlighted, move-aware diffs. Binary is `delta`, formula is
# git-delta.
brew "git-delta"

# gitconfig is rebase-first (pull.rebase, rebase.autoStash, rerere +
# rerere.autoupdate); absorb is the step rebase alone doesn't cover — it
# assigns worktree hunks back to the commit that last touched those lines,
# which is the review-fixup step that was missing.
brew "git-absorb"

# Wired as a `git difftool`, deliberately not the default pager — it's slow
# and can't do intra-line word diff, which delta handles better for ordinary
# changes. Its value is reviewing a refactor that moved code, where delta's
# line-based view falls apart. Binary is `difft`.
brew "difftastic"

# Used colocated (`jj git init --colocate`) so the repo stays a normal git
# repo underneath. Earns its place from fleet: every dispatched worker gets
# its own worktree and branch, and `jj undo` on the operation log reverts a
# worker's change atomically, while jj's automatic descendant rebase makes
# restacking a chain of worker branches cheap. Config: config/jj/config.toml.
brew "jj"

# .pre-commit-config.yaml runs this at commit time. It catches the generic
# secret case — tokens, keys, credentials — leaving CI's bespoke work-
# identifier grep (ci.yml) to do only the part it's uniquely positioned for:
# strings that look like ordinary words to any generic scanner.
brew "gitleaks"

# ── Shell/JSON tooling this repo's own scripts use ──────────────────────────
# jq is the only one actually load-bearing: config/herdr/palette/palette.sh
# shells out to `jq -r` to build fzf's rows and unpack herdr's JSON-RPC
# responses. shellcheck and shfmt are Justfile/CI (`just shellcheck`) and
# config/nvim/lua/configs/conform.lua's sh/bash formatter, respectively.
brew "jq"
brew "shellcheck"
brew "shfmt"

# ── Markdown linting ─────────────────────────────────────────────────────────
# .markdownlint.yaml is the shared rule config: config/nvim/lua/configs/
# lint.lua's "markdownlint" linter reads it too, so the editor and `just
# fix-md` agree on the same rules. `--fix` covers the auto-fixable subset
# (table pipe spacing, trailing newlines, bare URLs); MD013/MD041 are
# disabled outright rather than fought, since neither matches this repo's
# actual conventions — see the config file itself for why.
brew "markdownlint-cli2"

# ── Local reverse proxy ─────────────────────────────────────────────────────
# Terminates real, browser-trusted HTTPS for internal-only dev hostnames that
# Let's Encrypt can never issue certs for — `local_certs` in the tracked
# Caddyfile mints them from Caddy's own built-in CA instead (`caddy trust`
# installs that CA into your keychain, once). Base config: caddy/Caddyfile;
# the actual site blocks are machine-local, never tracked — see
# caddy/Caddyfile.local.example. Not started automatically by
# install.sh: run `brew services start caddy` yourself once you've filled in
# a local Caddyfile.
brew "caddy"

# ── Local DNS ────────────────────────────────────────────────────────────────
# Pairs with macOS's per-domain /etc/resolver/<domain> mechanism to resolve an
# entire wildcard domain (and every subdomain under it) straight to
# 127.0.0.1 — for local dev tooling like a Caddy reverse proxy terminating
# TLS for a service normally only reachable over VPN/Tailscale, without
# maintaining one /etc/hosts line per hostname. Base config: dnsmasq/
# dnsmasq.conf; the actual domain(s) are machine-local, never tracked — see
# dnsmasq/dnsmasq.local.conf.example. Not started automatically by
# install.sh: run `brew services start dnsmasq` yourself once you've filled
# in a local.conf.
brew "dnsmasq"

# ── General CLI utilities ────────────────────────────────────────────────────
# None of these are dependencies of anything this repo runs — no script here
# calls yq, a g-prefixed coreutils binary, a moreutils tool, or wget. They're
# here because they're genuinely useful to have on PATH for ad-hoc work: yq is
# jq's YAML-shaped counterpart, coreutils gives GNU flags BSD's tools lack (see
# the coreutils help entry), moreutils' sponge/vipe/ts/etc plug real pipeline
# gaps, and wget's `-c`/`--mirror` cover cases curl makes you hand-roll.
#
# `tree` used to live here too, aliased over by `zshrc`'s `eza --tree --icons`
# and kept only for a `command tree` escape hatch nothing in this repo (or in
# practice) ever reached for — eza's `-T`/`-L`/`-D`/`-I` already cover what
# `tree` offers apart from JSON/XML output, so it was cut rather than kept for
# a capability gap that was never actually used.
brew "yq"
brew "coreutils"
brew "moreutils"
brew "wget"

# ── Shell completions ────────────────────────────────────────────────────────
# install.sh hand-generates completions for tools that ship no generator at
# all — _omp, _herdr, _tree-sitter, from the `completions` step. carapace is
# the other half: one bridge shipping specs for roughly 1000 CLIs, and it
# feeds fzf-tab directly. It has no spec for omp/herdr/tree-sitter, so the two
# mechanisms coexist rather than collide — carapace does not replace the
# generated files.
brew "carapace"

# ── General dev CLIs ─────────────────────────────────────────────────────────
brew "rust"
brew "cmake"
brew "make"
brew "pipx"
# zshrc already sources ~/.local/bin/env and its comment names uv alongside
# pipx; uv was present on this machine but tracked in no manifest, so a fresh
# machine never got it. pipx stays too — pulling it now would strand whatever
# it already installed.
brew "uv"
brew "pre-commit"
brew "golangci-lint"
brew "clang-format"
brew "watchexec"
brew "just"
brew "fswatch"
brew "ncdu"
brew "dive"
brew "ctop"
# ncdu covers disk and ctop covers containers; nothing here covered host
# processes.
brew "btop"
# Benchmarking — the only measurement tool alongside cloc/dive/ctop.
brew "hyperfine"
# ripgrep finds, nothing here replaced. sd is the sed-shaped counterpart, with
# sane regex and a literal-string mode that doesn't need escaping.
brew "sd"
# `tldr` client. Binary name differs from the formula name.
brew "tealdeer"
brew "cloc"
brew "rsync"

# herdr — the terminal multiplexer config/herdr/config.toml, herdr_plugins.txt
# and this Brewfile's `andyhite/foreman` bits all assume is already on PATH.
# A real Homebrew core formula (`brew info herdr`), same tier as lazygit/btop
# above — not a tap, not a cargo build.
#
# The same shadow trap already fixed once for `uv` applies here: herdr's own
# installer (`curl -fsSL https://herdr.dev/install.sh | sh`) also drops a
# binary at ~/.local/bin/herdr, and `zshrc` puts `~/.local/bin` ahead of
# Homebrew's bin on PATH — so a machine that ever ran that installer by hand
# has a copy `brew upgrade` will never touch, silently shadowing this one.
# `which -a herdr` shows both if that's happened; `rm ~/.local/bin/herdr`
# lets the Homebrew copy win, same fix as uv's.
brew "herdr"

# ── Casks ─────────────────────────────────────────────────────────────────────
cask "ghostty"
cask "zed"
# macOS window/Space automation (Lua-scriptable) — drives config/hammerspoon/init.lua's
# per-Space Ghostty toggle, working around the upstream app-wide toggle_visibility bug
# tracked in that file. See help/00-shell.md's hammerspoon section.
cask "hammerspoon"
# config/zed/settings.json sets ui_font_family to "Geist", so font-geist is
# a hard requirement of that config, not a nice-to-have.
cask "font-geist"
# config/zed/settings.json sets buffer_font_family to "Geist Mono", so
# font-geist-mono is a hard requirement of that config, not a nice-to-have.
cask "font-geist-mono"
# ghostty and nvim both render Nerd Font glyphs (icons in eza/telescope
# output, powerline separators in the prompt); this is the one font both need.
cask "font-geist-mono-nerd-font"
# Ships a signed .pkg, so installing or upgrading it runs sudo mid-bundle —
# the entry behind the password prompt install.sh's tools step warns about.
cask "1password-cli"

# dive and ctop were already in this file and are both useless without a
# container runtime, which was the actual gap they left open.
#
# args: { adopt: true } is required, not decorative: /Applications/Docker.app
# already exists on the machine this repo runs on, and a plain cask install
# aborts with "It seems there is already an App at...". adopt tells brew to
# take over the existing install instead of refusing to proceed.
#
# No Linux counterpart in install.sh's apt branch, deliberately: Docker's apt
# repository needs a third-party source list, and the container runtime on a
# headless box is a host-level decision, not a dotfiles one.
cask "docker-desktop", args: { adopt: true }
