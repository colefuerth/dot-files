#!/usr/bin/env bash
set -euo pipefail

DISK="${1:-}"
FLAKE_REPO="https://github.com/colefuerth/dot-files.git"
MOUNT="/mnt"

if [[ -z "$DISK" ]]; then
  echo "Usage: $0 <disk> (e.g., /dev/nvme0n1)"
  exit 1
fi

if [[ ! -b "$DISK" ]]; then
  echo "Error: $DISK is not a block device"
  exit 1
fi

echo "=== WARNING: This will WIPE $DISK ==="
lsblk "$DISK"
echo ""
read -rp "Type 'yes' to continue: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

# Partition: 512M ESP + rest for LUKS
echo ">>> Partitioning $DISK..."
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:ESP "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:nixos "$DISK"
partprobe "$DISK"
sleep 1

# LUKS encryption
echo ">>> Setting up LUKS encryption..."
cryptsetup luksFormat /dev/disk/by-partlabel/nixos
cryptsetup luksOpen /dev/disk/by-partlabel/nixos cryptroot

# Filesystems
echo ">>> Creating filesystems..."
mkfs.fat -F32 -n ESP /dev/disk/by-partlabel/ESP
mkfs.btrfs -f -L nixos /dev/mapper/cryptroot

# Create btrfs subvolumes
echo ">>> Creating btrfs subvolumes..."
mount /dev/mapper/cryptroot "$MOUNT"
btrfs subvolume create "$MOUNT/@"
btrfs subvolume create "$MOUNT/@home"
btrfs subvolume create "$MOUNT/@nix"
btrfs subvolume create "$MOUNT/@log"
btrfs subvolume create "$MOUNT/@snapshots"
umount "$MOUNT"

# Mount subvolumes
OPTS="compress=zstd,noatime,ssd,discard=async"
echo ">>> Mounting subvolumes..."
mount -o "subvol=@,$OPTS" /dev/mapper/cryptroot "$MOUNT"
mkdir -p "$MOUNT"/{home,nix,var/log,.snapshots,boot}
mount -o "subvol=@home,$OPTS" /dev/mapper/cryptroot "$MOUNT/home"
mount -o "subvol=@nix,$OPTS" /dev/mapper/cryptroot "$MOUNT/nix"
mount -o "subvol=@log,$OPTS" /dev/mapper/cryptroot "$MOUNT/var/log"
mount -o "subvol=@snapshots,$OPTS" /dev/mapper/cryptroot "$MOUNT/.snapshots"
mount /dev/disk/by-partlabel/ESP "$MOUNT/boot"

# Clone dot-files repo
echo ">>> Cloning dot-files..."
mkdir -p "$MOUNT/home/cole"
git clone "$FLAKE_REPO" "$MOUNT/home/cole/dot-files"

# Install NixOS
echo ">>> Installing NixOS..."
nixos-install --flake "$MOUNT/home/cole/dot-files#cole-desktop" --no-root-passwd --log-format internal-json -v \
  |& nix run nixpkgs#nix-output-monitor -- --json

echo ""
echo "=== Installation complete! ==="
echo "You can now reboot into your new system."
echo "Remember to remove the live USB."
