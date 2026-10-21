#!/usr/bin/env bash
# Wait until reviewer A and B review files exist (max ~25 min).
set -euo pipefail
d="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review"
for _ in $(seq 1 150); do
    if [ -f "$d/S4-Review-A-review.md" ]; then
        if [ -f "$d/S4-Review-B-review.md" ]; then
            echo "both present"
            exit 0
        fi
    fi
    sleep 10
done
echo "timeout"
exit 1
