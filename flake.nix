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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      nixos-wsl,
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

      # Helper to create the common module list for a host configuration
      mkConfigModules =
        {
          host,
          username,
          repoRoot,
          backupSuffix ? "bak.home-manager-${self.shortRev or self.dirtyShortRev or self.lastModified or "unknown"}",
        }:
        [
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
            home-manager.backupFileExtension = backupSuffix;
            home-manager.users.${username} = import ./nixos/users/${username}/home.nix;
          }
          sops-nix.nixosModules.sops
        ]
        ++ (nixpkgs.lib.optionals (nixpkgs.lib.strings.hasSuffix "wsl2" host) [
          nixos-wsl.nixosModules.wsl
        ]);

      mkNixosConfiguration =
        {
          host,
          username,
          system,
          repoRoot,
        }:
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
          modules = mkConfigModules {
            inherit
              host
              username
              repoRoot
              ;
          };
        };
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
        cole-laptop = mkNixosConfiguration {
          host = "cole-laptop";
          username = "cole";
          system = "x86_64-linux";
          repoRoot = builtins.toString ./.;
        };
        cole-wsl2 = mkNixosConfiguration {
          host = "cole-wsl2";
          username = "cole";
          system = "x86_64-linux";
          repoRoot = builtins.toString ./.;
        };
        cole-vm = mkNixosConfiguration {
          host = "cole-vm";
          username = "cole";
          system = "x86_64-linux";
          repoRoot = builtins.toString ./.;
        };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
          };
          repoRoot = builtins.toString ./.;
        in
        {
          # Interactive VMs for each configuration
          cole-laptop-vm = self.nixosConfigurations.cole-laptop.config.system.build.vm;
          cole-vm-vm = self.nixosConfigurations.cole-vm.config.system.build.vm;
          cole-wsl2-vm = self.nixosConfigurations.cole-wsl2.config.system.build.vm;

          # Standalone shell environment
          default = import ./shell.nix { inherit pkgs repoRoot; };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Helper function to create a test for a configuration
          mkConfigTest =
            {
              name,
              host,
              username,
            }:
            pkgs.testers.runNixOSTest {
              inherit name;
              nodes.machine = {
                imports = mkConfigModules {
                  inherit host username;
                  repoRoot = builtins.toString ./.;
                  backupSuffix = "bak.home-manager-test";
                };
              };

              testScript = ''
                machine.wait_for_unit("multi-user.target")
                machine.succeed("systemctl status")
              '';
            };
        in
        {
          cole-laptop-test = mkConfigTest {
            name = "cole-laptop-test";
            host = "cole-laptop";
            username = "cole";
          };
          cole-vm-test = mkConfigTest {
            name = "cole-vm-test";
            host = "cole-vm";
            username = "cole";
          };
          # Skip cole-wsl2 as WSL configurations may not work well in QEMU
        }
      );
    };
}
