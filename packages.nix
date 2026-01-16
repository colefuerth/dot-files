{ pkgs }:
{
  # Derivation containing all alias files
  aliases = pkgs.runCommand "dot-files-aliases" { } ''
    mkdir -p $out
    cp -r ${./aliases}/* $out/
  '';

  # Derivation containing all scripts
  scripts = pkgs.runCommand "dot-files-scripts" { } ''
    mkdir -p $out/bin
    cp -r ${./scripts}/* $out/bin/
    # Make all scripts executable
    chmod +x $out/bin/*
  '';

  # Derivation containing all completion files
  completions = pkgs.runCommand "dot-files-completions" { } ''
    mkdir -p $out
    cp -r ${./completions}/* $out/
  '';

  # Derivation containing all config files
  configs = pkgs.runCommand "dot-files-configs" { } ''
    mkdir -p $out
    cp -r ${./.config}/* $out/
  '';

  # Convenience derivation that includes the welcome script
  welcome = "${./10-welcome}";

  bambu-studio = pkgs.appimageTools.wrapType2 rec {
    pname = "bambu-studio";
    version = "02.04.00.70";

    src = pkgs.fetchurl {
      url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/Bambu_Studio_ubuntu-24.04_PR-8834.AppImage";
      hash = "sha256-JrwH3MsE3y5GKx4Do3ZlCSAcRuJzEqFYRPb11/3x3r0=";
    };

    extraPkgs = pkgs: with pkgs; [
      # Graphics libraries
      glew
      glfw
      gtk3
      webkitgtk_4_1

      # GStreamer for media
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad

      # System libraries
      dbus
      glib
      glib-networking
      xorg.libX11

      # Network/TLS libraries
      cacert
      curl
      gnutls
      openssl
    ];

    extraBwrapArgs = [
      "--setenv SSL_CERT_FILE ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "--setenv CURL_CA_BUNDLE ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "--setenv GIO_EXTRA_MODULES ${pkgs.glib-networking}/lib/gio/modules"
    ];

    extraInstallCommands =
      let
        extracted = pkgs.appimageTools.extractType2 { inherit pname version src; };
      in
      ''
        # Install desktop file and icon
        install -m 444 -D ${extracted}/BambuStudio.desktop -t $out/share/applications
        substituteInPlace $out/share/applications/BambuStudio.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=${pname}'
        install -m 444 -D ${extracted}/BambuStudio.png \
          $out/share/pixmaps/bambu-studio.png
      '';

    meta = with pkgs.lib; {
      description = "Bambu Studio 3D printer slicer";
      homepage = "https://github.com/bambulab/BambuStudio";
      license = licenses.agpl3Only;
      platforms = [ "x86_64-linux" ];
    };
  };
}
