#!/usr/bin/env bash
# pr-status.sh PR... -- print mergeability, changed files, head and latest CI run per PR
set -euo pipefail
for pr in "$@"; do
    info=$(gh api "repos/nobul-tech/aitools/pulls/$pr" --jq '"\(.head.ref) \(.head.sha[0:7]) mergeable=\(.mergeable) state=\(.mergeable_state) files=\(.changed_files)"')
    branch=${info%% *}
    run=$(gh run list --repo nobul-tech/aitools --branch "$branch" --workflow CI --limit 1 --json databaseId,headSha,status,conclusion --jq '.[0] | "run=\(.databaseId) sha=\(.headSha[0:7]) \(.status) \(.conclusion)"')
    printf '#%s %s | %s\n' "$pr" "$info" "$run"
done
