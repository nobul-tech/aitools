#!/usr/bin/env bash
# Export the base files the drafts apply to (read-only git show into scratch)
set -euo pipefail
R=/Users/new-jose/repos/aitools
B=/Users/new-jose/repos/aitools/.scratch/session-rccode/base
rm -rf "$B"
mkdir -p "$B/pr106" "$B/main" "$B/pr115"
for f in aitools aitools.ps1 aitools-install.sh aitools-install.ps1; do
  git -C "$R" show "origin/feature/harness-hookin:scripts/$f" > "$B/pr106/$f"
done
for f in aitools aitools.ps1 setup-user-config.sh setup-user-config.ps1 check-pre-push.sh check-pre-push.ps1 aitools-lib.sh aitools-lib.ps1; do
  git -C "$R" show "origin/main:scripts/$f" > "$B/main/$f"
done
for f in aitools-lib.sh aitools-lib.ps1; do
  git -C "$R" show "origin/fix/mf-lib-relay:scripts/$f" > "$B/pr115/$f"
done
ls -R "$B"
