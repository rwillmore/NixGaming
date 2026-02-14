# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Kernel (XanMod gaming kernel)
  boot.kernelPackages = pkgs.linuxPackages_xanmod;

  # NVIDIA driver setup
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # Enable NVIDIA persistence daemon
  hardware.nvidia.nvidiaPersistenced = true;

  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "amd_pstate=active"
  ];

  # CPU governor: balanced desktop, GameMode boosts games
  powerManagement.cpuFreqGovernor = "schedutil";

  # Compressed RAM swap for smoother memory behavior
  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";
  zramSwap.memoryPercent = 25;
  zramSwap.priority = 100;

  # SSD trim
  services.fstrim.enable = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";

  # Networking
  networking.networkmanager.enable = true;

  # Timezone
  time.timeZone = "America/Chicago";

  # Locale
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

  # X11 / Plasma
  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Printing
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

  # Steam + GameMode
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  # Controller/device support
  hardware.steam-hardware.enable = true;
  services.udev.packages = with pkgs; [ game-devices-udev-rules ];

  # Firefox
  programs.firefox.enable = true;

  # Chrome
  programs.google-chrome.enable = true;


  # User
  users.users.rwillmore = {
    isNormalUser = true;
    description = "rwillmore";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    git
    kdePackages.kate

    protonup-qt
    mangohud
    goverlay
    gamescope
    vkbasalt
    heroic
    lutris
  ];

  system.stateVersion = "25.11";
}
