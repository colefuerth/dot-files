{
  pkgs,
}:
pkgs.python3Packages.buildPythonApplication rec {
  pname = "sudoplz";
  version = "0.2.1";
  pyproject = true;

  src = pkgs.python3Packages.fetchPypi {
    inherit pname version;
    hash = "sha256-7z5PhRFSXe7bplNYbeK+22uWdMDWc/bmI1hFK/n4cWM=";
  };

  build-system = [ pkgs.python3Packages.hatchling ];
  dependencies = [ pkgs.python3Packages.keyring ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # age is required for ed25519 keys; ssh-keygen/ssh-add/openssl for the others.
  postFixup = ''
    for bin in $out/bin/*; do
      wrapProgram $bin --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.age
          pkgs.openssh
          pkgs.openssl
        ]
      }
    done
  '';

  # ponytail: no tests upstream, just check the entry points import.
  pythonImportsCheck = [
    "sudoplz.askpass"
    "sudoplz.manager"
  ];

  meta = {
    description = "Case-by-case sudo access for AI coding agents via GUI approval";
    homepage = "https://github.com/crypdick/sudoplz";
    license = pkgs.lib.licenses.mit;
    mainProgram = "sudoplz";
  };
}
