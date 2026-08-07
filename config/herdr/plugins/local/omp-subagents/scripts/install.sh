#!/usr/bin/env bash
# Installs src/viewer.ts's native-renderer dependencies (@oh-my-pi/pi-coding-agent,
# @oh-my-pi/pi-tui), run by this plugin's [[build]] step (see ../herdr-plugin.toml)
# with cwd = plugin root.
#
# src/viewer.ts imports internal, unstable APIs straight out of the installed omp
# package — there is no semver contract on any of them. Installing anything other
# than the exact package versions the running `omp` binary itself ships with is how
# the two silently drift apart, so this script re-pins package.json's dependency
# versions to `omp --version` (format "omp/<semver>") every time it runs, then
# installs. Falls back to whatever is already committed in package.json — this
# repo's last-known-good pin — when `omp` isn't on PATH at all (herdr installed
# without omp yet, or omp temporarily missing); src/viewer.ts's own
# fallback-on-any-failure path (see its header comment) is what covers any runtime
# skew that slips through despite this.
set -euo pipefail
cd "$(dirname "$0")/.."

if version="$(command -v omp >/dev/null 2>&1 && omp --version 2>/dev/null | sed -n 's#.*/##p')" && [ -n "$version" ]; then
  echo "omp-subagents: pinning to installed omp v$version"
  jq --arg v "$version" \
    '.dependencies["@oh-my-pi/pi-coding-agent"] = $v | .dependencies["@oh-my-pi/pi-tui"] = $v' \
    package.json >package.json.tmp
  mv package.json.tmp package.json
else
  echo "omp-subagents: omp not on PATH (or --version unparseable) — using the committed package.json pin" >&2
fi

bun install
