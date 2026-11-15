#!/usr/bin/env bash
# run-suites.sh -- run the remaining suites for M5-L1, one log per suite, and print
# each suite's exit code and its last summary line. Usage: run-suites.sh
set -uo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
S="$WT/.scratch/session-M5-L1"
cd "$WT"
run() {  # name, command...
    local name="$1"; shift
    "$@" > "$S/suite-$name.log" 2>&1
    local rc=$?
    printf '%-28s rc=%s  %s\n' "$name" "$rc" "$(grep -E 'passed|PASS:|FAIL:|Summary|failed' "$S/suite-$name.log" | tail -n 1)"
}
run menus-ps1 pwsh -NoProfile -File "$(cygpath -w "$WT/tests/menus/test-menu-choice.ps1")"
run managed-files-sh bash "$WT/tests/managed-files/test-managed-files.sh"
run managed-files-ps1 pwsh -NoProfile -File "$(cygpath -w "$WT/tests/managed-files/test-managed-files.ps1")"
run adopt-push-sh bash "$WT/tests/managed-files/test-adopt-push.sh"
run adopt-push-ps1 pwsh -NoProfile -File "$(cygpath -w "$WT/tests/managed-files/test-adopt-push.ps1")"
run os-guards bash "$WT/tests/os-guards/test-os-guards.sh"
