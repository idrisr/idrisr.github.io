{
  description = "idrisraja.com site";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          compiler = "ghc984";
        in
        {
          packages =
            rec {
              site = pkgs.haskellPackages.callPackage ./. { };
              default = site;
            };

          devShells.default = pkgs.mkShell
            {
              buildInputs =
                with pkgs.haskell.packages."${compiler}";
                [
                  fourmolu
                  cabal-fmt
                  implicit-hie
                  ghcid
                  cabal2nix
                  ghc
                  pkgs.ghciwatch
                  cabal-install
                  pkgs.haskell-language-server
                  pkgs.zlib
                ];
            };
        }
      );
}
