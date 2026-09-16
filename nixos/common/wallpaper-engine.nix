{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.nixcfg.wallpaperEngine;

  wallpaperOptions = lib.types.submodule {
    options = {
      wallpaperId = lib.mkOption {
        type = lib.types.str;
        description = "Steam Workshop id, or a path to the background folder.";
        example = "3437148262";
      };
      scaling = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "stretch"
            "fit"
            "fill"
            "default"
          ]
        );
        default = null;
        description = "Scaling mode for this screen. Null leaves the default alone.";
      };
      extraOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments applied to this screen, one list entry per argv item.";
        example = [
          "--set-property"
          "backgroundcolor=0.0,0.0,0.0"
        ];
      };
    };
  };

  # Give every entry the same shape so the launcher can stay dumb about defaults.
  normalizeWallpaper =
    wallpaper:
    if wallpaper == null then
      null
    else
      {
        inherit (wallpaper) wallpaperId scaling extraOptions;
      };

  wallpaperSettings = builtins.toJSON {
    exe = lib.getExe pkgs.linux-wallpaperengine;
    inherit (cfg) assetsPath fps silent;
    connectors = lib.mapAttrs (lib.const normalizeWallpaper) cfg.connectors;
    monitors = lib.mapAttrs (lib.const normalizeWallpaper) cfg.monitors;
    default = normalizeWallpaper cfg.defaultWallpaper;
  };

  wallpaperLauncher =
    pkgs.writers.writePython3Bin "wallpaper-engine-launch" { flakeIgnore = [ "E501" ]; }
      ''
        """Start linux-wallpaperengine against the monitors that are actually here."""
        import glob
        import json
        import os
        import sys

        SETTINGS = json.loads(r"""${wallpaperSettings}""")


        def edid_identity(path):
            """Vendor id plus model name from a connector's EDID, e.g. "TCL Beyond TV"."""
            try:
                with open(path, "rb") as handle:
                    raw = handle.read()
            except OSError:
                return None
            if len(raw) < 128:
                return None
            # Bytes 8-9 pack three 5-bit letters, big endian, 'A' at 1.
            packed = int.from_bytes(raw[8:10], "big")
            vendor = "".join(chr(((packed >> shift) & 0x1F) + 64) for shift in (10, 5, 0))
            # The model name lives in whichever 18-byte descriptor is tagged 0xFC.
            model = None
            for offset in range(0x36, 0x7E, 18):
                descriptor = raw[offset:offset + 18]
                if descriptor[0:3] == b"\x00\x00\x00" and descriptor[3] == 0xFC:
                    model = descriptor[5:18].split(b"\n")[0].decode("ascii", "ignore").strip()
                    break
            if not model:
                # Panels with no name descriptor still have a unique product code.
                model = "%04X" % int.from_bytes(raw[10:12], "little")
            return (vendor + " " + model).strip()


        def connected_screens():
            """Connected connectors as (name, identity), one entry per connector name."""
            screens = {}
            for status_path in sorted(glob.glob("/sys/class/drm/card*-*/status")):
                node = os.path.dirname(status_path)
                with open(status_path) as handle:
                    if handle.read().strip() != "connected":
                        continue
                # card1-HDMI-A-1 -> HDMI-A-1
                name = os.path.basename(node).split("-", 1)[1]
                screens.setdefault(name, edid_identity(os.path.join(node, "edid")))
            return sorted(screens.items())


        def wallpaper_for(name, identity):
            """A connector pin beats EDID identity, which beats the global default."""
            if name in SETTINGS["connectors"]:
                return SETTINGS["connectors"][name]
            if identity is not None and identity in SETTINGS["monitors"]:
                return SETTINGS["monitors"][identity]
            return SETTINGS["default"]


        def main():
            screens = connected_screens()
            if "--list" in sys.argv[1:]:
                sharing = {}
                for name, identity in screens:
                    sharing.setdefault(identity, []).append(name)
                for name, identity in screens:
                    others = [n for n in sharing.get(identity, []) if n != name]
                    note = ""
                    if identity is not None and others:
                        note = "  <-- same identity as " + ", ".join(others) + ", pin by connector"
                    print(name, "->", identity, note)
                return 0

            argv = [
                SETTINGS["exe"],
                # linux-wallpaperengine hands its whole argv to CEF, which picks its
                # own Ozone backend and defaults to X11. That works only because
                # XWayland happens to be up; with no DISPLAY, CEF aborts outright
                # rather than falling back. Pin it to Wayland so it never depends on
                # XWayland being present.
                "--ozone-platform=wayland",
                "--assets-dir", SETTINGS["assetsPath"],
                "--fps", str(SETTINGS["fps"]),
            ]
            if SETTINGS["silent"]:
                argv.append("--silent")

            painted = 0
            for name, identity in screens:
                wallpaper = wallpaper_for(name, identity)
                if wallpaper is None:
                    continue
                argv += ["--screen-root", name]
                if wallpaper["scaling"]:
                    argv += ["--scaling", wallpaper["scaling"]]
                argv += wallpaper["extraOptions"]
                argv += ["--bg", wallpaper["wallpaperId"]]
                painted += 1

            if not painted:
                # Nothing to draw on. Exit 0 so Restart=on-failure leaves us alone
                # until the DRM hotplug rule starts us again.
                print("no connected monitor wants a wallpaper, nothing to do")
                return 0

            os.execv(argv[0], argv)


        if __name__ == "__main__":
            sys.exit(main())
      '';

  # Monitors come and go, so re-resolve the wallpaper set whenever the kernel
  # reports a DRM hotplug instead of leaving the service pinned to whatever
  # happened to be connected at login. Restarting the timer rather than the
  # service is what debounces a burst of events into a single reload.
  hotplugRules = ''
    ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="${pkgs.systemd}/bin/systemctl --user --machine=${username}@.host --no-block restart linux-wallpaperengine-reload.timer"
  '';

  # Laptops only: stop the wallpaper on battery and bring it back on AC.
  acRules = ''
    # ATTR{type}=="Mains" ensures only the AC adapter triggers these rules,
    # not USB-C power supply devices which enumerate with online=0 at boot.
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl --user --machine=${username}@.host stop linux-wallpaperengine.service"
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl --user --machine=${username}@.host reset-failed linux-wallpaperengine.service"
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl --user --machine=${username}@.host start linux-wallpaperengine.service"
  '';
in
{
  options.nixcfg.wallpaperEngine = {
    enable = lib.mkEnableOption "linux-wallpaperengine with runtime monitor detection";

    acGated = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Only run on AC power: adds ConditionACPower, udev rules that stop the
        service on battery and start it on mains, and a timer that periodically
        recovers it. Wanted on laptops, pointless on a desktop.
      '';
    };

    assetsPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/${username}/.local/share/Steam/steamapps/common/wallpaper_engine/assets";
      description = "Steam Wallpaper Engine assets path.";
    };

    fps = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "Frame rate cap. Applies to every screen -- the flag is global.";
    };

    silent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Mute wallpaper audio. Applies to every screen -- the flag is global.";
    };

    monitors = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr wallpaperOptions);
      default = { };
      description = ''
        Wallpapers keyed on EDID identity ("<vendor id> <model name>"), so a
        display keeps its wallpaper whichever port it lands on. Run
        `wallpaper-engine-launch --list` to print what is connected.
      '';
      example = lib.literalExpression ''
        { "TCL Beyond TV" = { wallpaperId = "3168641857"; }; }
      '';
    };

    connectors = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr wallpaperOptions);
      default = { };
      description = ''
        Wallpapers pinned to a DRM connector, checked before `monitors`. Needed
        for panels with no useful EDID, and for two displays that report the
        same EDID (which `--list` flags).
      '';
      example = lib.literalExpression ''
        { "eDP-1" = { wallpaperId = "2472509205"; scaling = "fill"; }; }
      '';
    };

    defaultWallpaper = lib.mkOption {
      type = lib.types.nullOr wallpaperOptions;
      default = null;
      description = "Applied to any connected monitor matched by neither map. Null leaves it bare.";
    };

    serviceEnvironment = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra Environment= entries for the service (e.g. a VAAPI driver).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.extraRules = hotplugRules + lib.optionalString cfg.acGated acRules;

    home-manager.users.${username} = {
      home.packages = [
        pkgs.linux-wallpaperengine
        wallpaperLauncher
      ];

      systemd.user.services = {
        # linux-wallpaperengine takes a fixed screen list on its command line and
        # exits 1 if any of those screens is missing, so a static list plus
        # Restart= turns an unplugged monitor into a permanent crash loop --
        # which also leaks a ~4MB CEF profile per restart. wallpaperLauncher
        # resolves the screens at start time instead.
        linux-wallpaperengine = {
          Unit = {
            Description = "Implementation of Wallpaper Engine on Linux";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
            # A real crash (compositor restart, GPU reset) still gets retried,
            # but gives up instead of restarting forever.
            StartLimitIntervalSec = 60;
            StartLimitBurst = 5;
          }
          // lib.optionalAttrs cfg.acGated { ConditionACPower = true; };
          Service = {
            ExecStart = lib.getExe wallpaperLauncher;
            Restart = "on-failure";
            RestartSec = "5s";
            # CEF frequently ignores SIGTERM on shutdown, so systemd sits through
            # the full 90s default before SIGKILL -- and the desktop has no
            # wallpaper for that whole stretch after every hotplug. Nothing here
            # has state worth saving, so cut the wait short.
            TimeoutStopSec = "5s";
            # CEF creates a ~4MB profile dir under $TMPDIR on every launch and
            # never cleans it up. Point that at a RuntimeDirectory so systemd
            # wipes it on every stop rather than letting it pile up in /tmp.
            # Keep the path short: CEF puts its process-singleton AF_UNIX socket
            # under $TMPDIR, and blowing past sun_path's 107 bytes aborts the
            # browser on startup.
            RuntimeDirectory = "linux-wallpaperengine";
            Environment = cfg.serviceEnvironment ++ [ "TMPDIR=%t/linux-wallpaperengine" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        linux-wallpaperengine-reload = {
          Unit.Description = "Re-resolve wallpapers for the current set of displays";
          Service = {
            Type = "oneshot";
            # Leading "-": a unit that never failed makes this exit non-zero.
            ExecStart = "-${pkgs.systemd}/bin/systemctl --user reset-failed linux-wallpaperengine.service";
            ExecStartPost = "${pkgs.systemd}/bin/systemctl --user --no-block restart linux-wallpaperengine.service";
          };
        };
      }
      // lib.optionalAttrs cfg.acGated {
        linux-wallpaperengine-watchdog = {
          Unit = {
            Description = "Recover linux-wallpaperengine if failed on AC power";
            ConditionACPower = true;
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl --user reset-failed linux-wallpaperengine.service 2>/dev/null; ${pkgs.systemd}/bin/systemctl --user start linux-wallpaperengine.service'";
          };
        };
      };

      systemd.user.timers = {
        # A single replug emits several DRM change events, and restarting on each
        # one both black-flashes the desktop and races the kernel: a launcher
        # that runs before the connectors settle sees a half-built screen list.
        # So udev pokes this timer rather than the service, and every further
        # event re-arms it -- the reload happens once, OnActiveSec after the last
        # event in the burst.
        linux-wallpaperengine-reload = {
          Unit.Description = "Debounce display hotplugs before reloading wallpapers";
          Timer = {
            OnActiveSec = "4s";
            AccuracySec = "1s";
            RemainAfterElapse = false;
          };
        };
      }
      // lib.optionalAttrs cfg.acGated {
        linux-wallpaperengine-watchdog = {
          Unit.Description = "Periodically recover linux-wallpaperengine";
          Timer = {
            OnBootSec = "30s";
            OnUnitActiveSec = "5min";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    };
  };
}
