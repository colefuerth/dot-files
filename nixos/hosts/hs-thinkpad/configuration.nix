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
  boot.kernelPackages = pkgs.linuxPackages;

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

  networking.hostName = host; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

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
    packages = with pkgs; [
      discord
      firefoxpwa
      google-chrome
      kdePackages.okular
      signal-desktop
      slack
      spotify
    ];
    initialHashedPassword = "$y$j9T$YcR7aNLjwHuI5yMbcA8UB.$UbVZuOsp9AsovPS8ApWj4flsMZJUBStWA3e1E8SSBo1";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    cachix
    e2fsprogs
    gnome-terminal
    gparted
    jq
    neofetch
    nil
    nixfmt-tree
    solaar
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
          monitor = "eDP-1"; # Your laptop's internal display
          wallpaperId =
            # "3346104040"; # polish cow dandadan
            # "3136351729"; # ascii donut
            # "3348560292"; # jjp
            # "3250755486"; # cat eating chips
            # "2717323779"; # dog dvd
            "2472509205"; # floppa ps1
            # "2421217072"; # eminem goose
            # "2620623306"; # ricardo
            # "2156652467"; # misato clock (no clock)
            # "1756162891"; # end of evangelion beer
            # "1542633413"; # tblz
            # "1731760875"; # minecraft redstone clock (also broken)
            # "2190879698"; # get stick bugged lol
            # "1922177752"; # firewatch clock (no clock)
            # "1945071673"; # witcher clock (particle assets not supported yet) (also no clock)
          scaling = "fill"; # "stretch", "fit", "fill", or "default"
          # fps = 25;
          audio.silent = true;
          # extraOptions = [
          #   "--set-property spacemode=1"
          #   "--set-property backgroundcolor=0.0,0.0,0.0"
          # ];
        }
      ];
    };
    systemd.user.services.linux-wallpaperengine.Unit.ConditionACPower = true;
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
