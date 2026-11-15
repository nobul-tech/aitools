#!/usr/bin/env bash
# run-baseline.sh -- run hookin and skills-fanout on the unmodified main baseline
set -uo pipefail
B="/Users/new-jose/repos/aitools/.claude/worktrees/harness-baseline"
D="$(cd "$(dirname "$0")" && pwd)/baseline"
mkdir -p "$D"
bash "$B/tests/hookin/test-hookin.sh" > "$D/hookin.log" 2>&1 &
p1=$!
bash "$B/tests/skills-fanout/test-skills-fanout.sh" > "$D/skills-fanout.log" 2>&1 &
p2=$!
wait "$p1"
wait "$p2"
grep -E '^FAIL|[0-9]+ passed' "$D/hookin.log" "$D/skills-fanout.log"
