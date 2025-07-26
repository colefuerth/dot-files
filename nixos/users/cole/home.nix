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
      ];
    };

    # Allow certail unfree packages
    nixpkgs.config.allowUnfreePredicate = (p: builtins.elem (lib.getName p) [ ]);

    programs = {
      awscli.enable = true;
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
      nix-index.enable = true;
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
        };
      };
      starship = {
        enable = true;
        settings = {
          add_newline = true;
          command_timeout = 1000;
          scan_timeout = 50;
          format = ''
            $username\
            $hostname\
            $directory\
            $git_branch\
            $git_state\
            $git_status\
            $cmd_duration\
            $status\
            $nix_shell\
            $python\
            $line_break\
            $conda\
            $character
          '';
          cmd_duration = {
            format = "[$duration]($style) ";
            style = "yellow";
          };
          character = {
            success_symbol = "[>](bold purple)";
            error_symbol = "[>](bold red)";
          };
          directory = {
            read_only = " ro";
            style = "blue";
          };
          git_branch = {
            symbol = "git ";
          };
          git_state = {
            format = "\([$state( $progress_current/$progress_total)]($style)\) ";
            style = "bright-black";
          };
          git_status = {
            ahead = ">";
            behind = "<";
            diverged = "d";
            renamed = "r";
            deleted = "x";
          };
          hostname = {
            ssh_symbol = "";
          };
          python = {
            symbol = "py ";
            format = "[(\($virtualenv\) )]($style)";
          };
          python_binary = [
            "./venv/bin/python"
            "python"
            "python3"
            "python2"
          ];
        };
      };
      vscode = {
        enable = true;
      };
      zsh = rec {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        history.append = true;
        history.expireDuplicatesFirst = true;
        history.extended = true;
        history.ignoreDups = true;
        initContent =
          let
            # autocompletion
            zshConfigEarlyInit = lib.mkOrder 500 ''
              for f in ${repoRoot}/completions/*; do
                source $f
              done
            '';
            # general / path
            zshConfig = lib.mkOrder 1000 ''
              for f in ${repoRoot}/aliases/*; do
                source $f
              done
              export PATH=$PATH:${repoRoot}/scripts
            '';
            # dev shell setup
            zshConfigLateInit = lib.mkOrder 1500 ''
              eval "$(starship init zsh)"
            '';
          in
          lib.mkMerge [
            zshConfigEarlyInit
            zshConfig
            zshConfigLateInit
          ];
      };
    };

    home.file.".ssh/allowed_signers".text = ''
      * ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIIw7/9vkQKS0ultxI6Pbb7wqDlkE120uUw/Hr2UVvcG
    '';
    home.file.".ssh/config" = {
      target = ".ssh/config_source";
      force = true;
      onChange = ''
        touch ~/.ssh/config || true
        chmod 666 ~/.ssh/config || true
        cat ~/.ssh/config_source > ~/.ssh/config
        chmod 400 ~/.ssh/config

        mkdir -p /data/cole/.ssh/ || true
        chmod 755 /data/cole/.ssh/ || true
        cp -r ~/.ssh /data/cole/ || true
      '';
    };
    # "* ${builtins.readFile /home/${username}/.ssh/id_ed25519.pub}";
    services.gpg-agent = {
      enable = true;
      enableBashIntegration = true;
      enableSshSupport = true;
    };
  };
}
