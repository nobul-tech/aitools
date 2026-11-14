#!/usr/bin/env bash
# Compare two build-deploy outputs with timestamps and temp-name suffixes normalised.
set -euo pipefail
d=/c/Users/jdpal/repos/aitools/.claude/worktrees/console-profile/.scratch/session-M3-B
norm() {
    perl -pe 's/^\[[0-9TZ:-]+\] //; s/deploy\.(swap\.bak|bak)\.[A-Za-z0-9T:-]+/deploy.$1.X/g; s/ (Nov|Dec) \d+ \d\d:\d\d / DATE /' "$1"
}
norm "$d/build-output-guard.log" > "$d/cmp-guard.tmp"
norm "$d/build-output-guard-nullstdin.log" > "$d/cmp-guard-nullstdin.tmp"
norm "$d/build-output-nullstdin.log" > "$d/cmp-nullstdin-1.tmp"
echo "== guard (console stdin) vs guard-nullstdin (pipe stdin):"
if diff "$d/cmp-guard.tmp" "$d/cmp-guard-nullstdin.tmp"; then echo "IDENTICAL (after normalisation)"; fi
echo "== deploy/ tree after last build: file count"
ls "$d/dotprofile/deploy" | wc -l
