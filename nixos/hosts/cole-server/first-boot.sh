#!/usr/bin/env bash
# First boot after the Ubuntu -> NixOS install (MIGRATION.md §3). On the server:
#   sudo bash first-boot.sh
# Safe to re-run: it never overwrites a file, and only creates restic.pass and
# merges the zsh history the first time.
set -euo pipefail
shopt -s nullglob

die() {
	echo "!! $*" >&2
	exit 1
}

[ "$(id -u)" = 0 ] || die "run with sudo"
backups=(/HDD/ubuntu-backup-*/root)
[ ${#backups[@]} -gt 0 ] || die "no /HDD/ubuntu-backup-*/root"
B=${backups[-1]}
H=/home/cole
PROVISION=/HDD/docker/mediaserver/provision

echo "== secrets in /HDD/secrets"
install -d -m 700 /HDD/secrets
if [ -s /HDD/secrets/ddclient.pass ]; then
	echo "ddclient.pass: present"
else
	echo "!! ddclient.pass is missing: MIGRATION.md §3 has the manual fallback"
fi
new_restic=false
if [ ! -s /HDD/secrets/restic.pass ]; then
	(umask 077 && openssl rand -base64 32 >/HDD/secrets/restic.pass)
	new_restic=true
fi

echo "== home: $B/home/cole -> $H, keeping what home-manager put there"
rsync -aHAX --ignore-existing --exclude=/X/ --exclude=/torrents_handbrake/ \
	--exclude=/.nix-profile --exclude=/.local/state/nix/ "$B/home/cole/" "$H/"

# zsh history: the old one, then what was typed since first boot. Skipped when
# the current file already starts with the old one (a re-run).
old=$B/home/cole/.zsh_history
if [ -f "$old" ] && ! cmp -s -n "$(stat -c %s "$old")" "$old" "$H/.zsh_history"; then
	{
		cat "$old"
		if [ -f "$H/.zsh_history" ]; then cat "$H/.zsh_history"; fi
	} >"$H/.zsh_history.new"
	chown cole:cole "$H/.zsh_history.new"
	chmod 600 "$H/.zsh_history.new"
	mv "$H/.zsh_history.new" "$H/.zsh_history"
	echo "zsh history merged"
fi

echo "== samba users (from the old passdb)"
if pdbedit -L | grep -q '^cole:'; then
	pdbedit -L
else
	echo "!! cole has no Samba password: run sudo smbpasswd -a cole"
fi

echo "== things only root could see on Ubuntu (look, nothing to do unless something matters)"
ls -la "$B/root"
for f in "$B"/var/spool/cron/crontabs/*; do
	echo "-- crontab ${f##*/}:"
	grep -v '^#' "$f" || true
done

echo "== jellyfin: hand its state to cole (the container ran as root)"
chown -R cole:cole "$PROVISION/jellyfin"
systemctl reset-failed jellyfin
systemctl restart jellyfin
sleep 15
systemctl is-active jellyfin || journalctl -u jellyfin -b --no-pager -n 15

echo "== ddclient"
systemctl start ddclient || true
journalctl -u ddclient -b --no-pager -n 3 -o cat

if $new_restic; then
	cat <<EOF

== NEW restic password: save it in your password manager. The backups in
   /HDD4TB/restic and /HDD/restic-archive are unreadable without it.
$(cat /HDD/secrets/restic.pass)
EOF
fi
echo
echo "== done. Jellyfin upgrades its database on this first start; watch it with"
echo "   journalctl -fu jellyfin, then do the checks in MIGRATION.md §3."
