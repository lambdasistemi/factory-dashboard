default:
    @just --list

docs-speech:
    nix develop . --quiet -c tools/update-speech.sh

docs-check:
    nix build --quiet .#docs

docs-shell-check:
    nix develop . --quiet -c tools/docs-shell-check.sh

docs:
    nix build .#docs

docs-preview:
    nix build --quiet .#docs --out-link result
    nix develop . --quiet -c python3 -m http.server 4173 --bind 127.0.0.1 --directory result
