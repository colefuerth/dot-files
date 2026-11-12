#!/usr/bin/env bash
# Installs cole-server onto its SSD (REINSTALL.md). The installer ISO
# (nix build .#cole-server-installer) runs this on its console with the system
# closure it carries; by hand, as root on any NixOS installer:
#   bash install.sh /nix/store/...-nixos-system-cole-server-...
#
# Only the SSD below is written. The WD drives are mounted read-only to fetch
# the server's identity: SSH host keys, the tailscale node and Samba passwords,
# from the latest snapshot of the restic `state` repo.
set -euo pipefail
shopt -s nullglob

SYSTEM=${1:?usage: install.sh <cole-server system path>}
DISK=/dev/disk/by-id/ata-CT480BX500SSD1_2217E62A7D7E
HDD=/dev/disk/by-uuid/f31ab4ab-891c-4861-9bc0-0059cbda3267    # /HDD
HDD4TB=/dev/disk/by-uuid/6f891660-4d30-49cc-9651-8aaa2597a43e # /HDD4TB

die() {
	echo "!! $*" >&2
	exit 1
}

[ "$(id -u)" = 0 ] || die "run as root"
[ -e "$SYSTEM/bin/switch-to-configuration" ] || die "$SYSTEM is not a NixOS system"
[ -d /sys/firmware/efi ] || die "booted in legacy BIOS mode: pick the USB stick's UEFI boot entry"
udevadm settle # tty1 autostarts early; let the disk links appear first
[ -e "$DISK" ] || die "SSD $DISK not found: is this cole-server?"
[ -e "$HDD" ] || die "/HDD (WD 1TB) not found: it holds the restic password"
[ -e "$HDD4TB" ] || die "/HDD4TB (WD 4TB) not found: it holds the restic repo"

mkdir -p /hdd /hdd4tb
mountpoint -q /hdd || mount -o ro "$HDD" /hdd
mountpoint -q /hdd4tb || mount -o ro "$HDD4TB" /hdd4tb
[ -f /hdd4tb/restic/config ] || die "no restic repo at /HDD4TB/restic"
[ -f /hdd/secrets/restic.pass ] || die "no /HDD/secrets/restic.pass"

cat <<EOF

Installs: $SYSTEM
Identity (SSH host keys, tailscale, Samba passwords) from: the restic repo /HDD4TB/restic (latest snapshot)
ERASES this disk:
$(lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL "$(readlink -f "$DISK")")

EOF
read -r -p "Type 'erase' to continue: " answer
[ "$answer" = erase ] || die "aborted; nothing was changed"

echo "== partitioning"
if mountpoint -q /mnt; then umount -R /mnt; fi # left over from a failed run
for p in "$DISK"-part*; do wipefs -aq "$p"; done
wipefs -aq "$DISK"
parted -s "$DISK" -- mklabel gpt \
	mkpart ESP fat32 1MiB 1GiB set 1 esp on \
	mkpart nixos btrfs 1GiB 100%
udevadm settle # the -partN links appear asynchronously
mkfs.fat -F32 -n BOOT "$DISK-part1"
mkfs.btrfs -qf -L nixos "$DISK-part2"
udevadm settle

# Subvolumes and mount options as in hardware-configuration.nix
mount "$DISK-part2" /mnt
for v in @ @home @nix @log @snapshots; do btrfs -q subvolume create "/mnt/$v"; done
umount /mnt
opts=compress=zstd,noatime,ssd,discard=async
mount -o "subvol=@,$opts" "$DISK-part2" /mnt
for m in home:@home nix:@nix var/log:@log .snapshots:@snapshots; do
	mount --mkdir -o "subvol=${m#*:},$opts" "$DISK-part2" "/mnt/${m%%:*}"
done
mount --mkdir -o umask=077 "$DISK-part1" /mnt/boot

echo "== identity"
restic -r /hdd4tb/restic -p /hdd/secrets/restic.pass --no-lock --cache-dir /tmp/restic-cache \
	restore latest --target /mnt \
	--include /etc/ssh --include /var/lib/tailscale --include /var/lib/samba/private

echo "== installing (copies ~14G)"
nixos-install --system "$SYSTEM" --root /mnt --no-root-passwd --no-channel-copy

umount -R /mnt
umount /hdd /hdd4tb
echo "== done: cole-server is installed on the SSD"
