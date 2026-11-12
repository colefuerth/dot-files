{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../common
    ../../common/cachix.nix
    ../../common/user.nix
    ./hardware-configuration.nix
    inputs.vscode-server.nixosModules.default
  ];

  # Select the kernel version
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Bootloader — use the default one generated with the system for safety
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.useOSProber = true;

  networking.wireless.enable = lib.mkForce false;

  # Enable the X11 windowing system.
  services.xserver.enable = false;

  # VM configuration for headless operation with serial console
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 2048;
      cores = 2;
      graphics = false;
      # Use serial console for terminal access
      qemu.options = [
        "-nographic"
        "-serial mon:stdio"
      ];
      # Forward SSH port for easy access
      forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
    };
    # Enable serial console getty
    boot.kernelParams = [ "console=ttyS0" ];
    systemd.services."serial-getty@ttyS0".enable = true;
  };

  services.vscode-server.enable = true;

  # cole's account and password hash come from common/user.nix.
  users.mutableUsers = false; # Required for declarative password management in VMs
  users.users.root.initialPassword = "root"; # Root login for debugging

  environment.systemPackages = with pkgs; [
    claude-code
    vscode-with-extensions
  ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  system.stateVersion = "26.05";

}
