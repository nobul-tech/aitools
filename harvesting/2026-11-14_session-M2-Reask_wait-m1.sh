#!/usr/bin/env bash
# wait-m1.sh -- exit when the PR from fix/json-review-display is MERGED or CLOSED
# (or after MAX_MIN minutes). Prints the state.
set -uo pipefail
MAX_MIN="${1:-25}"
end=$(( $(date +%s) + MAX_MIN * 60 ))
while [ "$(date +%s)" -lt "$end" ]; do
    st=$(gh pr list --repo nobul-tech/aitools --head fix/json-review-display --state all --json number,state,url --jq '.[0] | "\(.number) \(.state) \(.url)"' 2>&1)
    case "$st" in
        *MERGED*|*CLOSED*) echo "M1 PR: $st"; exit 0 ;;
    esac
    sleep 60
done
echo "M1 PR not merged after $MAX_MIN min: ${st:-none}"
