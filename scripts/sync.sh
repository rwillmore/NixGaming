#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-gaming}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO"

echo "== Sync: repo pull =="
git pull --rebase --autostash

echo
echo "== Apply =="
# If the pull produced changes, apply.sh will run.
# If nothing changed, apply.sh will fast-exit unless you force it.
./scripts/apply.sh "$HOST" || true

echo
echo "Done."
echo "Tip: FORCE=1 ./scripts/sync.sh ${HOST}  (rebuild even if no repo changes)"
