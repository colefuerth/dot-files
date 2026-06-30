{
  config,
  dotFilesPackages,
  inputs,
  lib,
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
    ../../common/gnome.nix
    ../../common/graphical.nix
    ../../common/laptop.nix
    ../../common/nixbuild.nix
    ../../common/solaar.nix
    ../../common/ssh.nix
    ../../common/tailscale.nix
    ../../common/user.nix
    ../../common/wallpaper-engine.nix
    ../../common/xone.nix
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p1-gen3
  ];

  # Desktop Environment Configuration
  # Enable only one at a time:
  nixcfg.gnome.enable = false;
  nixcfg.cosmic.enable = true;

  nixcfg.nixbuild.enable = false;

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # `fprintd-enroll` to enroll fingerprints
  services.fprintd.enable = true;

  # modules to load at boot time
  boot.kernelModules = [
    "acpi_call" # Required for ThinkPad battery charge thresholds
  ];
  # Packages containing kernel modules to load at boot time
  boot.extraModulePackages = with config.boot.kernelPackages; [
    acpi_call
  ];

  users.users.${username}.packages =
    with pkgs;
    [
      act
      binsider
      codex
      discord
      firefoxpwa
      flameshot
      git-lfs
      google-chrome
      grim
      kdePackages.okular
      micro
      opencode
      ristretto
      signal-desktop
      slack
      slurp
      spotify
      tidal-hifi
      vlc
    ]
    ++ [
      dotFilesPackages.bambu-studio
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
    platformio
    (python312.withPackages dotFilesPackages.pyPackages)
    smartmontools
    solaar
    tio
    wineWow64Packages.stagingFull
    winetricks
    wineWow64Packages.waylandFull
    tumbler
  ];

  # initial system state when machine was created, used for backwards compatibility
  system.stateVersion = "25.11";

  powerManagement.enable = true;
  services.thermald.enable = lib.mkForce false; # Unsupported on Meteor Lake with thinkpad_acpi dytc_lapmode
  services.tlp.settings = {
    # Explicit max frequencies to fix AC restore on hybrid Meteor Lake CPUs.
    # Kernel clamps per-core to each core type's actual max.
    CPU_SCALING_MAX_FREQ_ON_AC = 5100000;
    CPU_SCALING_MAX_FREQ_ON_BAT = 2300000;
    USB_DENYLIST = builtins.concatStringsSep " " [
      # USB devices to disable autosuspend for (keyboards/mice)
      "25a7:fa70" # gaming mouse at home
      "258a:0150" # rk m75
      "046d:c548" # Logitech MX Master 3S
      "05e3:0610" # Generic USB Hub at work
    ];
    DISK_DEVICES = "nvme0n1";
    DISK_APM_LEVEL_ON_AC = "254";
    DISK_APM_LEVEL_ON_BAT = "128";
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vpl-gpu-rt
      intel-media-driver
    ];
  };

  # mx master 3s
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = false;
    prime = {
      # [offload, sync, reverseSync] only one should be true
      offload.enable = true; # use igpu for everything except when using the offload cmd
      offload.enableOffloadCmd = true;
      sync.enable = false; # render everything on the dgpu; igpu used for display only
      reverseSync.enable = false; # use the dgpu for everything
    };
    # fine grained power management for newer architectures
    powerManagement = {
      enable = true;
      finegrained = true;
    };
  };

  nixcfg.wallpaperEngine = {
    enable = true;
    wallpapers = [
      {
        # laptop display
        monitor = "eDP-1"; # Your laptop's internal display
        wallpaperId = wallpaperIds.floppa-ps1;
        scaling = "fit"; # "stretch", "fit", "fill", or "default"
        fps = 24;
        audio.silent = true; # only use this flag once for all monitors
      }
      {
        # Ultrawide
        monitor = "DP-3";
        wallpaperId = wallpaperIds.hyper-cube-oled;
      }
      {
        # mini
        monitor = "DP-2";
        wallpaperId = wallpaperIds.frieren-cold;
      }
    ];
  };

  services.hardware.bolt.enable = true;

  services.envfs.enable = false;

  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = [ "${username}" ];
    };
    steam = {
      enable = true;
      protontricks.enable = true;
    };
    qgroundcontrol.enable = true;
  };

  nix.settings.secret-key-files = [
    "/etc/nix/signing-key.sec"
  ];
}
