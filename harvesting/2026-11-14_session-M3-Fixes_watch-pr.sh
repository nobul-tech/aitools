#!/usr/bin/env bash
# Emit each PR check as it finishes; exit when none is pending. Usage: watch-pr.sh <pr>
set -uo pipefail
pr="$1"
prev=""
while true; do
    cur=$(gh pr checks "$pr" --repo nobul-tech/aitools --json name,bucket --jq '.[] | select(.bucket != "pending") | "\(.name): \(.bucket)"' 2>&1 | sort)
    if [ -n "$cur" ] && [ "$cur" != "$prev" ]; then
        printf '%s\n' "$cur" | grep -vxF -f <(printf '%s\n' "$prev") || true
        prev="$cur"
    fi
    pending=$(gh pr checks "$pr" --repo nobul-tech/aitools --json bucket --jq '[.[] | select(.bucket == "pending")] | length' 2>&1)
    if [ "$pending" = "0" ]; then echo "ALL CHECKS DONE"; exit 0; fi
    sleep 45
done
