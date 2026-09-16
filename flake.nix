{
  description = "NixOS Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    croft.url = "github:vitali87/croft?ref=main";
    croft.flake = false;
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    determinate.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager?ref=master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote/v1.1.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixos-hardware-pi-5.url = "github:nixos/nixos-hardware?ref=raspberry-pi-5";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    flameshot.url = "github:flameshot-org/flameshot?ref=master";
    flameshot.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    dschana-system-config.url = "git+https://codeberg.org/dschana/system-config?ref=master";
    dschana-system-config.inputs = {
      nixpkgs.follows = "nixpkgs";
      nixpkgs-cosmic-pinned.follows = "nixpkgs";
      determinate.follows = "determinate";
      home-manager.follows = "home-manager";
      nix-darwin.follows = "nix-darwin";
    };
    tw3mm.url = "github:Systemcluster/The-Witcher-3-Mod-manager";
    tw3mm.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      determinate,
      flake-utils,
      home-manager,
      rust-overlay,
      sops-nix,
      nixos-wsl,
      nix-vscode-extensions,
      nix-darwin,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # home-manager user entry: `username` is passed per-user (not via
      # extraSpecialArgs) so a host can have more than one home.
      mkHomeUser = user: {
        imports = [ ./nixos/users/${user}/home.nix ];
        _module.args.username = user;
      };

      # Helper to create the common module list for a host configuration
      # `username` is the primary (admin) user; `extraUsers` get a home only.
      mkConfigModules =
        {
          host,
          username,
          extraUsers ? [ ],
          dotFilesPackages,
        }:
        [
          ./nixos/hosts/${host}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = {
              inherit
                inputs
                host
                dotFilesPackages
                ;
            };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "bak.home-manager-${
              self.shortRev or self.dirtyShortRev or self.lastModified or "unknown"
            }";
            home-manager.users = nixpkgs.lib.genAttrs ([ username ] ++ extraUsers) mkHomeUser;
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
          extraUsers ? [ ],
        }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              rust-overlay.overlays.default
              nix-vscode-extensions.overlays.default
              self.overlays.default
            ];
          };
          dotFilesPackages = import ./packages.nix { inherit pkgs inputs; };
          isDarwin = false;
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              host
              username
              dotFilesPackages
              isDarwin
              ;
          };
          modules = mkConfigModules {
            inherit
              host
              username
              extraUsers
              dotFilesPackages
              ;
          };
        };

      mkDarwinConfiguration =
        {
          host,
          username,
          system,
        }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              rust-overlay.overlays.default
              nix-vscode-extensions.overlays.default
              self.overlays.default
            ];
          };
          dotFilesPackages = import ./packages.nix { inherit pkgs inputs; };
          isDarwin = true;
        in
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              host
              username
              dotFilesPackages
              isDarwin
              ;
          };
          modules = [
            ./nixos/hosts/${host}/configuration.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.extraSpecialArgs = {
                inherit
                  inputs
                  host
                  dotFilesPackages
                  ;
              };
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "bak.home-manager-${
                self.shortRev or self.dirtyShortRev or self.lastModified or "unknown"
              }";
              home-manager.users.${username} = mkHomeUser username;
            }
            sops-nix.darwinModules.sops
          ];
        };
    in
    {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
      overlays.default = import ./overlays inputs;

      nixosConfigurations = {
        cole-laptop = mkNixosConfiguration {
          host = "cole-laptop";
          username = "cole";
          extraUsers = [ "caroline" ];
          system = "x86_64-linux";
        };
        cole-desktop = mkNixosConfiguration {
          host = "cole-desktop";
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
        cole-pi = mkNixosConfiguration {
          host = "cole-pi";
          username = "cole";
          system = "aarch64-linux";
        };
        cole-server = mkNixosConfiguration {
          host = "cole-server";
          username = "cole";
          system = "x86_64-linux";
        };
        hs-thinkpad = mkNixosConfiguration {
          host = "hs-thinkpad";
          username = "cole";
          system = "x86_64-linux";
        };
      };

      darwinConfigurations = {
        cole-darwin = mkDarwinConfiguration {
          host = "cole-darwin";
          username = "cole";
          system = "aarch64-darwin";
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
              ];
            overlays = [
              self.overlays.default
              rust-overlay.overlays.default
            ];
          };
          dotFilesPackages = import ./packages.nix { inherit pkgs inputs; };
        in
        rec {
          # Interactive VMs for each configuration
          cole-laptop-vm = self.nixosConfigurations.cole-laptop.config.system.build.vm;
          cole-desktop-vm = self.nixosConfigurations.cole-desktop.config.system.build.vm;
          cole-vm-vm = self.nixosConfigurations.cole-vm.config.system.build.vm;
          cole-pi-vm = self.nixosConfigurations.cole-pi.config.system.build.vm;
          cole-server-vm = self.nixosConfigurations.cole-server.config.system.build.vm;
          hs-thinkpad-vm = self.nixosConfigurations.hs-thinkpad.config.system.build.vm;
          # Note: cole-wsl2-vm is not included because WSL configurations cannot be built as VMs
          shell = import ./shell.nix { inherit pkgs dotFilesPackages; };
          default = shell;
        }
        // dotFilesPackages
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # Define which configs to test and their metadata
          configsToTest = {
            cole-laptop = {
              host = "cole-laptop";
              username = "cole";
              extraUsers = [ "caroline" ];
            };
            cole-desktop = {
              host = "cole-desktop";
              username = "cole";
            };
            cole-vm = {
              host = "cole-vm";
              username = "cole";
            };
            hs-thinkpad = {
              host = "hs-thinkpad";
              username = "cole";
            };
            cole-pi = {
              host = "cole-pi";
              username = "cole";
            };
            cole-server = {
              host = "cole-server";
              username = "cole";
            };
            # Note: cole-wsl2 excluded - WSL configurations cannot be tested as VMs
          };
          # Use the lower-level nixos-lib.runTest for proper specialArgs support
          nixos-lib = import (nixpkgs + "/nixos/lib") { };
          mkBootTest =
            name:
            {
              host,
              username,
              extraUsers ? [ ],
            }:
            let
              testPkgs = import nixpkgs {
                inherit system;
                overlays = [
                  rust-overlay.overlays.default
                  nix-vscode-extensions.overlays.default
                  self.overlays.default
                ];
              };
              dotFilesPackages = import ./packages.nix {
                pkgs = testPkgs;
                inherit inputs;
              };
            in
            (nixos-lib.runTest {
              hostPkgs = pkgs;
              name = "${name}-boot-test";
              # Provide the same args as mkNixosConfiguration's specialArgs
              node.specialArgs = {
                inherit
                  inputs
                  host
                  username
                  dotFilesPackages
                  ;
                isDarwin = false;
              };
              nodes.machine =
                { ... }:
                {
                  imports = mkConfigModules {
                    inherit
                      host
                      username
                      extraUsers
                      dotFilesPackages
                      ;
                  };
                  # Override hardware-specific settings for VM testing
                  virtualisation.graphics = false;
                };
              testScript = ''
                machine.start()
                machine.wait_for_unit("multi-user.target")
                machine.succeed("systemctl is-system-running --wait || systemctl is-system-running | grep -E 'running|degraded'")
              '';
            }).config.result;
        in
        nixpkgs.lib.mapAttrs mkBootTest configsToTest
      );
    };
}
