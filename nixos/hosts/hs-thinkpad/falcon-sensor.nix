{ inputs, ... }:
{
  imports = [
    "${inputs.heaviside-nixpkgs.outPath}/packages/external/falcon-sensor/module.nix"
  ];

  services.falcon-sensor = {
    enable = true;
    package = inputs.heaviside-nixpkgs.packages.x86_64-linux.falcon-sensor;
    # CID should be set manually after rebuild using:
    #   sudo falconctl -s --cid=YOUR_CID --provisioning-token=YOUR_TOKEN
    # Or configure via sops-nix:
    #   cid = config.sops.secrets.falcon-cid.value;
  };
}
