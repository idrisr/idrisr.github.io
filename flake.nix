{
  description = "idrisraja.com site";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      system = flake-utils.lib.system.x86_64-linux;
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system}.site = pkgs.haskellPackages.callPackage ./site { };
      defaultPackage.${system} = self.packages.${system}.site;
    };
}
