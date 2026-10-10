{ pkgs, repoRoot }:

let
  nodejs = pkgs.nodejs_22;
  packageJson = builtins.fromJSON (builtins.readFile (repoRoot + "/package.json"));
  packageLock = builtins.fromJSON (builtins.readFile (repoRoot + "/package-lock.json"));

  # Zero runtime npm dependencies: only the pinned Playwright runner is
  # installed, and only for the browser checks.
  playwrightPackage = {
    name = packageJson.name;
    private = true;
    type = packageJson.type;
    dependencies = {
      "@playwright/test" = packageJson.devDependencies."@playwright/test";
    };
  };
  playwrightPackageLock = packageLock // {
    packages = packageLock.packages // {
      "" = {
        name = packageLock.packages."".name;
        dependencies = {
          "@playwright/test" = packageLock.packages."".devDependencies."@playwright/test";
        };
      };
    };
  };
  playwrightNodeModules = pkgs.importNpmLock.buildNodeModules {
    inherit nodejs;
    npmRoot = repoRoot;
    package = playwrightPackage;
    packageLock = playwrightPackageLock;
    derivationArgs = {
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    };
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
      spago bundle --offline --module Main 2>&1 | tee build.log
      if grep -E '^\[WARNING' build.log; then
        echo "strict warning policy: compiler warnings are not allowed" >&2
        exit 1
      fi
    '';
    installPhase = ''
      mkdir -p $out
      cp dist/index.html dist/index.js $out/
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
