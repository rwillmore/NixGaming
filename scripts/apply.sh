#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:-gaming}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="${REPO}/.logs"
LOG="${LOGDIR}/apply-${HOST}-${STAMP}.log"

mkdir -p "$LOGDIR"

echo "== Repo: $REPO ==" | tee -a "$LOG"
echo "== Host: $HOST ==" | tee -a "$LOG"
echo "== Time: $STAMP ==" | tee -a "$LOG"
echo | tee -a "$LOG"

cd "$REPO"

echo "== Git status ==" | tee -a "$LOG"
git status --porcelain=v1 | tee -a "$LOG" || true
echo | tee -a "$LOG"

echo "== Diff (working tree) ==" | tee -a "$LOG"
git --no-pager diff | tee -a "$LOG" || true
echo | tee -a "$LOG"

echo "== nix flake check ==" | tee -a "$LOG"
nix flake check --show-trace 2>&1 | tee -a "$LOG"
echo | tee -a "$LOG"

echo "== Build system ==" | tee -a "$LOG"
nix build ".#nixosConfigurations.${HOST}.config.system.build.toplevel" --show-trace 2>&1 | tee -a "$LOG"
echo | tee -a "$LOG"

echo "== Switch ==" | tee -a "$LOG"
echo "Running: sudo nixos-rebuild switch --flake .#${HOST} --show-trace" | tee -a "$LOG"
sudo nixos-rebuild switch --flake ".#${HOST}" --show-trace 2>&1 | tee -a "$LOG"
echo | tee -a "$LOG"

echo "== Done. Log: $LOG ==" | tee -a "$LOG"
echo "Rollback tip: sudo nixos-rebuild --rollback switch" | tee -a "$LOG"
