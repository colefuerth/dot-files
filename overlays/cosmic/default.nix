inputs: final: prev: 
let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.system};
in
{
  # Pull COSMIC packages from nixpkgs-unstable to get version 1.0
  inherit (unstable)
    cosmic-bg
    cosmic-applets
    cosmic-comp
    cosmic-panel
    cosmic-settings
    cosmic-edit
    cosmic-files
    cosmic-greeter
    cosmic-launcher
    cosmic-term
    cosmic-notifications
    cosmic-idle
    cosmic-osd
    cosmic-player
    cosmic-workspaces-epoch
    cosmic-applibrary
    cosmic-session
    xdg-desktop-portal-cosmic
    cosmic-initial-setup;
}