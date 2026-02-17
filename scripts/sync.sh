#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-gaming}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO"

echo "== Repo: $REPO =="
echo "== Host: $HOST =="
echo

oldrev="$(git rev-parse HEAD)"

echo "== Git: fetch =="
git fetch --prune

echo
echo "== Git: status before =="
git status -sb

echo
echo "== Git: pull (rebase + autostash) =="
git pull --rebase --autostash

newrev="$(git rev-parse HEAD)"

echo
echo "== Git: status after =="
git status -sb

echo
if [[ "$oldrev" != "$newrev" ]]; then
  echo "== Apply (new commit detected, forcing rebuild) =="
  FORCE=1 ./scripts/apply.sh "$HOST"
else
  echo "== Apply (no new commit) =="
  ./scripts/apply.sh "$HOST"
fi

echo
echo "Done."
