#!/usr/bin/env bash
# Dump PR metadata, comments, reviews, commits for PRs 50-120 (read-only).
set -euo pipefail
out=/Users/new-jose/repos/aitools/.scratch/session-fricprs/data
repo=nobul-tech/aitools
gh pr list -R "$repo" --state all --limit 200 \
  --json number,title,state,baseRefName,headRefName,createdAt,mergedAt,closedAt,mergeCommit,isDraft,additions,deletions,changedFiles \
  > "$out/list.json"
for n in $(seq 50 120); do
  if ! gh pr view "$n" -R "$repo" \
      --json number,title,state,body,baseRefName,headRefName,createdAt,mergedAt,comments,reviews,commits,files,mergeCommit,statusCheckRollup \
      > "$out/pr-$n.json" 2> "$out/pr-$n.err"; then
    echo "pr $n: not a PR or error" >&2
    rm -f "$out/pr-$n.json"
  fi
done
gh issue list -R "$repo" --state all --limit 300 --json number,title,state,createdAt,closedAt,labels,body > "$out/issues.json"
gh run list -R "$repo" --limit 300 --json databaseId,workflowName,headBranch,event,status,conclusion,createdAt,displayTitle > "$out/runs.json"
echo done
