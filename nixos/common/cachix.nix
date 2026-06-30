{
  config,
  pkgs,
  lib,
  username,
  ...
}:
let
  cfg = config.nixcfg.cachix;
in
{
  options = {
    nixcfg.cachix = {
      enable = lib.mkOption {
        default = true;
        description = ''
          Enable a list of Cachix substituters
        '';
        type = lib.types.bool;
      };
      users = lib.mkOption {
        default = [ username ];
        description = "List of all users who should be trusted to use Cachix";
        type = lib.types.listOf lib.types.str;
      };
    };
  };
  config =
    lib.mkIf cfg.enable {
      environment.systemPackages = [ pkgs.cachix ];
      nix.settings.substituters = [ "https://cache.nixos.org/?priority=25" ];

      nix.settings.trusted-users = cfg.users;
    }
    // (import ./cachix/nix-community.nix)
    // (import ./cachix/cuda-maintainers.nix);
}
