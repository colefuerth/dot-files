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

  pkgs-cuda = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
    config.cudaSupport = true;
  };

  gstreamer-pkgs = pkgs-cuda.gst_all_1;
  gstreamer-systemPackages = with gstreamer-pkgs; [
    # Video/Audio data composition framework tools like "gst-inspect", "gst-launch" ...
    gstreamer
    # Common plugins like "filesrc" to combine within e.g. gst-launch
    gst-plugins-base
    # Specialized plugins separated by quality
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    # Plugins to reuse ffmpeg to play almost every video format
    gst-libav
    # Support the Video Audio (Hardware) Acceleration API
    gst-vaapi
    # Handle RTSP video and audio streams
    gst-rtsp-server
  ];
  gstreamer-plugin-paths = (
    [ ]
    ++ (lib.map (p: "${p.out}/lib") gstreamer-systemPackages)
    ++ (lib.map (p: "${p.out}/lib/gstreamer-1.0") gstreamer-systemPackages)
  );

  cudatoolkit = pkgs-cuda.cudaPackages_12.cudatoolkit;
  cudatoolkit-path = "${cudatoolkit}";

  # The following X11 package is identical to nvidiaPackages.production
  # nvidia-x11-pkgs = kernel-pkgs.nvidia_x11_production;
  nvidia-pkgs = (kernel-pkgs.nvidiaPackages.production.override { config.cudaSupport = true; });
  # Use the NVidia open source kernel module (not to be confused with the
  # independent third-party "nouveau" open source driver).
  # Support is limited to the Turing and later architectures. Full list of
  # supported GPUs is at:
  # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
  # Only available from driver 515.43.04+
  # Currently alpha-quality/buggy, so false is currently the recommended setting.
  nvidia-pkgs-open = false;

  hardwareDrivers =
    [
      cudatoolkit
      nvidia-pkgs
    ]
    ++ (with pkgs; [
      nvidia-vaapi-driver
      # Needed to find EGL/egl.h in gstreamer
      libGL
    ]);
  hardwareDrivers32 = with pkgs.pkgsi686Linux; [ nvidia-vaapi-driver ];
in
{
  imports = [
    ../../common
    ../../common/cachix.nix
    ../../common/nixbuild.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Enable common NixOS configuration settings
  nixcfg.enable = true;
  nixcfg.cachix = {
    enable = true;
    users = [ username ];
  };
  nixcfg.nixbuild = {
    enable = true;
    disableThisSystem = true;
  };

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-468fc01f-17de-4294-9822-0f4f5d8f8d2f".device =
    "/dev/disk/by-uuid/468fc01f-17de-4294-9822-0f4f5d8f8d2f";

  services.udev.extraRules = ''
    # Seek Thermal SDK camera rules
    SUBSYSTEM=="usb", ATTRS{idVendor}=="289d", ATTRS{idProduct}=="0010", GROUP="users", MODE:="0666", SYMLINK+="usb/seekthermal/pir206.$attr{busnum}.$attr{devpath}.$attr{devnum}"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="289d", ATTRS{idProduct}=="0011", GROUP="users", MODE:="0666", SYMLINK+="usb/seekthermal/pir324.$attr{busnum}.$attr{devpath}.$attr{devnum}"
    ACTION=="add", ATTRS{idVendor}=="289d", ATTR{power/autosuspend}="-1", ATTR{power/control}="on", ATTR{power/level}="on"
  '';

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
  hardware.pulseaudio.enable = false;
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
  environment.systemPackages =
    (with pkgs; [
      bmap-tools
      cachix
      chromium
      dfu-util
      e2fsprogs
      firefoxpwa
      gparted
      jq
      neofetch
      nvitop
      libsForQt5.okular
      picocom
      slack
      wireshark
      zoom-us
    ])
    ++ hardwareDrivers
    ++ [ nvidia-pkgs ]
    ++ gstreamer-systemPackages
    ++ (with pkgs-cuda; [ ffmpeg ]);

  environment.sessionVariables = rec {
    GST_PLUGIN_SYSTEM_PATH_1_0 = gstreamer-plugin-paths;
    CUDA_PATH = [ cudatoolkit-path ];
  };

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
    passwordAuthentication = true;
  };

  # Open ports in the firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  # networking.firewall.allowedUDPPorts = [ 8554 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  system.stateVersion = "25.05";

  services.logind = {
    extraConfig = "HandlePowerKey=suspend";
    lidSwitch = "suspend";
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = hardwareDrivers;
    extraPackages32 = hardwareDrivers32;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = nvidia-pkgs;
    open = nvidia-pkgs-open;

    # # disable this for Xorg
    # # > If you keep the modules in the initramfs but don't enable modesetting do you still have either issue? The modeset parameter shouldn't inherently be necessary for xorg and the race condition should be fulfilled by the presence of the modules in the initramfs.
    # # https://bbs.archlinux.org/viewtopic.php?id=259073
    # modesetting.enable = false;
    # Keep on for Wayland
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement.enable = false;
    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Enable the Nvidia settings menu (nvidia-settings)
    nvidiaSettings = true;

    # Enable persistenced to keep GPU on in headless mode
    nvidiaPersistenced = true;

    prime = {
      # sync.enable = true;
      offload = {
        enable = true;
        enableOffloadCmd = true; # Provides `nvidia-offload` command.
      };

      # # pci@0000:00:02.0
      intelBusId = "PCI:0:2:0";
      # # pci@0000:01:00.0
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "nvidia_uvm"
  ];
  # boot.blacklistedKernelModules = [ "i915" ];
  # boot.kernelParams = [
  #   "module_blacklist=i915"
  #   # "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  # ];
  boot.extraModulePackages = [ nvidia-pkgs ];
  # hardware.nvidia.forceFullCompositionPipeline = true;

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
      # xdg-desktop-portal-gnome
    ];
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
    nix-ld.enable = true;
    qgroundcontrol = {
      enable = true;
      blacklistModemManagerFromTTYUSB = true;
    };
    tmux.enable = true;
    vim = {
      enable = true;
      defaultEditor = false;
    };
    wireshark.enable = true;
  };

}
