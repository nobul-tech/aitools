#!/usr/bin/env bash
# Concatenate report parts into S4-Review-report.md.
set -euo pipefail
d="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review"
s="$d/S4-Review-scratch"
cat "$s/part-0-2-4.md" "$s/part-1-overlaps.md" "$s/part-2-review.md" "$s/part-3-questions.md" "$s/part-4-incidents.md" "$s/part-5-batches.md" > "$d/S4-Review-report.md"
wc -l "$d/S4-Review-report.md"
