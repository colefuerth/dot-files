{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.nixcfg.wallpaperEngine;
in
{
  options.nixcfg.wallpaperEngine = {
    enable = lib.mkEnableOption "AC-power-gated linux-wallpaperengine";
    wallpapers = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "Per-monitor wallpapers for home-manager's linux-wallpaperengine.";
    };
    assetsPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/${username}/.local/share/Steam/steamapps/common/wallpaper_engine/assets";
      description = "Steam Wallpaper Engine assets path.";
    };
    serviceEnvironment = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra Environment= entries for the wallpaper service (e.g. a VAAPI driver).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Toggle the wallpaper service on AC power changes.
    services.udev.extraRules = ''
      # Monitor AC adapter state changes and toggle wallpaper service
      # ATTR{type}=="Mains" ensures only the AC adapter triggers these rules,
      # not USB-C power supply devices which enumerate with online=0 at boot.
      SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl --user --machine=${username}@.host stop linux-wallpaperengine.service"
      SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl --user --machine=${username}@.host reset-failed linux-wallpaperengine.service"
      SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl --user --machine=${username}@.host start linux-wallpaperengine.service"
    '';

    home-manager.users.${username} = {
      # https://github.com/nix-community/home-manager/blob/master/modules/services/linux-wallpaperengine.nix
      services.linux-wallpaperengine = {
        enable = true;
        assetsPath = cfg.assetsPath;
        wallpapers = cfg.wallpapers;
      };
      systemd.user.services.linux-wallpaperengine = {
        Unit.ConditionACPower = true;
        Service = {
          Restart = lib.mkForce "always";
          RestartSec = "3s";
          Environment = cfg.serviceEnvironment;
        };
      };
      systemd.user.services.linux-wallpaperengine-watchdog = {
        Unit = {
          Description = "Recover linux-wallpaperengine if failed on AC power";
          ConditionACPower = true;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl --user reset-failed linux-wallpaperengine.service 2>/dev/null; ${pkgs.systemd}/bin/systemctl --user start linux-wallpaperengine.service'";
        };
      };
      systemd.user.timers.linux-wallpaperengine-watchdog = {
        Unit.Description = "Periodically recover linux-wallpaperengine";
        Timer = {
          OnBootSec = "30s";
          OnUnitActiveSec = "5min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
