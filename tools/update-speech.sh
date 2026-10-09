#!/usr/bin/env bash
set -euo pipefail

mkdocs-speech --config mkdocs.yml docs

temporary_dir=$(mktemp -d)
trap 'rm -rf "$temporary_dir"' EXIT
cp README.md "$temporary_dir/README.md"
mkdocs-speech --config mkdocs.yml "$temporary_dir"
cp "$temporary_dir/README.speech.json" README.speech.json
