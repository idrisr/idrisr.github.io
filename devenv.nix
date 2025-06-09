{ pkgs, ... }:
let compiler = "ghc96";
in {
  packages = with pkgs.haskell.packages."${compiler}"; [
    fourmolu
    cabal-fmt
    implicit-hie
    ghcid
    cabal2nix
    pkgs.ghciwatch
  ];

  languages.haskell.enable = true;
}
