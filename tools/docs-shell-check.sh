#!/usr/bin/env bash
set -euo pipefail

mermaid_asset="docs/javascripts/mermaid.min.js"
if [ -e "$mermaid_asset" ]; then
  printf 'Refusing to replace existing %s\n' "$mermaid_asset" >&2
  exit 1
fi

site_root=$(mktemp -d "${TMPDIR:-/tmp}/factory-dashboard-docs-shell.XXXXXX")
cleanup() {
  unlink "$mermaid_asset"
  find "$site_root" -mindepth 1 -depth -delete
  rmdir "$site_root"
}
trap cleanup EXIT

ln -s "$MERMAID_JS" "$mermaid_asset"
tools/check-asset-versions.sh
python3 tools/check_presentation.py --front docs/index.md README.md docs
mkdocs build --strict --site-dir "$site_root/site"

# PureScript toolchain legs: the pinned tools must be on PATH and the
# committed lock must build from the development shell. The build fetches
# registry metadata as resolution input on first use (clean runners) while
# package versions and integrity hashes stay pinned by spago.lock, and it
# reuses the cache when present; offline mode is only valid with a warm
# cache and is deliberately not used here.
command -v purs
command -v spago
command -v purs-tidy
command -v esbuild
command -v node
purs-tidy check 'src/**/*.purs' 'test/**/*.purs'
spago build

printf "development shell checks passed\n"
