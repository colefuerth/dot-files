# Each utility script in ../scripts as its own package, with its runtime
# dependencies bundled onto PATH. Returns a list, spliced into home.packages
# (and the standalone shell's PATH) instead of the old "copy everything into one
# derivation and prepend its bin to PATH" bundle — which shipped the scripts
# without their dependencies (e.g. remote-switch calling sshpass, which then
# wasn't on PATH).
{ pkgs }:
let
  inherit (pkgs) lib;
  src = ../scripts;

  # Wrap a bash script as its own package. runtimeInputs are *prepended* to
  # PATH, so a script's own nixpkgs deps resolve while genuinely system-level
  # tools it also uses (systemctl, nixos-rebuild) still come from the ambient
  # environment, exactly as before. patchShebangs pins the bash interpreter.
  bashScript =
    name: runtimeInputs:
    pkgs.runCommandLocal name
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta.mainProgram = name;
      }
      ''
        install -Dm755 ${src + "/${name}"} $out/bin/${name}
        patchShebangs $out/bin/${name}
        ${lib.optionalString (runtimeInputs != [ ]) ''
          wrapProgram $out/bin/${name} --prefix PATH : ${lib.makeBinPath runtimeInputs}
        ''}
      '';

  # nomt shells out to nomr, so nomr must be a package it can find on PATH.
  nomr = bashScript "nomr" (
    with pkgs;
    [
      nix
      nix-output-monitor
      openssh
    ]
  );

  # mergehex is a Python script needing intelhex; point its shebang at an
  # interpreter that has the library rather than the ambient python3.
  mergehex =
    let
      pyEnv = pkgs.python3.withPackages (ps: [ ps.intelhex ]);
    in
    pkgs.runCommandLocal "mergehex" { meta.mainProgram = "mergehex"; } ''
      install -Dm755 ${src + "/mergehex"} $out/bin/mergehex
      substituteInPlace $out/bin/mergehex \
        --replace-fail '#!/usr/bin/env python3' '#!${pyEnv}/bin/python3'
    '';
in
[
  (bashScript "dp" (
    with pkgs;
    [
      pv
      coreutils
    ]
  ))
  (bashScript "pull-all" [ pkgs.git ])
  # switch also uses nixos-rebuild, left to the ambient NixOS environment.
  (bashScript "switch" [ pkgs.nix-output-monitor ])
  # tv only drives systemctl --user, which is always ambient on its NixOS hosts.
  (bashScript "tv" [ ])
  nomr
  (bashScript "nomt" [
    nomr
    pkgs.coreutils
  ])
  (bashScript "remote-switch" (
    with pkgs;
    [
      coreutils
      nix
      nix-output-monitor
      openssh
      sshpass
    ]
  ))
  mergehex
]
