# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{
  config,
  host,
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
    (fetchTarball {
      url = "https://github.com/nix-community/nixos-vscode-server/tarball/master";
      sha256 = "sha256:1rdn70jrg5mxmkkrpy2xk8lydmlc707sk0zb35426v1yxxka10by";
    })
  ];

  wsl.enable = true;
  wsl.defaultUser = username;

  nixcfg.enable = true;
  nixcfg.cachix = {
    enable = true;
    users = [ username ];
  };

  boot.kernelPackages = pkgs.linuxPackages;

  networking.hostName = host;

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.vscode-server.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      # TODO: dialout and docker may be security risks
      "dialout"
      "docker"
      "networkmanager"
      "video"
      "wheel"
    ];
    packages = with pkgs; [
      # userspace packages I want to install for all users
    ];
    shell = pkgs.zsh;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    cachix
    neofetch
    vscode-with-extensions
  ];

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

  programs = {
    nix-ld = {
      # required for vscode-server to run as a service
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        openssl
        curl
        git
        nodejs_20
        python3
      ];
    };
    vim = {
      enable = true;
      defaultEditor = false;
    };
    zsh = {
      enable = true;
    };
  };

  system.stateVersion = "25.11"; # Did you read the comment?
}
