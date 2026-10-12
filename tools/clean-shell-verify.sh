#!/usr/bin/env bash
# Reproducible clean-runner verification of the development-shell
# dependency setup. A clean hosted runner differs from a developer
# machine in two ways: no global Spago cache and no project dependency
# or build state. This script reproduces that exactly, without touching
# the active checkout or any user cache:
#   - a throwaway root is created and removed on exit (cleanup confined
#     to what this script created);
#   - only tracked sources are exported into it (git archive), so no
#     ignored .spago, output or generated state travels along;
#   - the tool's own cache paths are redirected to a task-specific
#     directory under that root; HOME is untouched;
#   - package versions and integrity hashes are pinned by the committed
#     spago.lock; registry metadata is fetched on use as resolution
#     input, and no claim is made that it is pinned.
# The ordinary docs-shell-check stays lean; this script is run on its
# own to prove the setup, not on every smoke.
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
root=$(mktemp -d "${TMPDIR:-/tmp}/factory-dashboard-clean-verify.XXXXXX")
trap 'rm -rf "$root"' EXIT

mkdir -p "$root/src" "$root/cache"
git -C "$repo" archive HEAD | tar -x -C "$root/src"

cd "$root/src"
nix develop "$repo" --quiet --no-eval-cache -c \
  env XDG_CACHE_HOME="$root/cache" \
  spago build

printf 'clean-runner dependency setup verified\n'
