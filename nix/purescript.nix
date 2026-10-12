{ pkgs, repoRoot }:

let
  nodejs = pkgs.nodejs_22;

  # One runtime geometry dependency; all npm packages are hash-locked.
  playwrightNodeModules = pkgs.importNpmLock.buildNodeModules {
    inherit nodejs;
    npmRoot = repoRoot;
    derivationArgs = { PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1"; };
  };

  commonArgs = {
    src = repoRoot;
    spagoYaml = repoRoot + "/spago.yaml";
    spagoLock = repoRoot + "/spago.lock";
    version = "0.1.0";
    nativeBuildInputs = [
      nodejs
      pkgs.purs
      pkgs.spago-unstable
      pkgs.esbuild
    ];
  };

  # The single app build: strict compiler-warning policy (a warning fails
  # the derivation), then the browser bundle. Every check that needs the
  # app reuses this derivation; nothing rebuilds it.
  web-dist = pkgs.mkSpagoDerivation (commonArgs // {
    pname = "factory-graph-web";
    buildPhase = ''
      set -o pipefail
      ln -s ${playwrightNodeModules}/node_modules node_modules
      esbuild src/bootstrap.js --bundle --platform=browser --format=iife --minify --legal-comments=inline --outfile=bootstrap.js
      spago bundle --offline --module Main 2>&1 | tee build.log
      cat bootstrap.js dist/index.js > combined.js
      mv combined.js dist/index.js
      if grep -E '^\[WARNING' build.log; then
        echo "strict warning policy: compiler warnings are not allowed" >&2
        exit 1
      fi
    '';
    installPhase = ''
      mkdir -p $out
      cp dist/index.html dist/index.js $out/
      assetHash=$(sha256sum $out/index.js | cut -d ' ' -f1)
      sed -i "s|src=\"index.js\"|src=\"index.js?v=$assetHash\"|" $out/index.html
      cp build.log $out/
      test -s $out/index.js || { echo "bundle is empty" >&2; exit 1; }
    '';
  });

  # Domain and boundary semantics: the spec suites run under Node inside
  # the sandbox.
  domain-semantics = pkgs.mkSpagoDerivation (commonArgs // {
    pname = "factory-graph-domain-semantics";
    buildPhase = ''
      spago test --offline
    '';
    installPhase = ''
      mkdir -p $out
      touch $out/passed
    '';
  });
in
{
  inherit
    nodejs
    playwrightNodeModules
    web-dist
    domain-semantics
    ;
}
