#!/usr/bin/env bash
# combo.sh TMP -- apply draft files that share a target file together, in batch order.
set -euo pipefail
tmp="$1"
D=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Fix-drafts
cat "$D/high/edits-post-push-step7.txt" "$D/checks/edits-postpush.txt" > "$tmp/combo-postpush.txt"
cat "$D/code/edits-lib.txt" "$D/code/edits-entry.txt" "$D/checks/edits-sigpipe.txt" > "$tmp/combo-lib-entry.txt"
for c in combo-postpush combo-lib-entry; do
    bash /Users/new-jose/repos/aitools/.scratch/session-rcfix/apply-refs.sh "$tmp/$c.txt" "$tmp/$c" origin/main
done
