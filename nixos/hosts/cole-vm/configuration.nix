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
    ../../common/nixbuild.nix
    ./hardware-configuration.nix
    inputs.vscode-server.nixosModules.default
  ];

  # Enable common NixOS configuration settings
  nixcfg.enable = true;
  nixcfg.cachix = {
    enable = true;
    users = [ username ];
  };
  nixcfg.nixbuild = {
    enable = true;
    disableThisSystem = false;
  };

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages;

  # Bootloader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  # use the default one that was generated with the system for safety
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.useOSProber = true;

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

  # Enable the X11 windowing system.
  services.xserver.enable = false;

  # VM configuration for headless operation with serial console
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 2048;
      cores = 2;
      graphics = false;
      # Use serial console for terminal access
      qemu.options = [
        "-nographic"
        "-serial mon:stdio"
      ];
      # Forward SSH port for easy access
      forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
    };
    # Enable serial console getty
    boot.kernelParams = [ "console=ttyS0" ];
    systemd.services."serial-getty@ttyS0".enable = true;
  };

  # fonts = {
  #   enableDefaultPackages = true;
  #   enableGhostscriptFonts = true;
  #   fontDir = {
  #     enable = true;
  #     decompressFonts = true;
  #   };
  #   fontconfig = {
  #     enable = true;
  #     antialias = true;
  #     cache32Bit = true;
  #     useEmbeddedBitmaps = true;
  #     defaultFonts = {
  #       monospace = [ "Consolas Nerd Font Mono" ];
  #     };
  #   };
  #   packages = with pkgs; [
  #     vista-fonts
  #   ];
  # };

  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  # Enable automatic login for the user.
  # services.displayManager.autoLogin.enable = true;
  # services.displayManager.autoLogin.user = "cole";

  # # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  # systemd.services."getty@tty1".enable = false;
  # systemd.services."autovt@tty1".enable = false;

  # Configure keymap in X11
  # services.xserver.xkb = {
  #   layout = "us";
  #   variant = "";
  # };

  # backend for gnome, required for printing and links etc
  # xdg.portal = {
  #   enable = true;
  #   wlr.enable = true;
  #   extraPortals = with pkgs; [
  #     # xdg-desktop-portal-wlr
  #     # xdg-desktop-portal-gtk
  #     xdg-desktop-portal-gnome
  #   ];
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

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

  services.vscode-server.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.mutableUsers = false; # Required for declarative password management in VMs
  users.users.root.initialPassword = "root"; # Root login for debugging
  users.users.${username} = {
    isNormalUser = true;
    description = "Cole Fuerth";
    initialPassword = " ";
    extraGroups = [
      # TODO: dialout and docker may be security risks
      "dialout"
      "docker"
      "networkmanager"
      "video"
      "wheel"
    ];
    packages = with pkgs; [
      # userspace packages I want to install for all users
    ];
    shell = pkgs.zsh;
  };

  home-manager.users.${username} = {
    programs.ssh = {
      enable = true;
      package = pkgs.openssh.override { withKerberos = true; };
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = lib.mkDefault true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    cachix
    claude-code
    neofetch
    vscode-with-extensions
  ];

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

  # Use simple graphics configuration like working /etc config
  # hardware.graphics.enable = true;
  # services.xserver.videoDrivers = [ "modesetting" ];
  # Removed nouveau blacklisting - not needed without NVIDIA config
  # Removed nvidia module packages
  # hardware.nvidia.forceFullCompositionPipeline = true;

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

  services.fwupd.enable = true;

  services.fprintd.enable = true;

  services.envfs.enable = true;

  programs = {
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    java.enable = true;
    nix-ld = {
      # required for vscode-server to run as a service
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
    vim = {
      enable = true;
      defaultEditor = false;
    };
    zsh = {
      enable = true;
    };
  };
}
