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
    ./hardware-configuration.nix
    inputs.vscode-server.nixosModules.default
  ];

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Bootloader — use the default one generated with the system for safety
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = host; # Define your hostname.
  networking.wireless.enable = lib.mkForce false;

  # Enable the X11 windowing system.
  services.xserver.enable = false;

  # VM configuration for headless operation with serial console
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      graphics = false;
      # Use serial console for terminal access
      qemu.options = [
        "-nographic"
        "-serial mon:stdio"
      ];
      # Forward SSH port for easy access
      forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
    };
    # Enable serial console getty
    boot.kernelParams = [ "console=ttyS0" ];
    systemd.services."serial-getty@ttyS0".enable = true;
  };

  # Data disks, ported from rs /etc/fstab (x-gvfs-show dropped, no desktop here)
  fileSystems."/HDD" = {
    device = "/dev/disk/by-uuid/f31ab4ab-891c-4861-9bc0-0059cbda3267";
    fsType = "ext4";
    options = [
      "nosuid"
      "nodev"
      "nofail"
    ];
  };
  fileSystems."/HDD4TB" = {
    device = "/dev/disk/by-uuid/6f891660-4d30-49cc-9651-8aaa2597a43e";
    fsType = "ext4";
    options = [
      "nosuid"
      "nodev"
      "nofail"
    ];
  };

  services.vscode-server.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.mutableUsers = false; # Required for declarative password management in VMs
  # Generate hashes with: nix run nixpkgs#mkpasswd -- -m yescrypt
  # "!" = account locked until a real hash is filled in
  users.users.root.initialHashedPassword = "$y$j9T$5v82vlS1Mj2SP/sLnKTgF/$tu0mLfF8sX6A6Em7nA05Ild2854drTGVfJzugL.jFr4";
  users.users.${username} = {
    isNormalUser = true;
    description = "Cole Fuerth";
    initialHashedPassword = "$y$j9T$5j61dXLsPSyg61uLD2dIY0$wNvWWxrZAIw./7FPYeEmA07Kvjo808BJqup3gzYLrFC";
    extraGroups = [
      "dialout"
      "docker"
      "libvirtd"
      "networkmanager"
      "video"
      "wheel"
    ];
    packages = with pkgs; [
    ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    claude-code
    docker-compose # minecraft stack stays in docker (see docker/minecraft in this repo)
    filebot # for the one-time `filebot --license` / `fn:configure` setup
    vscode-with-extensions
  ];

  # --- reverse proxy, was the nginx-proxy-manager container ---
  # NPM had exactly one proxy host; ACME re-issues the cert on first switch.
  # NOTE: router must forward port 80 to this box (NPM listened on 82).
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts."plex.colef.club" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:32400";
        proxyWebsockets = true;
      };
    };
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "colefuerth@gmail.com";
  };

  # --- wireguard, was the linuxserver/wireguard container ---
  # Server key, peers, and PSKs stay in the conf the old container generated;
  # existing peer configs keep working unchanged.
  networking.wg-quick.interfaces.wg0.configFile = "/HDD/docker/wireguard/config/wg_confs/wg0.conf";
  systemd.services.wg-quick-wg0.unitConfig.RequiresMountsFor = [ "/HDD" ];
  # The conf's PostUp masquerades via 'eth+', which doesn't match eno1 on bare
  # metal; NAT the nix way instead (the stale rule is a harmless no-op)
  networking.nat = {
    enable = true;
    externalInterface = "eno1";
    internalInterfaces = [ "wg0" ];
  };

  # --- mediaserver, was the /HDD/docker/mediaserver compose ---
  # Runs as ${username}: all state/media on /HDD* is uid-1000-owned (PUID=1000)
  services.plex = {
    enable = true;
    openFirewall = true; # 32400 + DLNA/GDM discovery ports
    user = username;
    group = "users";
    # the old container's /config volume; state survives reinstalls on /HDD
    dataDir = "/HDD/docker/mediaserver/provision/plex/Library/Application Support";
  };
  # After first start: edit library folders in the web UI, /tv -> /HDD4TB/TV
  # and /movies -> /HDD4TB/Movies (the container-internal paths)

  services.qbittorrent = {
    enable = true;
    user = username;
    group = "users";
    webuiPort = 8085;
    torrentingPort = 6881;
    openFirewall = true; # torrenting port only; webui opened below
  };
  # State migration: copy qBittorrent.conf + BT_backup from
  # /HDD/docker/mediaserver/provision/qbittorrent/qBittorrent into the new
  # profile under /var/lib/qbittorrent, then fix container paths
  # (/downloads -> /HDD/Downloads, /data -> /HDD/docker/mediaserver/content)

  # FileBot AMC pass every 3 min, was the jlesage/filebot container (AMC_INTERVAL=180).
  # One-time setup, as ${username}:
  #   filebot --license /HDD/docker/mediaserver/provision/filebot/license.psm
  #   filebot -script fn:configure   # opensubtitles login
  systemd.services.filebot-amc = {
    description = "FileBot AMC: sort /HDD/nohandbrake into /HDD4TB";
    unitConfig.RequiresMountsFor = [
      "/HDD"
      "/HDD4TB"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "users";
    };
    script = ''
      exec ${pkgs.filebot}/bin/filebot -script fn:amc \
        --output /HDD4TB --action copy -non-strict --conflict auto --lang en \
        --def artwork=y subtitles=en \
        --def excludeList=/HDD/docker/mediaserver/provision/filebot/amc-exlude-list.txt \
        --def "movieFormat=Movies/{n} ({y})/{n} ({y})" \
        --def "seriesFormat=TV/{n}/Season {s}/{n} {sxe} - {t}" \
        --def "animeFormat=TV/{n}/Season {s}/{n} {sxe} - {t}" \
        /HDD/nohandbrake
    '';
  };
  systemd.timers.filebot-amc = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "3min";
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
    8085 # qbittorrent webui
  ];
  networking.firewall.allowedUDPPorts = [ 51820 ]; # wireguard

  # qbittorrent watch dirs (configured inside qbt as /home/cole/torrents_*)
  systemd.tmpfiles.rules = [
    "d /home/${username}/torrents_handbrake 0755 ${username} users -"
    "d /home/${username}/torrents_nohandbrake 0755 ${username} users -"
    "d /home/${username}/torrents_downloads 0755 ${username} users -"
  ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  services.tailscale.enable = true;

  # Dynamic DNS, ported from rs /etc/ddclient.conf
  # ponytail: password lives in a root-only file on the host, move to sops-nix when more secrets show up
  # Seed the password file once before first switch (token is in the namecheap
  # dashboard under Domain -> Advanced DNS -> Dynamic DNS):
  #   sudo install -d -m 700 /var/lib/secrets
  #   printf '%s' '<the token>' | sudo tee /var/lib/secrets/ddclient.pass >/dev/null
  #   sudo chmod 600 /var/lib/secrets/ddclient.pass
  services.ddclient = {
    enable = true;
    protocol = "namecheap";
    server = "dynamicdns.park-your-domain.com";
    username = "colef.club";
    domains = [ "@" ];
    usev4 = "webv4, webv4=dynamicdns.park-your-domain.com/getip";
    passwordFile = "/var/lib/secrets/ddclient.pass";
  };

  # Samba share of /home/cole, ported from rs smb.conf
  # NOTE: run `smbpasswd -a cole` once after first switch (samba passwords are state, not config)
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "server role" = "standalone server";
        "map to guest" = "Bad User";
      };
      cole = {
        comment = "cole";
        path = "/home/cole";
        "read only" = "no";
      };
    };
  };

  virtualisation.libvirtd.enable = true;

  # NVIDIA GTX 1650 (Turing), headless; persistenced keeps the device initialized without X
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = false;
    nvidiaPersistenced = true;
  };

  system.stateVersion = "26.05";

}
