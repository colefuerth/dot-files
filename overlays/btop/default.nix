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
      # btop dlopens NVML for NVIDIA GPU stats; only cudaSupport puts /run/opengl-driver/lib in its RUNPATH.
      prev.btop.override { cudaSupport = true; };
}
