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
        pkgs.adwaita-icon-theme # GNOME cursor theme
        pkgs.nerd-fonts.consolas
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
      home.pointerCursor = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
        gtk.enable = true;
        x11.enable = true;
      };

      programs.kitty = {
        enable = true;
        font = {
          name = "Consolas NF";
          size = 12;
        };
      };

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

          # Environment variables
          env = [
            "XCURSOR_THEME,Adwaita"
            "XCURSOR_SIZE,24"
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

            # Move windows
            "$mod SHIFT, left, movewindow, l"
            "$mod SHIFT, right, movewindow, r"
            "$mod SHIFT, up, movewindow, u"
            "$mod SHIFT, down, movewindow, d"

            # Resize windows
            "$mod CTRL, left, resizeactive, -20 0"
            "$mod CTRL, right, resizeactive, 20 0"
            "$mod CTRL, up, resizeactive, 0 -20"
            "$mod CTRL, down, resizeactive, 0 20"

            # Workspace switching
            "$mod, 1, workspace, 1"
            "$mod, 2, workspace, 2"
            "$mod, 3, workspace, 3"
            "$mod, 4, workspace, 4"
            "$mod, 5, workspace, 5"

            # Move window to workspace
            "$mod SHIFT, 1, movetoworkspace, 1"
            "$mod SHIFT, 2, movetoworkspace, 2"
            "$mod SHIFT, 3, movetoworkspace, 3"
            "$mod SHIFT, 4, movetoworkspace, 4"
            "$mod SHIFT, 5, movetoworkspace, 5"
          ];

          # Window rules
          general = {
            gaps_in = 5;
            gaps_out = 5;
            border_size = 2;
          };

          decoration = {
            rounding = 5;
          };

          input = {
            touchpad = {
              natural_scroll = true;
              tap-to-click = true;
              disable_while_typing = true;
            };
          };
        };
      };
    };
  };

}
