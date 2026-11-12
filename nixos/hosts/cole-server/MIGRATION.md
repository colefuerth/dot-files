# cole-server: Ubuntu 22.04 → NixOS

Only the SSD (`sda`) is reinstalled. `/HDD` (all app state, under `/HDD/docker`)
and `/HDD4TB` (media) are left alone, and the NixOS services use their state
in place.

| Was (Ubuntu)                                                                        | Now                                                                              |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| jellyfin, qbittorrent, filebot containers                                           | native services, same state dirs via `BindPaths`; Jellyfin transcodes with NVENC |
| nginx-proxy-manager                                                                 | `services.nginx` + ACME (`jellyfin.colef.club`)                                  |
| ddclient, tailscale, samba, libvirtd                                                | native modules                                                                   |
| minecraft (`/docker`, on the SSD)                                                   | docker compose in `/HDD/docker/minecraft`                                        |
| cron backups (all broken since 2024)                                                | `services.restic.backups` (`state`, `archive`)                                   |
| plex, openvpn, portainer, cloudflared, xrdp, motion, wireguard, handbrake, musicbot | dropped: dead or unused (state deleted in §4)                                    |

### Secrets and config that carry over

| What                                                                                   | How                                                           |
| -------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Jellyfin, qBittorrent, FileBot (users, API keys, WebUI login, license), NPM data       | already on `/HDD`, used in place                              |
| SSH host keys, Tailscale node identity, Samba passwords (`passdb.tdb` + `secrets.tdb`) | the installer copies them onto the SSD (§2)                   |
| ddclient password                                                                      | `pre-wipe-backup.sh` saves it to `/HDD/secrets/ddclient.pass` |
| ddclient settings, static IP, Samba shares, mounts, firewall                           | re-declared in `configuration.nix`                            |
| Home: SSH keys, `authorized_keys`, zsh history, Claude Code login, app configs, repos  | restored in §3, except files home-manager now owns            |
| `~/X` (now lives on Google Drive)                                                      | archived to `/HDD4TB/Archive` in §1, not restored             |
| Minecraft world, EasyAuth, RCON password; win10-node VM                                | §3                                                            |

Not carried over: the Ubuntu login password (the hashes in `configuration.nix`
replace it), and the secrets of dropped services: the Cloudflare tunnel token,
the OpenVPN PKI and `.ovpn` profiles, and the Wi-Fi PSK in `~/hostapd.conf`.
They all stay readable in the backup. The home restore (§3) also brings the
`.ovpn` files and `hostapd.conf` back into `~`.

## 1. Before the wipe

- [ ] **Renew the FileBot license** (expires 2026-11-15). Drop the new
      `license.psm` into `/HDD/docker/mediaserver/provision/filebot/`.
- [x] **Check that you know the passwords** behind the `initialHashedPassword`
      hashes in `configuration.nix` (`users.mutableUsers = false`, so they are
      the only way to log in on the console or use sudo). Test them in the VM
      with `nix run .#cole-server-vm`.
- [x] **Archive `~/X`** (it lives on Google Drive now) to `/HDD4TB/Archive`,
      which the restic `archive` job backs up to `/HDD`. Prints OK when every
      file made it in:
      ```sh
      f=/HDD4TB/Archive/X-cole-server-$(date +%F).tar.zst
      (umask 077; tar -C ~ -cf - X | zstd -T0 -q -o "$f") &&
        [ "$(zstd -dc "$f" | tar -t | wc -l)" -eq "$(find ~/X | wc -l)" ] && echo OK
      ```
- [ ] **Disable Secure Boot** in the HP firmware setup (it's on, and the
      installer and systemd-boot are unsigned).
- [ ] On the server: `cd ~/dot-files && git pull`, then
      `bash nixos/hosts/cole-server/pre-wipe-backup.sh`. Run it outside
      02:59-03:30. It saves the ddclient password to `/HDD/secrets`, stops
      cron, the crash-looping openvpn and every container, copies the SSD to
      `/HDD/ubuntu-backup-<date>/root`, cold-copies the Jellyfin, qBittorrent
      and FileBot state to `/HDD4TB/premigration-<date>`, and writes
      `/HDD/tierA-<date>.tar.zst`. If it stops partway, re-run it: the copies
      are incremental. It may ask for the sudo password again after the long
      SSD copy.
- [ ] Pull `tierA-<date>.tar.zst` to cole-desktop with the commands the script
      prints, and check its sha256. The on-box copies share hardware (and a
      power supply with no UPS) with the disks being worked on.
- [ ] **Make the installer USB** on cole-desktop: `nix build .#cole-server-installer`,
      then write `result/iso/*.iso` (~7G) to a USB stick of 16G or more with
      GNOME Disks (the stick's ⋮ menu → *Restore Disk Image*). It carries the
      whole cole-server system, so rebuild it after any config change.

## 2. Install

Boot the USB stick on the server: F9 at power-on, then its **UEFI** entry. The
installer starts by itself on the console. It shows the SSD it will erase and
where the server's identity comes from: SSH host keys (clients' known_hosts,
cole-desktop's remote-builder key), the tailscale node (100.86.198.50, `ssh rs`)
and the Samba passwords, all taken from `/HDD/ubuntu-backup-<date>`.

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

## 3. First boot

The router's WAN TCP 80 forward has to point at `192.168.69.5:80` (it went to
`:82` for NPM). Without that, ACME can't get the jellyfin cert, and nginx serves
https with a self-signed placeholder until it can.

`~/dot-files` comes back with the home restore, so copy the script over first:

```sh
scp ~/dot-files/nixos/hosts/cole-server/first-boot.sh s:/tmp/   # on cole-desktop
ssh s   # cole-desktop's key is declared; host key unchanged
sudo bash /tmp/first-boot.sh
```

`first-boot.sh` is safe to re-run. It:

- creates `/HDD/secrets/restic.pass` and prints it at the end. Save it in a
  password manager: the restic repos are useless without it.
- restores the old home from `/HDD/ubuntu-backup-*/root/home/cole`, except
  files home-manager already put there (`~/.zshrc`, `~/.zshenv`,
  `~/.ssh/config`, a few `~/.config` files; the old versions stay in the
  backup). That includes `~/dot-files` as pulled in §1. It skips `~/X` and the
  old Ubuntu nix profile.
- puts the old zsh history in front of what this login has added.
- checks that cole has a Samba password, from the old passdb.
- lists root's old home and crontabs, the things only root could see on Ubuntu.
- chowns Jellyfin's state to cole, since the container ran as root, and
  restarts it.
- runs ddclient once. If it warns that `ddclient.pass` is missing, copy the
  value after `password=` from the backup's `etc/ddclient.conf` into it by hand:
  `sudo sh -c "umask 077; printf '%s' '<the token>' > /HDD/secrets/ddclient.pass"`.

Then check each service:

- **Jellyfin**: <http://cole-server.local:8096>. Version 12.4, libraries
  `/media/movies` and `/media/tv`, users and watch state intact. Under
  Dashboard → Networking, add `127.0.0.1` to *Known proxies* (nginx is local
  now). Playback → Transcoding should show NVIDIA NVENC (set in
  `configuration.nix`, so dashboard changes there are reset on restart). Play
  something with a forced lower bitrate, and `nvidia-smi` should list
  jellyfin-ffmpeg.
- **qBittorrent**: <http://cole-server.local:8085>, same login. All 25 torrents should
  be present. Under Options → Downloads, remove the `/watch_handbrake`
  monitored folder (Handbrake is gone); the other two stay.
- **FileBot**: `sudo systemctl start filebot-amc; journalctl -u filebot-amc`.
  It should say *No files selected for processing* because the exclude list
  matched. It reads the container's `license.psm` directly.
- **ddclient**: `journalctl -u ddclient` should show `SUCCESS` for `@`.
- **TLS**: `journalctl -u acme-order-renew-jellyfin.colef.club` should show the
  certificate obtained (`acme-jellyfin.colef.club` is only the self-signed
  placeholder and is always green). From outside, the cert's issuer should be
  Let's Encrypt.
- **Tailscale**: `tailscale ip -4` should print `100.86.198.50`.
- **Backups**: `sudo systemctl start restic-backups-state` (Jellyfin blinks off
  for a few seconds while its DB is copied), then `sudo restic-state snapshots`.

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

## 4. Afterwards

- cole-desktop: drop `?remote-program=/nix/var/nix/profiles/default/bin/nix-daemon`
  from its `nix.buildMachines` hostName. NixOS has `nix-daemon` on PATH.
- Delete Cloudflare tunnel `62f41e32-…` and its credentials. It carried no
  traffic: colef.club DNS is on Namecheap.
- Router: remove the WireGuard forward (51820/udp), and 25565 if Minecraft
  stays off.
- Delete the state of the dropped WireGuard, Handbrake and musicbot containers:
  `sudo rm -rf /HDD/docker/{wireguard,handbrake,musicbot-git} /HDD/handbrake`
  (`/HDD/handbrake` is empty; no torrent saves there).
- After a few weeks of normal running: `/HDD/ubuntu-backup-*`,
  `/HDD4TB/premigration-*`, `/HDD/tierA-*`, and the Plex leftovers
  (`/HDD/docker/mediaserver/provision/plex`, `/HDD/docker/archive`).

## Future reinstalls

Build a fresh installer USB and boot it (§2, no backup script needed). Once the
restic `state` repo exists, the installer takes the identity files from its
latest snapshot instead of `ubuntu-backup-*`. After first boot, restore the home dir without touching what home-manager
just put there:
`sudo restic-state restore latest --include /home/cole --overwrite never --target /`.
Every other piece of state is already on `/HDD`.
