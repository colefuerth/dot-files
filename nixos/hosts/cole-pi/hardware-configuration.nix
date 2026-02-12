# Placeholder hardware configuration for Raspberry Pi 5.
# Replace device paths with actual values after installing NixOS on the Pi.
# Generate with `nixos-generate-config` on the running Pi.
{
  lib,
  ...
}:
{
  # Typical Pi 5 SD card layout
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
