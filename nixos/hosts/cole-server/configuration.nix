{
  config,
  dotFilesPackages,
  host,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
# Reinstall/restore runbook for this box: ./MIGRATION.md
#
# Data disks: /HDD (state; everything that used to live in docker volumes stays
# here in place) and /HDD4TB (media + backups). Only the SSD is disposable.
#
# The media services were docker containers; the native units below give each
# one the exact paths its container saw (systemd BindPaths) because those paths
# are baked into their state: ~25k absolute paths in jellyfin.db, qbittorrent's
# fastresume files, the done list media-sort took over from FileBot. State is
# used in place, untouched, so going back to docker stays possible.
let
  provision = "/HDD/docker/mediaserver/provision";
  media-sort = pkgs.writers.writePython3Bin "media-sort" {
    libraries = [ pkgs.python3Packages.guessit ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./media-sort.py);
  # Root-equivalent for anything running as cole (docker group, nix
  # trusted-user, libvirtd group), so hidden from the media services below.
  # These overmount what exists at service start: if docker.socket restarts, the
  # new /run/docker.sock is reachable until the service restarts too (Jellyfin
  # does nightly for the backup, media-sort on every run; qBittorrent can't open
  # unix sockets at all). "-": skip a path that doesn't exist.
  rootSockets = [
    "-/run/docker.sock"
    "-/nix/var/nix/daemon-socket"
    "-/run/libvirt"
  ];
in
{
  imports = [
    ../../common
    ../../common/cachix.nix
    ./hardware-configuration.nix
    inputs.vscode-server.nixosModules.default
  ];

  # LTS kernel: the proprietary nvidia driver can lag behind linuxPackages_latest
  boot.kernelPackages = pkgs.linuxPackages;

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
    editor = false;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = host; # Define your hostname.
  networking.wireless.enable = lib.mkForce false;

  # Static, like the Ubuntu NM profile: `ssh s`, the router's port forwards and
  # cole-desktop's remote-builder entry all point at .5
  networking.networkmanager.ensureProfiles.profiles.gigabit = {
    connection = {
      id = "gigabit";
      type = "ethernet";
      interface-name = "eno1";
    };
    ipv4 = {
      method = "manual";
      address1 = "192.168.69.5/24,192.168.69.1";
      dns = "1.1.1.1;1.0.0.1;";
      ignore-auto-dns = "true";
    };
    ipv6.method = "auto";
  };
  # ensureProfiles writes the profile only after NM has started, by which time NM
  # has already put eno1 on an auto-created DHCP "Wired connection 1" for good
  networking.networkmanager.settings.main.no-auto-default = "*";

  # Enable the X11 windowing system.
  services.xserver.enable = false;

  zramSwap.enable = true; # Ubuntu had a 2G swapfile

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
    # the VM's NIC isn't eno1, so let it fall back to DHCP (for the ssh forward)
    networking.networkmanager.settings.main.no-auto-default = lib.mkForce "";
    systemd.services."serial-getty@ttyS0".enable = true;
  };

  # Data disks, ported from the Ubuntu /etc/fstab (x-gvfs-show dropped, no desktop here)
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
  # uid/gid 1000 like on Ubuntu: everything on /HDD* is 1000:1000 and the old
  # containers ran with PUID/PGID 1000
  users.groups.cole.gid = 1000;
  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    group = "cole";
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
    # cole-desktop: bootstraps the fresh install and is the nix remote-builder
    # client; the rest of the old keys come back with ~/.ssh/authorized_keys
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFozZCB6oPjnWlEZfaZlVI1oXtIAeSpRqw6kOhVlukmB cole@cole-desktop"
    ];
    packages = with pkgs; [
    ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    btop
    claude-code
    docker-compose # minecraft stack stays in docker (see docker/minecraft in this repo)
    media-sort # for dry runs, see the media-sort unit
    herdr
    ncdu
    nvtopPackages.nvidia
    (python313.withPackages dotFilesPackages.pyPackages)
    uv
    vscode-with-extensions
  ];

  # Ubuntu ran sshd key-only too
  services.openssh = {
    enable = true;
    settings.KbdInteractiveAuthentication = false;
  };

  # --- reverse proxy, was the nginx-proxy-manager container ---
  # The only live NPM proxy host. ACME re-issues the cert on first switch.
  # NOTE: router must forward WAN 80 to this box's :80 (NPM listened on 82).
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts."jellyfin.colef.club" = {
      enableACME = true;
      # NPM didn't force https and some clients (the TV app) still use http
      addSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8096";
        proxyWebsockets = true;
        extraConfig = "proxy_buffering off;";
      };
    };
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "colefuerth@gmail.com";
  };

  # --- mediaserver, was the /HDD/docker/mediaserver compose ---
  # Runs as ${username}: /HDD is 0710 cole:root and all media is cole-owned.
  # Before the first start: sudo chown -R cole:cole ${provision}/jellyfin
  # (the container ran as root)
  services.jellyfin = {
    enable = true;
    user = username;
    group = "cole";
    openFirewall = true;
    # the container's JELLYFIN_DATA_DIR/CACHE_DIR; bound to the real dirs below
    dataDir = "/config";
    cacheDir = "/cache";

    # NVENC on the GTX 1650. encoding.xml is written from these options on every
    # start (the previous one is kept as encoding.xml.backup-<time>), so change
    # transcoding here, not in the dashboard. Values match the container's
    # encoding.xml; everything the module doesn't set was a Jellyfin default.
    hardwareAcceleration = {
      enable = true;
      type = "nvenc";
      device = "/dev/nvidia0";
    };
    forceEncodingConfig = true;
    transcoding = {
      enableHardwareEncoding = true; # h264; hevc/av1 encoding stay off as before
      enableToneMapping = false; # as before
      # what the GTX 1650's NVDEC (Turing) can decode
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        hevc10bit = true;
        mpeg2 = true;
        vc1 = true;
        vp8 = true;
        vp9 = true;
      };
    };
  };
  systemd.services.jellyfin = {
    environment.JELLYFIN_PublishedServerUrl = "http://jellyfin.colef.club";
    # cole's real $HOME is hidden below; .NET keeps its DataProtection keys and
    # fontconfig its cache under $HOME
    environment.HOME = "/cache";
    unitConfig.RequiresMountsFor = [
      "/HDD"
      "/HDD4TB"
    ];
    after = [ "nvidia-persistenced.service" ]; # GPU initialized, /dev/nvidia* present
    serviceConfig = {
      # the module allows only hardwareAcceleration.device; CUDA also opens these
      DeviceAllow = [
        "/dev/nvidiactl rw"
        "/dev/nvidia-uvm rw"
      ];
      BindPaths = [
        "${provision}/jellyfin/config:/config"
        "${provision}/jellyfin/cache:/cache"
      ];
      # read-only like the container (so "save trickplay/NFO with media" fails)
      BindReadOnlyPaths = [
        "/HDD4TB/TV:/media/tv"
        "/HDD4TB/Movies:/media/movies"
      ];
      # Internet-facing: only its two binds are writable (else the media would
      # still be writable at /HDD4TB/...), and no cole home, /run/user or sockets
      ProtectSystem = lib.mkForce "strict";
      ProtectHome = true;
      InaccessiblePaths = rootSockets;
    };
  };
  # jellyfin-ffmpeg loads libcuda/libnvcuvid/libnvidia-encode from /run/opengl-driver
  hardware.graphics.enable = true;

  services.qbittorrent = {
    enable = true;
    user = username;
    group = "cole";
    webuiPort = 8085;
    torrentingPort = 6881;
    openFirewall = true; # TCP only; 6881/udp opened below
    # serverConfig stays unset: it would overwrite qBittorrent.conf (WebUI login)
  };
  systemd.services.qbittorrent = {
    unitConfig.RequiresMountsFor = [ "/HDD" ];
    serviceConfig.Restart = "on-failure"; # the container was restart: unless-stopped
    serviceConfig.BindPaths = [
      # the linuxserver profile is flat (XDG config == data dir), so it serves
      # as both halves of the module's <profileDir>/qBittorrent/{config,data}
      "${provision}/qbittorrent/qBittorrent:/var/lib/qBittorrent/qBittorrent/config"
      "${provision}/qbittorrent/qBittorrent:/var/lib/qBittorrent/qBittorrent/data"
      "${provision}/qbittorrent:/config" # FileLogger\Path=/config/qBittorrent/logs
      # container paths in the fastresume files / watched_folders.json / categories
      "/HDD/Downloads:/downloads"
      "/HDD/nohandbrake:/nohandbrake"
      "/HDD/docker/mediaserver/content:/data"
      # drop .torrent files here over the [cole] samba share; ProtectHome
      # hides /home from the service but not these binds
      "/home/${username}/torrents_downloads:/watch_downloads"
      "/home/${username}/torrents_nohandbrake:/watch_nohandbrake"
    ];
    serviceConfig.InaccessiblePaths = rootSockets;
  };
  systemd.tmpfiles.rules = [
    "d /home/${username}/torrents_nohandbrake 0755 ${username} cole -"
    "d /home/${username}/torrents_downloads 0755 ${username} cole -"
  ];

  # media-sort (./media-sort.py) replaces FileBot AMC, which was the
  # jlesage/filebot container: it copies finished torrents from
  # /HDD/nohandbrake into the libraries with FileBot's TMDB names and formats,
  # so new episodes land in the existing folders. FileBot's exclude list of
  # processed files (/watch/... paths) is its done list, so nothing is sorted
  # twice; the rest of ${provision}/filebot is just history now.
  # TMDB key (themoviedb.org -> Settings -> API -> "API Key"):
  #   sudo sh -c "umask 077; printf '%s' '<key>' > /HDD/secrets/tmdb.key"
  # Dry run over everything in /HDD/nohandbrake (prints, writes nothing):
  #   sudo systemd-run --pty -p User=cole -p LoadCredential=tmdb:/HDD/secrets/tmdb.key -p BindReadOnlyPaths=/HDD/nohandbrake:/watch -E DONE_LIST=/dev/null media-sort --dry-run
  system.checks = [
    (pkgs.runCommand "media-sort-self-test" { } "${media-sort}/bin/media-sort --self-test > $out")
  ];
  systemd.services.media-sort = {
    description = "Sort /HDD/nohandbrake into /HDD4TB";
    unitConfig.RequiresMountsFor = [
      "/HDD"
      "/HDD4TB"
    ];
    path = [
      media-sort
      pkgs._7zz-rar # rar too, like the container's 7z
    ];
    environment = {
      DONE_LIST = "${provision}/filebot/amc-exlude-list.txt";
      PYTHONUNBUFFERED = "1"; # log lines in order with tracebacks
    };
    serviceConfig = {
      Type = "oneshot";
      User = username;
      StateDirectory = "media-sort";
      LoadCredential = "tmdb:/HDD/secrets/tmdb.key";
      # archives are unpacked here: the libraries' disk, not the SSD
      ExecStartPre = "+${pkgs.coreutils}/bin/install -d -o ${username} -g cole /HDD4TB/.media-sort";
      # It parses names from torrents and unpacks their archives, so of the
      # data disks it sees only its input (read-only), the libraries, its
      # scratch dir and the done list; no cole home, /run/user or sockets, and
      # no D-Bus (polkit would give it cole's networkmanager rights)
      TemporaryFileSystem = [
        "/HDD:ro"
        "/HDD4TB:ro"
      ];
      BindReadOnlyPaths = [ "/HDD/nohandbrake:/watch" ];
      BindPaths = [
        "${provision}/filebot/amc-exlude-list.txt"
        "/HDD4TB/.media-sort"
        "/HDD4TB/Movies"
        "/HDD4TB/TV"
      ];
      ProtectSystem = "strict";
      ProtectHome = true;
      InaccessiblePaths = rootSockets ++ [ "-/run/dbus" ];
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateUsers = true;
      NoNewPrivileges = true;
      # the rest like the nixpkgs jellyfin/qbittorrent units
      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" ];
    };
    # Like FileBot's container: only run when the input changed since the last
    # successful run and has stopped changing (qbt copies finished torrents in;
    # don't sort half a file). A failed run is retried by the next timer tick.
    script = ''
      snap() { find /watch -printf '%P %s\n' | sort | sha1sum; }
      s=$(snap)
      [ "$s" != "$(cat "$STATE_DIRECTORY/last" 2>/dev/null)" ] || exit 0
      sleep 10
      [ "$s" = "$(snap)" ] || exit 0
      find /HDD4TB/.media-sort -mindepth 1 -delete # what a killed run left behind
      media-sort
      echo "$s" > "$STATE_DIRECTORY/last"
    '';
  };
  systemd.timers.media-sort = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "3min";
    };
  };

  # minecraft (docker/minecraft in this repo) bind-mounts /HDD/docker/minecraft;
  # don't let dockerd bring containers up before the data disks are mounted
  systemd.services.docker.unitConfig.RequiresMountsFor = [
    "/HDD"
    "/HDD4TB"
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    6881 # qbittorrent uTP/DHT
  ];

  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server"; # IPv4/IPv6 forwarding for the exit node
    # Applied by tailscaled-set, which only runs when tailscaled starts (not on a
    # switch): after changing these, `sudo systemctl start tailscaled-set`
    extraSetFlags = [ "--advertise-exit-node" ];
  };

  # Secrets live in /HDD/secrets (root 0700) so they survive SSD reinstalls.
  # ponytail: plain root-only files, move to sops-nix when more secrets show up

  # Dynamic DNS, same settings as the Ubuntu /etc/ddclient.conf. pre-wipe-backup.sh
  # copies its password to the file below; otherwise seed it by hand (namecheap
  # dashboard: Domain -> Advanced DNS -> Dynamic DNS):
  #   sudo sh -c "umask 077; printf '%s' '<the token>' > /HDD/secrets/ddclient.pass"
  systemd.services.ddclient.unitConfig.RequiresMountsFor = [ "/HDD" ];
  services.ddclient = {
    enable = true;
    protocol = "namecheap";
    server = "dynamicdns.park-your-domain.com";
    username = "colef.club";
    domains = [ "@" ]; # *.colef.club is a wildcard CNAME to @
    usev4 = "webv4, webv4=dynamicdns.park-your-domain.com/getip";
    usev6 = ""; # no IPv6 on this LAN
    passwordFile = "/HDD/secrets/ddclient.pass";
    interval = "5min"; # Debian's daemon_interval=300 (NixOS default is 10min)
  };

  # Nightly backups, replacing the Ubuntu cron jobs (X-backup.sh,
  # docker-restart.sh, archive-backup.sh), which had all been silently failing.
  # Seed the repo password once, and keep a copy in a password manager (the
  # repos are unreadable without it):
  #   sudo sh -c 'umask 077; openssl rand -base64 32 > /HDD/secrets/restic.pass'
  # Restore one path at a time (a bare `restore latest --target /` overwrites live state):
  #   sudo restic-state restore latest --include <path> --target /
  # For Jellyfin, put /HDD/docker/jellyfin-db-snapshot/* back over config/data/.
  services.restic.backups =
    let
      common = {
        initialize = true;
        passwordFile = "/HDD/secrets/restic.pass";
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
      };
    in
    {
      # SSD and /HDD state -> /HDD4TB
      state = common // {
        repository = "/HDD4TB/restic";
        paths = [
          "/home/${username}"
          "/HDD/docker"
          "/HDD/secrets"
          "/var/lib/samba/private" # SMB passwords (passdb.tdb + its SID in secrets.tdb)
          "/var/lib/tailscale" # node identity (keeps 100.86.198.50)
          "/etc/ssh" # host keys
        ];
        exclude = [
          "/home/*/.cache"
          "/home/*/.vscode-server*"
          "${provision}/jellyfin/cache"
        ];
        # jellyfin.db is SQLite: copy it cold, so Jellyfin is down for seconds
        # rather than for the whole backup + prune
        backupPrepareCommand = ''
          systemctl stop jellyfin
          rm -rf /HDD/docker/jellyfin-db-snapshot
          install -d -m 700 /HDD/docker/jellyfin-db-snapshot
          cp -a ${provision}/jellyfin/config/data/jellyfin.db* /HDD/docker/jellyfin-db-snapshot/
          systemctl start jellyfin
        '';
        # in case the copy failed with Jellyfin stopped
        backupCleanupCommand = "systemctl start jellyfin";
        timerConfig = {
          OnCalendar = "03:00";
          Persistent = true;
        };
      };
      # /HDD4TB/Archive -> /HDD, what archive-backup.sh was meant to do
      archive = common // {
        repository = "/HDD/restic-archive";
        paths = [ "/HDD4TB/Archive" ];
        timerConfig = {
          OnCalendar = "Sun 04:00";
          Persistent = true;
        };
      };
    };
  systemd.services.restic-backups-state.unitConfig.RequiresMountsFor = [
    "/HDD"
    "/HDD4TB"
  ];
  systemd.services.restic-backups-archive.unitConfig.RequiresMountsFor = [
    "/HDD"
    "/HDD4TB"
  ];

  # Samba, ported from the Ubuntu smb.conf plus its two Nautilus usershares
  # Passwords are state (/var/lib/samba/private): MIGRATION.md §3 restores the
  # Ubuntu passdb, restic keeps it after that
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
      HDD = {
        path = "/HDD";
        "read only" = "no";
      };
      HDD4TB = {
        path = "/HDD4TB";
        "read only" = "no";
      };
    };
  };

  # Ubuntu's smbd announced the shares over mDNS (Finder / file-manager
  # "Network"). nixpkgs samba is built without avahi, so publish them statically.
  services.avahi.extraServiceFiles.smb = ''
    <?xml version="1.0" standalone='no'?>
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    <service-group>
      <name replace-wildcards="yes">%h</name>
      <service>
        <type>_smb._tcp</type>
        <port>445</port>
      </service>
      <service>
        <type>_device-info._tcp</type>
        <port>0</port>
        <txt-record>model=MacSamba</txt-record>
      </service>
    </service-group>
  '';

  virtualisation.libvirtd.enable = true;
  # plain `virsh` talks to the system daemon, like Ubuntu's /etc/profile.d/libvirt-uri.sh
  environment.sessionVariables.LIBVIRT_DEFAULT_URI = "qemu:///system";

  # NVIDIA GTX 1650 (Turing), headless; persistenced keeps the device initialized without X
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = false;
    nvidiaPersistenced = true;
  };

  system.stateVersion = "26.11";

}
