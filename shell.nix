let pkgs = import <unstable> { };
in pkgs.mkShell {
  buildInputs = with pkgs; [
    haskellPackages.hakyll
    stack
    # zlib

  ];

  shellHook = ''
    set -o vi
    alias v='vim';
  '';
}
