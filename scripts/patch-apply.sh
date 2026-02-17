#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-gaming}"
PATCH="${2:-}"

if [[ -z "$PATCH" || ! -f "$PATCH" ]]; then
  echo "Usage: $0 [host] /path/to/patch.diff"
  exit 1
fi

BR="change-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BR"

git apply "$PATCH"
git status --porcelain

"$(dirname "$0")/apply.sh" "$HOST"
echo
echo "If everything looks good:"
echo "  git add -A && git commit -m \"Apply patch\" && git checkout main && git merge $BR"
echo "If you want to discard:"
echo "  git checkout main && git branch -D $BR"
