#!/usr/bin/env bash
# Each local script or stylesheet reference carries ?v=<first 16 hex of the file's sha256>,
# so browsers fetch a new copy when the file changes. Fail when a reference is stale.
set -euo pipefail

status=0
check() {
  local reference_file=$1 asset=$2
  local expected
  expected=$(sha256sum "docs/$asset" | cut -c1-16)
  if ! grep -F "$asset" "$reference_file" | grep -qF "?v=$expected"; then
    printf '%s: reference to %s must carry ?v=%s\n' "$reference_file" "$asset" "$expected" >&2
    status=1
  fi
}

check mkdocs.yml javascripts/mermaid-init.js
check mkdocs.yml stylesheets/terminal.css
check docs/overrides/main.html javascripts/palette.js
exit "$status"
