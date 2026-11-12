# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ../../common
    ../../common/cachix.nix
    ../../common/user.nix
    inputs.vscode-server.nixosModules.default
  ];

  wsl.enable = true;
  wsl.defaultUser = username;

  boot.kernelPackages = pkgs.linuxPackages;

  networking.wireless.enable = lib.mkForce false;

  services.vscode-server.enable = true;

  environment.systemPackages = with pkgs; [
    cachix
    claude-code
    fastfetch
    vscode-with-extensions
  ];

  system.stateVersion = "25.11"; # Did you read the comment?
}
