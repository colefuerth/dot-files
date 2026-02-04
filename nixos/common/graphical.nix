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

  services.printing.enable = true;
}
