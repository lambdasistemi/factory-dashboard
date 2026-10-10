{
  pkgs,
  repoRoot,
  documentation,
  purescript,
}:

let
  # Shared staging for the browser checks: the built artifact under
  # staging/app plus the deliberately mutated copy with one seeded external
  # request under staging/mutated. One bundle input, two checks.
  mkBrowserCheck =
    name: specFile:
    pkgs.runCommand name
      {
        nativeBuildInputs = [
          purescript.nodejs
          pkgs.python3
          pkgs.bash
          pkgs.coreutils
          pkgs.gnused
        ];
      }
      ''
        set -euo pipefail
        cp -R ${repoRoot} source
        chmod -R u+w source
        cd source
        ln -s ${purescript.playwrightNodeModules}/node_modules node_modules
        rm -rf staging
        mkdir -p staging/app staging/mutated
        cp ${purescript.web-dist}/index.html ${purescript.web-dist}/index.js staging/app/
        cp staging/app/index.html staging/mutated/index.html
        chmod u+w staging/app/index.html staging/app/index.js staging/mutated/index.html
        sed -i 's|src="index.js"|src="../app/index.js"|' staging/mutated/index.html
        printf '<script>fetch("https://example.invalid/beacon").catch(function(){})</script>' >> staging/mutated/index.html
        export HOME=$(mktemp -d)
        export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
        export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
        ./node_modules/.bin/playwright test -c e2e/playwright.config.js ${specFile} --reporter=list
        mkdir -p $out
        touch $out/passed
      '';
in
{
  docs = documentation;

  app-format = pkgs.runCommand "factory-graph-format"
    {
      nativeBuildInputs = [
        pkgs.purs-tidy-bin.purs-tidy-0_10_0
        pkgs.findutils
        pkgs.coreutils
      ];
    }
    ''
      set -euo pipefail
      cd ${repoRoot}
      srcCount=$(find src -name '*.purs' -type f | wc -l)
      testCount=$(find test -name '*.purs' -type f | wc -l)
      if [ "$srcCount" -lt 5 ]; then echo "source extent collapsed to $srcCount files" >&2; exit 1; fi
      if [ "$testCount" -lt 1 ]; then echo "test extent collapsed to zero files" >&2; exit 1; fi
      purs-tidy check 'src/**/*.purs' 'test/**/*.purs'
      touch $out
    '';

  # Structure-only checks per the frozen gate: strict warning policy replayed
  # against the single app build log, module responsibility/dependency
  # rules, and the typed FFI/dependency inventory.
  app-static-quality = pkgs.runCommand "factory-graph-static-quality"
    {
      nativeBuildInputs = [
        pkgs.bash
        pkgs.gnugrep
        pkgs.jq
        pkgs.findutils
        pkgs.coreutils
        pkgs.gawk
      ];
    }
    ''
      set -euo pipefail
      cd ${repoRoot}
      bash tools/static-quality.sh ${purescript.web-dist}/build.log
      touch $out
    '';

  app-build = purescript.web-dist;

  domain-semantics = purescript.domain-semantics;

  browser-journey = mkBrowserCheck "factory-graph-browser-journey" "e2e/journey.spec.js";

  browser-offline-boundary = mkBrowserCheck "factory-graph-browser-offline-boundary" "e2e/offline.spec.js";
}
