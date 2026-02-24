{ pkgs, ... }:

{
  # linux_zen 6.18.x with BORE (Burst-Oriented Response Enhancer) scheduler.
  # BORE reduces latency for interactive/gaming workloads by favouring
  # recently-burst tasks, complementing the Zen kernel's latency tuning.
  #
  # After editing the hash placeholder, get the real hash with:
  #   nix store prefetch-file --hash-type sha256 \
  #     https://raw.githubusercontent.com/firelzrd/bore-scheduler/main/patches/stable/linux-6.18-bore/0001-linux6.18.3-bore-6.6.1.patch
  # Or just try to build — Nix will print the correct hash in the error.
  boot.kernelPackages =
    let
      linux_zen_bore = pkgs.linux_zen.override {
        kernelPatches = pkgs.linux_zen.kernelPatches ++ [
          {
            name = "bore-scheduler";
            patch = pkgs.fetchpatch {
              name  = "0001-linux6.18.3-bore-6.6.1.patch";
              url   = "https://raw.githubusercontent.com/firelzrd/bore-scheduler/main/patches/stable/linux-6.18-bore/0001-linux6.18.3-bore-6.6.1.patch";
              hash  = "sha256-xJvOR0teN3YujDzXk4w4qtHZvLEWls/ft9amYXBGv5Y=";
            };
            extraConfig = "SCHED_BORE y";
          }
        ];
      };
    in
      pkgs.linuxPackagesFor linux_zen_bore;
}
