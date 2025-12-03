{
  config,
  host,
  inputs,
  lib,
  pkgs,
  username,
  repoRoot,
  ...
}:
{
  config = {
    home = rec {
      # Set the base home-manager options
      inherit username;
      homeDirectory = "/home/${username}";
      stateVersion = "25.05";
      language.base = "en_US.UTF-8";
      packages = with pkgs; [
        claude-code
        ncdu
        inxi
      ];
    };

    # Allow certain unfree packages
    nixpkgs.config.allowUnfreePredicate = (p: builtins.elem (lib.getName p) [ "claude-code" ]);

    programs = {
      btop.enable = true;
      direnv.enable = true;
      firefox = with pkgs; {
        enable = true;
        package = firefox;
        nativeMessagingHosts = [ firefoxpwa ];
      };
      gh.enable = true;
      git = {
        enable = true;
        userName = "Cole Fuerth";
        userEmail = "colefuerth@gmail.com";
        extraConfig = {
          commit.gpgsign = true;
          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = "/home/cole/.ssh/allowed_signers";
          user.signingkey = "/home/cole/.ssh/id_ed25519.pub";
        };
      };
      gpg = {
        enable = true;
      };
      home-manager.enable = true;
      mcfly.enable = true;
      # nix-index.enable = true;  # Disabled temporarily - run `nix-index` manually when needed
      spotify-player.enable = true;
      ssh = {
        enable = true;
        package = pkgs.openssh.override { withKerberos = true; };
        # # IdentityAgent does not yet exist in matchBlocks so we need to
        # # use the extraConfig option.
        # extraConfig = ''
        #   IdentityAgent ${onePassPath}
        # '';
        matchBlocks = {
          "eu.nixbuild.net" = {
            hostname = "eu.nixbuild.net";
            # PubkeyAcceptedKeyTypes ssh-ed25519
            serverAliveInterval = 60;
            # IPQoS throughput
            identityFile = "/home/cole/.ssh/nixbuild/heaviside-shared";
          };
          "pi" = {
            user = "cole";
            hostname = "colepi.local";
            serverAliveInterval = 60;
            identityFile = "/home/cole/.ssh/id_rsa";
            forwardX11 = true;
            forwardX11Trusted = true;
          };
          "s" = {
            user = "cole";
            # hostname = "heaviside-thelio-server.local";
            hostname = "192.168.1.155";
            serverAliveInterval = 60;
          };
        };
      };
      starship = {
        enable = true;
      };
      vscode = {
        enable = true;
        package = pkgs.vscodium;
        extensions = with pkgs.vscode-extensions; [
          # Essential extensions that should be available
          ms-python.python
          rust-lang.rust-analyzer
          ms-vscode.cpptools
          jnoortheen.nix-ide
          eamodio.gitlens
        ];
      };
      zsh = rec {
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
          # Run the welcome screen on shell startup
          if [[ -f "${repoRoot}/10-welcome" ]]; then
            bash "${repoRoot}/10-welcome"
          fi
        '';

        # Fix Ctrl+Left/Right key bindings for word movement
        initContent =
          let
            # Add nix completions to fpath BEFORE compinit runs
            zshConfigPreInit = lib.mkOrder 100 ''
              fpath=(${pkgs.nix}/share/zsh/site-functions $fpath)
            '';
            # autocompletion - skip bash-only completion files
            zshConfigEarlyInit = lib.mkOrder 500 ''
              if [[ -d "${repoRoot}/completions" ]] && [[ -n "$(ls -A ${repoRoot}/completions 2>/dev/null)" ]]; then
                for f in ${repoRoot}/completions/*; do
                  # Skip bash completion files that use 'complete' command
                  if [[ -f "$f" ]] && ! grep -q "^complete " "$f" 2>/dev/null; then
                    source "$f"
                  fi
                done
              fi
            '';
            # general / path
            zshConfig = lib.mkOrder 1000 ''
              # Set SHRC variable for compatibility with your scripts
              export SHRC="zsh"

              # ncdu wrapper to use config from repo
              alias ncdu='XDG_CONFIG_HOME="${repoRoot}/.config" ncdu'

              # Load all aliases (skip mcfly and starship since handled by home-manager)
              for f in ${repoRoot}/aliases/*; do
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
              export PATH=$PATH:${repoRoot}/scripts
            '';
            # dev shell setup
            zshConfigLateInit = lib.mkOrder 1500 ''
              # Key bindings for word movement
              bindkey "^[[1;5C" forward-word    # Ctrl+Right
              bindkey "^[[1;5D" backward-word   # Ctrl+Left
              bindkey "^[[3~" delete-char       # Delete key
              bindkey "^[[H" beginning-of-line  # Home key
              bindkey "^[[F" end-of-line        # End key
            '';
          in
          lib.mkMerge [
            zshConfigPreInit
            zshConfigEarlyInit
            zshConfig
            zshConfigLateInit
          ];
      };
    };

    home.file.".ssh/allowed_signers".text = ''
      * ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIIw7/9vkQKS0ultxI6Pbb7wqDlkE120uUw/Hr2UVvcG
    '';
    home.file.".config/btop/btop.conf".source = "${repoRoot}/.config/btop/btop.conf";
    home.file.".config/ncdu/config".source = "${repoRoot}/.config/ncdu/config";
    home.file.".config/starship.toml".source = "${repoRoot}/.config/starship.toml";
    # home.file.".ssh/config" = {
    #   target = ".ssh/config_source";
    #   force = true;
    #   onChange = ''
    #     touch ~/.ssh/config || true
    #     chmod 666 ~/.ssh/config || true
    #     cat ~/.ssh/config_source > ~/.ssh/config
    #     chmod 400 ~/.ssh/config

    #     mkdir -p /data/cole/.ssh/ || true
    #     chmod 755 /data/cole/.ssh/ || true
    #     cp -r ~/.ssh /data/cole/ || true
    #   '';
    # };
    # "* ${builtins.readFile /home/${username}/.ssh/id_ed25519.pub}";
    services.gpg-agent = {
      enable = true;
      enableBashIntegration = true;
      enableSshSupport = true;
    };
  };
}
