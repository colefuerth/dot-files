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
    "vm" = {
      user = "anzenna";
      hostname = "192.168.122.185"; # win10 test VM on d's libvirt NAT
      proxyJump = "d";
      serverAliveInterval = 60;
      # recreated on demand (win10-vm recreate) → host key churns; don't wedge
      extraOptions = {
        StrictHostKeyChecking = "accept-new";
        UserKnownHostsFile = "/dev/null";
      };
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
    "m" = {
      user = "cole";
      hostname = "Coles-Macbook-Air.local";
      serverAliveInterval = 60;
    };
    "rm" = {
      user = "cole";
      hostname = "100.81.60.108"; # tailscale
      serverAliveInterval = 60;
    };
  };
}
