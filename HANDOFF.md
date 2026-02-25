# NixGaming — Complete Handoff Document

**Last updated:** 2026-02-22
**System:** `gaming` — single NixOS host, x86_64, AMD Zen 4 CPU, NVIDIA GPU, 4K display, user `rwillmore`
**Flake target:** `.#gaming`

---

## Quick reference

| Task | Command |
|------|---------|
| Rebuild + switch | `sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#gaming` |
| Validate only (no rebuild) | `NIX_CONFIG="experimental-features = nix-command flakes" nix flake check` |
| GC + prune generations | `nixgarbage [N]` — keeps N newest (default 5), then rebuilds boot |
| Open repo in Claude | `nixai` — alias: `cd /home/rwillmore/NixGaming && claude` |
| End of session | `git add -A && git commit -m "short summary"` |

**Rules:**
- Claude cannot run `sudo` (no TTY) — user runs all rebuilds
- Do not push to any git remote
- Do not reboot without explicit instruction
- Run `nix flake check` for read-only validation before rebuilding

---

## Repository structure

```
/home/rwillmore/NixGaming/
├── flake.nix
├── flake.lock
├── HANDOFF.md                          ← this file
├── .gitignore
├── hosts/
│   └── gaming/
│       ├── configuration.nix           ← top-level host config
│       ├── kernel.nix                  ← CachyOS Zen 4 kernel
│       ├── network.nix                 ← sysctl: BBR, buffers, VM/gaming tuning
│       ├── qos.nix                     ← CAKE QoS bidirectional via IFB
│       └── hardware-configuration.nix  ← auto-generated, do not hand-edit
└── pkgs/
    ├── nixupdate-tray/
    │   ├── default.nix
    │   └── nixupdate-tray.py
    ├── nixgarbage/
    │   └── default.nix
    └── leshade/
        └── default.nix
```

---

## Git history

```
c0008cc  Add HANDOFF.md with full current state and 2026-02-22 changes
8dd6c52  Add NVIDIA GSP disable and PipeWire low-latency quantum tuning
0276058  Add nixai shell alias (cd NixGaming && claude)
d900942  Add .gitignore, remove backup files and symlinks from tracking
7658bfb  Full audit and performance pass: clean all files, add gaming performance stack
```

---

## Changes made 2026-02-22

1. **`nixai` shell alias** — `environment.shellAliases.nixai = "cd /home/rwillmore/NixGaming && claude"`. Available in all shells after rebuild.

2. **NVIDIA GSP firmware disable** — added `nvidia.NVreg_EnableGpuFirmware=0` to `boot.kernelParams`. Disables the GPU System Processor firmware on 30xx/40xx cards, reducing GPU interrupt latency.

3. **PipeWire low-latency quantum** — added `extraConfig.pipewire."92-gaming-latency"` locking audio clock to 64 frames @ 48 kHz (~1.3 ms). `max-quantum = 64` prevents any app from widening back to the sluggish 1024-frame default.

---

## Intentional non-defaults (don't "fix" these)

| Setting | Looks wrong because | Actually correct because |
|---------|--------------------|-----------------------|
| `mitigations=off` | Security risk | Single-user gaming desktop; measurable Zen 4 perf gain |
| `vm.swappiness = 100` | Way too high | zramSwap (zstd) is faster than evicting hot pages |
| `forceFullCompositionPipeline = true` | Forces compositing | Eliminates desktop tearing; fullscreen games bypass compositor entirely |
| `nv_powermizer_mode = 1` | Forces max GPU clocks | Gamemode applies this only during active game sessions |
| `vm.compaction_proactiveness = 0` | Disables optimization | Proactive compaction causes latency jitter; not worth it for gaming |
| `kernel.split_lock_mitigate = 0` | Security/correctness | Games commonly trigger split-lock; throttling hurts perf more than it helps |

---

## Optimization candidates (not yet applied)

| Area | What | Expected impact |
|------|------|----------------|
| sysctl | `kernel.sched_autogroup_enabled = 1` | Better game process scheduler priority vs background tasks |
| sysctl | `kernel.numa_balancing = 0` | Zen 4 internal NUMA causes spurious page migrations in games |
| Kernel param | `skew_tick=1` | Staggers timer interrupts across cores, reduces latency spikes |
| System service | Disable `irqbalance` | Lets gamemode control IRQ affinity without fighting irqbalance |
| Tools | `programs.corectrl` | Per-game CPU/GPU profiles, powerplay tables |
| Tools | MangoHud + vkbasalt | Performance overlay + Vulkan post-processing |
| NVIDIA param | `NVreg_PreserveVideoMemoryAllocations=1` | Faster resume from suspend |

---

---

# Verbatim file contents

---

## flake.nix

```nix
{
  description = "Rob's NixOS system flake";

  inputs = {
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nix-cachyos-kernel }:
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
      };

      packages.${system} = {
        leshade = pkgs.leshade;
      };

      nixosConfigurations.gaming = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ({ ... }: { nixpkgs.overlays = [ self.overlays.default nix-cachyos-kernel.overlays.pinned ]; })
          ./hosts/gaming/configuration.nix
        ];
      };
    };
}
```

**Notes:**
- Two inputs: `nixpkgs/nixos-unstable` and `nix-cachyos-kernel/release`
- Custom overlay exposes `nixupdate-tray`, `nixgarbage`, `leshade`
- CachyOS kernel overlay (`nix-cachyos-kernel.overlays.pinned`) applied alongside custom overlay at the nixosSystem level
- Single host: `nixosConfigurations.gaming`

---

## hosts/gaming/configuration.nix

```nix
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

    # NVIDIA: disable GSP firmware — reduces GPU interrupt latency on 30xx/40xx
    "nvidia.NVreg_EnableGpuFirmware=0"

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
    extraConfig.pipewire."92-gaming-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        # 64 frames @ 48kHz ≈ 1.3ms — low latency for gaming audio
        "default.clock.quantum" = 64;
        "default.clock.min-quantum" = 64;
        "default.clock.max-quantum" = 64;
      };
    };
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
```

---

## hosts/gaming/kernel.nix

```nix
{ pkgs, ... }:

{
  # To force local compilation (slow — bypasses binary cache):
  # override with preferLocalBuild = true; allowSubstitutes = false;
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4;
}
```

**Notes:**
- Uses CachyOS binary cache at `attic.xuyh0120.win/lantian` (trusted key in configuration.nix) to avoid local recompilation
- `linuxPackages-cachyos-latest-zen4` — Zen 4-optimised CachyOS kernel, tracks latest release branch

---

## hosts/gaming/network.nix

```nix
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
```

---

## hosts/gaming/qos.nix

```nix
{ pkgs, ... }:

let
  ip = "${pkgs.iproute2}/bin/ip";
  tc = "${pkgs.iproute2}/bin/tc";
in
{
  # Load ifb at boot with the module option applied on first load
  boot.kernelModules = [ "ifb" ];
  boot.extraModprobeConfig = "options ifb numifbs=1";

  systemd.services.cake-qos = {
    description = "CAKE QoS (egress + ingress via IFB) on enp7s0";
    after   = [ "network-online.target" "sys-subsystem-net-devices-enp7s0.device" ];
    wants   = [ "network-online.target" ];
    bindsTo = [ "sys-subsystem-net-devices-enp7s0.device" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Tune these. Start here for 1G service.
      Environment = [
        "DEV=enp7s0"
        "IFB=ifb0"
        "DOWN=950Mbit"
        "UP=950Mbit"
      ];
    };

    script = ''
      set -euo pipefail

      # Clean up old state if present
      ${tc} qdisc del dev "$DEV" root 2>/dev/null || true
      ${tc} qdisc del dev "$DEV" ingress 2>/dev/null || true
      ${tc} qdisc del dev "$IFB" root 2>/dev/null || true
      ${ip} link del "$IFB" 2>/dev/null || true

      # Create IFB for ingress shaping
      ${ip} link add "$IFB" type ifb
      ${ip} link set "$IFB" up

      # Egress CAKE (uploads) — diffserv4 prioritises DSCP-marked gaming/VoIP over bulk
      ${tc} qdisc replace dev "$DEV" root cake bandwidth "$UP" diffserv4 ack-filter

      # Ingress redirect to IFB
      ${tc} qdisc add dev "$DEV" handle ffff: ingress
      ${tc} filter add dev "$DEV" parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev "$IFB"

      # Ingress CAKE (downloads)
      ${tc} qdisc replace dev "$IFB" root cake bandwidth "$DOWN" diffserv4
    '';

    postStop = ''
      ${tc} qdisc del dev "$DEV" root 2>/dev/null || true
      ${tc} qdisc del dev "$DEV" ingress 2>/dev/null || true
      ${tc} qdisc del dev "$IFB" root 2>/dev/null || true
      ${ip} link del "$IFB" 2>/dev/null || true
    '';
  };
}
```

**Notes:**
- Interface: `enp7s0`, speeds: 950Mbit up/down (tune for actual ISP rate)
- Egress CAKE on `enp7s0` root with `diffserv4` + `ack-filter`
- Ingress redirected to `ifb0` via `mirred`, shaped there with CAKE `diffserv4`
- Service bound to `sys-subsystem-net-devices-enp7s0.device` — auto-starts/stops with NIC
- Full teardown in `postStop` — idempotent, safe to restart

---

## hosts/gaming/hardware-configuration.nix

```nix
# Do not modify this file!  It was generated by 'nixos-generate-config'
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/03cf451a-f6f8-4ed1-a47b-c03a85cf234d";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/140C-E87B";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
```

**Notes:** Auto-generated by `nixos-generate-config`. Do not edit by hand. AMD CPU, NVMe root, vfat /boot, no swap (using zramSwap instead).

---

---

# Custom packages

---

## pkgs/nixupdate-tray/default.nix

```nix
{ lib
, stdenvNoCC
, makeWrapper
, python3
}:

stdenvNoCC.mkDerivation {
  pname = "nixupdate-tray";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: !(lib.hasSuffix ".bak" (baseNameOf path));
  };
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec
    install -Dm755 nixupdate-tray.py $out/libexec/nixupdate-tray.py

    makeWrapper ${python3.withPackages (ps: with ps; [ pyqt6 ])}/bin/python3 $out/bin/nixupdate-tray \
      --add-flags $out/libexec/nixupdate-tray.py

    runHook postInstall
  '';

  meta = with lib; {
    description = "Lightweight NixOS flake update tray app";
    mainProgram = "nixupdate-tray";
    platforms = platforms.linux;
  };
}
```

**nixupdate-tray.py summary:**
- PyQt6 system tray app
- Checks for flake input updates every 12 hours (first check delayed 2 hours after login)
- Uses `nix flake update --output-lock-file <tmp>` to check without touching `flake.lock`
- Compares old vs new lock file, shows human-readable diff of changed inputs
- "Install updates" menu item launches Konsole (fallback: xterm) running: `nix flake update` → `nixos-rebuild switch` → `nixgarbage 5`
- Env vars: `FLAKE_DIR` (default `/home/rwillmore/NixGaming`), `FLAKE_HOST` (default `gaming`)

---

## pkgs/nixgarbage/default.nix

```nix
{ lib, writeShellScriptBin, ... }:

(writeShellScriptBin "nixgarbage" ''
  set -euo pipefail

  KEEP="${1:-5}"
  if ! echo "$KEEP" | grep -Eq '^[0-9]+$'; then
    echo "Usage: nixgarbage [KEEP_GENERATIONS]"
    echo "Example: nixgarbage 5"
    exit 2
  fi

  FLAKE="${FLAKE:-/home/rwillmore/NixGaming#gaming}"

  NIX_ENV_BIN="/run/current-system/sw/bin/nix-env"
  NIX_GC_BIN="/run/current-system/sw/bin/nix-collect-garbage"
  NIXOS_REBUILD_BIN="/run/current-system/sw/bin/nixos-rebuild"

  echo "== NixOS garbage cleanup =="
  echo "Keep newest generations: $KEEP"
  echo "Flake: $FLAKE"
  echo

  echo "== Current system generations =="
  sudo "$NIX_ENV_BIN" -p /nix/var/nix/profiles/system --list-generations || true
  echo

  echo "== Dry run: what would be collected =="
  sudo "$NIX_GC_BIN" --dry-run || true
  echo

  echo "== Delete old system generations (keep newest $KEEP) =="
  sudo "$NIX_ENV_BIN" -p /nix/var/nix/profiles/system --delete-generations "+$KEEP"
  echo

  echo "== Garbage collect (delete) =="
  sudo "$NIX_GC_BIN" -d
  echo

  echo "== Rebuild boot entries =="
  sudo "$NIXOS_REBUILD_BIN" boot --flake "$FLAKE"
  echo

  echo "== Done =="
  df -h / || true
'').overrideAttrs (_: {
  meta = with lib; {
    description = "Delete old NixOS generations and collect garbage, keeping the N newest";
    mainProgram = "nixgarbage";
    platforms = platforms.linux;
  };
})
```

**Notes:**
- `writeShellScriptBin` — no compilation, just a wrapped shell script
- Steps: list generations → dry-run GC → delete old generations → GC → `nixos-rebuild boot`
- Override `FLAKE` env var to target a different host

---

## pkgs/leshade/default.nix

```nix
{ lib
, stdenv
, fetchFromGitHub
, python3
, qt6
, bash
}:

let
  py = python3.withPackages (ps: [
    ps.pyside6
  ]);
in
stdenv.mkDerivation {
  pname = "leshade";
  version = "2.1";

  src = fetchFromGitHub {
    owner = "Ishidawg";
    repo = "LeShade";
    rev = "8f9f0b419a7b3d0bf6559b8db74baf11f1f8a581";
    hash = "sha256-uRRUX1jdIaHsGuEQwZtWK0DiwtCrRziePYzCxSlsex4=";
  };

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtwayland
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/leshade
    cp -R . $out/share/leshade

    mkdir -p $out/bin
    cat > $out/bin/leshade <<SH
#!/bin/bash
set -euo pipefail
cd "$out/share/leshade"
exec ${py.interpreter} "$out/share/leshade/main.py" "$@"
SH
    chmod +x $out/bin/leshade

    runHook postInstall
  '';

  postFixup = ''
    wrapQtApp $out/bin/leshade
  '';

  meta = with lib; {
    description = "LeShade, a ReShade manager for Linux";
    homepage = "https://github.com/Ishidawg/LeShade";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "leshade";
  };
}
```

**Notes:**
- Fetched from `github:Ishidawg/LeShade` at pinned rev `8f9f0b4` — update `rev` + `hash` to upgrade
- PySide6 GUI; `qt6.wrapQtAppsHook` sets up Qt env vars correctly
- `dontBuild = true` — Python source, no compilation step
- KDE desktop item created in `configuration.nix` via `makeDesktopItem`
