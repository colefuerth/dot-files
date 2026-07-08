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

  # time.timeZone = "America/Toronto";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Trust the binary cache key from cole-desktop (rd) so signed closures
  # pulled by `nomt` are accepted by the local nix daemon.
  nix.settings.trusted-public-keys = [
    "cole-desktop-1:Gy9dhiisebzFg8c6mmsCyihQ+9LivAM1BWiWYx4iZPU="
  ];

  nixpkgs.overlays = [
    (
      final: prev:
      let
        version = "35.1";
      in
      {
        protobuf = prev.protobuf.overrideAttrs (old: {
          version = version;
          src = prev.fetchFromGitHub {
            owner = "protocolbuffers";
            repo = "protobuf";
            tag = "v${version}";
            hash = "sha256-nif9xjd+3ASR2pvvSXkzTEWoKi2oKLzV9gMQ3EevBVk=";
          };
          # Drop patches that were upstreamed into v35.0 (nixpkgs still applies
          # them for any version >= 30 / >= 33).
          patches = builtins.filter (
            p:
            let
              s = toString p;
            in
            !(lib.hasSuffix "211f52431b9ec30d4d4a1c76aafd64bd78d93c43.patch" s)
            && !(lib.hasSuffix "8282f0f8ecf8b847e5964a308e041ba3b049811c.patch" s)
          ) (old.patches or [ ]);
        });
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (python-final: python-prev: {
            protobuf = python-prev.protobuf.overrideAttrs (old: {
              version = "7.${version}";
              src = prev.fetchPypi {
                pname = "protobuf";
                version = "7.${version}";
                hash = "sha256-zhFaJv4MOaLCmXPZFNMn5RamRVRkSJ/jzR5RobNU+Bo=";
              };
            });
          })
        ];
      }
    )
  ];

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
  environment.systemPackages =
    (with pkgs; [
      act
      docker
      ffmpeg-full
      ffpb
      gh
      git-lfs
      libclang
      micro
      nil
      nixfmt-tree
      (python312.withPackages dotFilesPackages.pyPackages)
    ])
    ++ (with pkgs; [
      # anz deps
      patchutils
      go
      golangci-lint
      gomodifytags
      google-cloud-sdk
      google-cloud-sql-proxy
      gopls
      gotest
      ko
      nodejs
      pgcli
      postgresql_18
      protobuf
      protoc-gen-go
      typescript
      uv
    ])
    ++ [
      dotFilesPackages.f5
      dotFilesPackages.tour
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
  security.pam.services.sudo_local.reattach = true;

  # Homebrew integration
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
      # Homebrew 4.7+ requires explicit confirmation for `brew bundle --cleanup`;
      # pass --force so activation can proceed non-interactively.
      extraFlags = [ "--force" ];
      # Homebrew 4.7+ enforces HOMEBREW_REQUIRE_TAP_TRUST and refuses to load
      # formulae from untrusted third-party taps. Disable that check for the
      # `brew bundle` invocation here so taps like koekeishiya/formulae and
      # bnomei/tmux-mcp load without manual `brew trust` runs. Interactive shell
      # brew still respects the default trust prompt.
      extraEnv = {
        HOMEBREW_NO_REQUIRE_TAP_TRUST = "1";
      };
    };
    # macOS-specific apps that aren't available in nixpkgs or work better via Homebrew
    casks = [
      "brave-browser"
      "claude-code@latest"
      "cursor"
      "cursor-cli"
      "discord"
      "ghostty"
      "google-chrome"
      "hot"
      "linear"
      "localsend"
      "orbstack"
      "private-internet-access"
      "unnaturalscrollwheels"
      "signal"
      "slack"
      "spotify"
      "steam"
      "tailscale-app"
      "utm"
      "visual-studio-code"
      "vlc"
    ];
    taps = [
      "bnomei/tmux-mcp"
      "koekeishiya/formulae"
      "hashicorp/tap"
    ];
    brews = [
      "afsctool"
      "azure-cli"
      "hashicorp/tap/terraform"
      "koekeishiya/formulae/yabai"
      "koekeishiya/formulae/skhd"
      "bnomei/tmux-mcp/tmux-mcp-rs"
    ];
  };

  # Programs
  programs = {
    zsh.enable = true;
  };

  # Home-manager configuration for this machine
  home-manager.users.${username} = {
    imports = [
      "${inputs.dschana-system-config}/dev-shared/neovim.nix"
    ];

    programs.tmux = {
      enable = true;
      mouse = true;
      # keyMode = "vi";
      plugins = with pkgs.tmuxPlugins; [
        sensible
        resurrect
      ];
      extraConfig = ''
        # Forward modified keys (Ctrl+Arrow, Ctrl+Backspace, etc.) to inner programs
        set -g xterm-keys on

        # Truecolor + 256-color so starship/Nerd Fonts render correctly inside tmux
        set -g default-terminal "tmux-256color"
        set -as terminal-features ",xterm-256color:RGB"
        set -as terminal-features ",ghostty:RGB"

        # Style status bar
        set -g status-style fg=white,bg=black
        set -g window-status-current-style fg=green,bg=black
        set -g pane-active-border-style fg=green,bg=black
        set -g window-status-format " #I:#W#F "
        set -g window-status-current-format " #I:#W#F "
        set -g window-status-current-style bg=green,fg=black
        set -g window-status-activity-style bg=black,fg=yellow
        set -g window-status-separator ""
        set -g status-justify centre

        # Mouse scrolling
        bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
        bind -n WheelDownPane select-pane -t= \; send-keys -M
        bind -n C-WheelUpPane select-pane -t= \; copy-mode -e \; send-keys -M
        bind -T copy-mode-vi    C-WheelUpPane   send-keys -X halfpage-up
        bind -T copy-mode-vi    C-WheelDownPane send-keys -X halfpage-down
        bind -T copy-mode-emacs C-WheelUpPane   send-keys -X halfpage-up
        bind -T copy-mode-emacs C-WheelDownPane send-keys -X halfpage-down

        # macOS clipboard
        unbind -T copy-mode-vi Enter
        bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"
        bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
      '';
    };

    programs.ssh = {
      addKeysToAgent = "yes";
    };

    programs.git = {
      enable = true;
      extraConfig = {
        url."git@github.com:".insteadOf = "https://github.com/";
        # user.email = "cole@anzenna.ai";
      };
    };

    programs.vscode.enable = false;

    home.sessionVariables = {
      GOPRIVATE = "github.com/anzenna-ai";
    };

    programs.zsh.initExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
      export GOPATH=$HOME/go
      export GOPRIVATE=github.com/anzenna-ai
      export ANZENNA_LIBRARY="/Users/cole/anzenna/anzenna-library"
      export SWAGPATH="/Users/cole/anzenna/misc/openapi-generator"

      [ -f "$HOME/.work-env" ] && . "$HOME/.work-env"
    '';

    programs.zsh.shellAliases = {
      ndarwin = "nix run nixpkgs#nix-output-monitor -- build .#darwinConfigurations.cole-darwin.system";
    };

    # Yabai and skhd launchd services
    launchd.agents = {
      skhd = {
        enable = true;
        config = {
          ProgramArguments = [ "/opt/homebrew/bin/skhd" ];
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/tmp/skhd.out.log";
          StandardErrorPath = "/tmp/skhd.err.log";
        };
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
      alt - j : /opt/homebrew/bin/yabai -m window --focus west
      alt - k : /opt/homebrew/bin/yabai -m window --focus south
      alt - i : /opt/homebrew/bin/yabai -m window --focus north
      alt - l : /opt/homebrew/bin/yabai -m window --focus east

      # swap window
      shift + alt - j : /opt/homebrew/bin/yabai -m window --swap west
      shift + alt - k : /opt/homebrew/bin/yabai -m window --swap south
      shift + alt - i : /opt/homebrew/bin/yabai -m window --swap north
      shift + alt - l : /opt/homebrew/bin/yabai -m window --swap east

      # move window
      ctrl + alt - j : /opt/homebrew/bin/yabai -m window --warp west
      ctrl + alt - k : /opt/homebrew/bin/yabai -m window --warp south
      ctrl + alt - i : /opt/homebrew/bin/yabai -m window --warp north
      ctrl + alt - l : /opt/homebrew/bin/yabai -m window --warp east

      # toggle float and center
      alt - t : /opt/homebrew/bin/yabai -m window --toggle float --grid 4:4:1:1:2:2

      # toggle fullscreen
      alt - f : /opt/homebrew/bin/yabai -m window --toggle zoom-fullscreen

      # balance tree
      shift + alt - 0 : /opt/homebrew/bin/yabai -m space --balance

      # focus spaces
      alt - 1 : /opt/homebrew/bin/yabai -m space --focus 1
      alt - 2 : /opt/homebrew/bin/yabai -m space --focus 2
      alt - 3 : /opt/homebrew/bin/yabai -m space --focus 3
      alt - 4 : /opt/homebrew/bin/yabai -m space --focus 4
      alt - 5 : /opt/homebrew/bin/yabai -m space --focus 5

      # move window to space
      shift + alt - 1 : /opt/homebrew/bin/yabai -m window --space 1
      shift + alt - 2 : /opt/homebrew/bin/yabai -m window --space 2
      shift + alt - 3 : /opt/homebrew/bin/yabai -m window --space 3
      shift + alt - 4 : /opt/homebrew/bin/yabai -m window --space 4
      shift + alt - 5 : /opt/homebrew/bin/yabai -m window --space 5
    '';

    home.file."go/bin/f5".source = "${dotFilesPackages.f5}/bin/f5";
    home.file."go/bin/protoc-gen-go".source = "${pkgs.protoc-gen-go}/bin/protoc-gen-go";

    # Ghostty terminal config
    home.file.".config/ghostty/config".text = ''
      font-family = "Consolas Nerd Font Mono"
      # macos-titlebar-style = hidden
      theme = "Atom One Dark"
    '';
  };
}
