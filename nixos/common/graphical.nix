{ dotFilesPackages, pkgs, ... }:
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
      enable = true;
      package = firefox;
      # nativeMessagingHosts = [ firefoxpwa ];
    };
    vscode = {
      enable = true;
      package = pkgs.vscode;
    };
  };

  services.printing.enable = true;
}
