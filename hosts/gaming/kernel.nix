{ pkgs, ... }:

{
  # linux_zen: Zen-patched kernel optimised for desktop/gaming latency.
  # BORE patch removed — no compatible patch exists for 6.18.9 yet.
  # Re-add when firelzrd releases a 6.18.9+ patch:
  #   https://github.com/firelzrd/bore-scheduler/tree/main/patches/stable/linux-6.18-bore
  boot.kernelPackages = pkgs.linuxPackages_zen;
}
