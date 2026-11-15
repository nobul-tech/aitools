#!/usr/bin/env bash
# wait-agent.sh OUTPUT_FILE [MAX_SECONDS] -- wait until a delegate's transcript shows a real
# SubagentHandback tool call (or the timeout passes). Never prints the transcript.
set -euo pipefail
f="$1"; max="${2:-570}"; waited=0
pat='"type":"tool_use","id":"[^"]*","name":"SubagentHandback"'
until grep -qE "$pat" "$f" 2>/dev/null; do
    if [ "$waited" -ge "$max" ]; then
        printf 'still running after %ss\n' "$waited"
        exit 0
    fi
    sleep 10
    waited=$((waited + 10))
done
printf 'handback seen after %ss\n' "$waited"
