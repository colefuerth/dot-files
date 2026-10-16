final: prev: {
  btop =
    if prev.stdenv.hostPlatform.isDarwin then
      prev.btop.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./battery-watts-pstr.patch
          ./cpu-watts-smc.patch
          ./mem-used.patch
        ];
      })
    else
      prev.btop;
}
