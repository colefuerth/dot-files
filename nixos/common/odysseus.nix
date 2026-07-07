{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.odysseus;

  # Pinned to the curated `main` branch tip — upstream publishes no release
  # tags. Bump rev + hash together:
  #   nix-prefetch-url --unpack https://github.com/pewdiepie-archdaemon/odysseus/archive/<rev>.tar.gz
  src = pkgs.fetchFromGitHub {
    owner = "pewdiepie-archdaemon";
    repo = "odysseus";
    rev = "dd055ee6e36581ad8c9c539e02b5b9963fbac2a1";
    hash = "sha256-iwGtxXAaho8tN82TnSmaJ6YXnxMxKxJc2EcaR/cUkv4=";
  };

  # The whole runtime closure resolves to existing nixpkgs attrs — no overrides.
  # chromadb (full) substitutes the HTTP-only `chromadb-client` the app pins; the
  # code only ever calls chromadb.HttpClient, so the server bits sit unused.
  # nixpkgs ships pydantic 2.12.x vs the >=2.13.4 lower bound upstream lists; the
  # bound is conservative and the app runs on 2.12.
  # ponytail: bump pydantic via overlay only if something actually breaks.
  # Test-only deps (pytest, httpx2) are omitted; optional extras (faster-whisper
  # STT, PyMuPDF PDF-forms, markitdown office-docs) can be appended here when wanted.
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      fastapi
      uvicorn
      python-multipart
      python-dotenv
      httpx
      pydantic
      pydantic-settings
      sqlalchemy
      pypdf
      beautifulsoup4
      charset-normalizer
      numpy
      chromadb
      fastembed
      youtube-transcript-api
      markdown
      nh3
      icalendar
      python-dateutil
      caldav
      cryptography
      bcrypt
      mcp
      pyotp
      qrcode
      pillow
      croniter
      python-magic
      ddgs # keyless DuckDuckGo web search (stands in for the SearXNG service)
      # The Cookbook's Download tab shells out to the `hf` CLI (or, as a
      # fallback, `python3 -c "from huggingface_hub import snapshot_download"`)
      # to pull GGUFs from HuggingFace. Without huggingface-hub in the env the
      # native download runner has nothing to fetch with and the task dies with
      # no output. hf-transfer is the fast Rust parallel downloader it prefers.
      huggingface-hub
      hf-transfer
    ]
  );

  stateDir = "/var/lib/odysseus";
  appDir = "${stateDir}/app";
  dataDir = "${stateDir}/data";

  # The app expects a writable checkout: setup.py writes BASE_DIR/logs and
  # BASE_DIR/.env and aborts the whole run (unwrapped) if it can't, and the Nix
  # store copy is read-only. So materialize a writable working tree from the
  # pinned source — exactly how the upstream native-install doc runs it (clone +
  # setup.py + uvicorn). Re-copy only when the pinned source changes.
  # ponytail: a ~30MB cp beats auditing every write path in 110k LOC of app.
  bootstrap = pkgs.writeShellScript "odysseus-bootstrap" ''
    set -eu
    if [ "$(cat ${appDir}/.srcpath 2>/dev/null || true)" != "${src}" ]; then
      rm -rf ${appDir}
      cp -rT --no-preserve=mode ${src} ${appDir}
      printf '%s' "${src}" > ${appDir}/.srcpath
    fi
    mkdir -p ${dataDir}
    exec ${pythonEnv}/bin/python ${appDir}/setup.py
  '';
in
{
  options.services.odysseus = {
    enable = lib.mkEnableOption "Odysseus self-hosted AI workspace";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to bind. Use 0.0.0.0 only for LAN/reverse-proxy access.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      description = "Port to serve the web UI on.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/odysseus.env";
      description = ''
        Optional mode-600 env file kept out of the Nix store, for secrets and
        overrides — e.g. ODYSSEUS_ADMIN_PASSWORD, OPENAI_API_KEY, OLLAMA_BASE_URL.
        Without it, setup.py prints a one-time admin password to the journal on
        first boot. Matches the /etc/nm-secrets.env pattern already used here.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the configured port in the firewall (for non-loopback host).";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.odysseus = {
      isSystemUser = true;
      group = "odysseus";
      home = stateDir;
      description = "Odysseus self-hosted AI workspace service user";
    };
    users.groups.odysseus = { };

    systemd.services.odysseus = {
      description = "Odysseus self-hosted AI workspace";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # The Cookbook serves models by shelling out to background runner scripts
      # (tmux). These are the tools those runners and the bootstrap script call:
      #   bash      - the runners are #!/bin/bash and use bash-isms
      #   coreutils - cp/rm/mkdir/cat/head (bootstrap + GGUF path prelude)
      #   findutils - `find`, used to locate the cached .gguf before serving
      #   gnugrep/gnused/curl - misc parsing + health/probe calls in runners
      #   tmux      - detached background serve sessions
      #   llama-cpp - native `llama-server` for GGUF serving, pinned to a CUDA
      #               build. When the Cookbook generates a llama.cpp launch it
      #               finds llama-server on PATH (skips the from-source build)
      #               and offloads to the GPU.
      #   ollama    - `ollama` CLI for the Cookbook's ollama serve/show paths
      #   nvidia-smi (appended below) - the Cookbook probes it for VRAM/GPU count;
      #               without it hardware detection reports "No GPU" on NixOS,
      #               since its fallback paths don't cover the nix store location.
      path = [
        pythonEnv # `python3` + `hf` for the Cookbook download/serve runners
        pkgs.bash
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.curl
        pkgs.tmux
        (pkgs.llama-cpp.override { cudaSupport = true; })
        pkgs.ollama
      ]
      ++ lib.optional (lib.elem "nvidia" config.services.xserver.videoDrivers) config.hardware.nvidia.package.bin;

      environment = {
        ODYSSEUS_DATA_DIR = dataDir;
        DATABASE_URL = "sqlite:///${dataDir}/app.db";
        HOME = stateDir; # fastembed / HuggingFace model cache lands under here
        PYTHONUNBUFFERED = "1"; # flush the first-run admin password to the journal
      };

      serviceConfig = {
        # A plain static user, not DynamicUser: the Cookbook shells out to tmux
        # runner scripts that download/serve models, and DynamicUser's implicit
        # hardening (PrivateTmp + ProtectHome=read-only + ProtectSystem=strict)
        # makes those runners fail invisibly. A normal service user matches what
        # the app expects and keeps its state/tmp inspectable.
        User = "odysseus";
        Group = "odysseus";
        StateDirectory = "odysseus";
        StateDirectoryMode = "0750";
        WorkingDirectory = stateDir;
        ExecStartPre = bootstrap;
        ExecStart = "${pythonEnv}/bin/python -m uvicorn app:app --app-dir ${appDir} --host ${cfg.host} --port ${toString cfg.port}";
        Restart = "on-failure";
        TimeoutStartSec = 300; # first boot copies the tree + inits the DB
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;

    # The Cookbook's serve/download runner scripts start with `#!/bin/bash`, and
    # tmux execs them by path so the kernel resolves that shebang. NixOS ships no
    # /bin/bash, so provide one — otherwise every Cookbook launch dies instantly
    # with "no such file or directory".
    systemd.tmpfiles.rules = [ "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash" ];
  };
}
