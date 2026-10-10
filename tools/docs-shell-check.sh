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
# committed lock must build from the development shell.
command -v purs
command -v spago
command -v purs-tidy
command -v esbuild
command -v node
purs-tidy check 'src/**/*.purs' 'test/**/*.purs'
spago build --offline
printf 'development shell checks passed\n'
