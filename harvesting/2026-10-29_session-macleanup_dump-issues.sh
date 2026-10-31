#!/usr/bin/env bash
# dump-issues.sh -- write open issue bodies and comments to issues.txt
set -euo pipefail
OUT=/Users/new-jose/repos/aitools/.scratch/session-macleanup/issues.txt
: > "$OUT"
for n in 31 29 28 27 26 25 24 23 22 21 19 14 10; do
  printf '===== #%s\n' "$n" >> "$OUT"
  gh issue view "$n" -R nobul-tech/aitools --json body,comments \
    --jq '.body, (.comments[] | "--- comment: " + .body)' >> "$OUT"
done
wc -l "$OUT"
