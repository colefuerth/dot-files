final: prev: {
  ffmpeg-headless = prev.ffmpeg-headless.overrideAttrs { doCheck = false; };
  flac = prev.flac.overrideAttrs { doCheck = false; };
  libpulseaudio = prev.libpulseaudio.overrideAttrs { doCheck = false; };
  upower = prev.upower.overrideAttrs { doCheck = false; };

  freetype =
    (prev.freetype.override {
      # Use Harmony LCD rendering (not ClearType) so lcd_geometry is active
      useEncumberedCode = false;
    }).overrideAttrs
      (old: {
        patches = (old.patches or [ ]) ++ [
          # Triangular subpixel geometry for QD-OLED panels
          ./qdoled-subpixel.patch
        ];
      });
}
