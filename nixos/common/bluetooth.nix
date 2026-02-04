{ ... }:
{
  hardware = {
    bluetooth = {
      enable = true;
      # package = pkgs.bluez-experimental;
      powerOnBoot = true;
      settings.General = {
        # experimental = true;
        Privacy = "Device";
        JustWorksRepairing = "always";
        FastConnectable = true;
      };
      settings.Policy.AutoEnable = true;
    };
  };
}
