{
  config,
  inputs,
  lib,
  pkgs,
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

    nix = {
      gc = {
        automatic = true;
        randomizedDelaySec = "45min";
        options = "--delete-older-than 7d";
      };
      settings = {
        auto-optimise-store = true;
        experimental-features = [
          "nix-command"
          "flakes"
          "parallel-eval"
        ];
        substituters = [
          "https://nix-community.cachix.org"
          "https://cuda-maintainers.cachix.org"
          # "https://heaviside-industries.cachix.org"
          "https://install.determinate.systems"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
          # "heaviside-industries.cachix.org-1:DXGy3eI6sMfLS7/kC6naM3zqg5A7tcBUKKAaXveQh1M="
          "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
        ];
        max-jobs = "auto";
        cores = 0;
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
      binutils # provides strings, objdump, nm, etc.
      btop
      curl
      dig
      eza
      file
      git
      gnupg
      gptfdisk
      inetutils
      iotop
      lsof
      nano
      nix-index
      nix-output-monitor
      nmap
      openssh
      openssl
      ranger
      rsync
      tmux
      usbutils
      vim
      wget
      zip
    ];

    programs.vim.enable = true;
    programs.vim.defaultEditor = false;
    environment.variables.EDITOR = "nano";
  };

}
