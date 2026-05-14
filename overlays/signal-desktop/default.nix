final: prev: {
  signal-desktop = prev.symlinkJoin {
    name = "signal-desktop";
    paths = [ prev.signal-desktop ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/signal-desktop \
        --add-flags "--password-store=gnome-libsecret"
    '';
    inherit (prev.signal-desktop) meta;
  };
}
