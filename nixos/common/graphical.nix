{ dotFilesPackages, pkgs, lib, ... }:
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
      antialias = true;
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

  # users.users.${username} = {
  #   packages =
  #     with pkgs;
  #     [
  #     ];
  # };

  programs = {
    firefox = with pkgs; {
      enable = lib.mkDefault true;
      package = lib.mkDefault firefox;
      # nativeMessagingHosts = [ firefoxpwa ];
    };
    vscode = {
      enable = lib.mkDefault true;
      package = lib.mkDefault pkgs.vscode;
    };
  };

  services.printing.enable = true;
}
