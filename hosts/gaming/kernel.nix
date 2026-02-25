{ pkgs, nix-cachyos-kernel, ... }:

{
  boot.kernelPackages = pkgs.linuxPackagesFor
    nix-cachyos-kernel.hydraJobs.packages.x86_64-linux.linux-cachyos-latest-lto-zen4;
}
