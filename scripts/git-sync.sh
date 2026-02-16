#!/usr/bin/env bash
set -euo pipefail

REPO="/home/rwillmore/NixGaming"
BRANCH="main"

# Absolute binaries so this works from systemd user services too
NIX="/run/current-system/sw/bin/nix"
GIT="/run/current-system/sw/bin/git"

cd "$REPO"

echo "=== Flake update ==="
"$NIX" flake update
echo

# Ignore editor backups
if ! grep -q "^\*\.fishbak\.\*$" .gitignore 2>/dev/null; then
  printf "
# editor backups
*.fishbak.*
" >> .gitignore
fi

# Remove fish backup files
rm -f hosts/gaming/*.fishbak.* 2>/dev/null || true

"$GIT" add -A

if "$GIT" diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi

msg="Sync NixGaming $(date +%Y-%m-%d_%H%M)"
"$GIT" commit -m "$msg"
"$GIT" push origin "$BRANCH"

echo "Done."
