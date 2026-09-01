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
# nice to have: starship (config/starship.toml + zshrc's prompt init), direnv
# (zshrc's shell hook), atuin (config/atuin/config.toml + zshrc's ^R binding),
# fzf (zshrc's completion/keybinding source), eza and bat (zshrc's ls/cat
# aliases), neovim (config/nvim) and ripgrep (nvim's telescope live-grep
# pickers). fd is ripgrep's other half: telescope's find_files and fzf's
# CTRL-T/ALT-C prefer it and silently fall back to plain `find` without it, so
# a missing fd never errors — it just gets slower and loses .gitignore
# awareness.
brew "starship"
brew "atuin"
brew "fzf"
brew "eza"
brew "bat"
brew "direnv"
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

# Review-first terminal diff viewer, and this repo's git pager and difftool: it
# owns core.pager and diff.tool in gitconfig, so `git diff`/`show`/`difftool`
# open a multi-file review UI instead of a scrolling stream. Replaced
# difftastic, whose structural-diff niche never justified a second on-demand
# tool once hunk covered the everyday path. Pager mode falls back to plain text
# for non-diff output, so the slot stays usable for a bare `git log`. Binary is
# `hunk`, formula is `hunk`.
brew "hunk"

# lin — Linear issue tracker from the terminal (github.com/aaronkwhite/linear-cli).
# No Homebrew core formula and no apt package, so this pulls the author's own
# tap rather than a cargo build on macOS — same tier as gh above, just for
# Linear instead of GitHub. Binary name is `lin`, not `linear-cli`. Linux gets
# the same tool via `cargo install lincli` in install.sh's Linux branch, since
# the tap only publishes bottles for macOS.
brew "aaronkwhite/tap/lin"

# .pre-commit-config.yaml runs this at commit time. It catches the generic
# secret case — tokens, keys, credentials — leaving CI's bespoke work-
# identifier grep (ci.yml) to do only the part it's uniquely positioned for:
# strings that look like ordinary words to any generic scanner.
brew "gitleaks"

# jq is load-bearing for config/herdr/palette/palette.sh and
# config/herdr/plugins/ticket-worktree/modal.sh (herdr JSON-RPC). shellcheck
# and shfmt are Justfile/CI (`just shellcheck`) and config/nvim/lua/configs/
# conform.lua's sh/bash formatter, respectively.
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
# Not a dependency of anything this repo runs — no script here calls it. It's
# here because `-c` and `--mirror` cover the resumable and recursive downloads
# curl makes you hand-roll.
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
# rust, cmake and make are build dependencies rather than everyday tools:
# install.sh's Linux branch builds eza, delta, fd and lin from source with
# cargo wherever apt has no package, and those builds need a C toolchain.
brew "rust"
brew "cmake"
brew "make"
# zshrc sources ~/.local/bin/env, which uv's own installer writes; on macOS
# this line is what puts uv there in the first place. dstack is installed with
# `uv tool install`, so this is a hard dependency of install.sh, not a
# preference between Python packaging stacks.
brew "uv"
brew "pre-commit"
brew "just"
brew "fswatch"
brew "btop"
brew "rsync"

# herdr — the terminal multiplexer config/herdr/config.toml and
# herdr_plugins.txt assume is already on PATH.
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

# The container runtime. No tracked config reads it, but it's the one tool
# here whose absence turns an ordinary project checkout into a dead end.
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
