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
      config.allowUnfree = true;
    };
  in {
    # Expose LeShade as a buildable flake package
    packages.${system}.leshade = pkgs.callPackage ./pkgs/leshade { };

    # Keep your system config
    nixosConfigurations.gaming = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/gaming/configuration.nix
      ];
    };
  };
}
