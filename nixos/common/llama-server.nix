{
  config,
  lib,
  pkgs,
  ...
}:
# Declarative llama.cpp `llama-server` GPU model serving.
#
# The Odysseus Cookbook's own "Launch" tab spawns llama-server through a
# detached tmux session created from the uvicorn/asyncio process; in this
# native-systemd setup that tmux session never executes its runner (no process,
# no log), so Cookbook-launched serves silently never start. The underlying
# stack is fine — a CUDA `llama-server` serves the same GGUF on the GPU at full
# speed. So instead of relying on that flaky launcher, run llama-server as a
# plain nix-managed systemd service and point Odysseus at it as an OpenAI
# endpoint (http://HOST:PORT/v1), exactly like the Ollama endpoint.
let
  cfg = config.services.llama-server;

  modelType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        model = lib.mkOption {
          type = lib.types.str;
          description = "Absolute path to the .gguf model file to serve.";
        };
        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address to bind. Use 0.0.0.0 only for LAN access.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          description = "Port for this model's OpenAI-compatible API (served at /v1).";
        };
        contextSize = lib.mkOption {
          type = lib.types.int;
          default = 8192;
          description = ''
            Context window (-c). The KV cache scales with this; DeepSeek-Coder-V2-Lite
            Q4_K_M fits ~12.5 GB VRAM at 8192 and OOMs on a 16 GB card past ~20000.
          '';
        };
        gpuLayers = lib.mkOption {
          type = lib.types.int;
          default = 99;
          description = "Layers to offload to the GPU (-ngl). 99 = all of them.";
        };
        alias = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Model name advertised over the API (--alias). Shown in Odysseus.";
        };
        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "--flash-attn"
            "auto"
          ];
          description = "Extra llama-server flags.";
        };
      };
    }
  );
in
{
  options.services.llama-server = {
    enable = lib.mkEnableOption "llama.cpp llama-server GPU model serving";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-cpp.override { cudaSupport = true; };
      defaultText = lib.literalExpression "pkgs.llama-cpp.override { cudaSupport = true; }";
      description = "Package providing `llama-server`. Defaults to a CUDA build.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "llama-server";
      description = ''
        User to run llama-server as. It must be able to read the model files.
        When serving GGUFs downloaded via the Odysseus Cookbook (which live under
        /var/lib/odysseus, mode 0750), set this to "odysseus" so the process can
        traverse that home; otherwise a dedicated "llama-server" user is created.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "llama-server";
      description = "Group to run llama-server as.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open each model's port in the firewall (for non-loopback host).";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "Named models to serve, each as its own systemd service on its own port.";
      example = lib.literalExpression ''
        {
          deepseek-coder-v2-lite = {
            model = "/var/lib/odysseus/.cache/.../DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf";
            port = 8000;
          };
        }
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.models != { }) {
    users.users = lib.mkIf (cfg.user == "llama-server") {
      llama-server = {
        isSystemUser = true;
        group = cfg.group;
        description = "llama.cpp model serving user";
      };
    };
    users.groups = lib.mkIf (cfg.group == "llama-server") {
      llama-server = { };
    };

    systemd.services = lib.mapAttrs' (
      name: m:
      lib.nameValuePair "llama-server-${name}" {
        description = "llama.cpp server: ${name}";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        environment = {
          # NixOS keeps the NVIDIA userspace driver (libcuda.so) here; the CUDA
          # llama-cpp build needs it at runtime to see the GPU.
          LD_LIBRARY_PATH = "/run/opengl-driver/lib";
          CUDA_VISIBLE_DEVICES = "0";
        };

        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          ExecStart = lib.escapeShellArgs (
            [
              "${cfg.package}/bin/llama-server"
              "--model"
              m.model
              "--host"
              m.host
              "--port"
              (toString m.port)
              "--alias"
              m.alias
              "-ngl"
              (toString m.gpuLayers)
              "-c"
              (toString m.contextSize)
            ]
            ++ m.extraArgs
          );
          Restart = "on-failure";
          RestartSec = 5;
        };
      }
    ) cfg.models;

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall (
      lib.mapAttrsToList (_: m: m.port) cfg.models
    );
  };
}
