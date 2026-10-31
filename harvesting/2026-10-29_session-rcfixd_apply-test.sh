#!/usr/bin/env bash
# apply-test.sh REF -- export the files the docs drafts touch from REF into a
# mktemp dir, apply every edits-*.txt with apply.pl, report per-file results.
set -euo pipefail
R=/Users/new-jose/repos/aitools
REF="${1:-origin/main}"
D="$R/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Fix-drafts/docs"
APPLY="$R/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Code-drafts/apply.pl"
T=$(mktemp -d)
mkdir -p "$T/base" "$T/out"
files=$(perl -ne 'print "$1\n" if /^\@\@\@FILE (\S+)/' "$D"/edits-*.txt | sort -u)
# shellcheck disable=SC2086
git -C "$R" archive "$REF" $files | tar -x -C "$T/base"
echo "export: $T (ref $REF, $(git -C "$R" rev-parse --short "$REF"))"
fail=0
for e in "$D"/edits-*.txt; do
    echo "== $(basename "$e")"
    if ! perl "$APPLY" "$e" "$T/base" "$T/out"; then
        echo "FAILED: $(basename "$e")"
        fail=1
    fi
done
echo "== duplicate-check: files touched by more than one edits file"
for f in $files; do
    n=$(grep -l -F "@@@FILE $f " "$D"/edits-*.txt | wc -l | tr -d ' ')
    if [ "$n" != "1" ]; then echo "MULTI: $f in $n files"; fi
done
echo "== diffstat"
for f in $files; do
    if [ -f "$T/out/$f" ]; then
        printf '%s: ' "$f"
        diff "$T/base/$f" "$T/out/$f" | grep -c '^[<>]' || true
    fi
done
echo "result: fail=$fail"
exit "$fail"
