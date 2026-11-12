# USB installer for cole-server: a minimal NixOS ISO that carries the server's
# whole system closure, so nothing is built or downloaded during the install.
# Booting it starts install.sh on the console, which asks before it erases the
# SSD. Build: nix build .#cole-server-installer (result/iso/*.iso, ~7G)
{
  pkgs,
  modulesPath,
  coleServer,
  ...
}:
let
  install = pkgs.writeShellApplication {
    name = "install-cole-server";
    runtimeInputs = with pkgs; [
      btrfs-progs
      dosfstools
      parted
      restic
    ];
    text = ''exec bash ${./install.sh} ${coleServer} "$@"'';
  };
in
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";
  isoImage.storeContents = [ coleServer ];
  # 14G of store paths; zstd -19 (the default) would take far longer for a few % less
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  environment.systemPackages = [ install ];

  # The ISO auto-logs in as nixos on tty1: run the installer there, then reboot
  programs.bash.loginShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && sudo install-cole-server; then
      read -r -p "Remove the USB stick, then press Enter to reboot into cole-server. "
      sudo systemctl reboot
    fi
  '';
}
