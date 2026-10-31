#!/usr/bin/env bash
# Dump issue bodies (gh issue view --comments omits the body).
set -euo pipefail
out=/Users/new-jose/repos/aitools/.scratch/session-mafric/bodies.txt
: > "$out"
for n in 9 10 11 14 19 21 22 23 24 25 26 27 28 29 30 31 32 72; do
  printf '\n=========== ISSUE %s ===========\n' "$n" >> "$out"
  gh issue view "$n" -R nobul-tech/aitools --json title,body --jq '.title + "\n" + .body' >> "$out"
done
echo done
