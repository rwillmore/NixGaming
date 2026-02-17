#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-gaming}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO"

echo "== Repo: $REPO =="
echo "== Host: $HOST =="
echo

echo "== Git: fetch =="
git fetch --prune

echo
echo "== Git: status before =="
git status -sb

echo
echo "== Git: pull (rebase + autostash) =="
git pull --rebase --autostash

echo
echo "== Git: status after =="
git status -sb

echo
echo "== Apply =="
./scripts/apply.sh "$HOST"

echo
echo "Done."
echo "Tip: FORCE=1 ./scripts/force-apply.sh $HOST  (rebuild even if no repo changes)"
