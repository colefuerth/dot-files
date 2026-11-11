inputs: final: prev:
let
  inherit (prev) lib;
in
(lib.composeManyExtensions [
  (import ./btop)
  (import ./firefox.nix)
  (import ./flameshot inputs)
  (import ./fresh-editor)
  (import ./linux-wallpaperengine)
  (import ./okular)
  (import ./openrazer)
  (import ./python-test-skips.nix)
  (import ./r2modman)
  (import ./signal-desktop)
  # (import ./freetype-qdoled)
  # (import ./gh)
  # disable SSH overlay and use home-manager to fix ~/.ssh/config perms
  # (import ./openssh)
])
  final
  prev
