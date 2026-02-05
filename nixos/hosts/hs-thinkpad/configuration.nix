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
    ../../common/cachix/heaviside-industries.nix
    ../../common/cosmic.nix
    ../../common/gnome.nix
    ../../common/graphical.nix
    ../../common/laptop.nix
    ../../common/nixbuild.nix
    ../../common/xone.nix
    ./hardware-configuration.nix
    # ./globalprotect.nix
    # ./falcon-sensor.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p1-gen3
  ];

  # Enable common NixOS configuration settings
  nixcfg.enable = true;
  nixcfg.cachix = {
    enable = true;
    users = [ username ];
  };

  # Desktop Environment Configuration
  # Enable only one at a time:
  nixcfg.gnome.enable = false;
  nixcfg.cosmic.enable = true;

  nixcfg.nixbuild = {
    enable = false;
    disableThisSystem = false;
  };

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # boot.kernelParams = [
  # ];
  boot.plymouth.enable = false;

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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    isNormalUser = true;
    description = "Cole Fuerth";
    shell = pkgs.zsh;
    extraGroups = [
      "dialout"
      "docker"
      "networkmanager"
      "video"
      "wheel"
    ];
    packages =
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
        yazi
      ]
      ++ [
        dotFilesPackages.bambu-studio
      ];
    # ++ [
    #   # Wrapper for rpi-imager to run with sudo and proper Wayland support
    #   (pkgs.writeShellScriptBin "rpi-imager" ''
    #     exec sudo -E env \
    #       "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
    #       "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
    #       "QT_QPA_PLATFORM=wayland" \
    #       ${pkgs.rpi-imager}/bin/rpi-imager "$@"
    #   '')
    # ];
    initialHashedPassword = "$y$j9T$YcR7aNLjwHuI5yMbcA8UB.$UbVZuOsp9AsovPS8ApWj4flsMZJUBStWA3e1E8SSBo1";
  };

  nixpkgs.config.allowUnfree = lib.mkForce true;

  environment.systemPackages = with pkgs; [
    avrdude
    claude-code
    libclang
    libgcc
    nil
    nixfmt-tree
    pciutils
    platformio
    (python312.withPackages (
      ps: with ps; [
        matplotlib
        numpy
        pandas
        pip
        pyserial
        scipy
        tqdm
      ]
    ))
    smartmontools
    solaar
    tio
    wineWowPackages.staging
    winetricks
    wineWowPackages.waylandFull
    tumbler
  ];

  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = [ 5353 ];

  # initial system state when machine was created, used for backwards compatibility
  system.stateVersion = "25.11";

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };
  services.tlp.settings = {
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
  systemd.user.services.solaar = {
    description = "Solaar - Logitech Device Manager";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.solaar}/bin/solaar --window=hide";
      Restart = "on-failure";
    };
  };

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

  # Udev rule to automatically start/stop wallpaper based on AC power
  services.udev.extraRules = ''
    # Monitor AC adapter state changes and toggle wallpaper service
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl --user --machine=${username}@.host stop linux-wallpaperengine.service"
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl --user --machine=${username}@.host start linux-wallpaperengine.service"
  '';

  # Home-manager configuration for this machine
  home-manager.users.${username} = {
    services.linux-wallpaperengine = {
      # https://github.com/nix-community/home-manager/blob/master/modules/services/linux-wallpaperengine.nix
      enable = true;
      assetsPath = "/home/cole/.local/share/Steam/steamapps/common/wallpaper_engine/assets";
      wallpapers = [
        {
          # laptop display
          monitor = "eDP-1"; # Your laptop's internal display
          wallpaperId = wallpaperIds.floppa-ps1;
          scaling = "fill"; # "stretch", "fit", "fill", or "default"
          fps = 24;
          audio.silent = true; # only use this flag once for all monitors
          # extraOptions = [
          #   "--set-property spacemode=1"
          #   "--set-property backgroundcolor=0.0,0.0,0.0"
          # ];
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
    systemd.user.services.linux-wallpaperengine = {
      Unit.ConditionACPower = true;
      Service = {
        Restart = lib.mkForce "always";
        RestartSec = "3s";
        # Enable Intel iGPU hardware acceleration via VAAPI
        Environment = [
          "LIBVA_DRIVER_NAME=iHD" # Intel media driver for Core Ultra
          "LIBVA_DRIVERS_PATH=${pkgs.intel-media-driver}/lib/dri"
        ];
      };
    };
    programs.ssh = {
      matchBlocks = {
        "eu.nixbuild.net" = {
          hostname = "eu.nixbuild.net";
          # PubkeyAcceptedKeyTypes ssh-ed25519
          serverAliveInterval = 60;
          # IPQoS throughput
          identityFile = "/home/cole/.ssh/nixbuild/heaviside-shared";
        };
        "t" = {
          user = "heaviside_ai";
          hostname = "10.100.20.38";
          identityFile = "/home/cole/.ssh/id_ed25519";
        };
        "mothpi" = {
          user = "moth";
          hostname = "moth.local";
          identityFile = "/home/cole/.ssh/id_rsa";
          forwardX11 = true;
          forwardX11Trusted = true;
        };
        "bms_test" = {
          user = "heaviside";
          hostname = "moth-production-tester.local";
          identityFile = "/home/cole/.ssh/id_rsa";
        };
        "pi" = {
          user = "cole";
          hostname = "colepi.local";
          serverAliveInterval = 60;
          identityFile = "/home/cole/.ssh/id_rsa";
          forwardX11 = true;
          forwardX11Trusted = true;
        };
        "s" = {
          user = "cole";
          # hostname = "heaviside-thelio-server.local";
          hostname = "10.100.20.28";
          serverAliveInterval = 60;
        };
      };
    };
  };

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
  };
}
