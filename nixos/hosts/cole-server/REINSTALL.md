# cole-server: reinstall

Only the SSD (`sda`) is reinstalled. `/HDD` (all app state, under `/HDD/docker`,
and `/HDD/secrets`) and `/HDD4TB` (media and the restic `state` repo) are left
alone, and the services use their state in place.

## Install

**Make the installer USB** on cole-desktop: `nix build .#cole-server-installer`,
then write `result/iso/*.iso` (~7G) to a USB stick of 16G or more with
GNOME Disks (the stick's ⋮ menu → *Restore Disk Image*). It carries the
whole cole-server system, so rebuild it after any config change.

Secure Boot stays off in the HP firmware setup: the installer and systemd-boot
are unsigned.

Boot the USB stick on the server: F9 at power-on, then its **UEFI** entry. The
installer starts by itself on the console. It shows the SSD it will erase and
where the server's identity comes from: SSH host keys (clients' known_hosts,
cole-desktop's remote-builder key), the tailscale node (100.86.198.50, `ssh rs`)
and the Samba passwords, all restored from the latest snapshot of the restic
`state` repo (`/HDD4TB/restic`, password in `/HDD/secrets/restic.pass`).

Type `erase`. It partitions only the SSD, which it finds by serial number
(GPT: `BOOT` ESP + `nixos` btrfs with cole-desktop's `@`, `@home`, `@nix`,
`@log` and `@snapshots` subvolumes, no LUKS since there's no TPM). The WD drives are only mounted read-only. It then copies the identity
files and installs the system from the stick, which takes about 10-20 minutes
with no network or building. When it says done, press Enter and pull the stick
at the HP logo. Pulling it before the reboot crashes the reboot, because the
installer runs from the stick.

Anything else at the prompt aborts with nothing changed. If it stops with an
error, `sudo install-cole-server` reruns it. What it does, step by step, is
`install.sh` next to this file.

## First boot

Restore the home dir without touching what home-manager just put there:
`sudo restic-state restore latest --include /home/cole --overwrite never --target /`.
Every other piece of state is already on `/HDD`.

## Left over from the Ubuntu migration

Delete this section once these are done.

- **Jellyfin**: under Dashboard → Networking, add `127.0.0.1` to *Known
  proxies* (nginx is local now).
- **qBittorrent**: under Options → Downloads, remove the `/watch_handbrake`
  monitored folder (Handbrake is gone).
- **FileBot**: the license expires 2026-11-15. Drop the new `license.psm` into
  `/HDD/docker/mediaserver/provision/filebot/`.
- Delete Cloudflare tunnel `62f41e32-…` and its credentials. It carried no
  traffic: colef.club DNS is on Namecheap.
- Router: remove the WireGuard forward (51820/udp), and 25565 if Minecraft
  stays off.
- Delete the state of the dropped WireGuard, Handbrake and musicbot containers:
  `sudo rm -rf /HDD/docker/{wireguard,handbrake,musicbot-git} /HDD/handbrake`
  (`/HDD/handbrake` is empty; no torrent saves there).
- After a few weeks of normal running, and once the Minecraft world and the
  VM below are restored or given up (they only exist in these backups):
  `/HDD/ubuntu-backup-*`, `/HDD4TB/premigration-*`, `/HDD/tierA-*`, and the
  Plex leftovers (`/HDD/docker/mediaserver/provision/plex`,
  `/HDD/docker/archive`).

Minecraft, when wanted:

```sh
B=$(sudo sh -c 'ls -d /HDD/ubuntu-backup-*/root' | tail -1)
sudo mv "$B/docker/minecraft" /HDD/docker/minecraft   # cole-owned, same disk: instant
cd /HDD/docker/minecraft
cp ~/dot-files/docker/minecraft/docker-compose.yml .   # pins VERSION 26.2
printf 'RCON_PASSWORD=%s\n' "$(sed -n 's/^rcon.password=//p' server/server.properties)" > .env
docker compose up -d
```

The `win10-node` VM, if wanted (plain `virsh` talks to `qemu:///system`, as on
Ubuntu):

```sh
B=$(sudo sh -c 'ls -d /HDD/ubuntu-backup-*/root' | tail -1)
sudo install -d /var/lib/libvirt/images
sudo cp "$B/var/lib/libvirt/images/win10-node.qcow2" /var/lib/libvirt/images/   # 38G
sudo sed 's#/usr/bin/qemu-system-x86_64#/run/libvirt/nix-emulators/qemu-system-x86_64#' \
  "${B%/root}/records/win10-node.xml" >/tmp/win10-node.xml
virsh define /tmp/win10-node.xml
virsh net-autostart default && virsh net-start default   # NixOS doesn't autostart it
```

The Pi Network node ports (Ubuntu's DNAT of tcp 31400-31409 to the VM) aren't
ported. libvirt's forward rules rejected new inbound connections on Ubuntu
anyway.
