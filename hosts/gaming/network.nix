{ ... }:

{
  boot.kernel.sysctl = {
    # Queue discipline + congestion control
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Backlog/buffer knobs
    "net.core.netdev_max_backlog" = 16384;
    "net.core.somaxconn" = 8192;
    "net.ipv4.tcp_max_syn_backlog" = 8192;

    # Socket buffer ceilings
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.tcp_rmem" = "4096 1048576 33554432";
    "net.ipv4.tcp_wmem" = "4096 1048576 33554432";

    # Modern TCP behavior
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_slow_start_after_idle" = 0;

    # TCP keepalive — reduces stale connection overhead
    "net.ipv4.tcp_keepalive_time" = 60;
    "net.ipv4.tcp_keepalive_intvl" = 10;
    "net.ipv4.tcp_keepalive_probes" = 6;

    # VM / gaming tuning
    # swappiness=100 is intentional: zramSwap is enabled, zram is faster than evicting hot pages
    "vm.swappiness" = 100;

    # Byte-based dirty tracking — more predictable on large-RAM systems than ratio-based
    "vm.dirty_bytes" = 419430400;            # 400MB
    "vm.dirty_background_bytes" = 209715200; # 200MB

    "vm.compaction_proactiveness" = 0; # disable proactive memory compaction; reduces latency jitter
    "kernel.split_lock_mitigate" = 0;  # don't throttle split-lock accesses; games commonly trigger these

    # Disable swap readahead clustering — correct behavior with zram (RAM-backed swap)
    "vm.page-cluster" = 0;

    # Less aggressive VFS cache reclaim — keeps directory/inode cache warmer
    "vm.vfs_cache_pressure" = 50;

    # Allow unprivileged user namespaces — needed for Steam sandbox, Flatpak
    "kernel.unprivileged_userns_clone" = 1;
  };
}
