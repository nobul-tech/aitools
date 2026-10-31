#!/usr/bin/env bash
# reapply-all.sh TMP -- re-apply every S3-Reconcile-Fix main-based draft file on origin/main.
set -euo pipefail
tmp="$1"
D=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Fix-drafts
n=0
for f in "$D"/high/edits-*.txt "$D"/code/edits-lib.txt "$D"/code/edits-entry.txt "$D"/code/edits-installer.txt "$D"/code/edits-relay-prompt.txt "$D"/code/edits-harness.txt "$D"/code/edits-build.txt "$D"/code/edits-misc.txt "$D"/checks/edits-*.txt "$D"/docs/edits-*.txt; do
    n=$((n + 1))
    out=$(bash /Users/new-jose/repos/aitools/.scratch/session-rcfix/apply-refs.sh "$f" "$tmp/re$n" origin/main 2>&1) || out="$out (script rc $?)"
    if printf '%s\n' "$out" | grep -q 'FAIL'; then
        echo "FAIL: $(basename "$(dirname "$f")")/$(basename "$f")"
        printf '%s\n' "$out" | grep -E 'FAIL|edit ' || true
    else
        echo "ok: $(basename "$(dirname "$f")")/$(basename "$f") -- $(printf '%s\n' "$out" | grep 'edit(s) applied')"
    fi
done
