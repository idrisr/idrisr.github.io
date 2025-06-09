{ mkDerivation, base, hakyll }:

mkDerivation {
  pname = "idrisraja-site";
  version = "0.1";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [ base hakyll ];
  mainProgram = "site";
  license = "MIT";
}
