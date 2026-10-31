#!/usr/bin/env bash
# Which open PR heads contain other open PR heads (stack detection, read-only).
set -euo pipefail
R=/Users/new-jose/repos/aitools
git -C "$R" fetch -q origin
prs="97 98 100 101 102 103 104 105 106 108 109 110 111 112 113 114 115 116"
for a in $prs; do
  ha=$(gh pr view "$a" -R nobul-tech/aitools --json headRefOid --jq .headRefOid)
  echo "$a $ha" >> /Users/new-jose/repos/aitools/.scratch/session-fricprs/data/heads.txt
done
while read -r a ha; do
  inner=""
  while read -r b hb; do
    [ "$a" = "$b" ] && continue
    if git -C "$R" merge-base --is-ancestor "$hb" "$ha"; then inner="$inner #$b"; fi
  done < /Users/new-jose/repos/aitools/.scratch/session-fricprs/data/heads.txt
  behind=$(git -C "$R" rev-list --count "$ha..origin/main")
  echo "#$a contains:${inner:- none} ; main commits not in head: $behind"
done < /Users/new-jose/repos/aitools/.scratch/session-fricprs/data/heads.txt
