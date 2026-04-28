{
  pkgs,
  tw3mm,
  ...
}:
let
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.fasteners
    ps.pyside6
    ps.watchdog
    ps.charset-normalizer
    ps.patool
    ps.easyprocess
  ]);
in
pkgs.stdenv.mkDerivation {
  pname = "tw3mm";
  version = "0.9.3-beta.3";

  src = tw3mm;

  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.qt6.wrapQtAppsHook
  ];

  buildInputs = [
    pythonEnv
    pkgs.qt6.qtbase
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/tw3mm
    cp -r main.py src res translations tools $out/share/tw3mm/

    makeWrapper ${pythonEnv}/bin/python $out/bin/tw3mm \
      --add-flags "$out/share/tw3mm/main.py" \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.patchelf ]} \
      "''${qtWrapperArgs[@]}"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Mod Manager for The Witcher 3";
    homepage = "https://github.com/Systemcluster/The-Witcher-3-Mod-manager";
    license = licenses.bsd2;
    platforms = platforms.linux;
    mainProgram = "tw3mm";
  };
}
