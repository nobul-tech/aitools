#!/usr/bin/env bash
# test-check-ci-suites.sh -- tests for scripts/check-ci-suites.pl, the logic of
# the CI step "Every test suite is in CI" (.github/workflows/check.yml).
#
# Cases: the current tree passes (every tracked test-*.sh and test-*.ps1 has a
# step); a planted test-*.ps1 or test-*.sh with no step fails; removing the
# step of a tracked .ps1 suite (and of a .sh suite) from a copy of the
# workflow fails; the .ps1 forms that count (pwsh -File, no -File, a \ path, a
# quoted path, -file in lower case); the forms that do not (bash running a
# .ps1, a step after "#", a longer file name, a "run: |" block); an unsupported
# suite type; no suites on stdin; --help; a workflow that cannot be read.
#
# Safe to re-run: writes only to a temp dir, removed on exit. Needs git and
# perl. Exit 1 if any case fails.
# Platform: macOS, Linux, Windows Git Bash (CI: linux job).
# Usage: bash tests/ci-suites/test-check-ci-suites.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 16' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$ROOT/scripts/check-ci-suites.pl"
WF="$ROOT/.github/workflows/check.yml"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -f "$TMP_ROOT/out" ]; then
            perl -pe 's/^/      | /' "$TMP_ROOT/out" | tail -n 15
        fi
    fi
}

# run_check <stdin file> <workflow>: exit code in RC, output in $TMP_ROOT/out
run_check() {
    RC=0
    perl "$CHECK" "$2" < "$1" > "$TMP_ROOT/out" 2>&1 || RC=$?
}

# The tracked suites, as CI lists them
LIST="$TMP_ROOT/suites.txt"
if ! git -C "$ROOT" ls-files 'tests/*/test-*.sh' 'tests/*/test-*.ps1' > "$LIST"; then
    printf 'FAIL git ls-files failed in %s\n' "$ROOT"
    exit 1
fi
N_PS1=$(perl -ne '$n++ if /\.ps1$/; END { print $n || 0 }' "$LIST")

# --- The current tree -------------------------------------------------------
run_check "$LIST" "$WF"
check "current tree: every tracked suite has a step (exit 0)" "[ $RC -eq 0 ] && grep -q '^All [0-9]* test suites are in CI or exempt' '$TMP_ROOT/out'"
check "current tree: the .ps1 suites are in the list ($N_PS1 found)" "[ $N_PS1 -ge 1 ]"

# --- Planted suites with no step ------------------------------------------
cp "$LIST" "$TMP_ROOT/planted-ps1.txt"
printf 'tests/planted/test-planted.ps1\n' >> "$TMP_ROOT/planted-ps1.txt"
run_check "$TMP_ROOT/planted-ps1.txt" "$WF"
check "planted test-*.ps1 with no step: exit 1, named" "[ $RC -eq 1 ] && grep -q '::error::tests/planted/test-planted.ps1 is not run by any step' '$TMP_ROOT/out'"

cp "$LIST" "$TMP_ROOT/planted-sh.txt"
printf 'tests/planted/test-planted.sh\n' >> "$TMP_ROOT/planted-sh.txt"
run_check "$TMP_ROOT/planted-sh.txt" "$WF"
check "planted test-*.sh with no step: exit 1, named" "[ $RC -eq 1 ] && grep -q '::error::tests/planted/test-planted.sh is not run by any step' '$TMP_ROOT/out'"

# --- A step removed from a copy of the workflow -----------------------------
perl -ne 'print unless m{^\s*run:.*tests/logging/test-logging\.ps1}' "$WF" > "$TMP_ROOT/no-ps1-step.yml"
run_check "$LIST" "$TMP_ROOT/no-ps1-step.yml"
check "workflow without the tests/logging/test-logging.ps1 step: exit 1, named" "[ $RC -eq 1 ] && grep -q '::error::tests/logging/test-logging.ps1 is not run' '$TMP_ROOT/out'"
check "workflow without that step: tests/logging/test-logging.sh still counts" "! grep -q 'test-logging.sh is not run' '$TMP_ROOT/out'"

perl -ne 'print unless m{^\s*run:.*tests/os-guards/test-os-guards\.sh}' "$WF" > "$TMP_ROOT/no-sh-step.yml"
run_check "$LIST" "$TMP_ROOT/no-sh-step.yml"
check "workflow without the tests/os-guards/test-os-guards.sh steps: exit 1, named" "[ $RC -eq 1 ] && grep -q '::error::tests/os-guards/test-os-guards.sh is not run' '$TMP_ROOT/out'"

# --- .ps1 forms ------------------------------------------------------------
# form_case <name> <want rc> <run: text>: one suite tests/x/test-y.ps1 against a
# one-step workflow
form_case() {
    printf 'tests/x/test-y.ps1\n' > "$TMP_ROOT/one.txt"
    printf 'jobs:\n  windows:\n    steps:\n      - name: t\n        shell: pwsh\n        run: %s\n' "$3" > "$TMP_ROOT/form.yml"
    run_check "$TMP_ROOT/one.txt" "$TMP_ROOT/form.yml"
    check "$1" "[ $RC -eq $2 ]"
}
form_case "ps1 form counts: pwsh -NoProfile -File <path>" 0 'pwsh -NoProfile -File tests/x/test-y.ps1'
form_case "ps1 form counts: pwsh <path> (no -File)" 0 'pwsh -NoProfile tests/x/test-y.ps1'
form_case "ps1 form counts: a \\ path" 0 'pwsh -NoProfile -File tests\x\test-y.ps1'
form_case "ps1 form counts: a quoted path" 0 'pwsh -NoProfile -File "tests/x/test-y.ps1"'
form_case "ps1 form counts: -file in lower case, arguments after the path" 0 'pwsh -NoProfile -file tests/x/test-y.ps1 -Verbose'
form_case "ps1 form does not count: bash running a .ps1" 1 'bash tests/x/test-y.ps1'
form_case "ps1 form does not count: the step after a #" 1 'echo skipped # pwsh -File tests/x/test-y.ps1'
form_case "ps1 form does not count: a longer file name (test-y.ps1x)" 1 'pwsh -File tests/x/test-y.ps1x'
form_case "ps1 form does not count: another suite (test-yz.ps1)" 1 'pwsh -File tests/x/test-yz.ps1'
form_case "ps1 form does not count: a run: | block (documented blind spot)" 1 '|
          pwsh -File tests/x/test-y.ps1'

# --- Input errors --------------------------------------------------------------
printf 'tests/x/test-y.py\n' > "$TMP_ROOT/py.txt"
run_check "$TMP_ROOT/py.txt" "$WF"
check "unsupported suite type: exit 1, named" "[ $RC -eq 1 ] && grep -q '::error::tests/x/test-y.py is not a test-\*.sh or test-\*.ps1 suite' '$TMP_ROOT/out'"

: > "$TMP_ROOT/empty.txt"
run_check "$TMP_ROOT/empty.txt" "$WF"
check "no suites on stdin: exit 1" "[ $RC -eq 1 ] && grep -q '::error::no test suites on stdin' '$TMP_ROOT/out'"

run_check "$LIST" "$TMP_ROOT/does-not-exist.yml"
check "unreadable workflow: exit 2" "[ $RC -eq 2 ] && grep -q '::error::cannot read' '$TMP_ROOT/out'"

RC=0
perl "$CHECK" --help > "$TMP_ROOT/out" 2>&1 || RC=$?
check "--help: exit 0, prints the usage" "[ $RC -eq 0 ] && grep -q 'check-ci-suites.pl \[WORKFLOW\]' '$TMP_ROOT/out'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
