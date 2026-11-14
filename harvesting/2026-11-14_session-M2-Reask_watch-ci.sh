#!/usr/bin/env bash
# watch-ci.sh PR [MAX_MIN] -- exit when every check on the PR has finished (or
# after MAX_MIN minutes); print each check's name and conclusion, and the
# merge state.
set -uo pipefail
PR="$1"; MAX_MIN="${2:-30}"
end=$(( $(date +%s) + MAX_MIN * 60 ))
while [ "$(date +%s)" -lt "$end" ]; do
    pending=$(gh pr view "$PR" --repo nobul-tech/aitools --json statusCheckRollup --jq '[.statusCheckRollup[] | select(.status != "COMPLETED")] | length' 2>&1)
    if [ "$pending" = "0" ]; then break; fi
    sleep 60
done
gh pr view "$PR" --repo nobul-tech/aitools --json mergeStateStatus,headRefOid,statusCheckRollup \
    --jq '"merge=\(.mergeStateStatus) head=\(.headRefOid)", (.statusCheckRollup[] | "\(.name): \(.status) \(.conclusion) \(.detailsUrl)")'
