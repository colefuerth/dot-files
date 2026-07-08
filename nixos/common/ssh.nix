{ username, ... }:
{
  # Shared SSH host blocks for all of cole's machines.
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
      hostname = "192.168.69.5";
      serverAliveInterval = 60;
    };
    "rs" = {
      user = "cole";
      hostname = "100.86.198.50"; # tailscale
      serverAliveInterval = 60;
    };
    "d" = {
      user = "cole";
      hostname = "cole-desktop.local";
      serverAliveInterval = 60;
    };
    "rd" = {
      user = "cole";
      hostname = "100.100.194.119"; # tailscale
      serverAliveInterval = 60;
    };
    "l" = {
      user = "cole";
      hostname = "cole-laptop.local";
      serverAliveInterval = 60;
    };
    "rl" = {
      user = "cole";
      hostname = "100.125.46.32"; # tailscale
      serverAliveInterval = 60;
    };
  };
}
