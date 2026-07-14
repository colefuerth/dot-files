inputs: final: prev:
let
  inherit (prev) lib;
in
(lib.composeManyExtensions [
  (import ./btop)
  (import ./flameshot inputs)
  (import ./signal-desktop)
  # (import ./freetype-qdoled)
  # (import ./fresh-editor)
  # (import ./gh)
  # disable SSH overlay and use home-manager to fix ~/.ssh/config perms
  # (import ./openssh)
])
  final
  prev
