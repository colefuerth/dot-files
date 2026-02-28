inputs: final: prev:
let
  inherit (prev) lib;
in
(lib.composeManyExtensions [
  (import ./chromium)
  (import ./flameshot inputs)
  (import ./fresh-editor)
  (import ./gh)
  # disable SSH overlay and use home-manager to fix ~/.ssh/config perms
  # (import ./openssh)
])
  final
  prev
