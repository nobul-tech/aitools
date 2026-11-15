#!/usr/bin/env bash
# watch-main.sh SHA [MAX_MIN] -- wait for the CI workflow runs on main for SHA to finish; print them.
set -uo pipefail
SHA="$1"; MAX_MIN="${2:-40}"
end=$(( $(date +%s) + MAX_MIN * 60 ))
while [ "$(date +%s)" -lt "$end" ]; do
    out=$(gh run list --repo nobul-tech/aitools --commit "$SHA" --json databaseId,name,status,conclusion,event --jq '.[] | "\(.databaseId) \(.name) \(.event) \(.status) \(.conclusion)"' 2>&1)
    if [ -n "$out" ] && ! printf '%s\n' "$out" | grep -qvE ' completed '; then break; fi
    sleep 60
done
printf '%s\n' "$out"
for id in $(gh run list --repo nobul-tech/aitools --commit "$SHA" --json databaseId,name --jq '.[] | select(.name=="CI") | .databaseId'); do
    gh run view "$id" --repo nobul-tech/aitools --json jobs,url --jq '.url, (.jobs[] | "\(.name): \(.conclusion)")'
done
