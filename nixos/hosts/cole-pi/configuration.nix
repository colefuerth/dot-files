{
  config,
  dotFilesPackages,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ../../common
    ../../common/bluetooth.nix
    ../../common/cachix.nix
    ../../common/cachix/heaviside-industries.nix
    ../../common/nixbuild.nix
    ./hardware-configuration.nix
    inputs.nixos-hardware-pi-5.nixosModules.raspberry-pi-5
  ];

  # Enable common NixOS configuration settings
  nixcfg.enable = true;
  nixcfg.cachix = {
    enable = true;
    users = [ username ];
  };

  nixcfg.nixbuild = {
    enable = false;
    disableThisSystem = false;
  };

  # Cross-compile from x86_64 instead of emulating aarch64 via QEMU
  nixpkgs.buildPlatform = "x86_64-linux";

  # Bootloader - Pi 5 uses its own firmware bootloader
  # The nixos-hardware-pi-5 module handles kernel and boot configuration
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    isNormalUser = true;
    description = "Cole Fuerth";
    shell = pkgs.zsh;
    extraGroups = [
      "dialout"
      "docker"
      "networkmanager"
      "video"
      "wheel"
    ];
    packages = with pkgs; [
      binsider
      codex
    ];
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
    avrdude
    claude-code
    libclang
    libgcc
    nil
    nixfmt-tree
    platformio
    (python312.withPackages (
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
    tio
  ];

  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = [ 5353 ];

  # initial system state when machine was created, used for backwards compatibility
  system.stateVersion = "26.05";

  powerManagement.enable = true;
  services.fwupd.enable = lib.mkForce false;

  # hardware.graphics = {
  #   enable = true;
  # };

  # Home-manager configuration for this machine
  home-manager.users.${username} = {
    programs.gh.enable = lib.mkForce false;
    programs.ssh = {
      matchBlocks = {
        "eu.nixbuild.net" = {
          hostname = "eu.nixbuild.net";
          # PubkeyAcceptedKeyTypes ssh-ed25519
          serverAliveInterval = 60;
          # IPQoS throughput
          identityFile = "/home/cole/.ssh/nixbuild/heaviside-shared";
        };
        "t" = {
          user = "heaviside_ai";
          hostname = "10.100.20.38";
          identityFile = "/home/cole/.ssh/id_ed25519";
        };
        "mothpi" = {
          user = "moth";
          hostname = "moth.local";
          identityFile = "/home/cole/.ssh/id_rsa";
          forwardX11 = true;
          forwardX11Trusted = true;
        };
        "bms_test" = {
          user = "heaviside";
          hostname = "moth-production-tester.local";
          identityFile = "/home/cole/.ssh/id_rsa";
        };
        "pi" = {
          user = "cole";
          hostname = "colepi.local";
          serverAliveInterval = 60;
          identityFile = "/home/cole/.ssh/id_rsa";
          forwardX11 = true;
          forwardX11Trusted = true;
        };
        "s" = {
          user = "cole";
          # hostname = "heaviside-thelio-server.local";
          hostname = "10.100.20.28";
          serverAliveInterval = 60;
        };
      };
    };
  };

  services.envfs.enable = false;

  programs = {
  };
}
