{ username, ... }:
{
  # Shared SSH host blocks for cole's personal machines (cole-pi, hs-thinkpad).
  home-manager.users.${username}.programs.ssh.matchBlocks = {
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
