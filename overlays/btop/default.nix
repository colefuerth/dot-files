final: prev: {
  # btop 1.4.7 collects Apple Silicon GPU stats via IOReport, but both watts readouts stay empty
  # on macOS: the cpu box (src/osx never assigns Cpu::supports_watts) and the battery indicator
  # (get_battery returns -1 watts). Linux is unaffected, so leave it on the binary cache.
  btop =
    if prev.stdenv.hostPlatform.isDarwin then
      prev.btop.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          # CPU package watts from the "CPU Energy" IOReport channel, read off the same
          # subscription btop already opens for "GPU Energy". No upstream PR for this.
          # Piggybacking means watts go stale if btop skips Gpu::collect entirely, i.e. only
          # with no gpu panel shown *and* show_gpu_info = "Off". Our btop.conf shows both.
          ./cpu-watts.patch
          # Total system watts next to the battery indicator, from the SMC "PSTR" key (a 'flt '
          # key, a type btop's SMC code couldn't read). Not AppleSmartBattery like upstream PR
          # 1676 does: its InstantAmperage only refreshes on the battery's slow SMBus poll, so it
          # sits frozen for minutes at a time on discharge. PSTR tracks load every sample.
          ./battery-watts-pstr.patch
        ];
      })
    else
      prev.btop;
}
