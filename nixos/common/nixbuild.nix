{
  config,
  lib,
  ...
}:
let
  cfg = config.nixcfg.nixbuild;
in
{
  options = {
    nixcfg.nixbuild = {
      enable = lib.mkOption {
        default = true;
        description = ''
          Enable remote builds using nixbuild.net servers
        '';
        type = lib.types.bool;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    programs.ssh = {
      knownHosts = {
        nixbuild = {
          hostNames = [ "eu.nixbuild.net" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
        };
        s = {
          hostNames = [ "s" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM"; # TODO: fix this
        };
      };
    };
    nix = {
      distributedBuilds = true;
      buildMachines = [
        {
          hostName = "l";
          system = "x86_64-linux";
          maxJobs = 100;
          supportedFeatures = [
            "benchmark"
            "big-parallel"
          ];
        }
        {
          hostName = "s";
          system = "aarch64-linux";
          maxJobs = 100;
          supportedFeatures = [
            "benchmark"
            "big-parallel"
          ];
        }
        {
          hostName = "eu.nixbuild.net";
          system = "armv7l-linux";
          maxJobs = 100;
          supportedFeatures = [
            "benchmark"
            "big-parallel"
          ];
        }
        {
          hostName = "eu.nixbuild.net";
          system = "i686-linux";
          maxJobs = 100;
          supportedFeatures = [
            "benchmark"
            "big-parallel"
          ];
        }
      ];
      settings = {
        trusted-public-keys = [ "nixbuild.net/PM4CHU-1:RpxgxQ+tNPjQ+GAyUDJcESVTTxH64SG4sBNHakKQNbU=" ];
      };
    };
  };
}
