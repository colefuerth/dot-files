{ inputs, ... }:
{
  # Import the GlobalProtect module from heaviside-nixpkgs
  # (automatically disables upstream module and provides simpler alternative)
  imports = [
    "${inputs.heaviside-nixpkgs.outPath}/packages/external/globalprotect/module.nix"
  ];

  # Enable and configure GlobalProtect
  services.globalprotect = {
    enable = true;
    package = inputs.heaviside-nixpkgs.packages.x86_64-linux.globalprotect;
    # enableUserService = true;  # Enabled by default (required for CLI/GUI)
  };
}
