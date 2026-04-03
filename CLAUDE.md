# dot-files

Personal system configuration repo managed with Nix flakes. Configures 7 hosts across NixOS (Linux), nix-darwin (macOS), and WSL2.

## Repo structure

```
flake.nix              # Main flake: inputs, host configs, packages, checks
packages.nix           # Custom derivations (fonts, scripts, aliases, bambu-studio, etc.)
shell.nix              # Standalone interactive zsh shell (default package)
nixos/
  hosts/               # Per-host system configs (each has configuration.nix)
    cole-laptop/       # x86_64-linux, NVIDIA hybrid GPU, COSMIC desktop
    cole-desktop/      # x86_64-linux
    cole-darwin/       # aarch64-darwin, macOS with yabai + skhd
    cole-wsl2/         # x86_64-linux, WSL
    cole-vm/           # x86_64-linux
    cole-pi/           # aarch64-linux, Raspberry Pi 5
    hs-thinkpad/       # x86_64-linux, ThinkPad P1 Gen 3
  common/              # Shared NixOS modules imported by hosts
    default.nix        # Core settings (nix config, base packages, networking, docker)
    laptop.nix         # TLP power management
    graphical.nix      # Fonts, Firefox, VS Code, printing
    cosmic.nix         # COSMIC desktop environment
    gnome.nix          # GNOME desktop (alternative to cosmic)
    audio.nix, bluetooth.nix, xone.nix, cachix.nix, nixbuild.nix, ...
  users/cole/          # home-manager config (zsh, git, starship, tmux, neovim, etc.)
overlays/              # Package overlays (chromium, flameshot, fresh-editor, gh, openssh)
aliases/               # Shell alias files sourced by zsh
scripts/               # Utility scripts added to PATH (switch, remote-switch, nomr, etc.)
completions/           # Shell completion files
packages/              # Extra nix package definitions (tour.nix, f5.nix)
```

## Key commands

```bash
# Apply current host config (macOS)
darwin-rebuild switch --flake .#cole-darwin

# Apply config on NixOS (uses nom for output)
sudo ./scripts/switch <hostname>

# Format all nix files (required by CI)
nix fmt

# Run flake checks locally
nix flake check

# Build the standalone shell
nix build .#shell
# or just: nix run .
```

## CI (.github/workflows/main.yml)

Runs on pushes/PRs to `master` and `release/**/*`:

1. **format-checks** -- `nix fmt -- --ci`
2. **flake-checks** -- `nix flake check`
3. **build-packages** -- builds all standalone packages on x86_64-linux
4. **dry-build-system-toplevels** -- dry-builds all NixOS host configs (cole-laptop, cole-desktop, cole-vm, cole-wsl2, hs-thinkpad)

The formatter is `nixfmt-tree`. Always run `nix fmt` before committing nix changes.

## How configs are wired together

- `flake.nix` defines `mkNixosConfiguration` and `mkDarwinConfiguration` helpers that wire together host config + home-manager + sops-nix + overlays
- Each host imports `nixos/common/default.nix` plus whatever extra common modules it needs
- User environment is managed by home-manager via `nixos/users/cole/home.nix`
- Custom packages (aliases, scripts, completions, configs) are built as derivations in `packages.nix` and passed to home-manager as `dotFilesPackages`
- Neovim config comes from the `dschana-system-config` flake input

## Conventions

- Nix code is formatted with `nixfmt-tree` (the flake's formatter)
- The main branch is `main` locally but CI triggers on `master` -- keep this in mind
- Hosts use `nixos-unstable` channel for latest packages
- Secrets are managed with sops-nix
