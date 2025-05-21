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
          Enable a bunch of my common NixOS things.
        '';
        type = lib.types.bool;
      };

      applyOverlay = lib.mkOption {
        default = true;
        description = ''
          Apply my common NixOS overlay.
        '';
        type = lib.types.bool;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = lib.optionals cfg.applyOverlay [ (import ../../overlays) ];

    nix = {
      gc = {
        automatic = true;
        randomizedDelaySec = "45min";
        options = "--delete-older-than 30d";
      };
      settings = {
        auto-optimise-store = true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = [
          "https://nix-community.cachix.org"
          "https://cuda-maintainers.cachix.org"
          "https://heaviside-industries.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
          "heaviside-industries.cachix.org-1:DXGy3eI6sMfLS7/kC6naM3zqg5A7tcBUKKAaXveQh1M="
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
      btop
      curl
      eza
      git
      gnupg
      gptfdisk
      inetutils
      iotop
      nano
      nix-index
      nix-output-monitor
      # Since `nixfmt` is the classic style, use `nixfmt-rfc-style` for now
      nixfmt-rfc-style
      nmap
      openssh
      openssl
      ranger
      rsync
      tmux
      usbutils
      vim
      wget
    ];

    programs.vim.enable = true;
    programs.vim.defaultEditor = false;
    environment.variables.EDITOR = "nano";
  };

}
