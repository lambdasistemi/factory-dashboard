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
python3 tools/check_presentation.py --front docs/index.md README.md docs
mkdocs build --strict --site-dir "$site_root/site"
