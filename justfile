default:
    @just --list

# Documentation
docs-check:
    nix build --quiet .#docs

docs-shell-check:
    nix develop . --quiet -c tools/docs-shell-check.sh

docs:
    nix build .#docs

docs-preview:
    nix build --quiet .#docs --out-link result
    nix develop . --quiet -c python3 -m http.server 4173 --bind 127.0.0.1 --directory result

# Graph app
app-build:
    nix build --quiet .#app

app-format:
    nix develop . --quiet -c purs-tidy check 'src/**/*.purs' 'test/**/*.purs'

app-test:
    nix develop . --quiet -c spago test --offline

app-format-fix:
    nix develop . --quiet -c purs-tidy format-in-place 'src/**/*.purs' 'test/**/*.purs'

# Local gate mirroring hosted CI
ci:
    nix flake check --no-eval-cache
