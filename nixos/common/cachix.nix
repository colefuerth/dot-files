{
  config,
  pkgs,
  lib,
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
        description = ''List of all users who should be trusted to use Cachix'';
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
    # TODO: make this better with nix lib code to
    #       read the ./cachix dir and compile attrs
    // (import ./cachix/nix-community.nix)
    // (import ./cachix/cuda-maintainers.nix);
    # // (import ./cachix/heaviside-industries.nix)
}
