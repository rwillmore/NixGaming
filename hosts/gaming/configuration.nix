{ config, pkgs, nix-cachyos-kernel, nixos-conf-editor, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./qos.nix
  ];

  # ============================================================
  # NIX SETTINGS
  # ============================================================

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = "auto";
    cores = 0;

    # CachyOS kernel binary cache
    substituters = [
      "https://cache.nixos.org"
      "https://attic.xuyh0120.win/lantian"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  # ============================================================
  # KERNEL
  # ============================================================

  boot.kernelPackages = pkgs.linuxPackagesFor
    nix-cachyos-kernel.hydraJobs.packages.x86_64-linux.linux-cachyos-latest-lto-zen4;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [
    "mitigations=off"
    "nvidia.NVreg_UsePageAttributeTable=1"
    "nvidia.NVreg_InitializeSystemMemoryAllocations=0"
    "nvidia.NVreg_EnableGpuFirmware=0"
    "nmi_watchdog=0"
    "transparent_hugepage=madvise"
  ];

  boot.extraModprobeConfig = ''
    options nvidia_drm modeset=1
    options snd-hda-intel power_save=0
  '';

  # ============================================================
  # SYSCTL
  # ============================================================

  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    "net.core.netdev_max_backlog" = 16384;
    "net.core.somaxconn" = 8192;
    "net.ipv4.tcp_max_syn_backlog" = 8192;

    "net.core.rmem_max" = 33554432;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.tcp_rmem" = "4096 1048576 33554432";
    "net.ipv4.tcp_wmem" = "4096 1048576 33554432";

    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_slow_start_after_idle" = 0;

    "net.ipv4.tcp_keepalive_time" = 60;
    "net.ipv4.tcp_keepalive_intvl" = 10;
    "net.ipv4.tcp_keepalive_probes" = 6;

    "vm.swappiness" = 100;

    "vm.dirty_bytes" = 419430400;
    "vm.dirty_background_bytes" = 209715200;

    "vm.compaction_proactiveness" = 0;
    "kernel.split_lock_mitigate" = 0;
    "vm.page-cluster" = 0;
    "vm.vfs_cache_pressure" = 50;
    "kernel.unprivileged_userns_clone" = 1;
  };

  # ============================================================
  # POWER
  # ============================================================

  powerManagement.cpuFreqGovernor = "performance";

  # ============================================================
  # NETWORKING
  # ============================================================

  networking = {
    hostName = "gaming";
    networkmanager.enable = true;
  };

  # ============================================================
  # LOCALE
  # ============================================================

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # ============================================================
  # DISPLAY
  # ============================================================

  services.xserver.enable = true;

  services.xserver.displayManager.setupCommands = ''
    OUT="$(${pkgs.xrandr}/bin/xrandr --query | awk '/ connected/{print $1; exit}')"
    [ -n "$OUT" ] && ${pkgs.xrandr}/bin/xrandr --output "$OUT" --mode 1920x1080 || true
  '';

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;

    settings = {
      Theme = {
        Current = "breeze";
        CursorTheme = "breeze_cursors";
        CursorSize = 48;
      };
      General = {
        GreeterEnvironment = "QT_SCALE_FACTOR=2,QT_ENABLE_HIGHDPI_SCALING=1";
      };
      X11 = {
        EnableHiDPI = true;
        ServerArguments = "-nolisten tcp -dpi 192";
      };
    };
  };

  services.desktopManager.plasma6.enable = true;
  services.desktopManager.gnome.enable = true;

  programs.ssh.askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

  # ============================================================
  # NVIDIA
  # ============================================================

  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    forceFullCompositionPipeline = true;
    powerManagement.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # ============================================================
  # GAMING
  # ============================================================

  hardware.steam-hardware.enable = true;
  programs.steam.enable = true;

  programs.gamemode = {
    enable = true;
    settings = {
      general.renice = 10;
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        nv_powermizer_mode = 1;
      };
    };
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # ============================================================
  # AUDIO
  # ============================================================

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    extraConfig.pipewire."92-gaming-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 64;
        "default.clock.min-quantum" = 64;
        "default.clock.max-quantum" = 64;
      };
    };
  };

  # ============================================================
  # STORAGE
  # ============================================================

  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
    ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="max_performance"
    KERNEL=="rtc0", GROUP="audio"
    KERNEL=="hpet", GROUP="audio"
  '';

  # ============================================================
  # SYSTEMD
  # ============================================================

  systemd.settings.Manager = {
    DefaultLimitNOFILE = "2048:2097152";
    DefaultTimeoutStartSec = "15s";
    DefaultTimeoutStopSec = "10s";
  };

  services.journald.extraConfig = ''
    SystemMaxUse=50M
  '';

  # ============================================================
  # FLATPAK & PORTALS
  # ============================================================

  services.flatpak.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # ============================================================
  # NIX-LD
  # ============================================================

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      libx11
      libxext
      libxrender
      libxrandr
      libxi
      libxcursor
      libxxf86vm
      libGL
      alsa-lib
      pulseaudio
    ];
  };

  # ============================================================
  # USERS
  # ============================================================

  users.users.rwillmore = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # ============================================================
  # PACKAGES & ENVIRONMENT
  # ============================================================

  environment.systemPackages = with pkgs; [
    pkgs.vlc
    pkgs.htop-vim
    nixupdate-tray
    git
    nixgarbage
    leshade
    nodejs

    nixos-conf-editor.packages.${pkgs.system}.nixos-conf-editor

    (makeDesktopItem {
      name = "leshade";
      desktopName = "LeShade";
      exec = "leshade";
      comment = "ReShade manager for Linux";
      categories = [ "Game" "Utility" ];
      terminal = false;
    })
  ];

  environment.sessionVariables = {
    IBUS_USE_PORTAL = "1";
  };

  environment.shellAliases = {
    nixai = "cd /home/rwillmore/NixGaming && claude";
  };

  system.stateVersion = "25.11";
}
