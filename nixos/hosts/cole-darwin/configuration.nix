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
  imports = [
    ../../common
  ];

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
      "com.apple.swipescrolldirection" = true; # Enable natural scrolling
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
      "discord"
      "google-chrome"
      "signal"
      "slack"
      "spotify"
      "steam"
      "vlc"
    ];
    taps = [
      "koekeishiya/formulae"
    ];
    brews = [
      "koekeishiya/formulae/yabai"
      "koekeishiya/formulae/skhd"
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

    programs.zsh.initExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';

    programs.zsh.shellAliases = {
      ndarwin = "nix run nixpkgs#nix-output-monitor -- build .#darwinConfigurations.cole-darwin.system";
    };

    # Yabai and skhd launchd services
    launchd.agents.yabai = {
      enable = true;
      config = {
        ProgramArguments = [ "/opt/homebrew/bin/yabai" ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/yabai.out.log";
        StandardErrorPath = "/tmp/yabai.err.log";
      };
    };
    launchd.agents.skhd = {
      enable = true;
      config = {
        ProgramArguments = [ "/opt/homebrew/bin/skhd" ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/skhd.out.log";
        StandardErrorPath = "/tmp/skhd.err.log";
      };
    };

    # Yabai tiling window manager config
    home.file.".yabairc" = {
      executable = true;
      text = ''
        #!/usr/bin/env sh

        /opt/homebrew/bin/yabai -m config layout                 bsp
        /opt/homebrew/bin/yabai -m config window_placement       second_child
        /opt/homebrew/bin/yabai -m config top_padding            8
        /opt/homebrew/bin/yabai -m config bottom_padding         8
        /opt/homebrew/bin/yabai -m config left_padding           8
        /opt/homebrew/bin/yabai -m config right_padding          8
        /opt/homebrew/bin/yabai -m config window_gap             8
        /opt/homebrew/bin/yabai -m config mouse_follows_focus    off
        /opt/homebrew/bin/yabai -m config focus_follows_mouse    off
        /opt/homebrew/bin/yabai -m config mouse_modifier         alt
        /opt/homebrew/bin/yabai -m config mouse_action1          move
        /opt/homebrew/bin/yabai -m config mouse_action2          resize
        /opt/homebrew/bin/yabai -m config window_shadow          float
        /opt/homebrew/bin/yabai -m config split_ratio            0.5
        /opt/homebrew/bin/yabai -m config auto_balance           off
      '';
    };

    # skhd hotkey daemon config
    home.file.".skhdrc".text = ''
      # focus window
      alt - h : yabai -m window --focus west
      alt - j : yabai -m window --focus south
      alt - k : yabai -m window --focus north
      alt - l : yabai -m window --focus east

      # swap window
      shift + alt - h : yabai -m window --swap west
      shift + alt - j : yabai -m window --swap south
      shift + alt - k : yabai -m window --swap north
      shift + alt - l : yabai -m window --swap east

      # move window
      ctrl + alt - h : yabai -m window --warp west
      ctrl + alt - j : yabai -m window --warp south
      ctrl + alt - k : yabai -m window --warp north
      ctrl + alt - l : yabai -m window --warp east

      # toggle float and center
      alt - t : yabai -m window --toggle float --grid 4:4:1:1:2:2

      # toggle fullscreen
      alt - f : yabai -m window --toggle zoom-fullscreen

      # balance tree
      shift + alt - 0 : yabai -m space --balance

      # focus spaces
      alt - 1 : yabai -m space --focus 1
      alt - 2 : yabai -m space --focus 2
      alt - 3 : yabai -m space --focus 3
      alt - 4 : yabai -m space --focus 4
      alt - 5 : yabai -m space --focus 5

      # move window to space
      shift + alt - 1 : yabai -m window --space 1
      shift + alt - 2 : yabai -m window --space 2
      shift + alt - 3 : yabai -m window --space 3
      shift + alt - 4 : yabai -m window --space 4
      shift + alt - 5 : yabai -m window --space 5
    '';
  };
}
