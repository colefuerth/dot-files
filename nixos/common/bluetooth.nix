{ ... }:
{
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        Privacy = "Device";
        JustWorksRepairing = "always";
        FastConnectable = true;
      };
      settings.Policy.AutoEnable = true;
    };
  };
}
