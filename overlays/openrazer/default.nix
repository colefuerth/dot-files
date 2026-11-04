# Onboard button remapping and macros for the Razer Naga V2 Pro, from the
# unmerged upstream PR https://github.com/openrazer/openrazer/pull/2962.
# It's built on master, which has moved too far past v3.12.4 for the patch to
# apply, so build the PR's head commit instead. The kernel module is swapped in
# from this same src via hardware.openrazer.packages.kernel in
# nixos/common/razer.nix. Drop both once a release includes the PR.
final: prev:
let
  version = "3.12.4-unstable-2026-10-22";
  src = prev.fetchFromGitHub {
    owner = "opdude";
    repo = "openrazer";
    rev = "73071e54b3eb6f657518ea95fd223d22e97b2432";
    hash = "sha256-bJ9Bllnkv9Vcee0gcCvzPqpgmDoW3bxFy0TKxZsI0R0=";
  };
in
{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      openrazer = pyprev.openrazer.overridePythonAttrs { inherit version src; };
      openrazer-daemon = pyprev.openrazer-daemon.overridePythonAttrs { inherit version src; };
    })
  ];
}
