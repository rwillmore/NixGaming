{
  description = "Rob's NixOS system flake";

  inputs = {
    nixos-conf-editor.url = "github:snowfallorg/nixos-conf-editor";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nix-cachyos-kernel, nixos-conf-editor }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ self.overlays.default ];
      };
    in {
      overlays.default = final: prev: {
        nixupdate-tray = prev.callPackage ./pkgs/nixupdate-tray { };
        nixgarbage     = prev.callPackage ./pkgs/nixgarbage { };
        leshade        = prev.callPackage ./pkgs/leshade { };
        nixie          = prev.callPackage ./pkgs/nixie { };
      };

      packages.${system} = {
        leshade = pkgs.leshade;
      };

      nixosConfigurations.gaming = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nix-cachyos-kernel nixos-conf-editor; };
        modules = [
          ({ ... }: { nixpkgs.overlays = [ self.overlays.default nix-cachyos-kernel.overlays.pinned ]; })
          ./hosts/gaming/configuration.nix
        ];
      };
    };
}
