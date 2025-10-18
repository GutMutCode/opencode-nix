{
  description = "OpenCode - AI coding agent built for the terminal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      # Overlay for adding opencode package to nixpkgs
      overlays.default = import ./overlay.nix;

      # NixOS module
      nixosModules.default = import ./module.nix;

      # home-manager module
      homeManagerModules.default = import ./module.nix;

      # Packages for each system
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          opencode = pkgs.opencode;
          default = pkgs.opencode;
        }
      );

      # Apps (for nix run)
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.opencode}/bin/opencode";
        };
      });

      # Development shell
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [ self.packages.${system}.opencode ];
            shellHook = ''
              echo "OpenCode development environment"
              echo "Run 'opencode' to start"
            '';
          };
        }
      );
    };
}
