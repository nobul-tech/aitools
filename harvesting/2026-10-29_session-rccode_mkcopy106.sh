#!/usr/bin/env bash
# Throwaway copy of PR #106 (feature/harness-hookin) + the item 3 runner drafts,
# for tests/hookin/test-hookin.sh (which builds isolated HOMEs itself)
set -euo pipefail
R=/Users/new-jose/repos/aitools
S=/Users/new-jose/repos/aitools/.scratch/session-rccode
C="$S/repo-106"
rm -rf "$C"
mkdir -p "$C"
git -C "$R" archive -o "$S/pr106.tar" origin/feature/harness-hookin scripts shared tests
tar -xf "$S/pr106.tar" -C "$C"
for f in aitools aitools.ps1 aitools-install.sh aitools-install.ps1; do
  cp "$S/out/pr106/$f" "$C/scripts/$f"
done
chmod +x "$C/scripts/aitools" "$C/scripts/aitools-install.sh"
echo "copy ready: $C"
