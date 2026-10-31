#!/usr/bin/env bash
# Dump issue bodies+comments and PR history for friction research (read-only).
set -euo pipefail
out=/Users/new-jose/repos/aitools/.scratch/session-mafric
for n in 7 9 10 11 12 13 14 15 16 17 18 19 21 22 23 24 25 26 27 28 29 30 31 32 72; do
  if [ ! -s "$out/issue-$n.txt" ]; then
    gh issue view "$n" -R nobul-tech/aitools --comments > "$out/issue-$n.txt"
  fi
done
gh pr list -R nobul-tech/aitools --state all --limit 200 --json number,title,state,createdAt,mergedAt,closedAt,headRefName,isDraft,body > "$out/prs.json"
gh run list -R nobul-tech/aitools --limit 200 --json databaseId,name,headBranch,conclusion,event,createdAt,displayTitle > "$out/runs.json"
echo done
