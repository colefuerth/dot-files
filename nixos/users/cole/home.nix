{
  config,
  lib,
  pkgs,
  username,
  dotFilesPackages,
  ...
}:
{
  config = {
    home = {
      # Set the base home-manager options
      inherit username;
      homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
      stateVersion = lib.mkDefault "25.11";
      language.base = "en_US.UTF-8";
      packages = with pkgs; [
        inxi
        ncdu
        fastfetch
      ];
    };

    nixpkgs.config = {
      allowUnfree = lib.mkForce true; # Simplified for now - can restrict later if needed
    };

    programs = {
      btop.enable = true;
      direnv.enable = true;
      firefox =
        with pkgs;
        lib.mkIf (!pkgs.stdenv.isDarwin) {
          enable = lib.mkDefault true;
          nativeMessagingHosts = [ firefoxpwa ];
        };
      gh.enable = true;
      git = {
        enable = true;
        settings = {
          user = {
            name = lib.mkDefault "Cole Fuerth";
            email = lib.mkDefault "colefuerth@gmail.com";
            signingkey = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
          };
          commit.gpgsign = true;
          gpg = {
            format = "ssh";
            ssh.allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
          };
        };
      };
      gpg.enable = true;
      home-manager.enable = true;
      mcfly.enable = true;
      spotify-player.enable = true;
      ssh = {
        enable = lib.mkDefault true;
        package = pkgs.openssh.override { withKerberos = true; };
      };
      starship.enable = true;
      vscode = {
        enable = lib.mkDefault true;
      };
      zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        # Enable oh-my-zsh for better compatibility with your original setup
        oh-my-zsh = {
          enable = true;
          plugins = [ "git" ];
          theme = ""; # Empty theme since we use starship
        };
        history.append = true;
        history.expireDuplicatesFirst = true;
        history.extended = true;
        history.ignoreDups = true;

        loginExtra = ''
          # Run the welcome screen on shell startup (only in interactive shells,
          # and skip inside tmux panes so it doesn't fire on every new pane)
          if [[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -f "${dotFilesPackages.welcome}" ]]; then
            bash "${dotFilesPackages.welcome}"
          fi
        '';

        # Fix Ctrl+Left/Right key bindings for word movement
        initContent =
          let
            # Add nix completions to fpath BEFORE compinit runs
            zshConfigPreInit = lib.mkOrder 100 ''
              fpath=(${pkgs.nix}/share/zsh/site-functions $fpath)
            '';
            # general / path
            zshConfig = lib.mkOrder 1000 ''
              # Set SHRC variable for compatibility with your scripts
              export SHRC="zsh"

              # ncdu wrapper to use config from repo
              alias ncdu='XDG_CONFIG_HOME="${dotFilesPackages.configs}" ncdu'

              # Load all aliases (skip mcfly and starship since handled by home-manager)
              for f in ${dotFilesPackages.aliases}/*; do
                if [[ -f "$f" ]]; then
                  fname="$(basename "$f")"
                  case "$fname" in
                    "mcfly"|"starship")
                      # Skip - handled by home-manager
                      ;;
                    *)
                      # Check if file contains bash-only commands
                      if ! grep -q "shopt\|complete " "$f" 2>/dev/null; then
                        # echo "Loading alias file: $fname"
                        source "$f"
                      else
                        echo "Skipping bash-only alias file: $fname"
                      fi
                      ;;
                  esac
                fi
              done
              export PATH=$PATH:${dotFilesPackages.scripts}/bin
            '';
            # dev shell setup
            zshConfigLateInit = lib.mkOrder 1500 ''
              # Key bindings for word movement
              bindkey "^[[1;5C" forward-word    # Ctrl+Right
              bindkey "^[[1;5D" backward-word   # Ctrl+Left
              bindkey "^[[3~" delete-char       # Delete key
              bindkey "^[[H" beginning-of-line  # Home key
              bindkey "^[[F" end-of-line        # End key

              # Ctrl+Backspace to delete word backward
              bindkey "^H" backward-kill-word
              bindkey "^?" backward-delete-char

              # Ctrl+Enter to accept line (insert newline in multi-line mode)
              bindkey "^M" accept-line
            '';
          in
          lib.mkMerge [
            zshConfigPreInit
            zshConfig
            zshConfigLateInit
          ];
      };
    };

    home.file.".ssh/allowed_signers".text = ''
      * ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIIw7/9vkQKS0ultxI6Pbb7wqDlkE120uUw/Hr2UVvcG
    '';
    home.file.".config/btop/btop.conf".source = "${dotFilesPackages.configs}/btop/btop.conf";
    home.file.".config/ncdu/config".source = "${dotFilesPackages.configs}/ncdu/config";
    home.file.".config/.clang-format".source = "${dotFilesPackages.configs}/clang-format/.clang-format";
    home.file.".config/starship.toml".source = "${dotFilesPackages.configs}/starship.toml";
    home.file.".config/flameshot/flameshot.ini".source =
      "${dotFilesPackages.configs}/flameshot/flameshot.ini";
    home.file.".config/ranger/rc.conf".source = "${dotFilesPackages.configs}/ranger/rc.conf";
    services.gpg-agent = {
      enable = true;
      enableBashIntegration = true;
      enableSshSupport = true;
    };
  };
}
