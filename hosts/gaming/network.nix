{ ... }:

{
  boot.kernel.sysctl = {
    # Queue discipline + congestion control
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Sensible backlog/buffer knobs (safe, mild)
    "net.core.netdev_max_backlog" = 16384;
    "net.ipv4.tcp_max_syn_backlog" = 8192;

    # Socket buffer ceilings (does not force usage, just allows)
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.tcp_rmem" = "4096 1048576 33554432";
    "net.ipv4.tcp_wmem" = "4096 1048576 33554432";

    # Modern TCP behavior
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_fastopen" = 3;

    # Optional: reduce TCP idle slowdowns a bit
    "net.ipv4.tcp_slow_start_after_idle" = 0;

    # VM / gaming tuning
    # swappiness=100 is intentional: zramSwap is enabled, zram is faster than evicting hot pages
    "vm.swappiness" = 100;
    "vm.dirty_ratio" = 10;             # flush dirty pages at 10% RAM (default 20); reduces write spikes
    "vm.dirty_background_ratio" = 5;   # background flush at 5% (default 10)
    "vm.compaction_proactiveness" = 0; # disable proactive memory compaction; reduces latency jitter
    "kernel.split_lock_mitigate" = 0;  # don't throttle split-lock accesses; games commonly trigger these
  };
}
