final: prev: {
  # btop 1.4.7 collects Apple Silicon GPU stats via IOReport, but both watts readouts stay empty
  # on macOS: the cpu box (src/osx never assigns Cpu::supports_watts) and the battery indicator
  # (get_battery returns -1 watts). Linux is unaffected, so leave it on the binary cache.
  btop =
    if prev.stdenv.hostPlatform.isDarwin then
      prev.btop.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          # Total system watts next to the battery indicator, from the SMC "PSTR" key (a 'flt '
          # key, a type btop's SMC code couldn't read). Not AppleSmartBattery like upstream PR
          # 1676 does: its InstantAmperage only refreshes on the battery's slow SMBus poll, so it
          # sits frozen for minutes at a time on discharge. PSTR tracks load every sample.
          ./battery-watts-pstr.patch
          # CPU watts in the cpu box from SMC P-cluster "PP0b" + E-cluster "PPbb" rails (base M4
          # keys; other chips name them differently and the readout just stays hidden). Needs the
          # getSMCFloat reader from the patch above. Was IOReport "Energy Model" CPU Energy, but
          # macOS 27 freezes those counters unless the reader holds Apple's private
          # com.apple.private.pmgr.nrg.reporting entitlement (powermetrics does).
          ./cpu-watts-smc.patch
        ];
      })
    else
      prev.btop;
}
