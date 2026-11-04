{
  config,
  inputs,
  pkgs,
  username,
  ...
}:
let
  # Patched for Naga V2 Pro onboard remapping; see overlays/openrazer.
  inherit (pkgs.python3Packages.openrazer-daemon) src version;
in
{
  # RazerForLinux (our fork): GUI/CLI for the Naga's onboard buttons, macros and profiles.
  imports = [ inputs.razerforlinux.nixosModules.default ];
  programs.razerforlinux.enable = true;

  hardware.openrazer = {
    enable = true;
    packages.kernel = config.boot.kernelPackages.openrazer.overrideAttrs {
      inherit src;
      version = "${version}-${config.boot.kernelPackages.kernel.version}";
    };
  };
  environment.systemPackages = with pkgs; [
    openrazer-daemon
    polychromatic
  ];
  users.users.${username}.extraGroups = [ "openrazer" ];
}
