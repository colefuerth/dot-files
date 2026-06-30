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
    ../../common/nixbuild.nix
    ../../common/ssh.nix
    ../../common/user.nix
    ./hardware-configuration.nix
    inputs.nixos-hardware-pi-5.nixosModules.raspberry-pi-5
  ];

  nixcfg.nixbuild.enable = false;

  # Cross-compile from x86_64 instead of emulating aarch64 via QEMU
  nixpkgs.buildPlatform = "x86_64-linux";

  # Bootloader - Pi 5 uses its own firmware bootloader
  # The nixos-hardware-pi-5 module handles kernel and boot configuration
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = true;

  users.users.${username}.packages = with pkgs; [
    binsider
    codex
  ];

  environment.systemPackages = with pkgs; [
    avrdude
    claude-code
    libclang
    libgcc
    nil
    nixfmt-tree
    platformio
    (python312.withPackages dotFilesPackages.pyPackages)
    tio
  ];

  # initial system state when machine was created, used for backwards compatibility
  system.stateVersion = "26.05";

  powerManagement.enable = true;
  services.fwupd.enable = lib.mkForce false;

  # Home-manager configuration for this machine
  home-manager.users.${username} = {
    programs.gh.enable = lib.mkForce false;
  };

  services.envfs.enable = false;
}
