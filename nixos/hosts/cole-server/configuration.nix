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
# Reinstall/restore runbook for this box: ./REINSTALL.md
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
  # Any local user can connect to these (nix-daemon as an untrusted user,
  # libvirt's read-only API), so hidden from the media services that can open
  # unix sockets. "-": skip a path that doesn't exist.
  hostSockets = [
    "-/nix/var/nix/daemon-socket"
    "-/run/libvirt"
  ];
  # like jellyfin's: of the data disks a unit sees only its binds
  mediaSandbox = {
    ProtectSystem = "strict";
    TemporaryFileSystem = [
      "/HDD:ro"
      "/HDD4TB:ro"
    ];
    InaccessiblePaths = hostSockets;
  };
  # the nixpkgs sonarr/radarr units' hardening, for prowlarr, ombi and unpackerr
  # whose modules set none (no MemoryDenyWriteExecute: .NET's JIT needs W+X pages)
  dotnetHardening = {
    CapabilityBoundingSet = "";
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    PrivateUsers = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    RemoveIPC = true;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@debug"
      "~@mount"
    ];
  };
  arr-guard = pkgs.writers.writePython3Bin "arr-guard" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./arr-guard.py);
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
  # Headless: VS Code is used over Remote-SSH (vscode-server above) and nothing
  # here can display a GUI app, so skip the ones home.nix turns on by default
  home-manager.users.${username}.programs = {
    vscode.enable = false;
    firefox.enable = false;
  };

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
    packages = [ dotFilesPackages.win10-vm ];
    shell = pkgs.zsh;
    # user services/timers (~/trading's scheduled jobs) keep running with no login session
    linger = true;
  };

  environment.systemPackages = with pkgs; [
    btop
    claude-code
    docker-compose # minecraft stack stays in docker (see docker/minecraft in this repo)
    media-sort # for dry runs, see the media-sort unit
    arr-guard # same, see the arr-guard unit
    herdr
    ncdu
    nvtopPackages.nvidia
    (python313.withPackages dotFilesPackages.pyPackages)
    uv
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
    # mom's requests page; Ombi itself listens on :5000, which the firewall drops
    virtualHosts."ombi.colef.club" = {
      enableACME = true;
      forceSSL = true; # a login page: no plain http
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.ombi.port}";
        proxyWebsockets = true;
      };
      # Ombi never locks an account: throttle password guessing here (ASP.NET
      # routes ignore case, so must this match)
      locations."~* ^/api/v1/token" = {
        proxyPass = "http://127.0.0.1:${toString config.services.ombi.port}";
        extraConfig = "limit_req zone=ombi_login burst=5 nodelay;";
      };
    };
    appendHttpConfig = "limit_req_zone $binary_remote_addr zone=ombi_login:1m rate=10r/m;";
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "colefuerth@gmail.com";
  };

  # --- mediaserver, was the /HDD/docker/mediaserver compose ---
  # Each service runs as its own user and, of /HDD and /HDD4TB, sees only its
  # binds (systemd sets those up as root, so nothing on the disks is opened up).
  # Downloads, libraries, drop folders and the done list are shared through the
  # media group: setgid dirs, group-writable, so cole keeps working on them.
  # Ids are pinned like cole's: these files outlive SSD reinstalls.
  users.groups.media = {
    gid = 400;
    members = [
      username
      "jellyfin"
      "qbittorrent"
      "sonarr" # 274 and radarr 275: nixpkgs' static ids
      "radarr"
    ];
  };
  users.users.jellyfin.uid = 401;
  users.groups.jellyfin.gid = 401;
  users.users.qbittorrent.uid = 402;
  users.groups.qbittorrent.gid = 402;
  users.users.media-sort = {
    uid = 403;
    group = "media";
    isSystemUser = true;
  };
  users.users.prowlarr = {
    uid = 404;
    group = "prowlarr";
    isSystemUser = true;
  };
  users.groups.prowlarr.gid = 404;
  users.users.ombi.uid = 405;
  users.groups.ombi.gid = 405;
  users.users.unpackerr.uid = 406; # group media (services.unpackerr.group)

  services.jellyfin = {
    enable = true;
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
    # the jellyfin user's home is /var/empty; .NET keeps its DataProtection keys
    # and fontconfig its cache under $HOME
    environment.HOME = "/cache";
    unitConfig.RequiresMountsFor = [
      "/HDD"
      "/HDD4TB"
    ];
    after = [ "nvidia-persistenced.service" ]; # GPU initialized, /dev/nvidia* present
    serviceConfig = {
      # the module allows only hardwareAcceleration.device; CUDA also opens these
      # (all /dev/nvidia* are 0666, so no group is needed)
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
      # Internet-facing: only its /config and /cache binds are writable
      ProtectSystem = lib.mkForce "strict";
      ProtectHome = true;
      TemporaryFileSystem = [
        "/HDD:ro"
        "/HDD4TB:ro"
      ];
      InaccessiblePaths = hostSockets;
    };
  };
  # jellyfin-ffmpeg loads libcuda/libnvcuvid/libnvidia-encode from /run/opengl-driver
  hardware.graphics.enable = true;

  services.qbittorrent = {
    enable = true;
    webuiPort = 8085;
    torrentingPort = 6881;
    openFirewall = true; # TCP only; 6881/udp opened below
    # serverConfig stays unset: it would overwrite qBittorrent.conf (WebUI login)
  };
  systemd.services.qbittorrent = {
    unitConfig.RequiresMountsFor = [
      "/HDD"
      "/HDD4TB"
    ];
    serviceConfig.Restart = "on-failure"; # the container was restart: unless-stopped
    serviceConfig.UMask = "0002"; # downloads stay group-writable for cole
    serviceConfig.TemporaryFileSystem = [
      "/HDD:ro"
      "/HDD4TB:ro"
    ];
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
      # .torrent drop folders, on the [HDD] samba share; qBittorrent deletes
      # each file once added
      "/HDD/torrents_downloads:/watch_downloads"
      "/HDD/torrents_nohandbrake:/watch_nohandbrake"
      # Sonarr/Radarr's categories, at the paths those units see them (below)
      "/HDD4TB/TV/.torrents:/tv/.torrents"
      "/HDD4TB/Movies/.torrents:/movies/.torrents"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /HDD/torrents_nohandbrake 2775 ${username} media -"
    "d /HDD/torrents_downloads 2775 ${username} media -"
    # media-sort unpacks archives here (libraries' disk, not the SSD)
    "d /HDD4TB/.media-sort 0755 media-sort media -"
    # Sonarr/Radarr's downloads (seeded forever) and their root folders (staging,
    # which media-sort sorts into the library), all three names of a file
    # hardlinks of one inode. Hidden and .ignore'd: Jellyfin neither lists nor
    # watches them
    "d /HDD4TB/TV/.torrents 2775 ${username} media -"
    "d /HDD4TB/Movies/.torrents 2775 ${username} media -"
    "d /HDD4TB/TV/.sonarr 2775 ${username} media -"
    "d /HDD4TB/Movies/.radarr 2775 ${username} media -"
    "f /HDD4TB/TV/.torrents/.ignore 0644 ${username} media -"
    "f /HDD4TB/Movies/.torrents/.ignore 0644 ${username} media -"
    "f /HDD4TB/TV/.sonarr/.ignore 0644 ${username} media -"
    "f /HDD4TB/Movies/.radarr/.ignore 0644 ${username} media -"
    # what media-sort left for a human, and cole's overrides for it: on the
    # HDD4TB share, outside the libraries, so Jellyfin never scans it
    "d /HDD4TB/Unsorted 2775 ${username} media -"
    "f /HDD4TB/Unsorted/overrides.txt 0664 ${username} media - # <path> = tv <tmdb id> [S01E02] | movie <tmdb id> | skip   (paths and help: needs-sorting.txt)\\n"
    "d ${provision}/sonarr-native 0700 sonarr sonarr -"
    "d ${provision}/radarr-native 0700 radarr radarr -"
  ];

  # media-sort (./media-sort.py) replaces FileBot AMC, which was the
  # jlesage/filebot container: it copies finished torrents from
  # /HDD/nohandbrake into the libraries with FileBot's TMDB names and formats,
  # so new episodes land in the existing folders. It also sorts Sonarr/Radarr's
  # imports (/HDD4TB/TV/.sonarr, /HDD4TB/Movies/.radarr) the same way, as
  # hardlinks, so it is the one thing that names the library. FileBot's exclude
  # list of processed files (/watch/... paths) is its done list, so nothing is
  # sorted twice; the rest of ${provision}/filebot is just history now.
  # What it leaves for a human it lists in /HDD4TB/Unsorted/needs-sorting.txt;
  # a line in overrides.txt next to it names the show/movie (or "skip").
  # TMDB key (themoviedb.org -> Settings -> API -> "API Key"):
  #   sudo sh -c "umask 077; printf '%s' '<key>' > /HDD/secrets/tmdb.key"
  # Dry run over everything in /HDD/nohandbrake and the staging dirs (prints,
  # writes nothing):
  #   sudo systemd-run --pty -p User=media-sort -p LoadCredential=tmdb:/HDD/secrets/tmdb.key -p BindReadOnlyPaths=/HDD/nohandbrake:/watch -E DONE_LIST=/dev/null media-sort --dry-run
  system.checks = [
    (pkgs.runCommand "media-sort-self-test" { } "${media-sort}/bin/media-sort --self-test > $out")
    (pkgs.runCommand "arr-guard-self-test" { } "${arr-guard}/bin/arr-guard --self-test > $out")
  ];
  systemd.services.media-sort = {
    description = "Sort /HDD/nohandbrake and Sonarr/Radarr's imports into /HDD4TB";
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
      User = "media-sort";
      UMask = "0002"; # library files stay group-writable for cole
      StateDirectory = "media-sort";
      LoadCredential = "tmdb:/HDD/secrets/tmdb.key";
      # It parses names from torrents and unpacks their archives, so of the
      # data disks it sees only its input (read-only), the libraries, its
      # scratch dir, the done list and Unsorted; no /home, sockets or D-Bus
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
        "/HDD4TB/Unsorted"
      ];
      ProtectSystem = "strict";
      ProtectHome = true;
      InaccessiblePaths = hostSockets ++ [ "-/run/dbus" ];
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
      RemoveIPC = true;
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
    # Saving overrides.txt counts as a change (its content: an edit may keep the size).
    script = ''
      snap() { { find /watch /HDD4TB/TV/.sonarr /HDD4TB/Movies/.radarr -printf '%p %s\n' | sort; cat /HDD4TB/Unsorted/overrides.txt 2>/dev/null; } | sha1sum; }
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

  # --- requests: Ombi (ombi.colef.club) -> Sonarr/Radarr -> Prowlarr -> qBittorrent ---
  # Only what is requested in Ombi gets downloaded: Sonarr/Radarr start empty
  # (their docker state stays in ${provision}/{sonarr,radarr}, unused; never use
  # their "Library Import"), and arr-guard below unmonitors anything else and
  # flags settings that would let them grab more (upgrades, Minimum Free Space...).
  # They never write the library: a finished download in /tv/.torrents is
  # hardlinked into their root folder /tv/.sonarr (/movies/.radarr for Radarr),
  # and media-sort links it from there into the library under its TMDB name.
  # Prowlarr (IPTorrents, TorrentLeech) and Ombi keep their docker state, handed
  # over once like jellyfin's:
  #   sudo chown -R 404:404 ${provision}/prowlarr; sudo chown -R 405:405 ${provision}/ombi
  services.sonarr.enable = true;
  services.radarr.enable = true;
  services.prowlarr = {
    enable = true;
    settings.auth.required = "Enabled"; # its config.xml skipped the login for LAN addresses
  };
  services.ombi.enable = true;
  # web UIs on the LAN interface only, not tailscale0; each has its own login
  networking.firewall.interfaces.eno1.allowedTCPPorts = [
    7878 # radarr
    8989 # sonarr
    9696 # prowlarr
  ];
  systemd.services.sonarr = {
    unitConfig.RequiresMountsFor = [
      "/HDD"
      "/HDD4TB"
    ];
    serviceConfig = mediaSandbox // {
      BindPaths = [
        "${provision}/sonarr-native:${config.services.sonarr.dataDir}"
        # downloads (/tv/.torrents) and root folder (/tv/.sonarr) in ONE mount:
        # link(2) fails across mounts, even two binds of one disk, and imports
        # become copies
        "/HDD4TB/TV:/tv"
      ];
    };
  };
  systemd.services.radarr = {
    unitConfig.RequiresMountsFor = [
      "/HDD"
      "/HDD4TB"
    ];
    serviceConfig = mediaSandbox // {
      BindPaths = [
        "${provision}/radarr-native:${config.services.radarr.dataDir}"
        "/HDD4TB/Movies:/movies" # /movies/.torrents and /movies/.radarr, as above
      ];
    };
  };
  systemd.services.prowlarr = {
    unitConfig.RequiresMountsFor = [ "/HDD" ];
    serviceConfig =
      mediaSandbox
      // dotnetHardening
      // {
        # a DynamicUser's uid isn't pinned, and it would re-own the state on start
        DynamicUser = lib.mkForce false;
        User = "prowlarr";
        Group = "prowlarr";
        BindPaths = [ "${provision}/prowlarr:/var/lib/prowlarr" ];
        IPAddressDeny = "192.168.69.5"; # as ombi's
      };
  };
  systemd.services.ombi = {
    unitConfig.RequiresMountsFor = [ "/HDD" ];
    # Internet-facing (through nginx)
    serviceConfig =
      mediaSandbox
      // dotnetHardening
      // {
        BindPaths = [ "${provision}/ombi:${config.services.ombi.dataDir}" ];
        # qBittorrent (:8085) skips its login for 192.168.69.0/24, this host's
        # address included; Ombi only talks to 127.0.0.1 and the internet
        IPAddressDeny = "192.168.69.5";
      };
  };
  # Unpackerr: Sonarr/Radarr can't import a release packed as .rar. It unpacks
  # one next to its archives (which keep seeding), they link the video into
  # staging, and 5 minutes after the import it deletes its copy (never the
  # archives). Its keys, once arr-guard's file exists (below):
  #   sudo sh -c 'umask 077; sed -n "s/^\(SONARR\|RADARR\)_API_KEY=/UN_\1_0_API_KEY=/p" /HDD/secrets/arr-guard.env > /HDD/secrets/unpackerr.env'
  #   sudo systemctl start unpackerr
  services.unpackerr = {
    enable = true;
    group = "media";
    # file_mode also for archives that store a mode (a Unix-made rar's 0644 or
    # 0600), which upstream keeps: Sonarr/Radarr would copy or fail to read them
    package = pkgs.unpackerr.overrideAttrs (old: {
      postConfigure = (old.postConfigure or "") + ''
        chmod -R u+w vendor/golift.io/xtractr
        substituteInPlace vendor/golift.io/xtractr/write.go --replace-fail \
          'const minimum = 0o400 // ensure owner has read access to the file.' \
          'minimum := x.FileMode | 0o400'
      '';
    });
    settings = {
      # group-writable, so fs.protected_hardlinks lets Sonarr/Radarr link it
      file_mode = "0664";
      dir_mode = "0775";
      sonarr = [ { url = "http://127.0.0.1:8989"; } ];
      radarr = [ { url = "http://127.0.0.1:7878"; } ];
    };
  };
  systemd.services.unpackerr = {
    unitConfig = {
      RequiresMountsFor = [
        "/HDD"
        "/HDD4TB"
      ];
      ConditionPathExists = "/HDD/secrets/unpackerr.env"; # skipped, not failing, until then
    };
    # It parses untrusted archives: of the disks it sees only the downloads, at
    # the paths Sonarr/Radarr report, and of the network only localhost (them)
    serviceConfig =
      mediaSandbox
      // dotnetHardening
      // {
        EnvironmentFile = "/HDD/secrets/unpackerr.env";
        UMask = "0002";
        BindPaths = [
          "/HDD4TB/TV/.torrents:/tv/.torrents"
          "/HDD4TB/Movies/.torrents:/movies/.torrents"
        ];
        MemoryDenyWriteExecute = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        IPAddressAllow = "localhost";
        IPAddressDeny = "any";
      };
  };
  # ./arr-guard.py, every minute: Sonarr/Radarr unmonitor whatever no Ombi
  # request asked for, and it fails while a setting would let them download more.
  # API keys (Sonarr/Radarr: Settings -> General; Ombi: Settings -> Ombi):
  #   sudo sh -c 'umask 077; cat > /HDD/secrets/arr-guard.env'
  #   SONARR_API_KEY=...
  #   RADARR_API_KEY=...
  #   OMBI_API_KEY=...
  # Dry run (prints what it would change and every unsafe setting):
  #   sudo systemd-run --pty -p EnvironmentFile=/HDD/secrets/arr-guard.env arr-guard --dry-run
  systemd.services.arr-guard = {
    description = "Unmonitor in Sonarr/Radarr what nobody requested in Ombi";
    unitConfig.RequiresMountsFor = [ "/HDD" ];
    environment.PYTHONUNBUFFERED = "1";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${arr-guard}/bin/arr-guard";
      EnvironmentFile = "/HDD/secrets/arr-guard.env";
      DynamicUser = true;
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
    };
  };
  systemd.timers.arr-guard = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
      AccuracySec = "5s";
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

  # Dynamic DNS, same settings as the Ubuntu /etc/ddclient.conf. To re-seed the
  # password file below by hand (namecheap dashboard: Domain -> Advanced DNS ->
  # Dynamic DNS):
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
  # For Jellyfin, put /HDD/docker/jellyfin-db-snapshot/* back over config/data/
  # with cp -a (keeps the jellyfin owner).
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
        # setting checkOpts turns on runCheck: verify 2% of the pack data each
        # run, so repo corruption surfaces as a failed unit. %% because this
        # lands in ExecStart, where systemd treats % as a specifier.
        checkOpts = [ "--read-data-subset=2%%" ];
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
        # rather than for the whole backup + prune. set -e: the module runs this
        # without it, so a failed cp would still "succeed", minus the DB copy.
        backupPrepareCommand = ''
          set -e
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
      # /HDD4TB/Archive -> /HDD, what archive-backup.sh was meant to do, plus the photos
      archive = common // {
        repository = "/HDD/restic-archive";
        paths = [
          "/HDD4TB/Archive"
          "/HDD4TB/Pictures"
          "/HDD4TB/phone backup 20250524"
        ];
        timerConfig = {
          OnCalendar = "Sun 04:00";
          Persistent = true;
        };
      };
      # Off-site: state + everything irreplaceable -> personal Google Drive.
      # Same password as the local repos, so restic.pass must also live off this box.
      offsite = common // {
        repository = "rclone:gdrive:restic-cole-server";
        # init by hand: if a Drive lookup ever misses the repo, auto-init makes a same-named twin
        initialize = false;
        # a string, not a path, so it stays out of the store; root 0600, and
        # rclone rewrites it when it refreshes the OAuth token
        rcloneConfigFile = "/HDD/secrets/rclone.conf";
        rcloneOptions.drive-stop-on-upload-limit = true; # 750 GiB/day cap: fail, retry tomorrow
        paths = config.services.restic.backups.state.paths ++ [
          "/HDD4TB/Archive"
          "/HDD4TB/Pictures"
          "/HDD4TB/phone backup 20250524"
          "/HDD/Lecture Recordings"
        ];
        inherit (config.services.restic.backups.state) exclude;
        # read back a fixed 1 GiB from Drive nightly, not a % that grows with the repo
        checkOpts = [ "--read-data-subset=1G" ];
        # state's 03:00 run leaves a consistent jellyfin-db-snapshot to pick up
        timerConfig = {
          OnCalendar = "04:30";
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
  systemd.services.restic-backups-offsite = {
    environment.RESTIC_PACK_SIZE = "64"; # fewer, bigger packs: Drive manages ~2 file uploads/s
    unitConfig.RequiresMountsFor = [
      "/HDD"
      "/HDD4TB"
    ];
    # after a missed night both Persistent timers fire at boot: let state's snapshot finish first
    after = [ "restic-backups-state.service" ];
  };

  # Samba, ported from the Ubuntu smb.conf plus its two Nautilus usershares
  # Passwords are state (/var/lib/samba/private): restic backs it up and the
  # installer restores it
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
      # New files and folders take their parent's mode: group-writable in the
      # setgid media folders, so the services can use what cole adds there
      HDD = {
        path = "/HDD";
        "read only" = "no";
        "inherit permissions" = "yes";
      };
      HDD4TB = {
        path = "/HDD4TB";
        "read only" = "no";
        "inherit permissions" = "yes";
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
