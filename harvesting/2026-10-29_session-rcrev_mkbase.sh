#!/usr/bin/env bash
# Build base dirs for apply.pl checks from git refs (read-only on the repo).
set -euo pipefail
R=/Users/new-jose/repos/aitools
S=/Users/new-jose/repos/aitools/.scratch/session-rcrev/base
rm -rf "$S"
mkdir -p "$S/main" "$S/pr106" "$S/pr115" "$S/tests/profile" "$S/pr116"
for f in aitools aitools.ps1 setup-user-config.sh setup-user-config.ps1 aitools-lib.sh aitools-lib.ps1 check-pre-push.sh check-pre-push.ps1 aitools-install.sh aitools-install.ps1 aitools-profile.sh aitools-profile.ps1; do
  git -C "$R" show "origin/main:scripts/$f" > "$S/main/$f"
  git -C "$R" show "origin/feature/harness-hookin:scripts/$f" > "$S/pr106/$f"
  git -C "$R" show "origin/fix/mf-lib-relay:scripts/$f" > "$S/pr115/$f"
  git -C "$R" show "origin/fix/mf-installer-relay:scripts/$f" > "$S/pr116/$f"
done
cp "$S/pr116/aitools" "$S/pr115/aitools-116"
git -C "$R" show "origin/main:tests/profile/test-user-init.sh" > "$S/tests/profile/test-user-init.sh"
mkdir -p "$S/t116/tests/profile"
git -C "$R" show "origin/fix/mf-installer-relay:tests/profile/test-user-init.sh" > "$S/t116/tests/profile/test-user-init.sh"
D=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Code-drafts
O=/Users/new-jose/repos/aitools/.scratch/session-rcrev/out
rm -rf "$O"
for e in abort claim relay step7 test; do
  echo "=== edits-$e.txt (stated base)"
  perl "$D/apply.pl" "$D/edits-$e.txt" "$S" "$O/$e" 2>&1 || echo "FAILED edits-$e"
done
echo "=== edits-test.txt against #116 test file"
perl "$D/apply.pl" "$D/edits-test.txt" "$S/t116" "$O/test116" 2>&1 || echo "FAILED edits-test on 116"
# main/ edits against merged-later branches: claim on #116 aitools
mkdir -p "$S/m116/main"
cp "$S/pr116/aitools" "$S/pr116/aitools.ps1" "$S/m116/main/"
cp "$S/pr116/setup-user-config.sh" "$S/pr116/setup-user-config.ps1" "$S/m116/main/"
echo "=== edits-claim.txt against #116 branch copies"
perl "$D/apply.pl" "$D/edits-claim.txt" "$S/m116" "$O/claim116" 2>&1 || echo "FAILED edits-claim on 116"
