{
  config,
  host,
  inputs,
  lib,
  pkgs,
  username,
  dotFilesPackages,
  ...
}:
{
  config = {
    home = rec {
      # Set the base home-manager options
      inherit username;
      homeDirectory = "/home/${username}";
      stateVersion = lib.mkDefault "25.11";
      language.base = "en_US.UTF-8";
      packages = with pkgs; [
        inxi
        ncdu
        ripgrep
      ];
    };

    # Allow certain unfree packages
    nixpkgs.config = {
      allowUnfree = true; # Simplified for now - can restrict later if needed
    };

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
        settings = {
          user = {
            name = "Cole Fuerth";
            email = "colefuerth@gmail.com";
            signingkey = "/home/cole/.ssh/id_ed25519.pub";
          };
          commit.gpgsign = true;
          gpg = {
            format = "ssh";
            ssh.allowedSignersFile = "/home/cole/.ssh/allowed_signers";
          };
        };
      };
      gpg = {
        enable = true;
      };
      home-manager.enable = true;
      mcfly.enable = true;
      # nix-index.enable = true;  # Disabled temporarily - run `nix-index` manually when needed
      spotify-player.enable = true;
      starship = {
        enable = true;
      };
      vscode = {
        enable = true;
        # package = pkgs.vscodium;
        package = pkgs.vscode;
        # userSettings = {
        #   "editor.fontFamily" = "'Consolas Nerd Font Mono'";
        #   "nix.enableLanguageServer" = true;
        #   "nix.serverPath" = "nil"; # or "nixd", or ["executable", "argument1", ...]
        #   # LSP config can be passed via the ``nix.serverSettings.{lsp}`` as shown below.
        #   "nix.serverSettings" = {
        #     # check https://github.com/oxalica/nil/blob/main/docs/configuration.md for all options available
        #     "nil" = {
        #       # "diagnostics" = {
        #       #  "ignored" = ["unused_binding", "unused_with"],
        #       # },
        #       "formatting" = {
        #         "command" = [
        #           "treefmt"
        #         ];
        #       };
        #       "nix" = {
        #         "maxMemoryMB" = 8192;
        #         "flake" = {
        #           "autoArchive" = true;
        #           "autoEvalInputs" = true;
        #           "nixpkgsInputName" = "nixpkgs";
        #         };
        #       };
        #     };
        #   };
        #   "claudeCode.preferredLocation" = "panel";
        #   "claudeCode.useTerminal" = true;
        #   "terminal.integrated.shellIntegration.history" = 1000000;
        #   "git.confirmSync" = false;
        # };
        # profiles = {
        #   default = {
        #     extensions = with pkgs.vscode-marketplace; [
        #       # Themes
        #       akamud.vscode-theme-onedark
        #       chadbaileyvh.oled-pure-black---vscode
        #       github.github-vscode-theme
        #       pkief.material-icon-theme
        #       zhuangtongfa.material-theme
        #       # AI/Code assistance
        #       anthropic.claude-code
        #       github.copilot
        #       github.copilot-chat
        #       tabbyml.vscode-tabby
        #       # Git/Version Control
        #       codezombiech.gitignore
        #       eamodio.gitlens
        #       github.vscode-pull-request-github
        #       hashhar.gitattributes
        #       jasonnutter.vscode-codeowners
        #       # Nix
        #       jnoortheen.nix-ide
        #       # Python
        #       donjayamanne.python-extension-pack
        #       kevinrose.vsc-python-indent
        #       ms-python.autopep8
        #       ms-python.debugpy
        #       ms-python.isort
        #       ms-python.python
        #       ms-python.vscode-pylance
        #       ms-python.vscode-python-envs
        #       njpwerner.autodocstring
        #       # Jupyter
        #       ms-toolsai.jupyter
        #       ms-toolsai.jupyter-keymap
        #       ms-toolsai.jupyter-renderers
        #       ms-toolsai.vscode-jupyter-cell-tags
        #       ms-toolsai.vscode-jupyter-slideshow
        #       # C/C++/Embedded
        #       # dan-c-underwood.arm
        #       # eclipse-cdt.memory-inspector
        #       jeff-hykin.better-cpp-syntax
        #       llvm-vs-code-extensions.vscode-clangd
        #       ms-vscode.cpptools
        #       ms-vscode.cpptools-extension-pack
        #       ms-vscode.cpptools-themes
        #       # platformio.platformio-ide
        #       plorefice.devicetree
        #       # vscode-arduino.vscode-arduino-community
        #       xaver.clang-format
        #       # Microchip MPLAB
        #       # microchip.mplab-clangd
        #       # microchip.mplab-code-configurator
        #       # microchip.mplab-core-da
        #       # microchip.mplab-data-visualizer
        #       # microchip.mplab-extension-pack
        #       # microchip.mplab-extensions-core
        #       # microchip.mplab-extensions-platforms
        #       # microchip.mplab-kconfig
        #       # microchip.mplab-ui
        #       # microchip.mplabx-importer
        #       # microchip.runcmake
        #       # microchip.toolchains
        #       # Rust
        #       rust-lang.rust-analyzer
        #       # Docker/Containers
        #       docker.docker
        #       formulahendry.docker-explorer
        #       formulahendry.docker-extension-pack
        #       ms-azuretools.vscode-containers
        #       ms-azuretools.vscode-docker
        #       ms-vscode-remote.remote-containers
        #       # Remote Development
        #       ms-vscode-remote.remote-ssh
        #       ms-vscode-remote.remote-ssh-edit
        #       ms-vscode.remote-explorer
        #       ms-vscode.remote-server
        #       ms-vsliveshare.vsliveshare
        #       # Shell/Bash
        #       foxundermoon.shell-format
        #       mads-hartmann.bash-ide-vscode
        #       # Markdown
        #       bierner.markdown-preview-github-styles
        #       davidanson.vscode-markdownlint
        #       tomoki1207.pdf
        #       yzane.markdown-pdf
        #       yzhang.markdown-all-in-one
        #       # Other tools
        #       christian-kohler.path-intellisense
        #       hangxingliu.vscode-systemd-support
        #       james-yu.latex-workshop
        #       janisdd.vscode-edit-csv
        #       ms-vscode.hexeditor
        #       ms-vscode.vscode-serial-monitor
        #       mutantdino.resourcemonitor
        #       pbkit.vscode-pbkit
        #       redhat.vscode-xml
        #       tamasfe.even-better-toml
        #       wholroyd.jinja
        #     ];
        #     enableExtensionUpdateCheck = true;
        #   };
        # };
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
          # Run the welcome screen on shell startup (only in interactive shells)
          if [[ -o interactive ]] && [[ -f "${dotFilesPackages.welcome}" ]]; then
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
            # autocompletion - skip bash-only completion files
            zshConfigEarlyInit = lib.mkOrder 500 ''
              if [[ -d "${dotFilesPackages.completions}" ]] && [[ -n "$(ls -A ${dotFilesPackages.completions} 2>/dev/null)" ]]; then
                for f in ${dotFilesPackages.completions}/*; do
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
