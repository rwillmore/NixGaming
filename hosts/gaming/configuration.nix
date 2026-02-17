# Edit
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # -------------------------
  # Nix + flakes
  # -------------------------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-substitution-jobs = 16;
    http-connections = 64;
    connect-timeout = 10;
    stalled-download-timeout = 60;
    download-attempts = 5;
  };

  nixpkgs.config.allowUnfree = true;

  # -------------------------
  # Boot
  # -------------------------
  boot.loader.limine.enable = true;
  boot.loader.limine.efiInstallAsRemovable = true;

  # Gaming kernel
  boot.kernelPackages = pkgs.linuxPackages_xanmod;

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };

  # -------------------------
  # Networking
  # -------------------------
  networking.networkmanager.enable = true;
  # networking.hostName = "nixos"; # optional

  # -------------------------
  # Time + locale
  # -------------------------
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # -------------------------
  # Desktop: KDE Plasma (Wayland)
  # -------------------------
  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Optional: make sure Wayland is available for Plasma
  services.displayManager.defaultSession = "plasma";

  # -------------------------
  # Audio: PipeWire
  # -------------------------
  hardware.alsa.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = lib.mkForce true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # -------------------------
  # NVIDIA
  # -------------------------
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;

    # If you want to pin driver branch later, we can do it, but leaving default is safest.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # -------------------------
  # Gaming basics
  # -------------------------
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
  };

  programs.gamemode.enable = true;

  # Helpful tools
  environment.systemPackages = with pkgs; [
    firefox
    google-chrome
    brave
    git
    kdePackages.kate
    vim
    wget
    curl
    pciutils
    usbutils
    lm_sensors
  ];

  # -------------------------
  # Users
  # -------------------------
  # If your username is different, change rwillmore here.
  users.users.rwillmore = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" ];
  };

  # Allow sudo for wheel
  security.sudo.wheelNeedsPassword = true;

  # -------------------------
  # OpenGL 32-bit (helps Steam/Proton)
  # -------------------------
  hardware.graphics.enable32Bit = true;

  # -------------------------
  # IMPORTANT: nixtray disabled
  # -------------------------
  # This file intentionally does not define any nixtray systemd user services/timers,
  # does not write unit files into ~/.config/systemd/user, and does not set KDE autostart.

  # -------------------------
  # NixOS release pin
  # -------------------------
  system.stateVersion = "26.05";
}
