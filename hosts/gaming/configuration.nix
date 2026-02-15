# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Kernel (XanMod gaming kernel)
  boot.kernelPackages = pkgs.linuxPackages_xanmod;

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };

  # NVIDIA driver setup
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    nvidiaPersistenced = true;
  };

  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "amd_pstate=active"
  ];

  # CPU governor: balanced desktop, GameMode boosts games
  powerManagement.cpuFreqGovernor = "schedutil";

  # Compressed RAM swap for smoother memory behavior
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
    priority = 100;
  };

  # SSD trim
  services.fstrim.enable = true;

  # 32-bit graphics libs for Steam/Proton
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # DNS: systemd-resolved, avoid router DNS stalls
  services.resolved.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

  services.resolved.settings = {
    Resolve = {
      DNS = [ "1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4" ];
      FallbackDNS = [ "1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4" ];
      Domains = [ "~." ];
      DNSSEC = "no";
      DNSOverTLS = "no";
    };
  };

  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Plasma 6
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  # Audio via PipeWire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Raise file descriptor limit
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "nofile"; value = "1048576"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "1048576"; }
  ];

  # Steam + GameMode
  programs.steam.enable = true;
  programs.gamemode.enable = true;
  programs.steam.remotePlay.openFirewall = true;
  programs.steam.dedicatedServer.openFirewall = true;

  # Controller/device support
  hardware.steam-hardware.enable = true;
  services.udev.packages = with pkgs; [ game-devices-udev-rules ];

  # Browsers
  programs.firefox.enable = true;

  users.users.rwillmore = {
    isNormalUser = true;
    description = "rwillmore";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    kdePackages.kate

    # gaming tools
    protonup-qt
    mangohud
    goverlay
    gamescope
    vkbasalt
    heroic
    lutris
    vulkan-tools

    # LeShade (your local package)
    (pkgs.callPackage ../../pkgs/leshade { })

    # Chrome (unfree)
    google-chrome

    # wine tools
    wineWow64Packages.stable
    winetricks

    # audio mixer UI
    pavucontrol
  ];

  system.stateVersion = "25.11";
}

