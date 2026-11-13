# My Dot-Files

Originally a central place to sync my home environment across machines using shell scripts, this repo now holds my nixos configs for all of my systems.

The default package in this flake is a `zsh` session with my dev environment loaded through the nix daemon, which works on any distro with the nix daemon installed.

## Interactive Shell

Start by installing nix

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
nix run github:colefuerth/dot-files
```

## Installation on NixOS

### switch without cloning (from fresh nixos)

```bash
SYSTEM="cole-laptop"
sudo echo "sudo acquired" # nom cuts off the sudo prompt, so preauthenticate
sudo nixos-rebuild \
    --option extra-substituters https://install.determinate.systems \
    --option extra-trusted-public-keys cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= \
    --flake github:colefuerth/dot-files#$SYSTEM \
    --log-format internal-json -v switch |& nix run nixpkgs#nix-output-monitor -- --json
```

### cloning and switching locally

```bash
SYSTEM="cole-laptop"
nix run nixpkgs#git -- clone https://github.com/colefuerth/dot-files.git
cd dot-files
sudo nixos-rebuild --flake .#$SYSTEM --log-format internal-json -v switch |& nom --json
```

### build without deploying

```bash
SYSTEM="cole-wsl2"
nixos-rebuild --flake .#$SYSTEM --log-format internal-json -v build |& nom --json

# OR (build through the nix daemon on non-nixos systems)

SYSTEM="cole-vm"
nix build --log-format internal-json --verbose .#nixosConfigurations.$SYSTEM.config.system.build.toplevel |& nom --json
```

### test local config

```bash
SYSTEM="cole-laptop"
sudo nixos-rebuild --flake .#$SYSTEM test
```

## Installation on macOS (nix-darwin)

### Initial setup

1. **Install Nix with flakes** (if not already installed):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/colefuerth/dot-files.git ~/dot-files
   cd ~/dot-files
   ```

3. **Build the configuration**:
   ```bash
   SYSTEM="cole-darwin"
   nix build .#darwinConfigurations.$SYSTEM.system
   ```

4. **Apply the configuration** (first time):
   ```bash
   ./result/sw/bin/darwin-rebuild switch --flake .#cole-darwin
   ```

### Update configuration

After the initial setup, you can update your system with:

```bash
darwin-rebuild switch --flake .#cole-darwin
```

## Adding Custom Aliases

zsh sources the files in `aliases/`, both on the configured hosts (via home-manager) and in the standalone shell. To add aliases, add a file there and rebuild.
