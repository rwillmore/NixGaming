{
  description = "Rob's NixOS gaming desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
  in {
    nixosConfigurations.gaming = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/gaming/configuration.nix
      ];
    };
  };
}
