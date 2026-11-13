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
    ../../common/user.nix
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-5
  ];

  # Cross-compile from x86_64 instead of emulating aarch64 via QEMU
  nixpkgs.buildPlatform = "x86_64-linux";

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
