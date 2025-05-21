{
  description = "NixOS Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager?ref=release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      ...
    }@inputs:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems =
        f:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = f name;
          }) systems
        );
    in
    {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
      legacyPackages = forAllSystems (
        system:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ self.overlays.default ];
          };
        in
        pkgs
      );
      overlays.default = import ./overlays;

      nixosConfigurations = rec {
        workstation =
          let
            host = "workstation";
            username = "cole";
            system = "x86_64-linux";
            repoRoot = builtins.toString ./.;
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit
                inputs
                host
                username
                repoRoot
                ;
            };
            modules = [
              ./nixos/hosts/${host}/configuration.nix
              home-manager.nixosModules.home-manager
              {
                home-manager.extraSpecialArgs = {
                  inherit
                    inputs
                    host
                    username
                    repoRoot
                    ;
                };
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "bak.home-manager-${
                  self.shortRev or self.dirtyShortRev or self.lastModified or "unknown"
                }";
                home-manager.users.${username} = import ./nixos/hosts/${host}/${username}/home.nix;
              }
              sops-nix.nixosModules.sops
            ];
          };
      };
    };
}
