#!/usr/bin/env bash
# Poll nobul-tech/aitools for the M1 PR (head fix/json-review-display); exit when merged or closed.
set -uo pipefail
prev=""
while true; do
    s=$(gh pr list --repo nobul-tech/aitools --head fix/json-review-display --state all --json number,state,mergedAt --jq '.[] | "\(.number) \(.state) \(.mergedAt)"' 2>&1)
    if [ "$s" != "$prev" ]; then
        echo "M1 PR: ${s:-none yet}"
        prev="$s"
    fi
    case "$s" in
        *MERGED*|*CLOSED*) exit 0 ;;
    esac
    sleep 60
done
