{ config, ... }:
{
  imports = [ ./bluetooth.nix ];
  # stuff needed to use an xbox one controller
  hardware = {
    xpadneo.enable = true;
  };
  boot = {
    extraModulePackages = with config.boot.kernelPackages; [
      xpadneo
    ];
    extraModprobeConfig = ''
      options bluetooth disable_ertm=Y
    '';
    blacklistedKernelModules = [
      "xpad-noone"
      "xone"
    ];
  };
  environment.sessionVariables.SDL_JOYSTICK_HIDAPI = "0";
}
