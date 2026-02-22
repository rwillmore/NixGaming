# NixGaming Handoff Document

**Last updated:** 2026-02-22
**System:** `gaming` (single NixOS host, x86_64, Zen 4 CPU, NVIDIA GPU, 4K display)
**Working directory:** `/home/rwillmore/NixGaming`

---

## Quick reference

| Task | Command |
|------|---------|
| Rebuild | `sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#gaming` |
| Validate (no rebuild) | `NIX_CONFIG="experimental-features = nix-command flakes" nix flake check` |
| GC + cleanup | `nixgarbage [N]` — keeps N newest generations (default 5) |
| Open this repo in Claude | `nixai` (alias: cds to NixGaming and launches claude) |
| End of session | `git add -A && git commit -m "..."` |

Claude cannot run `sudo`; user runs all rebuilds manually.
Do not push to any git remote.

---

## Repository structure

```
NixGaming/
├── flake.nix                        # Inputs + overlay + nixosConfigurations
├── hosts/
│   └── gaming/
│       ├── configuration.nix        # Top-level host config (imports below)
│       ├── kernel.nix               # CachyOS zen4 kernel
│       ├── network.nix              # Sysctl: BBR, buffers, VM tuning
│       ├── qos.nix                  # CAKE QoS (egress + ingress via IFB)
│       └── hardware-configuration.nix  # Auto-generated, do not edit
└── pkgs/
    ├── nixupdate-tray/              # PyQt6 systray: watches flake.lock for updates
    ├── nixgarbage/                  # Shell script: GC + prune generations
    └── leshade/                     # ReShade manager (PySide6), pinned GitHub rev
```

---

## flake.nix

- **Inputs:** `nixpkgs/nixos-unstable`, `nix-cachyos-kernel/release`
- **Overlay:** exposes `nixupdate-tray`, `nixgarbage`, `leshade` as packages
- **Output:** one NixOS config — `nixosConfigurations.gaming`
- CachyOS kernel overlay (`nix-cachyos-kernel.overlays.pinned`) applied alongside custom overlay

---

## hosts/gaming/configuration.nix

### Nix settings
- `experimental-features = nix-command flakes`
- `max-jobs = auto`, `cores = 0` (use all available)
- Binary substituters: `cache.nixos.org` + `attic.xuyh0120.win/lantian` (CachyOS kernel cache, prevents local recompiles)

### Boot
- `systemd-boot` + EFI

### Kernel parameters
| Param | Reason |
|-------|--------|
| `mitigations=off` | Intentional perf choice; single-user gaming desktop, measurable gain on Zen 4 |
| `nvidia.NVreg_UsePageAttributeTable=1` | Better VRAM throughput |
| `nvidia.NVreg_InitializeSystemMemoryAllocations=0` | Skip zeroing memory on driver init |
| `nvidia.NVreg_EnableGpuFirmware=0` | **New 2026-02-22** — disables GSP firmware, reduces GPU interrupt latency on 30xx/40xx |
| `nmi_watchdog=0` | Reduce interrupt jitter |
| `transparent_hugepage=madvise` | THP opt-in per-app (not forced) |

### CPU / power
- `powerManagement.cpuFreqGovernor = "performance"`

### Display / SDDM
- KDE Plasma 6 desktop
- SDDM with X11 (Wayland disabled for SDDM)
- Greeter forced to 1920x1080 via `setupCommands` (4K display; Plasma corrects after login)
- HiDPI: `QT_SCALE_FACTOR=2`, `dpi 192`, `CursorSize = 48`

### NVIDIA
| Setting | Value |
|---------|-------|
| `modesetting.enable` | true |
| `open` | false (proprietary driver) |
| `package` | `nvidiaPackages.latest` |
| `forceFullCompositionPipeline` | true — eliminates desktop tearing; fullscreen games bypass compositing unaffected |
| `powerManagement.enable` | true |

### Gaming programs
- `programs.steam.enable = true`
- `hardware.steam-hardware.enable = true`
- `programs.gamemode` — renice=10; NVIDIA powermizer mode 1 (`nv_powermizer_mode = 1`)
- `programs.gamescope` — `capSysNice = true`
- `programs.nix-ld` — enabled with common gaming/compat libraries (zlib, openssl, libGL, alsa, pulse, X11 set)

### Audio
- `security.rtkit.enable = true`
- PipeWire with ALSA (32-bit) + PulseAudio compat
- **New 2026-02-22** — PipeWire quantum locked to **64 frames @ 48kHz (~1.3ms latency)** via `extraConfig.pipewire."92-gaming-latency"`:
  ```nix
  "default.clock.quantum" = 64;
  "default.clock.min-quantum" = 64;
  "default.clock.max-quantum" = 64;
  ```

### Memory
- `zramSwap` — enabled, `zstd` algorithm
- `vm.swappiness = 100` — intentional; zram is faster than evicting hot pages
- `vm.dirty_ratio = 10`, `vm.dirty_background_ratio = 5` — reduce write spikes vs defaults
- `vm.compaction_proactiveness = 0` — disable proactive compaction, reduces latency jitter
- `kernel.split_lock_mitigate = 0` — don't throttle split-lock (games commonly trigger these)

### Networking
- `networking.hostName = "gaming"`, NetworkManager
- See `network.nix` and `qos.nix` below

### Storage / IO
- udev rules:
  - NVMe → `scheduler=none` (hardware queues handle ordering)
  - SATA SSD → `mq-deadline` (low-latency deterministic I/O)

### System packages
`nixupdate-tray`, `git`, `nixgarbage`, `leshade`, `nodejs`, leshade KDE desktop item

### Shell aliases
- `nixai` — `cd /home/rwillmore/NixGaming && claude`

### Misc
- `services.flatpak.enable = true` (Hytale launcher + runtimes)
- `xdg.portal.extraPortals = [xdg-desktop-portal-gtk]`
- `system.stateVersion = "25.11"`

---

## hosts/gaming/kernel.nix

```nix
boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4;
```

Binary cache at `attic.xuyh0120.win/lantian` prevents local recompilation. To force local build (slow): `preferLocalBuild = true; allowSubstitutes = false`.

---

## hosts/gaming/network.nix

| sysctl | Value | Reason |
|--------|-------|--------|
| `net.core.default_qdisc` | `fq` | Flow queuing for BBR |
| `net.ipv4.tcp_congestion_control` | `bbr` | Low-latency congestion control |
| `net.core.netdev_max_backlog` | 16384 | |
| `net.ipv4.tcp_max_syn_backlog` | 8192 | |
| `net.core.rmem_max` / `wmem_max` | 33554432 | 32MB socket buffer ceiling |
| `net.ipv4.tcp_rmem` / `tcp_wmem` | 4096 / 1MB / 32MB | |
| `net.ipv4.tcp_mtu_probing` | 1 | |
| `net.ipv4.tcp_fastopen` | 3 | Client + server |
| `net.ipv4.tcp_slow_start_after_idle` | 0 | No slowdown after idle |
| `vm.swappiness` | 100 | See Memory section |
| `vm.dirty_ratio` | 10 | |
| `vm.dirty_background_ratio` | 5 | |
| `vm.compaction_proactiveness` | 0 | |
| `kernel.split_lock_mitigate` | 0 | |

---

## hosts/gaming/qos.nix

CAKE QoS on `enp7s0` — bidirectional shaping via IFB (Intermediate Functional Block):

- **Egress** (upload): CAKE on `enp7s0` root — `diffserv4`, `ack-filter`, 950Mbit
- **Ingress** (download): traffic redirected to `ifb0`, CAKE there — `diffserv4`, 950Mbit
- `boot.kernelModules = ["ifb"]`, `options ifb numifbs=1`
- Systemd oneshot service `cake-qos`, bound to `sys-subsystem-net-devices-enp7s0.device` (auto-starts/stops with NIC)
- Cleans up on `postStop`

Tune `DOWN`/`UP` env vars in `serviceConfig.Environment` to match your actual ISP speeds.

---

## pkgs/

### nixupdate-tray
- PyQt6 systray app watching `flake.lock` for upstream changes
- Built with `stdenvNoCC.mkDerivation` + `makeWrapper` wrapping `python3 + pyqt6`
- Binary: `nixupdate-tray`

### nixgarbage
- Shell script via `writeShellScriptBin`
- Usage: `nixgarbage [N]` — deletes all but N newest system generations, runs `nix-collect-garbage -d`, then `nixos-rebuild boot`
- Default: keep 5 generations
- Flake target: `FLAKE` env var (default: `/home/rwillmore/NixGaming#gaming`)

### leshade
- ReShade manager GUI, PySide6
- Fetched from `github:Ishidawg/LeShade` at pinned rev `8f9f0b4`
- Uses `qt6.wrapQtAppsHook` for proper Qt environment
- Binary: `leshade`

---

## Git history

```
8dd6c52  Add NVIDIA GSP disable and PipeWire low-latency quantum tuning
0276058  Add nixai shell alias (cd NixGaming && claude)
d900942  Add .gitignore, remove backup files and symlinks from tracking
7658bfb  Full audit and performance pass: clean all files, add gaming performance stack
```

---

## Changes made 2026-02-22

1. **`nixai` shell alias** — `environment.shellAliases.nixai = "cd /home/rwillmore/NixGaming && claude"`. Available system-wide after rebuild.

2. **NVIDIA GSP firmware disable** — added `nvidia.NVreg_EnableGpuFirmware=0` to `boot.kernelParams`. Disables the GSP (GPU System Processor) firmware on 30xx/40xx series cards, reducing GPU interrupt latency.

3. **PipeWire low-latency quantum** — added `extraConfig.pipewire."92-gaming-latency"` locking the audio clock to 64 frames @ 48kHz (~1.3ms). `max-quantum = 64` prevents any app from widening the buffer back to the sluggish default (1024 frames).

---

## Known intentional non-defaults

| Setting | Why it looks wrong | Why it's correct |
|---------|-------------------|-----------------|
| `mitigations=off` | Security risk | Single-user gaming desktop; Zen 4 perf gain is measurable |
| `vm.swappiness = 100` | Looks too high | zramSwap is zstd-compressed RAM; faster than evicting hot pages |
| `forceFullCompositionPipeline` | "Forces" compositing | Eliminates desktop tearing; fullscreen games bypass compositor entirely |
| `nv_powermizer_mode = 1` | Forces max GPU clock | Gamemode applies this only during active game sessions |

---

## Optimization candidates (not yet applied)

| Area | What | Impact |
|------|------|--------|
| sysctl | `kernel.sched_autogroup_enabled = 1` | Medium — better game process scheduling priority |
| sysctl | `kernel.numa_balancing = 0` | Medium — Zen 4 internal NUMA causes spurious page migrations |
| Kernel param | `skew_tick=1` | Medium — staggers timer interrupts, reduces latency spikes |
| System | Disable `irqbalance` | Medium — lets gamemode control IRQ affinity |
| Tools | `programs.corectrl` | Medium — per-game CPU/GPU profiles |
| Tools | MangoHud + vkbasalt | Low — overlay + Vulkan post-processing |
| NVIDIA | `NVreg_PreserveVideoMemoryAllocations=1` | Low — faster resume from suspend |
