#!/usr/bin/env bash
# test-check-ci-suites.sh -- tests for scripts/check-ci-suites.pl, the logic of
# the CI step "Every test suite is in CI" (.github/workflows/check.yml).
#
# Cases: the current tree passes (every tracked test-*.sh and test-*.ps1 runs
# in the jobs of its platforms); a planted test-*.ps1 or test-*.sh with no step
# fails; removing the step of a tracked .ps1 suite (and of a .sh suite) from a
# copy of the workflow fails; the .ps1 forms that count (pwsh -File, no -File,
# a \ path, a quoted path, -file in lower case); the forms that do not (bash
# running a .ps1, a step after "#", a longer file name, a "run: |" block); the
# platform rule (a .ps1 suite in the windows job only, a POSIX-guarded .sh in
# the macos and linux jobs only, an unguarded cross-platform .sh in all three;
# an unreadable .sh suite); an unsupported suite type; no suites on stdin;
# --help; a workflow that cannot be read.
#
# Safe to re-run: writes only to a temp dir, removed on exit. Needs git and
# perl. Exit 1 if any case fails.
# Platform: macOS, Linux (CI: linux job; the check is static). Windows refuses
# it (commander 2026-11-14: "sh scripts and tests should only run on linux/mac
# and ps1 on windows"); the perl script it tests is cross-platform.
# Usage: bash tests/ci-suites/test-check-ci-suites.sh [--help]

set -uo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. It has no Windows twin: the CI linux job runs it.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. It has no Windows twin: the CI linux job runs it.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 21' "$0"
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

# run_check <stdin file> <workflow> [root]: exit code in RC, output in $TMP_ROOT/out
run_check() {
    RC=0
    perl "$CHECK" --root "${3:-$ROOT}" "$2" < "$1" > "$TMP_ROOT/out" 2>&1 || RC=$?
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
check "current tree: every tracked suite runs on its platforms (exit 0)" "[ $RC -eq 0 ] && grep -q '^All [0-9]* test suites are in CI on their platforms' '$TMP_ROOT/out'"
check "current tree: the .ps1 suites are in the list ($N_PS1 found)" "[ $N_PS1 -ge 1 ]"
check "current tree: the %only entry is reported" "grep -q '^only: tests/ci-suites/test-check-ci-suites.sh in linux' '$TMP_ROOT/out'"

perl -ne 'print unless m{^tests/ci-suites/test-check-ci-suites\.sh$}' "$LIST" > "$TMP_ROOT/no-only.txt"
run_check "$TMP_ROOT/no-only.txt" "$WF"
check "an %only entry missing from stdin while its file exists: exit 1, stale" "[ $RC -eq 1 ] && grep -q '::error::tests/ci-suites/test-check-ci-suites.sh is listed in check-ci-suites.pl but not on stdin' '$TMP_ROOT/out'"

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
    # --root is the empty temp dir: a synthetic tree, so the real %only entry
    # (a file under the repo root) is not reported as stale
    run_check "$TMP_ROOT/one.txt" "$TMP_ROOT/form.yml" "$TMP_ROOT"
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

# --- The platform rule -----------------------------------------------------
# A tree with one POSIX-guarded .sh suite (g), one unguarded .sh suite (u) and
# one .ps1 suite (p); plat_case runs the check on one of them against a
# workflow whose jobs run it as given.
TREE="$TMP_ROOT/tree"
mkdir -p "$TREE/tests/x"
printf '%s\n' '#!/usr/bin/env bash' 'case "$(uname -s)" in' '    MINGW*|MSYS*|CYGWIN*)' \
    "        printf 'This script is for macOS/Linux.\\n' >&2" '        exit 1 ;;' 'esac' > "$TREE/tests/x/test-g.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo cross-platform' > "$TREE/tests/x/test-u.sh"
printf '%s\n' 'Write-Output windows' > "$TREE/tests/x/test-p.ps1"
# plat_case <name> <want rc> <want output text or ""> <suite> <jobs...>
plat_case() {
    local name="$1" want="$2" text="$3" suite="$4" j
    shift 4
    printf '%s\n' "$suite" > "$TMP_ROOT/plat.txt"
    printf 'name: CI\njobs:\n' > "$TMP_ROOT/plat.yml"
    for j in "$@"; do
        case "$suite" in
            *.ps1) printf '  %s:\n    steps:\n      - name: t\n        run: pwsh -NoProfile -File %s\n' "$j" "$suite" >> "$TMP_ROOT/plat.yml" ;;
            *) printf '  %s:\n    steps:\n      - name: t\n        run: bash %s\n' "$j" "$suite" >> "$TMP_ROOT/plat.yml" ;;
        esac
    done
    run_check "$TMP_ROOT/plat.txt" "$TMP_ROOT/plat.yml" "$TREE"
    if [ -n "$text" ]; then
        check "$name" "[ $RC -eq $want ] && grep -qF -- '$text' '$TMP_ROOT/out'"
    else
        check "$name" "[ $RC -eq $want ]"
    fi
}
plat_case "platform: guarded .sh in macos and linux passes" 0 "" tests/x/test-g.sh macos linux
plat_case "platform: guarded .sh also in windows fails" 1 "tests/x/test-g.sh is a POSIX-guarded .sh suite (macOS/Linux; its .ps1 twin runs on Windows) but the windows job runs it" tests/x/test-g.sh macos linux windows
plat_case "platform: guarded .sh missing from macos fails" 1 "no step of the macos job runs it" tests/x/test-g.sh linux
plat_case "platform: unguarded .sh in all three jobs passes" 0 "" tests/x/test-u.sh macos linux windows
plat_case "platform: unguarded .sh missing from windows fails" 1 "tests/x/test-u.sh is a cross-platform .sh suite (no OS guard) but no step of the windows job runs it" tests/x/test-u.sh macos linux
plat_case "platform: .ps1 in windows passes" 0 "" tests/x/test-p.ps1 windows
plat_case "platform: .ps1 also in linux fails" 1 "tests/x/test-p.ps1 is a .ps1 suite (Windows) but the linux job runs it" tests/x/test-p.ps1 windows linux
plat_case "platform: unreadable .sh suite fails" 1 "cannot read $TREE/tests/x/test-missing.sh to check its OS guard" tests/x/test-missing.sh macos linux

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
check "--help: exit 0, prints the usage" "[ $RC -eq 0 ] && grep -q 'check-ci-suites.pl \[--root DIR\] \[WORKFLOW\]' '$TMP_ROOT/out'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
