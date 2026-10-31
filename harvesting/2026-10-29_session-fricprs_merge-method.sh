#!/usr/bin/env bash
# For merged PRs 50-99: merge commit parent count (2 = merge commit, 1 = squash/rebase) and who merged.
set -euo pipefail
git -C /Users/new-jose/repos/aitools fetch -q origin
for n in $(seq 50 99); do
  line=$(gh pr view "$n" -R nobul-tech/aitools --json state,mergeCommit,mergedBy,baseRefName --jq '"\(.state) \(.mergeCommit.oid // "-") \(.mergedBy.login // "-") \(.baseRefName)"' 2>/dev/null) || continue
  set -- $line
  if [ "$1" = "MERGED" ]; then
    parents=$(git -C /Users/new-jose/repos/aitools rev-list --parents -n 1 "$2" | wc -w)
    onmain=no
    if git -C /Users/new-jose/repos/aitools merge-base --is-ancestor "$2" origin/main; then onmain=yes; fi
    echo "#$n merged_by=$3 base=$4 commit=${2:0:7} parents=$((parents - 1)) on_main=$onmain"
  fi
done
