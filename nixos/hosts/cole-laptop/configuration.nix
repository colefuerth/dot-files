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

  # Simplified graphics setup - no complex NVIDIA configuration
in
{
  imports = [
    ../../common
    ../../common/cachix.nix
    ../../common/hyprland.nix
    ../../common/gnome.nix
    ../../common/cosmic.nix
    # ../../common/nixbuild.nix
    # Include the results of the hardware scan.
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
  # nixcfg.nixbuild = {
  #   enable = false;
  #   disableThisSystem = false;
  # };

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # boot.initrd.luks.devices."luks-468fc01f-17de-4294-9822-0f4f5d8f8d2f".device =
  #   "/dev/disk/by-uuid/468fc01f-17de-4294-9822-0f4f5d8f8d2f";

  networking.hostName = host; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

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
    ]; # todo: add
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
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    isNormalUser = true;
    description = "Cole Fuerth";
    shell = pkgs.zsh;
    extraGroups = [
      # TODO: dialout and docker may be security risks
      "dialout"
      "docker"
      "networkmanager"
      "video"
      "wheel"
    ];
    packages = with pkgs; [
      # packages I want to install in userspace
    ];
    initialHashedPassword = "$y$j9T$YcR7aNLjwHuI5yMbcA8UB.$UbVZuOsp9AsovPS8ApWj4flsMZJUBStWA3e1E8SSBo1";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # bmap-tools
    cachix
    chromium
    discord
    # dfu-util
    e2fsprogs
    firefoxpwa
    gnome-terminal
    gparted
    jq
    neofetch
    kdePackages.okular
    # picocom
    # slack
    spotify
    steam
    # wireshark
    # zoom-us
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

  services.logind.settings = {
    Login = {
      HandlePowerKey = "suspend";
      HandleLidSwitch = "suspend";
    };
  };

  # Use simple graphics configuration like working /etc config
  hardware.graphics.enable = true;
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
    # fine grained power management for newer architectures
    # powerManagement = {
    #   enable = true;
    #   finegrained = true;
    # };
    # dynamic boost is for smart shifting power between cpu and gpu on laptops
    # dynamicBoost.enable = true;
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

  services.fwupd.enable = true;

  services.fprintd.enable = true;

  services.envfs.enable = true;

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
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };
    # tmux.enable = true;
    vim = {
      enable = true;
      defaultEditor = false;
    };
    # wireshark.enable = true;
    zsh.enable = true;
  };
}
