{
  config,
  dotFilesPackages,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcfg.cinnamon;
in
{
  options = {
    nixcfg.cinnamon.enable = lib.mkOption {
      default = false;
      description = ''
        Enable the Cinnamon desktop environment
      '';
      type = lib.types.bool;
    };
  };
  config = lib.mkIf cfg.enable {
    # Enable the X server (Cinnamon runs on X11)
    services.xserver.enable = true;

    # Enable LightDM login manager
    services.xserver.displayManager.lightdm.enable = true;

    # Enable the Cinnamon desktop environment
    services.xserver.desktopManager.cinnamon.enable = true;

    # Enable automatic login for the user
    services.displayManager.autoLogin.enable = true;
    services.displayManager.autoLogin.user = "cole";

    # Force the nvidia X11 driver — modesetting (inherited from plasma.nix
    # via mkDefault) does not initialize an X server on the RTX 5070 Ti, so
    # LightDM's greeter X server exits with code 1.
    services.xserver.videoDrivers = lib.mkForce [
      "nvidia"
    ];

    environment.systemPackages = with pkgs; [
      adwaita-icon-theme
      dotFilesPackages.consolas-nf
      gnome-disk-utility
    ];

    home-manager.users.cole = {
      home.pointerCursor = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
        gtk.enable = true;
        x11.enable = true;
      };
    };

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
    };
  };
}
