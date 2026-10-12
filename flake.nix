{
  description = "Factory Dashboard product record and synthetic graph app";

  inputs.dev-assets.url = "github:paolino/dev-assets/a9d7371c1118de4026ba6ee3a9c3b54614924b82?dir=mkdocs";

  inputs.purescript-overlay = {
    url = "github:paolino/purescript-overlay/fix/remove-nodePackages";
    inputs.nixpkgs.follows = "dev-assets/nixpkgs";
  };

  inputs.mkSpagoDerivation = {
    url = "github:jeslie0/mkSpagoDerivation";
    inputs.nixpkgs.follows = "dev-assets/nixpkgs";
  };

  outputs =
    {
      self,
      dev-assets,
      purescript-overlay,
      mkSpagoDerivation,
    }:
    let
      system = "x86_64-linux";
      shared = dev-assets;
      pkgs = import shared.inputs.nixpkgs {
        inherit system;
        overlays = [
          purescript-overlay.overlays.default
          mkSpagoDerivation.overlays.default
        ];
      };
      repoRoot = ./.;
      terminal = pkgs.python3Packages.buildPythonPackage {
        pname = "mkdocs-terminal";
        version = "4.8.0";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/cd/21/7eb37356eeeaa87be873c806ea84794b3b81285e49a6c7c4a250c66729a6/mkdocs_terminal-4.8.0-py3-none-any.whl";
          sha256 = "86af80cc7152aa61e9058db0a84eefae56e769222e81eb5291ad87e89d3f2922";
        };
        dependencies = with pkgs.python3Packages; [
          jinja2
          markdown
          mkdocs
          pygments
          pymdown-extensions
        ];
      };
      docsPython = pkgs.python3.withPackages (
        pythonPackages:
        with pythonPackages;
        [
          mkdocs
          markdown
          pymdown-extensions
          pyyaml
          terminal
        ]
      );
      purescript = import ./nix/purescript.nix { inherit pkgs repoRoot; };
      documentation = pkgs.stdenvNoCC.mkDerivation {
        pname = "factory-dashboard-docs";
        version = (builtins.fromJSON (builtins.readFile ./.release-please-manifest.json)).".";
        src = pkgs.lib.fileset.toSource {
          root = ./.;
          fileset = pkgs.lib.fileset.unions [
            ./docs
            ./tools
            ./mkdocs.yml
            ./README.md
          ];
        };
        nativeBuildInputs = [ docsPython ];
        buildPhase = ''
          cp ${shared.packages.${system}.mermaid-js} docs/javascripts/mermaid.min.js
          bash tools/check-asset-versions.sh
          python3 tools/check_presentation.py --front docs/index.md README.md docs
          mkdocs build --strict --site-dir build-site
        '';
        installPhase = ''
          mkdir -p "$out"
          cp -R build-site/. "$out/"
          mkdir -p "$out/app"
          cp ${purescript.web-dist}/index.html ${purescript.web-dist}/index.js "$out/app/"
        '';
        dontFixup = true;
      };
      checks = import ./nix/checks.nix {
        inherit pkgs repoRoot documentation purescript;
      };
      docsPackages = [
        docsPython
        pkgs.just
      ];
      appShell = pkgs.mkShell {
        packages =
          docsPackages
          ++ [
            pkgs.purs
            pkgs.spago-unstable
            pkgs.purs-tidy-bin.purs-tidy-0_10_0
            pkgs.esbuild
            purescript.nodejs
          ];
        MERMAID_JS = shared.packages.${system}.mermaid-js;
      };
      docsShell = pkgs.mkShell {
        packages = docsPackages;
        MERMAID_JS = shared.packages.${system}.mermaid-js;
      };
    in
    {
      devShells.${system} = {
        default = appShell;
        docs = docsShell;
      };

      packages.${system} = {
        default = documentation;
        docs = documentation;
        app = purescript.web-dist;
      };

      checks.${system} = checks;
    };
}
