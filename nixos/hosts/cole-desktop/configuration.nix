{
  config,
  dotFilesPackages,
  host,
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
    ../../common/cachix.nix
    ../../common/cosmic.nix
    ../../common/xone.nix
    ./hardware-configuration.nix
  ];

  # Enable common NixOS configuration settings
  nixcfg.enable = true;
  nixcfg.cachix = {
    enable = true;
    users = [ username ];
  };

  nixcfg.cosmic.enable = true;

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Boot with systemd output visible
  boot.plymouth.enable = false;

  # Enable networking
  networking.hostName = host; # Define your hostname.
  networking.networkmanager.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
      addresses = true;
    };
  };

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  fonts = {
    enableDefaultPackages = true;
    enableGhostscriptFonts = true;
    fontDir = {
      enable = true;
      decompressFonts = true;
    };
    fontconfig = {
      enable = true;
      antialias = true;
      cache32Bit = true;
      useEmbeddedBitmaps = true;
      defaultFonts = {
        monospace = [ "Consolas Nerd Font Mono" ];
      };
    };
    packages = with pkgs; [
      dotFilesPackages.consolas-nf
      vista-fonts
    ];
  };

  # X11 is configured by the desktop environment modules

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

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
        claude-code
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
    neofetch
    nil
    nixfmt-tree
    pciutils
    powertop
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

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = [ 5353 ];

  # initial system state when machine was created, used for backwards compatibility
  system.stateVersion = "26.05";

  virtualisation.vmVariant = {
    virtualisation = {
      cores = 8;
      memorySize = 8192;
    };
  };

  services.logind.settings = {
    Login = {
      HandlePowerKey = "suspend";
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "ignore";
    };
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  hardware.graphics = {
    enable = true;
  };
  services.xserver.videoDrivers = [
    "modesetting" # allows wayland to work properly
    "nvidia" # use nvidia proprietary driver
  ];

  systemd.user.services.solaar = {
    description = "Solaar - Logitech Device Manager";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.solaar}/bin/solaar --window=hide";
      Restart = "on-failure";
    };
  };

  # enable bluetooth
  hardware = {
    bluetooth = {
      enable = true;
      # package = pkgs.bluez-experimental;
      powerOnBoot = true;
      settings.General = {
        # experimental = true;
        Privacy = "Device";
        JustWorksRepairing = "always";
        FastConnectable = true;
      };
      settings.Policy.AutoEnable = true;
    };
  };

  hardware.nvidia = {
    open = false;
    powerManagement = {
      enable = true;
    };
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

  # Home-manager configuration for this machine
  home-manager.users.${username} = {
    home.stateVersion = "26.05";
    services.linux-wallpaperengine = {
      # https://github.com/nix-community/home-manager/blob/master/modules/services/linux-wallpaperengine.nix
      enable = true;
      assetsPath = "/home/cole/.local/share/Steam/steamapps/common/wallpaper_engine/assets";
      wallpapers = [
        {
          # ultrawide
          monitor = "DP-1"; # Your laptop's internal display
          wallpaperId = wallpaperIds.hyper-cube-oled;
          scaling = "fill"; # "stretch", "fit", "fill", or "default"
          fps = 24;
          audio.silent = true; # only use this flag once for all monitors
          # extraOptions = [
          #   "--set-property spacemode=1"
          #   "--set-property backgroundcolor=0.0,0.0,0.0"
          # ];
        }
        {
          # mini
          monitor = "DP-2";
          wallpaperId = wallpaperIds.frieren-cold;
        }
      ];
    };
    systemd.user.services.linux-wallpaperengine = {
      Service = {
        Restart = lib.mkForce "always";
        RestartSec = "3s";
        Environment = [
          "LIBVA_DRIVER_NAME=nvidia"
          "LIBVA_DRIVERS_PATH=${pkgs.nvidia-vaapi-driver}/lib/dri"
        ];
      };
    };
    programs.ssh = {
      enable = true;
      package = pkgs.openssh.override { withKerberos = true; };
      matchBlocks = {
        "s" = {
          user = "cole";
          hostname = "192.168.69.5";
          serverAliveInterval = 60;
        };
      };
    };
  };

  services.fwupd.enable = true;

  services.fprintd.enable = true;

  services.envfs.enable = false;

  services.wivrn = {
    enable = true;
    openFirewall = true;

    # Write information to /etc/xdg/openxr/1/active_runtime.json, VR applications
    # will automatically read this and work with WiVRn (Note: This does not currently
    # apply for games run in Valve's Proton)
    defaultRuntime = true;

    # Run WiVRn as a systemd service on startup
    autoStart = true;

    # If you're running this with an nVidia GPU and want to use GPU Encoding (and don't otherwise have CUDA enabled system wide), you need to override the cudaSupport variable.
    package = (pkgs.wivrn.override { cudaSupport = true; });

    # You should use the default configuration (which is no configuration), as that works the best out of the box.
    # However, if you need to configure something see https://github.com/WiVRn/WiVRn/blob/master/docs/configuration.md for configuration options and https://mynixos.com/nixpkgs/option/services.wivrn.config.json for an example configuration.
  };

  programs = {
    java.enable = true;
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        openssl
        curl
        git
        nodejs_20
        python3
      ];
    };
    steam =
      let
        patchedBwrap = pkgs.bubblewrap.overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [
            ./bwrap.patch
          ];
        });
      in
      {
        enable = true;
        protontricks.enable = true;
        package = pkgs.steam.override {
          buildFHSEnv = (
            args:
            (
              (pkgs.buildFHSEnv.override {
                bubblewrap = patchedBwrap;
              })
              (
                args
                // {
                  extraBwrapArgs = (args.extraBwrapArgs or [ ]) ++ [ "--cap-add ALL" ];
                }
              )
            )
          );
        };
      };
    vim = {
      enable = true;
      defaultEditor = false;
    };
    zsh.enable = true;
  };
}
