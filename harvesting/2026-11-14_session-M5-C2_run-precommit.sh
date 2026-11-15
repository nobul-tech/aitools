#!/usr/bin/env bash
# Run the CI-suites check (as check.yml runs it) and check-pre-commit.ps1 from the
# worktree, logs into scratch. Arg 1: a label for the log dir / output file.
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/m5-checks
S=$WT/.scratch/session-M5-C2
label="${1:-run}"
cd "$WT"
echo "=== check-ci-suites ==="
rc=0
git ls-files 'tests/*/test-*.sh' 'tests/*/test-*.ps1' | perl scripts/check-ci-suites.pl .github/workflows/check.yml || rc=$?
echo "check-ci-suites exit: $rc"
echo "=== check-pre-commit.ps1 ==="
mkdir -p "$S/logs-$label"
rc=0
AITOOLS_LOG_DIR="$(cygpath -w "$S/logs-$label")" pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$WT/scripts/check-pre-commit.ps1")" > "$S/precommit-$label.log" 2>&1 || rc=$?
perl -pe 's/\e\[[0-9;]*m//g' "$S/precommit-$label.log" | grep -E "FAIL|WARN|PASS|SKIP|Summary|passed|failed" | tail -n 40
echo "check-pre-commit exit: $rc"
