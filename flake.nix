{
  description = "Rob's NixOS gaming desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ (import ./overlays/default.nix) ];
      config.allowUnfree = true;
    };
  in {
    # Expose buildable flake packages
    packages.${system} = {
      leshade = pkgs.callPackage ./pkgs/leshade { };
      volt-gui = pkgs.volt-gui;
    };
# Keep your system config
    nixosConfigurations.gaming = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ({ config, pkgs, ... }: { nixpkgs.overlays = [ (import ./overlays/default.nix) ]; })
        ./hosts/gaming/configuration.nix
      ];
    };
  };
}
