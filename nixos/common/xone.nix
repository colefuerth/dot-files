{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.nixcfg.xone;
in
{
  imports = [ ./bluetooth.nix ];

  options.nixcfg.xone.bigPictureSink = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "alsa_output.pci-0000_2d_00.1.hdmi-stereo";
    description = ''
      PipeWire sink to make the default audio output when the controller
      connects — the couch/TV output. Host-specific, since the name encodes the
      card's PCI address; find it with `pw-metadata -n default` or `wpctl status`.
      Null leaves the audio default alone.
    '';
  };

  config = {
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

    # Jump straight into Big Picture when the controller connects over Bluetooth.
    # The joystick node is uaccess-tagged for the logged-in user, so udev can hand
    # the event to their systemd instance rather than us shelling out as root.
    # Matches Microsoft (045e) devices on the Bluetooth bus (bustype 0005) only,
    # so wired pads and other gamepads don't trigger it.
    services.udev.extraRules = lib.mkIf config.programs.steam.enable ''
      ACTION=="add", SUBSYSTEM=="input", ENV{ID_INPUT_JOYSTICK}=="1", ATTRS{id/bustype}=="0005", ATTRS{id/vendor}=="045e", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="steam-bigpicture.service"
    '';

    home-manager.users.${username} = lib.mkIf config.programs.steam.enable {
      systemd.user.services.steam-bigpicture = {
        Unit = {
          Description = "Open Steam Big Picture when an Xbox controller connects";
          After = [
            "graphical-session.target"
            "pipewire.service"
          ];
        };
        Service = {
          Type = "oneshot";
          # The steam:// URL switches a running Steam into Big Picture, and starts
          # Steam first if it isn't running. Deliberately not ${pkgs.steam} —
          # programs.steam installs its own wrapped/overridden package.
          ExecStart = "/run/current-system/sw/bin/steam steam://open/bigpicture";
        }
        // lib.optionalAttrs (cfg.bigPictureSink != null) {
          # Point the default output at the TV before Steam comes up. This writes
          # the same metadata key pactl/wpctl do, so it lands as the user's
          # configured choice; WirePlumber applies it when the sink is present and
          # falls back to the next-best sink while it isn't. Leading `-` so a
          # missing sink or a not-yet-ready PipeWire can't block Big Picture.
          ExecStartPre = "-${pkgs.pipewire}/bin/pw-metadata -n default 0 default.configured.audio.sink '{ \"name\": \"${cfg.bigPictureSink}\" }'";
        };
      };
    };
  };
}
