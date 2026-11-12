#!/usr/bin/env bash
# Installs cole-server onto its SSD (MIGRATION.md §2). The installer ISO
# (nix build .#cole-server-installer) runs this on its console with the system
# closure it carries; by hand, as root on any NixOS installer:
#   bash install.sh /nix/store/...-nixos-system-cole-server-...
#
# Only the SSD below is written. The WD drives are mounted read-only to fetch
# the server's identity: SSH host keys, the tailscale node and Samba passwords.
# They come from the restic `state` repo once it exists (later reinstalls),
# otherwise from the pre-wipe Ubuntu backup (pre-wipe-backup.sh).
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
[ -e "$HDD" ] || die "/HDD (WD 1TB) not found: it holds the identity backup"

mkdir -p /hdd /hdd4tb
mountpoint -q /hdd || mount -o ro "$HDD" /hdd
if [ -e "$HDD4TB" ] && ! mountpoint -q /hdd4tb; then mount -o ro "$HDD4TB" /hdd4tb; fi

backups=(/hdd/ubuntu-backup-*/root)
if [ -f /hdd4tb/restic/config ] && [ -f /hdd/secrets/restic.pass ]; then
	src=restic
	desc="the restic repo /HDD4TB/restic (latest snapshot)"
elif [ ${#backups[@]} -gt 0 ]; then
	src=${backups[-1]}
	desc=/HDD${src#/hdd}
	for f in etc/ssh/ssh_host_ed25519_key var/lib/tailscale/tailscaled.state \
		var/lib/samba/private/passdb.tdb var/lib/samba/private/secrets.tdb; do
		[ -e "$src/$f" ] || die "$desc/$f is missing"
	done
else
	die "no identity source: neither /HDD4TB/restic nor /HDD/ubuntu-backup-*"
fi

cat <<EOF

Installs: $SYSTEM
Identity (SSH host keys, tailscale, Samba passwords) from: $desc
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
if [ "$src" = restic ]; then
	restic -r /hdd4tb/restic -p /hdd/secrets/restic.pass --no-lock --cache-dir /tmp/restic-cache \
		restore latest --target /mnt \
		--include /etc/ssh --include /var/lib/tailscale --include /var/lib/samba/private
else
	install -d -m 755 /mnt/etc/ssh
	cp -a "$src"/etc/ssh/ssh_host_* /mnt/etc/ssh/
	install -d -m 700 /mnt/var/lib/tailscale
	cp -a "$src"/var/lib/tailscale/. /mnt/var/lib/tailscale/
	install -d -m 755 /mnt/var/lib/samba
	install -d -m 700 /mnt/var/lib/samba/private
	cp -a "$src"/var/lib/samba/private/{passdb,secrets}.tdb /mnt/var/lib/samba/private/
fi

echo "== installing (copies ~14G)"
nixos-install --system "$SYSTEM" --root /mnt --no-root-passwd --no-channel-copy

umount -R /mnt
umount /hdd
if mountpoint -q /hdd4tb; then umount /hdd4tb; fi
echo "== done: cole-server is installed on the SSD"
