{ ... }:
{
  # Enable sound with pipewire.
  boot.kernelModules = [
    "snd_hda_intel" # Load the sound driver for Intel/AMD audio chips
  ];
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;
  };
  services.pulseaudio = {
    enable = false; # Disable PulseAudio to avoid conflicts with PipeWire
  };
}
