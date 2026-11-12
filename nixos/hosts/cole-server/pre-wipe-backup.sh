#!/usr/bin/env bash
# One-shot backup of the Ubuntu cole-server before reinstalling it as NixOS.
# Run ON the server, as cole, right before the wipe (see MIGRATION.md):
#   bash ~/dot-files/nixos/hosts/cole-server/pre-wipe-backup.sh
#
#  1. saves records that only exist in the running system (docker inspect, VM xml, ...),
#     and the ddclient password to /HDD/secrets, where the NixOS config reads it
#  2. stops cron + all containers so the copies are consistent (the server is
#     going down anyway; undo with `sudo systemctl start cron` + `docker start`)
#  3. copies the whole root SSD, minus regenerable bulk, to /HDD, which the
#     reinstall leaves untouched
#  4. cold-copies the app state NixOS will take over in place to /HDD4TB
#     (Jellyfin's 12.2 -> 12.4 DB upgrade is one-way; this is the rollback)
#  5. packs the irreplaceable subset into one tarball to pull off-box
# Nothing on the SSD is modified or deleted.
set -euo pipefail

DATE=$(date +%F)
OUT=/HDD/ubuntu-backup-$DATE # root/ = the SSD, records/ = runtime records
PREMIG=/HDD4TB/premigration-$DATE
TIER_A=tierA-$DATE.tar.zst # lands in /HDD
PROVISION=/HDD/docker/mediaserver/provision

mountpoint -q /HDD && mountpoint -q /HDD4TB || {
	echo "/HDD and /HDD4TB must be mounted" >&2
	exit 1
}
sudo -v

echo "== 1/5 runtime records -> $OUT/records"
sudo install -d -m 700 "$OUT" "$OUT/records"
rec() { sudo tee "$OUT/records/$1" >/dev/null; }
# shellcheck disable=SC2046 # one arg per container id
docker inspect $(docker ps -aq) | rec docker-inspect.json # holds env secrets; dir is 0700
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | rec docker-ps.txt
crontab -l | rec crontab-cole.txt
virsh -c qemu:///system dumpxml win10-node | rec win10-node.xml
dpkg --get-selections | rec dpkg-selections.txt

# The namecheap DDNS password (32 hex chars). Debian writes it as
# password=<pw> or password='<pw>'; anything else falls back to MIGRATION.md §3.
sudo install -d -m 700 /HDD/secrets
ddpass=$(sudo sed -nE "s/^([^#]*[,[:space:]])?password[[:space:]]*=[[:space:]]*['\"]?([[:alnum:]]+).*/\2/p" /etc/ddclient.conf)
if [[ $ddpass =~ ^[0-9a-f]{32}$ ]]; then
	printf '%s' "$ddpass" | sudo sh -c 'umask 077; cat >/HDD/secrets/ddclient.pass'
	echo "   ddclient password -> /HDD/secrets/ddclient.pass"
else
	echo "!! couldn't parse the ddclient password; copy it by hand after the install (MIGRATION.md §3)" >&2
fi
unset ddpass

echo "== 2/5 stopping cron (02:59 docker-restart.sh), openvpn and all containers"
# openvpn-server@server crash-loops every 5s (dropped anyway); its churn of tun0,
# /tmp dirs and resolv.conf would otherwise show up in the copy and the verify
sudo systemctl stop cron openvpn-server@server
running=$(docker ps -q)
[ -z "$running" ] || docker stop $running >/dev/null

echo "== 3/5 root SSD -> $OUT/root"
# --one-file-system keeps it off /HDD, /HDD4TB, /boot/efi and pseudo filesystems.
# Skipped: swap, the 22G ~/hv tarball (a bad copy of /docker + /HDD/docker),
# caches, docker images (re-pullable; volumes are empty), logs, /nix and /usr
# (except /usr/local, minus CUDA), snaps.
sudo rsync -aHAXS --numeric-ids --one-file-system --info=progress2 \
	--exclude=/swapfile \
	--exclude=/home/cole/hv \
	--exclude='/home/*/.cache/' \
	--exclude='/home/*/.vscode-server*/' \
	--exclude=/var/lib/docker/ \
	--exclude=/var/lib/containerd/ \
	--exclude=/var/lib/snapd/ \
	--exclude=/snap/ \
	--exclude=/var/log/ \
	--exclude=/var/cache/ \
	--exclude=/nix/ \
	--exclude='/usr/local/cuda*' \
	--include=/usr/ \
	--include='/usr/local/***' \
	--exclude='/usr/*' \
	/ "$OUT/root/" || [ $? -eq 24 ] # 24: files vanished on the live system

echo "== 4/5 cold copy of migrated app state -> $PREMIG"
sudo install -d -m 700 "$PREMIG"
sudo rsync -aHAXS --numeric-ids --info=progress2 \
	"$PROVISION/jellyfin" "$PROVISION/qbittorrent" "$PROVISION/filebot" \
	/HDD/docker/mediaserver/docker-compose.yml \
	"$PREMIG/"

echo "== 5/5 irreplaceable subset -> /HDD/$TIER_A"
# ~10G: ssh keys, the minecraft world + its two 2024 world archives, host keys,
# tailscale identity, ddns password, and records/. (~/X is archived separately,
# MIGRATION.md §1.)
sudo tar -C "$OUT/root" -cf - \
	home/cole/.ssh \
	docker/minecraft \
	etc/ssh var/lib/tailscale etc/ddclient.conf \
	-C "$OUT" records |
	zstd -T0 | sudo tee "/HDD/$TIER_A" >/dev/null
sudo chown cole:cole "/HDD/$TIER_A"
chmod 600 "/HDD/$TIER_A"
(cd /HDD && sha256sum "$TIER_A" >"$TIER_A.sha256")

echo "== verify: each rsync below should print nothing"
# (only static paths: all of /etc and tailscaled's own log files keep changing)
for p in home/cole/.ssh docker etc/ssh var/lib/tailscale; do
	echo "-- /$p"
	sudo rsync -aHAXn -c --itemize-changes --exclude='tailscaled.log*' "/$p/" "$OUT/root/$p/"
done
sudo cmp /etc/ddclient.conf "$OUT/root/etc/ddclient.conf"
for p in jellyfin qbittorrent filebot; do
	echo "-- $PROVISION/$p"
	sudo rsync -aHAXn -c --itemize-changes "$PROVISION/$p/" "$PREMIG/$p/"
done
zstd -tq "/HDD/$TIER_A"

cat <<EOF

Done. Now, from cole-desktop, pull the irreplaceable subset off-box:
  mkdir -p ~/backups/cole-server && chmod 700 ~/backups/cole-server
  rsync -P s:/HDD/$TIER_A s:/HDD/$TIER_A.sha256 ~/backups/cole-server/
  (cd ~/backups/cole-server && sha256sum -c $TIER_A.sha256)
It contains host keys and the tailscale identity: keep it on an encrypted disk.
Cron and all containers are stopped; continue with the install in MIGRATION.md.
EOF
