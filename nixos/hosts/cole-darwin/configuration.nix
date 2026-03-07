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
    ];
  };

  # Programs
  programs = {
    zsh.enable = true;
  };

  # Home-manager configuration for this machine
  home-manager.users.${username} = {
    programs.ssh = {
      matchBlocks = {
      };
    };
  };
}
