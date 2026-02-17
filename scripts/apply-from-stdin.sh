#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-gaming}"
tmp="$(mktemp /tmp/nixgaming-patch.XXXXXX.diff)"

cat > "$tmp"
echo "Saved patch to: $tmp"

"$(dirname "$0")/patch-apply.sh" "$HOST" "$tmp"
