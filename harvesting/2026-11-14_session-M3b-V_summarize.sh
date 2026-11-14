#!/usr/bin/env bash
# summarize.sh -- M3b-Finish-V: print exit code, last 3 non-empty lines and the
# FAIL / SKIP / error lines of every suite log.
set -uo pipefail
S="C:/Users/jdpal/repos/aitools/.claude/worktrees/console-input/.scratch/session-M3b-V"
tail -n +2 "$S/suite-results.tsv" | while IFS=$'\t' read -r name cmd rc sec; do
    log="$S/suite-logs/$name.log"
    echo "=== $name | exit=$rc | ${sec}s | $cmd"
    grep -v '^[[:space:]]*$' "$log" | tail -n 3 | sed 's/^/    tail: /'
    nf=$(grep -cE '^[[:space:]]*(FAIL|not ok|fail )' "$log")
    ns=$(grep -cE '^[[:space:]]*(SKIP|skip )' "$log")
    echo "    FAIL-lines=$nf SKIP-lines=$ns"
    grep -nE '^[[:space:]]*(FAIL|not ok|fail )' "$log" | head -n 20 | sed 's/^/    F: /'
done
