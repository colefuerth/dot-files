# HP h8-1413c: i7-3770, Intel 7-series AHCI, xHCI + EHCI, GTX 1650.
# Hand-written from the Ubuntu install's lspci/lsmod. Filesystems are by label,
# matching what install.sh creates on the SSD (BOOT ESP + nixos btrfs).
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # cole-desktop's btrfs layout, minus LUKS: the i7-3770 has no TPM to unlock it
  fileSystems =
    let
      subvol = name: {
        device = "/dev/disk/by-label/nixos";
        fsType = "btrfs";
        options = [
          "subvol=${name}"
          "compress=zstd"
          "noatime"
          "ssd"
          "discard=async"
        ];
      };
    in
    {
      "/" = subvol "@";
      "/home" = subvol "@home";
      "/nix" = subvol "@nix";
      "/var/log" = subvol "@log" // {
        neededForBoot = true;
      };
      "/.snapshots" = subvol "@snapshots";
      "/boot" = {
        device = "/dev/disk/by-label/BOOT";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };
    };

  # Monthly checksum scrub of the SSD. Listed explicitly: the VM tests swap in
  # their own non-btrfs root, which fails the module's autodetect assertion.
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
