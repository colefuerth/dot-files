{ lib, ... }:
{
  # Inherit cole's environment instead of keeping a copy in sync; she only
  # uses the laptop for games. Drop what is tied to cole's identity.
  imports = [ ../cole/home.nix ];

  programs.git.enable = lib.mkForce false;
  programs.gh.enable = lib.mkForce false;
  # Only used to verify cole's commit signatures.
  home.file.".ssh/allowed_signers".enable = false;
}
