{ lib, writeShellScriptBin, ... }:

(writeShellScriptBin "nixgarbage" ''
  set -euo pipefail

  KEEP="''${1:-5}"
  if ! echo "$KEEP" | grep -Eq '^[0-9]+$'; then
    echo "Usage: nixgarbage [KEEP_GENERATIONS]"
    echo "Example: nixgarbage 5"
    exit 2
  fi

  FLAKE="''${FLAKE:-/home/rwillmore/NixGaming#gaming}"

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
