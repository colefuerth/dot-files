{
  config,
  dotFilesPackages,
  host,
  lib,
  pkgs,
  username,
  inputs,
  ...
}:
let
  wallpaperIds = import ../../common/wallpaper-engine-ids.nix { };

  # Switch the onboard ALC1220 to a duplex profile and select the line-in
  # port before starting the loopback. Without this, the analog input source
  # doesn't exist and pw-loopback silently falls back to the default source
  # (the G733 mic), so `tv on` ends up looping the headset mic instead.
  tvLoopbackPrepare = pkgs.writeShellApplication {
    name = "tv-loopback-prepare";
    runtimeInputs = with pkgs; [
      alsa-utils
      pipewire
      python3
      wireplumber
    ];
    text = ''
      export DEVICE_NAME="alsa_card.pci-0000_2f_00.4"
      export PROFILE_NAME="output:analog-surround-51+input:analog-stereo"
      export ROUTE_NAME="analog-input-linein"
      SOURCE_NAME="alsa_input.pci-0000_2f_00.4.analog-stereo"

      mapfile -t result < <(pw-dump | python3 -c '
      import json, os, sys
      data = json.load(sys.stdin)
      target_dev = os.environ["DEVICE_NAME"]
      target_profile = os.environ["PROFILE_NAME"]
      target_route = os.environ["ROUTE_NAME"]
      dev_id = ""
      profile_idx = ""
      route_idx = ""
      for obj in data:
          info = obj.get("info") or {}
          props = info.get("props") or {}
          if props.get("device.name") != target_dev:
              continue
          dev_id = obj["id"]
          params = info.get("params") or {}
          for p in params.get("EnumProfile", []):
              if p.get("name") == target_profile:
                  profile_idx = p.get("index")
                  break
          for r in params.get("EnumRoute", []):
              if r.get("name") == target_route:
                  route_idx = r.get("index")
                  break
          break
      print(dev_id)
      print(profile_idx)
      print(route_idx)
      ')

      DEV_ID="''${result[0]:-}"
      PROFILE_IDX="''${result[1]:-}"
      ROUTE_IDX="''${result[2]:-}"

      if [[ -z "$DEV_ID" || -z "$PROFILE_IDX" ]]; then
          echo "tv-loopback: could not locate device $DEVICE_NAME or profile $PROFILE_NAME" >&2
          exit 1
      fi

      wpctl set-profile "$DEV_ID" "$PROFILE_IDX"

      for _ in $(seq 1 30); do
          if pw-cli ls Node 2>/dev/null | grep -q "node.name = \"$SOURCE_NAME\""; then
              break
          fi
          sleep 0.1
      done

      if [[ -n "$ROUTE_IDX" ]]; then
          pw-cli set-param "$DEV_ID" Route "{ index: $ROUTE_IDX, direction: Input, save: true }" >/dev/null || true
      fi

      amixer -c 1 set 'Line Boost' 0% >/dev/null 2>&1 || true
      amixer -c 1 set 'Capture' 50% >/dev/null 2>&1 || true
    '';
  };

  # Pin WiVRn to the upstream v26.6.1 release rather than the nixpkgs version.
  # Reuses the nixpkgs build recipe but repoints src + monado to the tag and
  # adds the build inputs current WiVRn needs (mirrors the extras the upstream
  # flake carries: https://github.com/WiVRn/WiVRn/blob/master/flake.nix). The
  # monado rev must match the tag's monado-rev file or the recipe's postUnpack
  # check fails; GIT_DESC is derived from `version`, so bumping it is enough.
  wivrnLatest = pkgs.wivrn.overrideAttrs (
    finalAttrs: oldAttrs: {
      version = "26.6.1";
      src = pkgs.fetchFromGitHub {
        owner = "wivrn";
        repo = "wivrn";
        rev = "v${finalAttrs.version}";
        hash = "sha256-eXU7hYLYchAb6AbCyINfTmOp0NdxK35Kg9tcid2ucg4=";
      };
      monado = pkgs.applyPatches {
        src = pkgs.fetchFromGitLab {
          domain = "gitlab.freedesktop.org";
          owner = "monado";
          repo = "monado";
          rev = "1b526bb3a0ff326ecd05af4c2c541407f53c6d4b";
          hash = "sha256-SzuCQ1uX15vFGwGt3gswlVF2Su8sIND4R3tsTJ4T1LY=";
        };
        postPatch = ''
          ${finalAttrs.src}/patches/apply.sh ${finalAttrs.src}/patches/monado/*
        '';
      };
      buildInputs =
        oldAttrs.buildInputs
        ++ (with pkgs; [
          sdl2-compat
          libpng
          kdePackages.kirigami-addons
          curl
          ktx-tools
        ]);
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ pkgs.util-linux ];
      # 26.6.x's CMake insists on GIT_COMMIT, which the older nixpkgs recipe
      # doesn't pass; there's no .git in the fetched source to infer it from.
      cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
        (lib.cmakeFeature "GIT_COMMIT" "31dbc36f9a23c179d22b609fc51a9513f45e8bda")
      ];
    }
  );
in
{
  imports = [
    ../../common
    ../../common/audio.nix
    ../../common/bluetooth.nix
    ../../common/cachix.nix
    ../../common/cinnamon.nix
    ../../common/cosmic.nix
    ../../common/graphical.nix
    ../../common/llama-server.nix
    ../../common/odysseus.nix
    ../../common/plasma.nix
    ../../common/solaar.nix
    ../../common/tailscale.nix
    ../../common/user.nix
    ../../common/xone.nix
    ./hardware-configuration.nix
    "${inputs.nixos-hardware}/common/gpu/nvidia/blackwell/default.nix"
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  # Sign every store path added on this host so other machines (e.g. cole-darwin
  # pulling closures via `nomt`) can trust them by adding the matching public
  # key to trusted-public-keys. Generate the keypair once with:
  #   sudo nix-store --generate-binary-cache-key cole-desktop-1 \
  #     /var/lib/nix-signing-key.sec /var/lib/nix-signing-key.pub
  nix.settings.secret-key-files = "/var/lib/nix-signing-key.sec";

  nixcfg.cinnamon.enable = false;
  nixcfg.cosmic.enable = false;
  nixcfg.plasma.enable = true;

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Force s2idle instead of S3 deep sleep — the NVIDIA 595.x driver fails to
  # reinitialize the RTX 5070 Ti on S3 resume (Xid 13 shader exceptions)
  boot.kernelParams = [ "mem_sleep_default=s2idle" ];

  # NT synchronization primitives driver — lets Proton/Wine use real Windows
  # sync semantics instead of the fsync/esync userland fallbacks.
  boot.kernelModules = [ "ntsync" ];

  # Bootloader — lanzaboote (signed stub) replaces systemd-boot for Secure Boot.
  # Keep systemd-boot disabled via mkForce so nothing re-enables it.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # Needed for TPM2-based LUKS unlock via crypttab options.
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = [ "tpm2-device=auto" ];

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  # Base account (shell/groups/password) comes from common/user.nix; this host
  # adds libvirtd group membership and its own package set.
  users.users.${username} = {
    extraGroups = [ "libvirtd" ];
    packages =
      (with pkgs; [
        act
        binsider
        brave
        claude-code
        discord
        flameshot
        ghostty
        git-lfs
        google-chrome
        grim
        kdePackages.okular
        libreoffice
        micro
        opencode
        r2modman
        ristretto
        signal-desktop
        simple-scan
        slack
        slurp
        spotify
        vlc
      ])
      ++ (with dotFilesPackages; [
        tw3mm
      ]);
  };

  nixpkgs.config.cudaSupport = true;

  environment.systemPackages = with pkgs; [
    android-tools
    fastfetch
    gamescope
    hplipWithPlugin
    mangohud
    nil
    nixfmt-tree
    pciutils
    powertop
    sbctl
    tpm2-tools
    (python313.withPackages dotFilesPackages.pyPackages)
    smartmontools
    solaar
    tio
    wineWow64Packages.staging
    winetricks
    wineWow64Packages.waylandFull
    tumbler
  ];

  fileSystems = {
    "/mnt/balls" = {
      device = "/dev/disk/by-uuid/0e8cb026-25ce-4d4c-a2f7-5b936d89b607";
      fsType = "ext4";
    };
    "/mnt/big-boy" = {
      device = "/dev/disk/by-uuid/67de21fa-0e49-4dfd-ae68-81acb80a3b6d";
      fsType = "ext4";
    };
    "/mnt/hdd" = {
      device = "/dev/disk/by-uuid/82b3fa85-c97f-41e5-9520-a0b681bc8671";
      fsType = "ext4";
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];

  # initial system state when machine was created, used for backwards compatibility
  # DO NOT CHANGE AFTER THE INITIAL INSTALLATION
  system.stateVersion = "26.05";

  # RNNoise denoising for the G733 mic via a native PipeWire filter-chain.
  # Replaces NoiseTorch — pipewire-pulse does not implement module-ladspa-source,
  # so noisetorch's PA-emulated module load fails with "No such entity". The
  # filter-chain creates a virtual source "rnnoise_source" that auto-links to
  # the G733 when present, with priority.session=2000 so wireplumber promotes
  # it to the default input.
  services.pipewire.extraLadspaPackages = [ pkgs.rnnoise-plugin ];
  services.pipewire.extraConfig.pipewire."99-rnnoise-g733" = {
    "context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "G733 (RNNoise)";
          "media.name" = "G733 (RNNoise)";
          "filter.graph" = {
            nodes = [
              {
                type = "ladspa";
                name = "rnnoise";
                plugin = "librnnoise_ladspa";
                label = "noise_suppressor_mono";
                control = {
                  "VAD Threshold (%)" = 50.0;
                };
              }
            ];
          };
          "capture.props" = {
            "node.name" = "capture.rnnoise_g733";
            "node.passive" = true;
            "audio.rate" = 48000;
            "target.object" = "alsa_input.usb-Logitech_G733_Gaming_Headset_0000000000000000-00.mono-fallback";
          };
          "playback.props" = {
            "node.name" = "rnnoise_source";
            "node.description" = "G733 Noise-Suppressed Microphone";
            "media.class" = "Audio/Source";
            "audio.rate" = 48000;
            "priority.session" = 2000;
            "priority.driver" = 2000;
          };
        };
      }
    ];
  };

  # TV aux-in loopback: routes line-in (ALC1220) to G733 headset.
  # Not started by default — toggle with: systemctl --user start/stop tv-loopback
  systemd.user.services.tv-loopback = {
    description = "TV Aux-In Audio Loopback";
    after = [ "pipewire.service" ];
    serviceConfig = {
      ExecStartPre = "${tvLoopbackPrepare}/bin/tv-loopback-prepare";
      ExecStart = "${pkgs.pipewire}/bin/pw-loopback --capture-props='target.object=alsa_input.pci-0000_2f_00.4.analog-stereo' --playback-props='target.object=alsa_output.usb-Logitech_G733_Gaming_Headset_0000000000000000-00.analog-stereo'";
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  hardware.nvidia = {
    open = true;
    powerManagement.enable = true;
  };
  hardware.nvidia-container-toolkit.enable = true; # restored — keeps container CDI GPU working

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda; # replaces the deprecated `acceleration = "cuda"`
    host = "0.0.0.0"; # reachable from the Odysseus container via host.docker.internal
  };

  # Let Docker containers reach host services (Ollama on 172.17.0.1:11434).
  # The firewall default-denies, and compose stacks land on dynamically-named
  # br-* bridges, so trust the default bridge plus the br-* wildcard.
  networking.firewall.trustedInterfaces = [
    "docker0"
    "br-+"
  ];

  services.odysseus.enable = true;

  # Reliable GPU GGUF serving, declaratively — the Odysseus Cookbook's own tmux
  # "Launch" path never actually starts llama-server in this native systemd
  # setup, so serve the model directly and register http://127.0.0.1:8000/v1 as
  # an OpenAI endpoint in Odysseus (Settings), like the Ollama endpoint.
  # Runs as the odysseus user so it can read GGUFs the Cookbook downloaded under
  # /var/lib/odysseus. Verify the exact snapshot path after a Cookbook download:
  #   sudo find /var/lib/odysseus -iname '*.gguf'
  services.llama-server = {
    enable = true;
    user = "odysseus";
    group = "odysseus";
    models.deepseek-coder-v2-lite = {
      model = "/var/lib/odysseus/.cache/huggingface/hub/models--bartowski--DeepSeek-Coder-V2-Lite-Instruct-GGUF/snapshots/8f248fa2072348f77a8bc37754e470de1f61866e/DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf";
      port = 8000;
      contextSize = 8192;
    };
  };

  # Allow non-root users to read CPU power consumption (RAPL energy counters)
  systemd.services.powercap-permissions = {
    description = "Make RAPL energy counters readable without root";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = toString (
        pkgs.writeShellScript "powercap-perms" ''
          chmod a+r /sys/devices/virtual/powercap/intel-rapl/*/energy_uj \
                    /sys/devices/virtual/powercap/intel-rapl/*/*/energy_uj \
                    2>/dev/null || true
        ''
      );
    };
  };

  # Home-manager configuration for this machine
  home-manager.users.${username} = {
    home.stateVersion = "26.05";
    services.linux-wallpaperengine = {
      # https://github.com/nix-community/home-manager/blob/master/modules/services/linux-wallpaperengine.nix
      enable = true;
      assetsPath = "/home/cole/.local/share/Steam/steamapps/common/wallpaper_engine/assets";
      wallpapers = [
        {
          # ultrawide
          monitor = "DP-1"; # Your laptop's internal display
          wallpaperId = wallpaperIds.hyper-cube-oled;
          scaling = "default"; # "stretch", "fit", "fill", or "default"
          fps = 24;
          audio.silent = false; # only use this flag once for all monitors
          extraOptions = [
            #   "--set-property spacemode=1"
            "--set-property backgroundcolor=0.0,0.0,0.0"
          ];
        }
        {
          monitor = "HDMI-A-1";
          wallpaperId = wallpaperIds.frieren-cold;
        }
      ];
    };
    systemd.user.services.linux-wallpaperengine = {
      Service = {
        Restart = lib.mkForce "always";
        RestartSec = "3s";
        Environment = [
          "LIBVA_DRIVER_NAME=nvidia"
          "LIBVA_DRIVERS_PATH=${pkgs.nvidia-vaapi-driver}/lib/dri"
        ];
      };
    };
    home.file.".config/ghostty/config".text = ''
      font-family = "Consolas Nerd Font Mono"
      theme = "Atom One Dark"
      window-decoration = false
      gtk-titlebar = false
      keybind = ctrl+shift+enter=toggle_fullscreen
    '';
  };

  services.wivrn = {
    enable = true;
    openFirewall = true;
    package = wivrnLatest;

    # Steam/Proton games run inside the pressure-vessel sandbox, which doesn't
    # import the host's OpenXR runtime — so games can't find WiVRn even though
    # the headset connects fine. This sets PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES
    # system-wide so Steam discovers WiVRn. Requires a logout/login to take effect.
    steam.importOXRRuntimes = true;

    # Run WiVRn as a systemd service on startup
    autoStart = true;

    # If you're running this with an nVidia GPU and want to use GPU Encoding (and don't otherwise have CUDA enabled system wide), you need to override the cudaSupport variable.
    # package = (pkgs.wivrn.override { cudaSupport = true; }); # unnecessary when nixpkgs.config.cudaSupport is true

    # You should use the default configuration (which is no configuration), as that works the best out of the box.
    # However, if you need to configure something see https://github.com/WiVRn/WiVRn/blob/master/docs/configuration.md for configuration options and https://mynixos.com/nixpkgs/option/services.wivrn.config.json for an example configuration.
  };

  # TEMPORARY (trip): keep the desktop awake so I can SSH in over Tailscale
  # while I'm away. Remove this block when I'm back home.
  services.logind.lidSwitch = "ignore";
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  systemd.services.tailscale-autoconnect = {
    description = "Bring Tailscale up at boot";
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      status="$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r .BackendState)"
      if [ "$status" = "Running" ]; then
        exit 0
      fi
      ${pkgs.tailscale}/bin/tailscale up
    '';
  };

  # Declarative NM profile for the "stinky" wifi, pinned to a static IP.
  # PSK is substituted from /etc/nm-secrets.env at activation time so the
  # password never lands in the world-readable Nix store. Create it once:
  #   sudo install -m600 /dev/stdin /etc/nm-secrets.env <<<'PSK=<password>'
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ "/etc/nm-secrets.env" ];
    profiles.stinky = {
      connection = {
        id = "stinky";
        type = "wifi";
        interface-name = "wlp41s0";
        autoconnect = true;
      };
      wifi = {
        ssid = "stinky";
        mode = "infrastructure";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "$PSK";
      };
      ipv4 = {
        method = "manual";
        address1 = "192.168.69.4/24,192.168.69.1";
        dns = "192.168.69.1;";
      };
      ipv6.method = "auto";
    };
  };

  virtualisation.libvirtd.enable = true;

  programs = {
    firefox.enable = false;
    steam = {
      enable = true;
      protontricks.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      package = pkgs.steam.override {
        # ${pkgs.util-linux}/bin/renice -n 0 $$ > /dev/null 2>&1
        extraProfile = ''
          ${pkgs.util-linux}/bin/ionice -c 3 -p $$ > /dev/null 2>&1
          export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
        '';
      };
    };
    # Wraps games in an isolated micro-compositor so they see one virtual
    # display at a chosen resolution. Workaround for engines that crash on
    # multi-monitor / ultrawide / Wayland setups.
    # capSysNice is intentionally off — when set, gamescope tries to inherit
    # cap_sys_nice into children, but Steam's pressure-vessel bwrap sandbox
    # drops the cap, and gamescope bails with "failed to inherit capabilities".
    gamescope.enable = true;
    virt-manager.enable = true;
  };

  nixpkgs.overlays = [
    (
      final: prev:
      let
        src = prev.fetchFromGitHub {
          owner = "thefossguy";
          repo = "nixpkgs";
          rev = "e872b0d136394b0e8cf560d08a2a894f74a8e05a";
          hash = "sha256-nwtoV0C028BZLtS0hPlZjUybPb3kuRCFjLu6HyKZmwlp41s0hI=";
        };

        byName = name: "${src}/pkgs/by-name/${builtins.substring 0 2 name}/${name}/package.nix";

        pkgNames = [
          "cosmic-applets"
          "cosmic-applibrary"
          "cosmic-bg"
          "cosmic-comp"
          "cosmic-edit"
          "cosmic-files"
          "cosmic-greeter"
          "cosmic-icons"
          "cosmic-idle"
          "cosmic-initial-setup"
          "cosmic-launcher"
          "cosmic-notifications"
          "cosmic-osd"
          "cosmic-panel"
          "cosmic-player"
          "cosmic-randr"
          "cosmic-screenshot"
          "cosmic-session"
          "cosmic-settings"
          "cosmic-settings-daemon"
          "cosmic-store"
          "cosmic-term"
          "cosmic-wallpapers"
          "cosmic-workspaces-epoch"
          "xdg-desktop-portal-cosmic"
        ];
      in
      prev.lib.genAttrs pkgNames (
        name:
        (final.callPackage (byName name) { }).overrideAttrs (_: {
          doCheck = false;
        })
      )
    )
  ];
}
