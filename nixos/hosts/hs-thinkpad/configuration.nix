{
  config,
  host,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  kernel-pkgs = config.boot.kernelPackages;

  wallpaperIds = {
    amogus = "2427281874";
    polish-cow-dandadan = "3346104040";
    ascii-donut = "3136351729";
    jjp = "3348560292";
    cat-eating-chips = "3250755486"; # pins a cpu
    dog-dvd = "2717323779";
    floppa-ps1 = "2472509205";
    frieren-cold = "3168641857";
    eminem-goose = "2421217072";
    hyper-cube-oled = "3437148262";
    ricardo = "2620623306"; # pins a cpu
    misato-clock = "2156652467";
    evangelion-beer = "1756162891";
    tblz = "1542633413";
    minecraft-redstone-clock = "1731760875";
    stick-bugged = "2190879698";
    firewatch-clock = "1922177752";
    witcher-clock = "1945071673";
  };
in
{
  imports = [
    ../../common
    ../../common/cachix.nix
    ../../common/hyprland.nix
    ../../common/gnome.nix
    ../../common/cosmic.nix
    ../../common/nixbuild.nix
    ./hardware-configuration.nix
    ./globalprotect.nix
    ./falcon-sensor.nix
  ];

  # Enable common NixOS configuration settings
  nixcfg.enable = true;
  nixcfg.cachix = {
    enable = true;
    users = [ username ];
  };

  # Desktop Environment Configuration
  # Enable only one at a time:
  nixcfg.hyprland.enable = false;
  nixcfg.gnome.enable = false;
  nixcfg.cosmic.enable = true;

  nixcfg.nixbuild = {
    enable = false;
    disableThisSystem = false;
  };

  # Select the kernel version
  # Reverting to latest kernel for display support - Falcon Sensor needs investigation
  boot.kernelPackages = pkgs.linuxPackages;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Boot with systemd output visible
  # boot.kernelParams = [
  #   "nosplash"
  #   "debug"
  # ];
  boot.plymouth.enable = false;
  # boot.consoleLogLevel = 7;

  # Enable networking
  networking.hostName = host; # Define your hostname.
  networking.networkmanager.enable = true;
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];
  networking.networkmanager.dns = "systemd-resolved";

  # Enable systemd-resolved with local DNS stub
  # This creates a local DNS resolver at 127.0.0.53 that works even if
  # GlobalProtect deletes /etc/resolv.conf
  services.resolved = {
    enable = true;
    # Use DNSStubListener to create local DNS resolver
    dnssec = "allow-downgrade";
    domains = [ "~." ]; # Route all domains through systemd-resolved
    fallbackDns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
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
      consolas-nf
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
  boot.kernelModules = [ "snd_hda_intel" ]; # Load the sound driver for Intel/AMD audio chips
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

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
        discord
        firefoxpwa
        git-lfs
        google-chrome
        kdePackages.okular
        signal-desktop
        slack
        spotify
        tidal-hifi
      ]
      ++ [
        # Wrapper for rpi-imager to run with sudo and proper Wayland support
        (pkgs.writeShellScriptBin "rpi-imager" ''
          exec sudo -E env \
            "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
            "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
            "QT_QPA_PLATFORM=wayland" \
            ${pkgs.rpi-imager}/bin/rpi-imager "$@"
        '')
      ];
    initialHashedPassword = "$y$j9T$YcR7aNLjwHuI5yMbcA8UB.$UbVZuOsp9AsovPS8ApWj4flsMZJUBStWA3e1E8SSBo1";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    avrdude
    cachix
    libclang
    neofetch
    nil
    nixfmt-tree
    platformio
    (python312.withPackages (
      ps: with ps; [
        pip
        pyserial
      ]
    ))
    solaar
    xfce.tumbler # thumbnail daemon for ristretto
  ];

  # Removed CUDA/NVIDIA session variables

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # Open ports in the firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  # networking.firewall.allowedUDPPorts = [ 8554 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  system.stateVersion = "25.11";

  # VM-specific configuration (only applies when building as a VM)
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

  # Use simple graphics configuration like working /etc config
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [
    "modesetting" # allows wayland to work properly
    "nvidia" # use nvidia proprietary driver
  ];

  # mx master 3s
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  # stuff needed to use an xbox one controller
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
    xone.enable = false;
    xpad-noone.enable = false;
    xpadneo.enable = true;
  };
  boot = {
    extraModulePackages = with config.boot.kernelPackages; [
      xpadneo
    ];
    extraModprobeConfig = ''
      options bluetooth disable_ertm=Y
    '';
    blacklistedKernelModules = [
      "xpad-noone"
      "xone"
    ];
  };
  # services.blueman.enable = true;
  environment.sessionVariables.SDL_JOYSTICK_HIDAPI = "0";

  # Start Solaar minimized at boot
  systemd.user.services.solaar = {
    description = "Solaar - Logitech Device Manager";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.solaar}/bin/solaar --window=hide";
      Restart = "on-failure";
    };
  };

  hardware.nvidia = {
    open = false;
    prime = {
      # [offload, sync, reverseSync] only one should be true
      offload.enable = true; # use igpu for everything except when using the offload cmd
      offload.enableOffloadCmd = false;
      sync.enable = false; # render everything on the dgpu; igpu used for display only
      reverseSync.enable = false; # use the dgpu for everything
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
    # fine grained power management for newer architectures
    powerManagement = {
      enable = true;
      finegrained = true;
    };
    # dynamic boost is for smart shifting power between cpu and gpu on laptops
    dynamicBoost.enable = true;
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

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
          # fps = 25;
          audio.silent = true; # only use this flag once for all monitors
          # extraOptions = [
          #   "--set-property spacemode=1"
          #   "--set-property backgroundcolor=0.0,0.0,0.0"
          # ];
        }
        {
          # Ultrawide
          monitor = "DP-3";
          wallpaperId = wallpaperIds.frieren-cold;
        }
        {
          # mini
          monitor = "DP-2";
          wallpaperId = wallpaperIds.ricardo;
        }
      ];
    };
    systemd.user.services.linux-wallpaperengine = {
      Unit.ConditionACPower = true;
      Service = {
        Restart = lib.mkForce "always";
        RestartSec = "3s";
      };
    };
    programs.ssh = {
      enable = true;
      package = pkgs.openssh.override { withKerberos = true; };
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

  services.fwupd.enable = true;

  services.fprintd.enable = true;

  services.envfs.enable = true;

  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = [ "${username}" ];
    };
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
    steam = {
      enable = true;
      protontricks.enable = true;
    };
    vim = {
      enable = true;
      defaultEditor = false;
    };
    zsh.enable = true;
  };
}
