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

# No-op fast path (do not create a log) unless FORCE=1
if git diff --quiet && git diff --cached --quiet && [[ "${FORCE:-0}" != "1" ]]; then
  echo "== No repo changes detected. Skipping build/switch. =="
  echo "Tip: run with FORCE=1 to rebuild anyway."
  exit 0
fi


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
nix build -L ".#nixosConfigurations.${HOST}.config.system.build.toplevel" --show-trace 2>&1 | tee -a "$LOG"
echo | tee -a "$LOG"

echo "== Switch ==" | tee -a "$LOG"
echo "Running: sudo nixos-rebuild switch --flake .#${HOST} --show-trace" | tee -a "$LOG"
sudo nixos-rebuild switch --flake ".#${HOST}" --show-trace 2>&1 | tee -a "$LOG"
echo | tee -a "$LOG"

echo "== Done. Log: $LOG ==" | tee -a "$LOG"
echo "Rollback tip: sudo nixos-rebuild --rollback switch" | tee -a "$LOG"
