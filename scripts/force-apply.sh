#!/usr/bin/env bash
set -euo pipefail
FORCE=1 exec "$(dirname "$0")/apply.sh" "${1:-gaming}"
