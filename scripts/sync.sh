#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-gaming}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO"

oldrev="$(git rev-parse HEAD)"

echo "== Git pull =="
git pull --rebase --autostash

newrev="$(git rev-parse HEAD)"
dirty="$(git status --porcelain || true)"

if [[ "$oldrev" != "$newrev" || -n "$dirty" ]]; then
  echo "== Apply (forcing) =="
  FORCE=1 ./scripts/apply.sh "$HOST"
else
  echo "== Apply =="
  ./scripts/apply.sh "$HOST"
fi
