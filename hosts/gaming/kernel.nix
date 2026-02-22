{ pkgs, ... }:

{
  # To force local compilation (slow — bypasses binary cache):
  # override with preferLocalBuild = true; allowSubstitutes = false;
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4;
}
