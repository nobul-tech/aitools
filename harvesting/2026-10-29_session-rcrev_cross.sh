#!/usr/bin/env bash
# Apply abort/relay drafts against other branches' copies (as they will be after merges).
set -euo pipefail
S=/Users/new-jose/repos/aitools/.scratch/session-rcrev/base
D=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Code-drafts
O=/Users/new-jose/repos/aitools/.scratch/session-rcrev/out2
rm -rf "$O" "$S/x116" "$S/x115"
mkdir -p "$S/x116/pr106" "$S/x116/main" "$S/x116/pr115" "$S/x115/main"
for f in aitools aitools.ps1 aitools-install.sh aitools-install.ps1; do cp "$S/pr116/$f" "$S/x116/pr106/$f"; done
for f in aitools-lib.sh aitools-lib.ps1; do cp "$S/pr116/$f" "$S/x116/main/$f"; cp "$S/pr116/$f" "$S/x116/pr115/$f"; cp "$S/pr115/$f" "$S/x115/main/$f"; done
cp "$S/pr116/aitools" "$S/x116/pr115/aitools-116"
echo "=== abort drafts vs #116 branch copies"
perl "$D/apply.pl" "$D/edits-abort.txt" "$S/x116" "$O/a116" 2>&1 || echo "FAILED abort on 116"
echo "=== relay drafts vs #116 branch lib"
perl "$D/apply.pl" "$D/edits-relay.txt" "$S/x116" "$O/r116" 2>&1 || echo "FAILED relay on 116"
echo "=== E1/E2 vs #115 lib"
perl "$D/apply.pl" "$D/edits-abort.txt" "$S/x115" "$O/a115" 2>&1 || echo "FAILED abort on 115 (expected: pr106 files absent)"
