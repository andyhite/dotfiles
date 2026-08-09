# Read by EVERY zsh: interactive or not, login or not. That includes the
# one-shot shells behind `ssh host 'cmd'`, systemd units, git hooks, and editor
# subprocesses — none of which read ~/.zshrc. So anything those need on PATH has
# to live here, or `ssh box herdr status` answers "command not found" while the
# same command works fine once you're logged in.
#
# install.sh already prepends this exact list before running the remote copy of
# itself (see remote_bootstrap), because it hit this problem first: without it,
# every `command -v` guard decides its tool is missing and reinstalls from
# scratch. That workaround stays — it has to bootstrap a machine where this file
# isn't linked yet — but with this in place it is now a belt-and-braces measure
# rather than the only thing holding PATH together.
#
# Keep this file to PATH and nothing else. It runs ahead of every script on the
# box, so a subprocess or a prompt hook here is a tax charged to things that
# never wanted a shell in the first place. mise is the example: `mise activate`
# rewrites PATH on each prompt and belongs in zshrc, while the shims directory
# below is the non-interactive equivalent that needs no hook.

# -U makes the array reject duplicates, keeping the FIRST occurrence. That's
# what lets zshrc prepend these again without PATH growing a copy per shell —
# and it has to prepend again, because on macOS /etc/zprofile runs path_helper
# between this file and zshrc, which reorders PATH and pushes system
# directories back in front of everything here.
typeset -U path PATH

path=(
  # omp, herdr, paseo, tree-sitter, uv
  "$HOME/.local/bin"
  # rustup's own shell hook, ~/.cargo/env, does exactly this one prepend and is
  # what this file replaced on machines where rustup wrote its own ~/.zshenv.
  "$HOME/.cargo/bin"
  # node and friends for non-interactive shells. Interactive ones get the real
  # thing from `mise activate` in zshrc, which supersedes these shims.
  "$HOME/.local/share/mise/shims"
  $path
)
