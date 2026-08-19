{ pkgs, ... }:
{
  # Non-admin account (no `wheel`), so she can log into her own session.
  users.users.caroline = {
    isNormalUser = true;
    description = "Caroline";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "video"
    ];
    # Temporary; change it with `passwd` on first login.
    initialPassword = "caroline";
  };
}
