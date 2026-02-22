#!/usr/bin/env bash
set -euo pipefail

# How many newest system generations to keep (default 5)
KEEP="${1:-5}"

if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 [KEEP_GENERATIONS]"
  echo "Example: $0 5"
  exit 2
fi

FLAKE="${FLAKE:-/home/rwillmore/NixGaming#gaming}"

echo "== NixOS garbage cleanup =="
echo "Keep newest generations: $KEEP"
echo "Flake: $FLAKE"
echo

echo "== Current system generations =="
sudo nix-env -p /nix/var/nix/profiles/system --list-generations || true
echo

echo "== Dry run: what would be collected =="
sudo nix-collect-garbage --dry-run || true
echo

echo "== Delete old system generations (keep newest $KEEP) =="
sudo nix-env -p /nix/var/nix/profiles/system --delete-generations "+$KEEP"
echo

echo "== Garbage collect (delete) =="
sudo nix-collect-garbage -d
echo

echo "== Rebuild boot entries =="
sudo nixos-rebuild boot --flake "$FLAKE"
echo

echo "== Done =="
echo "Disk usage:"
df -h / || true
