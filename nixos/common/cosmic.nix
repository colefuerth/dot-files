{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcfg.cosmic;
in
{
  options = {
    nixcfg.cosmic.enable = lib.mkOption {
      default = false;
      description = ''
        Enable the COSMIC desktop environment
      '';
      type = lib.types.bool;
    };
  };
  config = lib.mkIf cfg.enable {
    # Enable the COSMIC login manager
    services.displayManager.cosmic-greeter.enable = true;

    # Enable the COSMIC desktop environment
    services.desktopManager.cosmic.enable = true;

    # Enable automatic login for the user
    services.displayManager.autoLogin.enable = true;
    services.displayManager.autoLogin.user = "cole";

    # Optional performance optimization for System76 hardware
    services.system76-scheduler.enable = true;

    # Enable clipboard access for COSMIC apps
    environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";

    # Optional: Exclude some default COSMIC applications
    environment.cosmic.excludePackages = with pkgs; [
      # cosmic-edit  # Uncomment to exclude COSMIC text editor
    ];

    # Install essential packages
    environment.systemPackages = with pkgs; [
      cosmic-term # COSMIC terminal
      adwaita-icon-theme # Icon theme
      nerd-fonts.fira-code # Font
    ];

    home-manager.users.cole = {
      home.pointerCursor = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
        gtk.enable = true;
        x11.enable = true;
      };

      # Configure firefox for better COSMIC theming if needed
      # programs.firefox = lib.mkIf config.programs.firefox.enable {
      #   preferences = {
      #     "widget.gtk.libadwaita-colors.enabled" = false;
      #   };
      # };
    };
  };
}