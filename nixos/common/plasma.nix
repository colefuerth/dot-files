{
  config,
  dotFilesPackages,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcfg.plasma;
in
{
  options = {
    nixcfg.plasma.enable = lib.mkOption {
      default = false;
      description = ''
        Enable the KDE Plasma 6 desktop environment
      '';
      type = lib.types.bool;
    };
  };
  config = lib.mkIf cfg.enable {
    # Enable SDDM login manager (Wayland)
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    # Enable KDE Plasma 6
    services.desktopManager.plasma6.enable = true;

    # Enable automatic login for the user
    services.displayManager.autoLogin.enable = true;
    services.displayManager.autoLogin.user = "cole";

    # Enable Wayland support for Electron/Chromium apps
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    services.xserver.videoDrivers = lib.mkDefault [
      "modesetting"
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
        xdg-desktop-portal-kde
      ];
    };
  };
}
