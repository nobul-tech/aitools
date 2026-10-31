#!/usr/bin/env bash
# Build a throwaway repo copy (origin/main + the item 4/5 drafts + test edits) for
# tests/profile/test-user-init.sh. The test builds isolated HOMEs itself.
set -euo pipefail
R=/Users/new-jose/repos/aitools
S=/Users/new-jose/repos/aitools/.scratch/session-rccode
C="$S/repo-claim"
rm -rf "$C"
mkdir -p "$C"
git -C "$R" archive -o "$S/main.tar" origin/main scripts shared tests
tar -xf "$S/main.tar" -C "$C"
cp "$S/out2/main/aitools" "$C/scripts/aitools"
cp "$S/out2/main/aitools.ps1" "$C/scripts/aitools.ps1"
cp "$S/out2/main/setup-user-config.sh" "$C/scripts/setup-user-config.sh"
cp "$S/out2/main/setup-user-config.ps1" "$C/scripts/setup-user-config.ps1"
chmod +x "$C/scripts/aitools"
perl "$S/apply.pl" "$S/edits-test.txt" "$C" "$C.t"
cp "$C.t/tests/profile/test-user-init.sh" "$C/tests/profile/test-user-init.sh"
echo "copy ready: $C"
