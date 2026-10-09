{
  description = "Documentation build for the Factory Dashboard product record";

  inputs.dev-assets.url = "github:paolino/dev-assets/a9d7371c1118de4026ba6ee3a9c3b54614924b82?dir=mkdocs";

  outputs = { self, dev-assets }:
    let
      system = "x86_64-linux";
      shared = dev-assets;
      pkgs = shared.inputs.nixpkgs.legacyPackages.${system};
      terminal = pkgs.python3Packages.buildPythonPackage {
        pname = "mkdocs-terminal";
        version = "4.8.0";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/cd/21/7eb37356eeeaa87be873c806ea84794b3b81285e49a6c7c4a250c66729a6/mkdocs_terminal-4.8.0-py3-none-any.whl";
          sha256 = "86af80cc7152aa61e9058db0a84eefae56e769222e81eb5291ad87e89d3f2922";
        };
        dependencies = with pkgs.python3Packages; [ jinja2 markdown mkdocs pygments pymdown-extensions ];
      };
      docsShell = shared.devShells.${system}.default.overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ terminal pkgs.just ];
      });
      docsPython = pkgs.python3.withPackages (pythonPackages: [
        pythonPackages.mkdocs
        pythonPackages.markdown
        pythonPackages.pymdown-extensions
        pythonPackages.pyyaml
        terminal
      ]);
      documentation = pkgs.stdenvNoCC.mkDerivation {
        pname = "factory-dashboard-docs";
        version = "0.1.0";
        src = self;
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
        '';
        dontFixup = true;
      };
    in
    {
      devShells.${system}.default = docsShell;

      packages.${system} = {
        default = documentation;
        docs = documentation;
      };

      checks.${system}.docs = documentation;
    };
}
