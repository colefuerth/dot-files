{
  description = "NixOS Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    determinate.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager?ref=master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";
    hyprland-plugins.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    heaviside-nixpkgs.url = "git+ssh://git@github.com/heaviside-industries/heaviside-nixpkgs.git?ref=refs/heads/master";
    heaviside-nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      determinate,
      home-manager,
      sops-nix,
      nixos-wsl,
      nix-vscode-extensions,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
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
          system,
          backupSuffix ? "bak.home-manager-${
            self.shortRev or self.dirtyShortRev or self.lastModified or "unknown"
          }",
        }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              nix-vscode-extensions.overlays.default
              (self.overlays.default inputs)
            ];
          };
          dotFilesPackages = import ./packages.nix { inherit pkgs; };
        in
        [
          ./nixos/hosts/${host}/configuration.nix
          # Configure nixpkgs with overlays
          {
            nixpkgs.overlays = [
              nix-vscode-extensions.overlays.default
              (self.overlays.default inputs)
            ];
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = {
              inherit
                inputs
                host
                username
                dotFilesPackages
                ;
            };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = backupSuffix;
            home-manager.users.${username} = import ./nixos/users/${username}/home.nix;
          }
          sops-nix.nixosModules.sops
          determinate.nixosModules.default
        ]
        ++ (nixpkgs.lib.optionals (nixpkgs.lib.strings.hasSuffix "wsl2" host) [
          nixos-wsl.nixosModules.wsl
        ]);

      mkNixosConfiguration =
        {
          host,
          username,
          system,
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              host
              username
              ;
          };
          modules = mkConfigModules {
            inherit
              host
              username
              system
              ;
          };
        };
    in
    {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
      overlays.default = inputs: import ./overlays inputs;

      nixosConfigurations = {
        cole-laptop = mkNixosConfiguration {
          host = "cole-laptop";
          username = "cole";
          system = "x86_64-linux";
        };
        cole-wsl2 = mkNixosConfiguration {
          host = "cole-wsl2";
          username = "cole";
          system = "x86_64-linux";
        };
        cole-vm = mkNixosConfiguration {
          host = "cole-vm";
          username = "cole";
          system = "x86_64-linux";
        };
        hs-thinkpad = mkNixosConfiguration {
          host = "hs-thinkpad";
          username = "cole";
          system = "x86_64-linux";
        };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "claude-code"
                "consolas-nf"
              ];
            overlays = [ (self.overlays.default inputs) ];
          };
          dotFilesPackages = import ./packages.nix { inherit pkgs; };
        in
        {
          # Interactive VMs for each configuration
          cole-laptop-vm = self.nixosConfigurations.cole-laptop.config.system.build.vm;
          hs-thinkpad-vm = self.nixosConfigurations.hs-thinkpad.config.system.build.vm;
          cole-vm-vm = self.nixosConfigurations.cole-vm.config.system.build.vm;
          cole-wsl2-vm = self.nixosConfigurations.cole-wsl2.config.system.build.vm;

          # Custom packages
          consolas-nf = pkgs.consolas-nf;

          # Standalone shell environment
          default = import ./shell.nix { inherit pkgs dotFilesPackages; };
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
                  inherit host username system;
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
          hs-thinkpad-test = mkConfigTest {
            name = "hs-thinkpad-test";
            host = "hs-thinkpad";
            username = "cole";
          };
          # Skip cole-wsl2 as WSL configurations may not work well in QEMU
        }
      );
    };
}
