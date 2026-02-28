{
  config,
  dotFilesPackages,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
{
  # Enable experimental features
  nix.settings.experimental-features = "nix-command flakes";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set primary user for system defaults
  system.primaryUser = username;

  # User configuration
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    description = "Cole Fuerth";
    shell = pkgs.zsh;
  };

  # System packages (macOS-compatible tools from hs-thinkpad)
  environment.systemPackages = with pkgs; [
    # Development tools
    act
    claude-code
    git-lfs
    libclang
    micro
    nil
    nixfmt-tree
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

    # User packages (macOS-compatible from hs-thinkpad)
    # Note: Some packages like discord, slack, spotify are better installed via Homebrew on macOS
  ];

  # System settings
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      minimize-to-application = true;
      show-recents = false;
      tilesize = 48;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      ShowPathbar = true;
      ShowStatusBar = true;
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 14;
      KeyRepeat = 1;
      "com.apple.swipescrolldirection" = false; # Disable natural scrolling
    };
    trackpad = {
      Clicking = true; # Enable tap to click
      TrackpadRightClick = true;
    };
  };

  # Fonts
  fonts.packages = [
    dotFilesPackages.consolas-nf
  ];

  # macOS system version
  system.stateVersion = 5;

  # Enable TouchID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Homebrew integration
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    # macOS-specific apps that aren't available in nixpkgs or work better via Homebrew
    casks = [
      # Apps from hs-thinkpad that work better via Homebrew on macOS:
      "discord"
      "slack"
      "spotify"
      "vlc"
      # Additional recommendations:
      # "google-chrome"
      # "signal"
      # "visual-studio-code"
    ];
    brews = [
      # Hardware tools that may not be in nixpkgs for darwin
      "avrdude"
      "platformio"
      # Serial communication
      "tio"
    ];
  };

  # Services
  services.tailscale = {
    enable = true;
  };

  # Programs
  programs = {
    zsh.enable = true;
  };

  # Home-manager configuration for this machine
  home-manager.users.${username} = {
    programs.ssh = {
      matchBlocks = {
        "eu.nixbuild.net" = {
          hostname = "eu.nixbuild.net";
          serverAliveInterval = 60;
          identityFile = "/Users/cole/.ssh/nixbuild/heaviside-shared";
        };
        "t" = {
          user = "heaviside_ai";
          hostname = "10.100.20.38";
          identityFile = "/Users/cole/.ssh/id_ed25519";
        };
        "mothpi" = {
          user = "moth";
          hostname = "moth.local";
          identityFile = "/Users/cole/.ssh/id_rsa";
          forwardX11 = true;
          forwardX11Trusted = true;
        };
        "bms_test" = {
          user = "heaviside";
          hostname = "moth-production-tester.local";
          identityFile = "/Users/cole/.ssh/id_rsa";
        };
        "pi" = {
          user = "cole";
          hostname = "colepi.local";
          serverAliveInterval = 60;
          identityFile = "/Users/cole/.ssh/id_rsa";
          forwardX11 = true;
          forwardX11Trusted = true;
        };
        "s" = {
          user = "cole";
          hostname = "10.100.20.28";
          serverAliveInterval = 60;
        };
        "narwhal" = {
          user = "heaviside";
          hostname = "narwhal-Pi4.local";
        };
      };
    };
  };
}
