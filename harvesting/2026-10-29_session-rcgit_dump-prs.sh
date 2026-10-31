#!/usr/bin/env bash
# Dump PR metadata, files, diffs, reviews and comments for PRs 97-116.
set -euo pipefail
out=/Users/new-jose/repos/aitools/.scratch/session-rcgit/prs
for n in $(seq 97 116); do
  gh pr view "$n" -R nobul-tech/aitools --json number,title,state,baseRefName,headRefName,headRefOid,mergeable,mergeStateStatus,reviews,comments,statusCheckRollup,files,body,commits > "$out/pr-$n.json"
  gh pr diff "$n" -R nobul-tech/aitools > "$out/pr-$n.diff" || echo "diff failed $n"
done
echo done
