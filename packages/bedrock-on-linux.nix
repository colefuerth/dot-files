{
  pkgs,
}:
# Minecraft Bedrock (Windows GDK build) launcher for Linux.
#
# Upstream ships an AppImage that bundles its own relocatable Python 3.12
# (rpath-based, so no patchelf needed) and downloads umu-launcher + a GDK-Proton
# engine into ~/.local/share at first run. Everything therefore has to run inside
# the FHS sandbox, which is exactly what wrapType2 gives us.
pkgs.appimageTools.wrapType2 rec {
  pname = "bedrock-on-linux";
  version = "2.1.1";

  src = pkgs.fetchurl {
    url = "https://github.com/Wyze3306/BedrockOnLinux/releases/download/v${version}/BedrockOnLinux-${version}-x86_64.AppImage";
    hash = "sha256-ooDyhz7BR9IzfA2q/X/yHmBLDuv/M2E3Bz7UQzSzteQ=";
  };

  extraPkgs =
    pkgs: with pkgs; [
      # `bol doctor` looks for these, and the engine bootstrap shells out to tar
      curl
      gnutar
      zstd
      xz

      # umu-launcher is a Python zipapp that spawns pressure-vessel (bwrap)
      bubblewrap
      python3

      # optional but probed with shutil.which(): gamescope wrapping, GUI toasts
      gamescope
      libnotify
    ];

  extraInstallCommands =
    let
      extracted = pkgs.appimageTools.extractType2 { inherit pname version src; };
    in
    ''
      # Upstream's desktop entry already uses `Exec=bedrock-on-linux gui`, which
      # matches the wrapper binary name, so it needs no rewriting.
      install -m 444 -D ${extracted}/usr/share/applications/${pname}.desktop \
        -t $out/share/applications
      install -m 444 -D ${extracted}/usr/share/icons/hicolor/256x256/apps/${pname}.png \
        -t $out/share/icons/hicolor/256x256/apps
    '';

  meta = with pkgs.lib; {
    description = "Run Minecraft Bedrock (Windows GDK) on Linux, multiplayer included";
    homepage = "https://github.com/Wyze3306/BedrockOnLinux";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
