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
    ../../common/plasma.nix
    ../../common/xone.nix
    ./hardware-configuration.nix
    "${inputs.nixos-hardware}/common/gpu/nvidia/blackwell/default.nix"
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  # Enable common NixOS configuration settings
  nixcfg.enable = true;
  nixcfg.cachix = {
    enable = true;
    users = [ username ];
  };

  nixcfg.cinnamon.enable = false;
  nixcfg.cosmic.enable = true;
  nixcfg.plasma.enable = false;

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Force s2idle instead of S3 deep sleep — the NVIDIA 595.x driver fails to
  # reinitialize the RTX 5070 Ti on S3 resume (Xid 13 shader exceptions)
  boot.kernelParams = [ "mem_sleep_default=s2idle" ];

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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    isNormalUser = true;
    description = "Cole Fuerth";
    shell = pkgs.zsh;
    extraGroups = [
      "dialout"
      "docker"
      "libvirtd"
      "networkmanager"
      "video"
      "wheel"
    ];
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
        ristretto
        signal-desktop
        slack
        slurp
        spotify
        vlc
      ])
      ++ (with dotFilesPackages; [
        tw3mm
      ]);
    # ++ [
    #   # Wrapper for rpi-imager to run with sudo and proper Wayland support
    #   (pkgs.writeShellScriptBin "rpi-imager" ''
    #     exec sudo -E env \
    #       "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
    #       "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
    #       "QT_QPA_PLATFORM=wayland" \
    #       ${pkgs.rpi-imager}/bin/rpi-imager "$@"
    #   '')
    # ];
    initialHashedPassword = "$y$j9T$YcR7aNLjwHuI5yMbcA8UB.$UbVZuOsp9AsovPS8ApWj4flsMZJUBStWA3e1E8SSBo1";
  };

  nixpkgs.config.allowUnfree = lib.mkForce true;

  environment.systemPackages = with pkgs; [
    fastfetch
    gamescope
    nil
    nixfmt-tree
    pciutils
    powertop
    sbctl
    tpm2-tools
    (python313.withPackages (
      ps: with ps; [
        matplotlib
        numpy
        pandas
        pip
        pyserial
        scipy
        tqdm
      ]
    ))
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

  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = [ 5353 ];

  # initial system state when machine was created, used for backwards compatibility
  # DO NOT CHANGE AFTER THE INITIAL INSTALLATION
  system.stateVersion = "26.05";

  systemd.user.services.solaar = {
    description = "Solaar - Logitech Device Manager";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.solaar}/bin/solaar --window=hide";
      Restart = "on-failure";
    };
  };

  # Autostart noisetorch noise suppression on G733 headset mic.
  # Waits for the USB source to register with PipeWire — wireplumber creates
  # the node asynchronously after pipewire.service is active, and the USB
  # headset may enumerate even later.
  systemd.user.services.noisetorch =
    let
      source = "alsa_input.usb-Logitech_G733_Gaming_Headset_0000000000000000-00.mono-fallback";
      startScript = pkgs.writeShellScript "noisetorch-start" ''
        for _ in $(seq 1 60); do
          if ${pkgs.pulseaudio}/bin/pactl list sources short | ${pkgs.gnugrep}/bin/grep -q "${source}"; then
            exec /run/wrappers/bin/noisetorch -i -s "${source}"
          fi
          sleep 1
        done
        echo "noisetorch: source ${source} not found after 60s" >&2
        exit 1
      '';
    in
    {
      description = "NoiseTorch Noise Suppression";
      wantedBy = [ "graphical-session.target" ];
      after = [
        "pipewire.service"
        "wireplumber.service"
      ];
      requires = [ "pipewire.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${startScript}";
        ExecStop = "/run/wrappers/bin/noisetorch -u";
      };
    };

  # TV aux-in loopback: routes line-in (ALC1220) to default audio output
  # Not started by default — toggle with: systemctl --user start/stop tv-loopback
  systemd.user.services.tv-loopback = {
    description = "TV Aux-In Audio Loopback";
    after = [ "pipewire.service" ];
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.alsa-utils}/bin/amixer -c 1 set 'Line Boost' 0%"
        "${pkgs.alsa-utils}/bin/amixer -c 1 set 'Capture' 50%"
      ];
      ExecStart = "${pkgs.pipewire}/bin/pw-loopback --capture-props='node.target=alsa_input.pci-0000_2f_00.4.analog-stereo' --playback-props='node.target=alsa_output.usb-Logitech_G733_Gaming_Headset_0000000000000000-00.analog-stereo'";
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  hardware.nvidia = {
    open = true;
    powerManagement.enable = true;
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
    programs.ssh = {
      matchBlocks = {
        "s" = {
          user = "cole";
          hostname = "192.168.69.5";
          serverAliveInterval = 60;
        };
      };
    };
  };

  # services.wivrn = {
  #   enable = true;
  #   openFirewall = true;

  # Write information to /etc/xdg/openxr/1/active_runtime.json, VR applications
  # will automatically read this and work with WiVRn (Note: This does not currently
  # apply for games run in Valve's Proton)
  #   defaultRuntime = true;

  # Run WiVRn as a systemd service on startup
  #   autoStart = true;

  # If you're running this with an nVidia GPU and want to use GPU Encoding (and don't otherwise have CUDA enabled system wide), you need to override the cudaSupport variable.
  #   package = (pkgs.wivrn.override { cudaSupport = true; });

  # You should use the default configuration (which is no configuration), as that works the best out of the box.
  # However, if you need to configure something see https://github.com/WiVRn/WiVRn/blob/master/docs/configuration.md for configuration options and https://mynixos.com/nixpkgs/option/services.wivrn.config.json for an example configuration.
  # };

  # services.openssh.settings.PasswordAuthentication = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  virtualisation.libvirtd.enable = true;

  programs = {
    virt-manager.enable = true;
    steam = {
      enable = true;
      protontricks.enable = true;
      package = pkgs.steam.override {
        extraProfile = ''
          # Lower CPU and I/O priority so updates/transfers don't starve the system
          ${pkgs.util-linux}/bin/renice -n 0 $$ > /dev/null 2>&1
          ${pkgs.util-linux}/bin/ionice -c 3 -p $$ > /dev/null 2>&1
        '';
      };
    };
  };
}
