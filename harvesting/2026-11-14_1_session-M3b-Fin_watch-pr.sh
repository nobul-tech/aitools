#!/usr/bin/env bash
# Emit each PR check as it finishes; exit when checks exist and none is pending.
# "No checks reported yet" counts as pending (right after a push GitHub lists none).
# Usage: watch-pr.sh <pr> <max-seconds>
set -uo pipefail
pr="$1"; max="$2"
end=$(( $(date +%s) + max ))
prev=""
while true; do
    cur=$(gh pr checks "$pr" --repo nobul-tech/aitools --json name,bucket --jq '.[] | select(.bucket != "pending") | "\(.name): \(.bucket)"' 2>/dev/null | sort)
    if [ -n "$cur" ] && [ "$cur" != "$prev" ]; then
        printf '%s\n' "$cur" | grep -vxF -f <(printf '%s\n' "$prev") || true
        prev="$cur"
    fi
    total=$(gh pr checks "$pr" --repo nobul-tech/aitools --json bucket --jq 'length' 2>/dev/null)
    pending=$(gh pr checks "$pr" --repo nobul-tech/aitools --json bucket --jq '[.[] | select(.bucket == "pending")] | length' 2>/dev/null)
    if [ -n "$total" ] && [ "$total" != "0" ] && [ "$pending" = "0" ]; then echo "ALL CHECKS DONE"; exit 0; fi
    if [ "$(date +%s)" -ge "$end" ]; then echo "TIMEOUT"; exit 1; fi
    sleep 45
done
