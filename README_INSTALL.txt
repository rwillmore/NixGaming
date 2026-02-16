NixOS Update Tray (flake packaged)

Copy these files into your repo at:
  /home/rwillmore/NixGaming

Paths (relative to repo root):
  pkgs/nixtray/default.nix
  pkgs/nixtray/nixtray/__init__.py
  pkgs/nixtray/nixtray/__main__.py
  modules/nixtray.nix

Then you must wire it into flake.nix and enable it in hosts/gaming/configuration.nix.

Recommended wiring:

1) In flake.nix, add package:
  packages.${system}.nixtray = pkgs.callPackage ./pkgs/nixtray { };

2) In nixosConfigurations.gaming.modules, add:
  ./modules/nixtray.nix

3) In hosts/gaming/configuration.nix, enable:
  services.nixtray = {
    enable = true;
    repo = "/home/rwillmore/NixGaming";
    host = "gaming";
    debug = true;
    keepLock = true;
  };

Then apply:
  cd /home/rwillmore/NixGaming
  sudo nixos-rebuild switch --flake ".#gaming"

Restart tray:
  systemctl --user daemon-reload
  systemctl --user restart nixtray.service
  systemctl --user status nixtray.service --no-pager

Artifacts:
  Lock file: /home/rwillmore/NixGaming/.cache/nixtray/flake.lock.nixtray.new
  Log file:  ~/.cache/nixtray.log
