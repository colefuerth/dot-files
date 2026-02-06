{
  config,
  inputs,
  lib,
  pkgs,
  host,
  ...
}:
let
  cfg = config.nixcfg;
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
  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = lib.optionals cfg.applyOverlay [ (import ../../overlays inputs) ];

    boot.plymouth.enable = false;

    nix = {
      gc = {
        automatic = true;
        randomizedDelaySec = "45min";
        options = "--delete-older-than 7d";
      };
      settings = {
        auto-optimise-store = true;
        cores = 0;
        eval-cores = 0;
        experimental-features = [
          "nix-command"
          "flakes"
          "parallel-eval"
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
      registry.nixpkgs = {
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
    };

    environment.systemPackages = with pkgs; [
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
      gptfdisk
      inetutils
      iotop
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
      ranger
      rar
      ripgrep
      rsync
      tmux
      unrar
      unzip
      usbutils
      vim
      wget
      zip
    ];

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

    environment.variables.EDITOR = "micro";
    programs = {
      appimage = {
        enable = true;
        binfmt = true;
      };
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };
      java.enable = true;
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
      vim.enable = true;
      vim.defaultEditor = false;
      zsh.enable = true;
    };

    networking.hostName = host; # Define your hostname.
    networking.networkmanager.enable = true;
    networking.firewall.enable = lib.mkDefault true;

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
  };

}
