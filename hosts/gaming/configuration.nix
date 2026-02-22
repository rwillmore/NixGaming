{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./kernel.nix
    ./network.nix
    ./qos.nix
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    max-jobs = "auto";
    cores = 0;

    # CachyOS kernel binary cache (prevents local kernel recompiles)
    substituters = [
      "https://cache.nixos.org"
      "https://attic.xuyh0120.win/lantian"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [
    # CPU vulnerability mitigations disabled — intentional performance choice
    # for a single-user gaming desktop (measurable gain on Zen 4 in particular)
    "mitigations=off"

    # NVIDIA: enable PAT for better VRAM throughput
    "nvidia.NVreg_UsePageAttributeTable=1"
    # NVIDIA: skip zeroing system memory on driver init
    "nvidia.NVreg_InitializeSystemMemoryAllocations=0"

    # Reduce NMI watchdog interrupt jitter
    "nmi_watchdog=0"

    # THP: let apps opt in rather than forcing always/never
    "transparent_hugepage=madvise"
  ];

  powerManagement.cpuFreqGovernor = "performance";

  networking = {
    hostName = "gaming";
    networkmanager.enable = true;
  };

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.enable = true;

  # Force a lower resolution for the SDDM greeter so it appears effectively scaled on 4K.
  # Plasma should switch back to your normal resolution after login.
  services.xserver.displayManager.setupCommands = ''
    OUT="$(${pkgs.xrandr}/bin/xrandr --query | awk '/ connected/{print $1; exit}')"
    [ -n "$OUT" ] && ${pkgs.xrandr}/bin/xrandr --output "$OUT" --mode 1920x1080 || true
  '';

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false;

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

  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    # Eliminates desktop tearing; fullscreen games bypass compositing and are unaffected
    forceFullCompositionPipeline = true;
    powerManagement.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

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

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  # Flatpak support (needed for Hytale launcher bundle and its runtimes)
  services.flatpak.enable = true;

  # Portals help Flatpak apps integrate with KDE (file pickers, etc.)
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  services.udev.extraRules = ''
    # NVMe: no software scheduler; hardware queues handle ordering
    ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
    # SATA SSD: mq-deadline for low-latency deterministic I/O
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
  '';

  users.users.rwillmore = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Install LeShade system wide plus add KDE launcher entry
  environment.systemPackages = with pkgs; [
    nixupdate-tray
    git
    nixgarbage
    leshade
    nodejs
    (makeDesktopItem {
      name = "leshade";
      desktopName = "LeShade";
      exec = "leshade";
      comment = "ReShade manager for Linux";
      categories = [ "Game" "Utility" ];
      terminal = false;
    })
  ];

  environment.shellAliases = {
    nixai = "cd /home/rwillmore/NixGaming && claude";
  };

  system.stateVersion = "25.11";
}