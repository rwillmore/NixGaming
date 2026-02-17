#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:-gaming}"

cd "$REPO"

# No-op fast path (do not create a log) unless FORCE=1
if [[ "${FORCE:-0}" != "1" ]] && [[ -z "$(git status --porcelain)" ]]; then
  echo "== No repo changes detected. Skipping build/switch. =="
  echo "Tip: run with FORCE=1 to rebuild anyway."
  exit 0
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="${REPO}/.logs"
LOG="${LOGDIR}/apply-${HOST}-${STAMP}.log"
mkdir -p "$LOGDIR"

on_err() {
  echo
  echo "== FAILED =="
  echo "Log: $LOG"
  echo
  echo "== Last 120 lines =="
  tail -n 120 "$LOG" || true
}
trap on_err ERR

log() { echo "$@" | tee -a "$LOG"; }

log "== Repo: $REPO =="
log "== Host: $HOST =="
log "== Time: $STAMP =="
log ""

log "== Git status =="
git status --porcelain=v1 2>&1 | tee -a "$LOG" || true
log ""

log "== Diff (working tree) =="
git --no-pager diff 2>&1 | tee -a "$LOG" || true
log ""

log "== nix flake check =="
nix flake check --show-trace 2>&1 | tee -a "$LOG"
log ""

log "== Build system =="
nix build -L ".#nixosConfigurations.${HOST}.config.system.build.toplevel" --show-trace 2>&1 | tee -a "$LOG"
log ""

log "== Switch =="
log "Running: nixos-rebuild switch --flake .#${HOST} --show-trace"
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  nixos-rebuild switch --flake ".#${HOST}" --show-trace 2>&1 | tee -a "$LOG"
else
  sudo nixos-rebuild switch --flake ".#${HOST}" --show-trace 2>&1 | tee -a "$LOG"
fi
log ""

log "== Done. Log: $LOG =="
log "Rollback tip: sudo nixos-rebuild --rollback switch"
