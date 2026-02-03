{
  description = "NixOS Configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    determinate.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager?ref=master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    flameshot.url = "github:flameshot-org/flameshot?ref=fix_cosmic";
    flameshot.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    # heaviside-nixpkgs.url = "git+ssh://git@github.com/heaviside-industries/heaviside-nixpkgs.git?ref=refs/heads/master";
    # heaviside-nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
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
              self.overlays.default
            ];
          };
          dotFilesPackages = import ./packages.nix { inherit pkgs; };
        in
        [
          ./nixos/hosts/${host}/configuration.nix
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
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              nix-vscode-extensions.overlays.default
              self.overlays.default
            ];
          };
          dotFilesPackages = import ./packages.nix { inherit pkgs; };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              host
              username
              dotFilesPackages
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
      overlays.default = import ./overlays inputs;

      nixosConfigurations = {
        cole-laptop = mkNixosConfiguration {
          host = "cole-laptop";
          username = "cole";
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
              ];
            overlays = [ self.overlays.default ];
          };
          dotFilesPackages = import ./packages.nix { inherit pkgs; };
        in
        rec {
          # Interactive VMs for each configuration
          cole-laptop-vm = self.nixosConfigurations.cole-laptop.config.system.build.vm;
          cole-desktop-vm = self.nixosConfigurations.cole-desktop.config.system.build.vm;
          cole-vm-vm = self.nixosConfigurations.cole-vm.config.system.build.vm;
          hs-thinkpad-vm = self.nixosConfigurations.hs-thinkpad.config.system.build.vm;
          # Note: cole-wsl2-vm is not included because WSL configurations cannot be built as VMs
          inherit (dotFilesPackages)
            aliases
            scripts
            completions
            configs
            bambu-studio
            consolas-nf
            ;

          # Standalone shell environment
          shell = import ./shell.nix { inherit pkgs dotFilesPackages; };
          default = shell;
        }
      );

      # Checks disabled due to incompatibility with stricter nixpkgs read-only
      # configuration in newer NixOS test infrastructure
      checks = forAllSystems (system: { });
    };
}
