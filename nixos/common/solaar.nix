{ pkgs, ... }:
{
  # udev rules (uaccess on Logitech hidraw nodes) + solaar itself; without
  # these the hidraw devices are root-only and `solaar show` finds nothing.
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  # Logitech device manager (e.g. MX Master); start hidden in the tray.
  systemd.user.services.solaar = {
    description = "Solaar - Logitech Device Manager";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.solaar}/bin/solaar --window=hide";
      Restart = "on-failure";
    };
  };
}
