final: prev:
let
  inherit (prev) lib;
in
(lib.composeManyExtensions [
  (import ./chromium)
  # (import ./firefoxpwa)
  # disable SSH overlay and use home-manager to fix ~/.ssh/config perms
  # (import ./openssh)
])
  final
  prev
