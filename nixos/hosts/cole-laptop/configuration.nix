{
  dotFilesPackages,
  lib,
  inputs,
  pkgs,
  username,
  ...
}:
let
  wallpaperIds = import ../../common/wallpaper-engine-ids.nix { };
in
{
  imports = [
    ../../common
    ../../common/audio.nix
    ../../common/bluetooth.nix
    ../../common/cachix.nix
    ../../common/cosmic.nix
    ../../common/graphical.nix
    ../../common/laptop.nix
    ../../common/tailscale.nix
    ../../common/user.nix
    ../../common/wallpaper-engine.nix
    ../../common/xone.nix
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.common-cpu-intel
  ];

  nixcfg.cosmic.enable = true;

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.${username}.packages = with pkgs; [
    binsider
    codex
    discord
    firefoxpwa
    flameshot
    google-chrome
    grim
    kdePackages.okular
    micro
    ristretto
    signal-desktop
    slurp
    spotify
    vlc
  ];

  nixpkgs.config.cudaSupport = true;

  environment.systemPackages = with pkgs; [
    avrdude
    claude-code
    libclang
    libgcc
    nil
    nixfmt-tree
    pciutils
    (python312.withPackages dotFilesPackages.pyPackages)
    smartmontools
    solaar
    tio
    wineWow64Packages.stagingFull
    winetricks
    wineWow64Packages.waylandFull
    tumbler
  ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  system.stateVersion = "25.11";

  powerManagement.enable = true;
  services.thermald.enable = lib.mkForce false; # Unsupported on Meteor Lake with thinkpad_acpi dytc_lapmode
  services.tlp.settings = {
    # Explicit max frequencies to fix AC restore on hybrid Meteor Lake CPUs.
    # Kernel clamps per-core to each core type's actual max.
    CPU_SCALING_MAX_FREQ_ON_AC = 4100000;
    CPU_SCALING_MAX_FREQ_ON_BAT = 2200000;
    USB_DENYLIST = builtins.concatStringsSep " " [
      # USB devices to disable autosuspend for (keyboards/mice)
      "25a7:fa70" # gaming mouse at home
      "258a:0150" # rk m75
      "046d:c548" # Logitech MX Master 3S
    ];
    DISK_DEVICES = "nvme0n1";
    DISK_APM_LEVEL_ON_AC = "254";
    DISK_APM_LEVEL_ON_BAT = "128";
  };

  # Use simple graphics configuration like working /etc config
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vpl-gpu-rt
      intel-media-driver
    ];
  };
  services.xserver.videoDrivers = [
    "modesetting" # allows wayland to work properly
    "nvidia" # use nvidia proprietary driver
  ];

  hardware.nvidia = {
    open = false;
    prime = {
      # [offload, sync, reverseSync] only one should be true
      offload.enable = true; # use igpu for everything except when using the offload cmd
      offload.enableOffloadCmd = true;
      sync.enable = false; # render everything on the dgpu; igpu used for display only
      reverseSync.enable = false; # use the dgpu for everything
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      protontricks.enable = true; # Enable protontricks for managing Proton prefixes
    };
  };

  nixcfg.wallpaperEngine = {
    enable = true;
    serviceEnvironment = [
      # Enable Intel iGPU hardware acceleration via VAAPI
      "LIBVA_DRIVER_NAME=iHD" # Intel media driver for Core Ultra
      "LIBVA_DRIVERS_PATH=${pkgs.intel-media-driver}/lib/dri"
    ];
    wallpapers = [
      {
        # laptop display
        monitor = "eDP-1"; # Your laptop's internal display
        wallpaperId = wallpaperIds.floppa-ps1;
        scaling = "fill"; # "stretch", "fit", "fill", or "default"
        fps = 24;
        audio.silent = true; # only use this flag once for all monitors
      }
    ];
  };

  services.hardware.bolt.enable = true;
}
