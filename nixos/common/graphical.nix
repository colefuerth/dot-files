{
  dotFilesPackages,
  pkgs,
  lib,
  username,
  ...
}:
{
  fonts = {
    enableDefaultPackages = true;
    enableGhostscriptFonts = true;
    fontDir = {
      enable = true;
      decompressFonts = true;
    };
    fontconfig = {
      enable = true;
      cache32Bit = true;
      useEmbeddedBitmaps = true;
      defaultFonts = {
        monospace = [ "Consolas Nerd Font Mono" ];
      };
    };
    packages = [
      dotFilesPackages.consolas-nf
      pkgs.vista-fonts
    ];
  };

  programs = {
    firefox.enable = lib.mkDefault true;
    spotify-player.enable = lib.mkDefault true;
    vscode.enable = lib.mkDefault true;
  };

  # Shared across desktop environments (cosmic/plasma/cinnamon).
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    gnome-disk-utility
  ];

  users.users.${username} = {
    packages = with pkgs; [
      qalculate-qt
    ];
    extraGroups = [ "scanner" "lp" ];
  };

  home-manager.users.${username}.home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      hplipWithPlugin # make sure to run `NIXPKGS_ALLOW_UNFREE=1 nix-shell -p hplipWithPlugin --run 'sudo -E hp-setup'`
    ];
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.hplipWithPlugin ];
  };
}
