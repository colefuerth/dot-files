# win10-vm is kept out of scripts.nix's shared list: its virt-manager/libvirt
# deps are a ~1.4 GiB closure, wanted only on the hosts that run libvirtd
# (cole-desktop, cole-server). Wrapped the same way as scripts.nix's bashScript.
{ pkgs }:
pkgs.runCommandLocal "win10-vm"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = "win10-vm";
  }
  ''
    install -Dm755 ${../scripts/win10-vm} $out/bin/win10-vm
    patchShebangs $out/bin/win10-vm
    # virt-install and virsh; hostname comes from coreutils
    wrapProgram $out/bin/win10-vm --prefix PATH : ${
      pkgs.lib.makeBinPath (
        with pkgs;
        [
          virt-manager
          libvirt
          coreutils
        ]
      )
    }
  ''
