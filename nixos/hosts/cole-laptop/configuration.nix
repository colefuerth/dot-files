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
        monospace = [ "Consolas" ];
      };
    };
    packages = with pkgs; [
      # todo: add
      # fira-code
      # fira-code-symbols
      vista-fonts
      # nerdfonts.consolas
    ]; # todo: add
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure GNOME keyboard shortcuts and terminal
  services.xserver.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.settings-daemon.plugins.media-keys]
    custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']

    [org.gnome.settings-daemon.plugins.media-keys.custom-keybindings.custom0]
    binding='<Primary><Alt>t'
    command='gnome-terminal'
    name='Open Terminal'

    [org.gnome.Terminal.Legacy.Settings]
    default-show-menubar=false

    [org.gnome.Terminal.Legacy.Profile]
    use-custom-command=true
    custom-command='${pkgs.zsh}/bin/zsh'
  '';

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "cole";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Exclude default GNOME apps
  environment.gnome.excludePackages = (
    with pkgs;
    [
      atomix # puzzle game
      cheese # webcam tool
      epiphany # web browser
      evince # document viewer
      geary # email reader
      # gedit # text editor
      # gnome-calendar # calendar application
      # gnome-characters
      # gnome-music
      # gnome-photos
      # gnome-terminal
      # gnome-weather
      # gnome-tour
      hitori # sudoku game
      iagno # go game
      tali # poker game
      totem # video player
    ]
  );

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
      # packages I want to install for all users
    ];
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
    libsForQt5.okular
    # picocom
    # slack
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

  services.logind = {
    extraConfig = "HandlePowerKey=suspend";
    lidSwitch = "suspend";
  };

  # Use simple graphics configuration like working /etc config
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];
  # Removed nouveau blacklisting - not needed without NVIDIA config
  # Removed nvidia module packages
  # hardware.nvidia.forceFullCompositionPipeline = true;

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      # xdg-desktop-portal-wlr
      # xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  services.fwupd.enable = true;

  services.fprintd.enable = true;

  services.envfs.enable = true;

  programs = {
    # _1password.enable = true;
    # _1password-gui = {
    #   enable = true;
    #   # Certain features, including CLI integration and system authentication support,
    #   # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    #   polkitPolicyOwners = [ "${username}" ];
    # };
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
