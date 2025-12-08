{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcfg.hyprland;
in
{
  options = {
    nixcfg.hyprland.enable = lib.mkOption {
      default = true;
      description = ''
        Enable the hyprland desktop
      '';
      type = lib.types.bool;
    };
  };
  config = lib.mkIf cfg.enable {
    nix.settings = {
      substituters = [ "https://hyprland.cachix.org" ];
      trusted-substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    };
    
    # Enable X11 and Wayland support
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    
    # Enable automatic login for the user
    services.displayManager.autoLogin.enable = true;
    services.displayManager.autoLogin.user = "cole";
    
    environment = {
      systemPackages = [
        pkgs.kitty # required for the default Hyprland config
      ];
      # Optional, hint Electron apps to use Wayland:
      sessionVariables.NIXOS_OZONE_WL = "1";
    };
    # hardware.opengl =
    #   # let
    #   #   pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    #   # in
    #   {
    #     # package = pkgs-unstable.mesa.drivers;
    #     # if you also want 32-bit support (e.g for Steam)
    #     driSupport32Bit = true;
    #     # package32 = pkgs-unstable.pkgsi686Linux.mesa.drivers;
    #   };
    hardware.graphics.enable32Bit = true;
    programs.hyprland =
      let
        pkgs-hyprland = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        enable = true;
        # set the flake package
        package = pkgs-hyprland.hyprland;
        # make sure to also set the portal package, so that they are in sync
        portalPackage = pkgs-hyprland.xdg-desktop-portal-hyprland;
        withUWSM = true; # recommended for most users
        xwayland.enable = true; # Xwayland can be disabled.
      };
    
    home-manager.users.cole = {
      wayland.windowManager.hyprland = {
        enable = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        systemd.enable = true;
        xwayland.enable = true;

        settings = {
          # Basic configuration
          "$mod" = "SUPER";

          # Monitor configuration
          monitor = ",preferred,auto,1";

          # Execute apps at launch
          exec-once = [
            "kitty"
          ];

          # Bindings
          bind = [
            "$mod, Q, exec, kitty"
            "$mod, C, killactive"
            "$mod, M, exit"
            "$mod, E, exec, dolphin"
            "$mod, V, togglefloating"
            "$mod, F, fullscreen"

            # Move focus
            "$mod, left, movefocus, l"
            "$mod, right, movefocus, r"
            "$mod, up, movefocus, u"
            "$mod, down, movefocus, d"
          ];

          # Window rules
          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
          };

          decoration = {
            rounding = 10;
          };
        };
      };
    };
  };

}
