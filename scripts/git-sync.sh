#!/usr/bin/env bash
set -euo pipefail

REPO="/home/rwillmore/NixGaming"
BRANCH="main"

cd "$REPO"

# Ignore editor backups
if ! grep -q "^\*\.fishbak\.\*$" .gitignore 2>/dev/null; then
  printf "
# editor backups
*.fishbak.*
" >> .gitignore
fi

# Remove fish backup files
rm -f hosts/gaming/*.fishbak.* 2>/dev/null || true

git add -A

if git diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi

msg="Sync NixGaming $(date +%Y-%m-%d_%H%M)"
git commit -m "$msg"
git push origin "$BRANCH"

echo "Done."
