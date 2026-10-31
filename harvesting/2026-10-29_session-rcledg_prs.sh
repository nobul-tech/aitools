#!/usr/bin/env bash
# List state, merge commit and whether the merge commit is on origin/main for given PR numbers.
set -euo pipefail
for n in "$@"; do
  line=$(gh pr view "$n" -R nobul-tech/aitools --json number,state,mergedAt,mergeCommit,baseRefName,headRefName,title --jq '"\(.number)\t\(.state)\t\(.mergedAt)\t\(.mergeCommit.oid // "-")\tbase=\(.baseRefName)\thead=\(.headRefName)\t\(.title)"')
  oid=$(printf '%s' "$line" | cut -f4)
  onmain="n/a"
  if [ "$oid" != "-" ]; then
    if git -C /Users/new-jose/repos/aitools merge-base --is-ancestor "$oid" origin/main; then onmain="on-main"; else onmain="NOT-on-main"; fi
  fi
  printf '%s\t%s\n' "$line" "$onmain"
done
