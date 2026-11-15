#!/usr/bin/env bash
# run-related.sh -- run the suites that exercise deploy-harness / build-deploy,
# in parallel; one log per suite, then a one-line result per suite.
set -uo pipefail
W="/Users/new-jose/repos/aitools/.claude/worktrees/harness-shared"
D="$(cd "$(dirname "$0")" && pwd)/related"
mkdir -p "$D"
suites="hookin/test-hookin.sh build-deploy/test-build-deploy-backup.sh skills-fanout/test-skills-fanout.sh skills-legacy/test-skills-legacy.sh claude-mdm/test-claude-mdm.sh rules-fanout/test-rules-fanout.sh rules-fanout-cursor/test-rules-fanout-cursor.sh fanout-lib/test-fanout-lib.sh"
pids=()
for s in $suites; do
    n="${s%%/*}"
    ( bash "$W/tests/$s" > "$D/$n.log" 2>&1; echo $? > "$D/$n.rc" ) &
    pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done
for s in $suites; do
    n="${s%%/*}"
    printf '%s rc=%s %s\n' "$n" "$(cat "$D/$n.rc")" "$(grep -E '[0-9]+ passed' "$D/$n.log" | tail -n 1)"
done
