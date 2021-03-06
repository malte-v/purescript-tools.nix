{
  inputs = {
    haskellNix.url = "github:input-output-hk/haskell.nix";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, haskellNix, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ] (
      system:
        let
          pkgs = haskellNix.legacyPackages."${system}";
        in
          {
            packages = {
              purescript = pkgs.lib.makeOverridable (
                { rev, sha256 }: (
                  pkgs.haskell-nix.stackProject' {
                    name = "purescript";
                    src = pkgs.fetchFromGitHub {
                      owner = "purescript";
                      repo = "purescript";
                      inherit rev sha256;
                    };
                    pkg-def-extras = [
                      (hackage: { hsc2hs = hackage.hsc2hs."0.68.7".revisions.default; })
                    ];
                  }
                ).hsPkgs.purescript.components.exes.purs
              ) {
                rev = "v0.14.0";
                sha256 = "1ffy77b8ack65r3q22c0ychfsyz8jg6d69w28fjf57v6lr8dmh5k";
              }
              ;

              spago = let
                # See https://github.com/purescript/spago/blob/0.19.1/src/Spago/Prelude.hs#L223
                # and https://github.com/purescript/spago/blob/0.19.1/src/Spago/Templates.hs#L31
                #
                # There is Template Haskell code downloading stuff from the internet,
                # so we have to fix it.
                docsSearchVersion = "v0.0.10";
                docsSearchApp = pkgs.fetchurl {
                  url = "https://github.com/spacchetti/purescript-docs-search/releases/download/${docsSearchVersion}/docs-search-app.js";
                  sha256 = "sha256-Rd0ieiE56WW+3DNBeolex8smeuSiwxTmBxkk0ZOAqlQ=";
                };
                docsSearch = pkgs.fetchurl {
                  url = "https://github.com/spacchetti/purescript-docs-search/releases/download/${docsSearchVersion}/purescript-docs-search";
                  sha256 = "sha256-Q3rIsVzxLE9YRzagdWD/0T9EQM0MRMOm96KSSKH/gXE=";
                };
              in
                (
                  pkgs.haskell-nix.stackProject' {
                    name = "spago";
                    src = pkgs.fetchFromGitHub {
                      owner = "purescript";
                      repo = "spago";
                      rev = "0.19.1";
                      sha256 = "sha256-k4k/Djq86YfMXN6f6YmnilWlO2z+ierlEy1CmPh85lE=";
                      extraPostFetch = ''
                        # See https://github.com/input-output-hk/haskell.nix/issues/219
                        sed -i '/defaults:/d' "$out/package.yaml"
                        # Force regeneration of the cabal file after patching package.yaml
                        rm "$out/spago.cabal"

                        cp ${docsSearchApp} $out/templates/docs-search-app.js
                        cp ${docsSearch} $out/templates/purescript-docs-search
                      '';
                    };
                    # See https://github.com/input-output-hk/haskell.nix/issues/219
                    modules = [ { packages.spago.components.tests.test.buildable = false; } ];
                  }
                ).hsPkgs.spago.components.exes.spago;

              spago2nix = let
                src = pkgs.fetchFromGitHub {
                  owner = "justinwoo";
                  repo = "spago2nix";
                  rev = "898798204fa8f53837bbcf71e30aeb425deb0906";
                  sha256 = "sha256-uIVlFzsayjCr7tBpx+ROTavPO0Rl63u3caJIGhsN68U=";
                };
                purs = self.packages.${system}.purescript.override {
                  rev = "v0.13.8";
                  sha256 = "sha256-QMyomlrKR4XfZcF1y0PQ2OQzbCzf0NONf81ZJA3nj1Y=";
                };
                jsOut = (import "${src}/spago-packages.nix" { inherit pkgs; }).mkBuildProjectOutput { inherit src purs; };
                jsBundled = pkgs.runCommand "spago2nix-bundled" {} ''
                  ${purs}/bin/purs bundle ${jsOut}/output/**/*.js --main Main -o $out
                '';
                path = pkgs.lib.makeBinPath [
                  pkgs.coreutils
                  pkgs.nix-prefetch-git
                  pkgs.dhall-json
                  self.packages.${system}.spago
                ];
              in
                pkgs.runCommand "spago2nix" {
                  nativeBuildInputs = [ pkgs.makeWrapper ];
                } ''
                  mkdir -p $out/bin
                  target=$out/bin/spago2nix

                  >>$target echo '#!${pkgs.nodejs}/bin/node'
                  >>$target echo "require('${jsBundled}')";

                  chmod +x $target

                  wrapProgram $target \
                    --prefix PATH : ${path}
                '';
            };

            purty = pkgs.nodePackages.purty;
          }
    );
}
