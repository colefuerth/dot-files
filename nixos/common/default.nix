{
  config,
  inputs,
  isDarwin ? false,
  lib,
  pkgs,
  host,
  ...
}:
let
  cfg = config.nixcfg;
  isLinux = !isDarwin;
in
{
  options = {
    nixcfg = {
      enable = lib.mkOption {
        default = true;
        description = ''
          Anything that goes on every system.
        '';
        type = lib.types.bool;
      };

      applyOverlay = lib.mkOption {
        default = true;
        description = ''
          Any overlays that goes on every system.
        '';
        type = lib.types.bool;
      };
    };
  };
  config = lib.mkIf cfg.enable (lib.mkMerge ([
    # Cross-platform configuration
    {
      nixpkgs.overlays = lib.optionals cfg.applyOverlay [ (import ../../overlays inputs) ];

      nix = {
        gc = {
          automatic = true;
        };
        settings = {
          cores = 0;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          max-jobs = "auto";
          substituters = [
            "https://nix-community.cachix.org"
            "https://cuda-maintainers.cachix.org"
            "https://install.determinate.systems"
          ];
          trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
            "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
          ];
        };
      };

      environment.systemPackages =
        with pkgs;
        [
          _7zz
          binutils # provides strings, objdump, nm, etc.
          btop
          curl
          dig
          eza
          file
          fresh-editor
          git
          gnupg
          inetutils
          lsof
          man-pages
          man-pages-posix
          micro
          nano
          nix-index
          nix-output-monitor
          nmap
          nvd
          openssh
          openssl
          pv
          ranger
          ripgrep
          rsync
          tmux
          unrar
          unzip
          vim
          wget
          zip
        ]
        ++ lib.optionals isLinux [
          gptfdisk
          iotop
          usbutils
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
          rar # x86_64 only
        ];

      # Set your time zone.
      time.timeZone = "America/Los_Angeles";

      environment.variables.EDITOR = lib.mkForce "fresh";
      environment.variables.VISUAL = lib.mkForce "code";
      programs = {
        gnupg.agent = {
          enable = true;
          enableSSHSupport = true;
        };
        vim.enable = true;
        zsh.enable = true;
      };
    }
  ] ++ lib.optionals isLinux [
    # Linux-specific configuration
    {
      boot.plymouth.enable = false;

      nix.gc = {
        randomizedDelaySec = "45min";
        options = "--delete-older-than 7d";
      };

      nix.settings = {
        auto-optimise-store = true;
        eval-cores = 0;
        experimental-features = [
          "parallel-eval"
        ];
      };

      nix.registry.nixpkgs = {
        flake = inputs.nixpkgs;
        to = {
          type = "path";
          path = pkgs.path;
          narHash = builtins.readFile (
            pkgs.runCommandLocal "get-nixpkgs-hash" {
              nativeBuildInputs = [ pkgs.nix ];
            } "nix-hash --type sha256 --sri ${pkgs.path} > $out"
          );
        };
      };

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

      programs = {
        appimage = {
          enable = true;
          binfmt = true;
        };
        java.enable = true;
        vim.defaultEditor = false;
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
      };

      networking = {
        hostName = host; # Define your hostname.
        networkmanager.enable = true;
        firewall.enable = lib.mkDefault true;
      };

      services = {
        avahi = {
          enable = lib.mkDefault true;
          nssmdns4 = true;
          openFirewall = true;
          publish = {
            enable = true;
            userServices = true;
            addresses = true;
          };
        };
        fwupd.enable = lib.mkDefault true;
        openssh = {
          enable = lib.mkDefault true;
          settings.PasswordAuthentication = lib.mkDefault false;
        };
        xserver.xkb = {
          layout = "us";
          variant = "";
        };
      };

      virtualisation = {
        vmVariant = {
          virtualisation = {
            cores = lib.mkDefault 8;
            memorySize = lib.mkDefault 8192;
          };
        };
        docker = {
          enable = lib.mkDefault true;
          daemon.settings.features.cdi = true;
        };
      };
    }
  ]));

}
