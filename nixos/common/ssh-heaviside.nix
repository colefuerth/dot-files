{ username, ... }:
{
  # Shared SSH host blocks for the Heaviside/personal machines (cole-pi, hs-thinkpad).
  home-manager.users.${username}.programs.ssh.matchBlocks = {
    "eu.nixbuild.net" = {
      hostname = "eu.nixbuild.net";
      serverAliveInterval = 60;
      identityFile = "/home/${username}/.ssh/nixbuild/heaviside-shared";
    };
    "t" = {
      user = "heaviside_ai";
      hostname = "10.100.20.38";
      identityFile = "/home/${username}/.ssh/id_ed25519";
    };
    "mothpi" = {
      user = "moth";
      hostname = "moth.local";
      identityFile = "/home/${username}/.ssh/id_rsa";
      forwardX11 = true;
      forwardX11Trusted = true;
    };
    "bms_test" = {
      user = "heaviside";
      hostname = "moth-production-tester.local";
      identityFile = "/home/${username}/.ssh/id_rsa";
    };
    "pi" = {
      user = "cole";
      hostname = "colepi.local";
      serverAliveInterval = 60;
      identityFile = "/home/${username}/.ssh/id_rsa";
      forwardX11 = true;
      forwardX11Trusted = true;
    };
    "s" = {
      user = "cole";
      hostname = "10.100.20.28";
      serverAliveInterval = 60;
    };
  };
}
