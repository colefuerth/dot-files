{
  config,
  # inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcfg.nixbuild;
in
# # TODO: placeholder for: config.sops.secrets.nixbuild-token
# # not sure how to do this, because the token needs to be in plaintext
# # using an SSH key for now
# nixbuild-authtoken = ""
# ;
# config = ''
#   # Use the authtoken for builds and store read/write(s)
#   Host eu.nixbuild.net
#     User authtoken
#     PreferredAuthentications none
#     SetEnv token=${nixbuild-authtoken}
#     ServerAliveInterval 60
#     IPQoS throughput
# '';
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

      disableThisSystem = lib.mkOption {
        default = false;
        description = ''
          Disable remote builds for this system's type
        '';
        type = lib.types.bool;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    # sops.secrets.nixbuild-token = {
    #   format = "yaml";
    #   sopsFile = ../../configs/secrets/nixbuild.yaml;
    #   key = "token";
    # };
    programs.ssh = {
      extraConfig = ''
        # Use the shared key for builds and store read/write(s)
        Host eu.nixbuild.net
          PubkeyAcceptedKeyTypes ssh-ed25519
          ServerAliveInterval 60
          IPQoS throughput
          IdentityFile /data/awatwe/.ssh/nixbuild/heaviside-shared
        # Keep an admin SSH config
        Host nixbuild-admin
          Hostname eu.nixbuild.net
          PubkeyAcceptedKeyTypes ssh-ed25519
          ServerAliveInterval 60
          IPQoS throughput
          IdentityFile /data/awatwe/.ssh/nixbuild/heaviside-admin
      '';
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
      buildMachines =
        lib.optionals (pkgs.system != "x86_64-linux" || !cfg.disableThisSystem) [
          {
            hostName = "l";
            system = "x86_64-linux";
            maxJobs = 100;
            supportedFeatures = [
              "benchmark"
              "big-parallel"
            ];
          }
        ]
        ++ lib.optionals (pkgs.system != "aarch64-linux" || !cfg.disableThisSystem) [
          {
            hostName = "s";
            system = "aarch64-linux";
            maxJobs = 100;
            supportedFeatures = [
              "benchmark"
              "big-parallel"
            ];
          }
        ]
        ++ [
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
        # substituters = [ "ssh://eu.nixbuild.net?priority=50" ];
        trusted-public-keys = [ "nixbuild.net/PM4CHU-1:RpxgxQ+tNPjQ+GAyUDJcESVTTxH64SG4sBNHakKQNbU=" ];
      };
    };
  };
}
