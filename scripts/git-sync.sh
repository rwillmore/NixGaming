
#!/usr/bin/env bash
set -euo pipefail

REPO="/home/rwillmore/NixGaming"
BRANCH="main"

# Absolute binaries so this works from systemd user services too
NIX="/run/current-system/sw/bin/nix"
GIT="/run/current-system/sw/bin/git"
SSH="/run/current-system/sw/bin/ssh"

# Make sure common tools are available even under systemd user env
export PATH="/run/current-system/sw/bin:${PATH:-}"
export GIT_SSH_COMMAND="$SSH"

cd "$REPO"

echo "=== Flake update ==="
"$NIX" flake update
echo

# Ensure .gitignore exists
touch .gitignore

# Ignore nixtray cache and generated lock artifacts
if ! grep -q "^\.cache/nixtray/\$" .gitignore 2>/dev/null; then
  printf "\n# nixtray cache\n.cache/nixtray/\n" >> .gitignore
fi
if ! grep -q "^\*\.nixtray\.new\$" .gitignore 2>/dev/null; then
  printf "*.nixtray.new\n" >> .gitignore
fi

# Ignore editor backups
if ! grep -q "^\*\.fishbak\.\*$" .gitignore 2>/dev/null; then
  printf "\n# editor backups\n*.fishbak.*\n" >> .gitignore
fi

# Stop tracking nixtray cache if it was accidentally committed before
"$GIT" rm -r --cached .cache/nixtray 2>/dev/null || true

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
