#!/usr/bin/env bash
# test-b8-consumers.sh -- dotprofile-resolver consumers outside tests/profile:
# setup-user-skills, setup-user-cursor (cli-config step) and check-lib, on a
# dotprofile resolver error (rc 3) and on the cursor dry run.
#
# Checks the S3-MF-Audit fixes: A-22 (skills .sh/.ps1 write the same rows and
# message on rc 3), A-23 (cursor counts its own rc 3 error, row "not merged:
# dotprofile error"), A-24 (a check run with a resolver error reports a WARN
# step), A-26 cursor part (the cli-config dry run writes a summary row).
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs the .sh scripts on macOS/Linux and refuses Windows; the
# .ps1 scripts are tested on Windows by tests/b8-consumers/test-b8-consumers.ps1.
# Parity between the two is checked against the committed golden summary rows
# in tests/b8-consumers/golden/ (tests/lib/platform-lib.sh golden_match).
# AITOOLS_TEST_UPDATE_GOLDEN=1 on macOS/Linux rewrites them.
#
# Safe to re-run: every case runs under its own temp HOME (removed on exit) with
# stub rg/agent on PATH; the real HOME is never read or written. AITOOLS_TEST_BASH
# picks the bash that runs the .sh scripts (default: bash). Exit 1 on failure.
#
# Usage: bash tests/b8-consumers/test-b8-consumers.sh [--bash-only] [--help]
#   --bash-only  accepted for compatibility: the harness always runs only .sh

set -uo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/b8-consumers/test-b8-consumers.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/b8-consumers/test-b8-consumers.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 24' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/platform-lib.sh
. "$ROOT/tests/lib/platform-lib.sh"
TB="${AITOOLS_TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
GOLDEN_DIR="$ROOT/tests/b8-consumers/golden"
GOLDEN_TMP="$TMP_ROOT"

PASS=0
FAIL=0
SKIP=0

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "${C:-}" ] && [ -f "$C/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/out" | tail -n 25
        fi
    fi
}

# setup_case <name>: fresh HOME, logs, summary and stub bin (rg, agent: version only).
setup_case() {
    C="$TMP_ROOT/$1"
    H="$C/home"
    mkdir -p "$H" "$C/bin" "$C/logs"
    printf '#!/usr/bin/env bash\necho "ripgrep 14.1.0"\n' > "$C/bin/rg"
    printf '#!/usr/bin/env bash\necho "2026.05.21-stub"\n' > "$C/bin/agent"
    chmod +x "$C/bin/rg" "$C/bin/agent"
    : > "$C/summary"
    CASE_ENV=""
}

# run_script <base name> [args...]: scripts/<base>.sh, non-interactive, case
# HOME. CASE_ENV (space-separated VAR=value words) is added to the environment.
run_script() {
    local base="$1"; shift
    # shellcheck disable=SC2086  # CASE_ENV is a list of VAR=value words
    env HOME="$H" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
        PATH="$C/bin:$PATH" $CASE_ENV "$TB" "$ROOT/scripts/$base.sh" "$@" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
}

rc() { cat "$C/rc"; }
rows() { grep -v '^DETAIL' "$C/summary" | perl -pe 's/\r//' | LC_ALL=C sort; }  # summary rows, order-free
has_row() { perl -pe 's/\r//' "$C/summary" | grep -qxF "$1"; }
in_log() { perl -pe 's/\e\[[0-9;]*m//g; s/\r//' "$C/out" "$C/logs/deploy.log" 2>/dev/null | grep -qF -- "$1"; }
nowhere() { printf 'AITOOLS_USER_REPO_PATH=%s/nowhere' "$C"; }

lang=sh

# --- A-22: setup-user-skills on a resolver error (rc 3) ------------------------
setup_case "skills-rc3-$lang"
CASE_ENV="$(nowhere)"
run_script setup-user-skills
check "skills $lang rc3: exit 1" "[ \"\$(rc)\" = 1 ]"
check "skills $lang rc3: lib ERROR row dotprofile" "grep -q '^ERROR|dotprofile|' '$C/summary'"
check "skills $lang rc3: ERROR row claude skills" "has_row 'ERROR|claude skills|not deployed: dotprofile error'"
check "skills $lang rc3: ERROR row cursor skills" "has_row 'ERROR|cursor skills|not deployed: dotprofile error'"
check "skills $lang rc3: no non-canonical 'skills' row" "! grep -q '^[A-Z]*|skills|' '$C/summary'"
check "skills $lang rc3: no 'skipped' detail" "! grep -qi 'skipped' '$C/summary'"
check "skills $lang rc3: consumer error logged" "in_log 'Dotprofile unresolved (resolver error above) -- skills not deployed, so shared copies cannot replace dotprofile versions'"
check "skills $lang rc3: nothing deployed" "[ ! -e '$H/.claude/skills' ] && [ ! -e '$H/.cursor/skills' ]"
rows > "$TMP_ROOT/skills-rc3.rows"
check "skills rc3 parity: summary rows match golden (sh and ps1 share it)" "golden_match skills-rc3.rows '$TMP_ROOT/skills-rc3.rows'"

# --- A-23: setup-user-cursor cli-config on a resolver error (rc 3) -------------
# The dry run keeps steps 1-2 to version checks; the rc 3 branch comes first.
setup_case "cursor-rc3-$lang"
CASE_ENV="$(nowhere)"
run_script setup-user-cursor --dry-run
check "cursor $lang rc3: exit 1" "[ \"\$(rc)\" = 1 ]"
check "cursor $lang rc3: ERROR row not merged" "has_row 'ERROR|cursor cli|not merged: dotprofile error'"
check "cursor $lang rc3: no 'skipped' detail" "! grep -qi 'skipped' '$C/summary'"
check "cursor $lang rc3: consumer error logged as error" "perl -pe 's/\e\[[0-9;]*m//g' '$C/logs/deploy.log' | grep -E '\[error\] Dotprofile unresolved \(resolver error above\) -- .*cli-config.json not merged, so defaults cannot replace the profile preferences' >/dev/null"
check "cursor $lang rc3: error counted (consumer + lib)" "in_log 'FAILED with 2 error(s)'"
check "cursor $lang rc3: no cli-config written" "[ ! -e '$H/.cursor/cli-config.json' ]"
rows > "$TMP_ROOT/cursor-rc3.rows"
check "cursor rc3 parity: summary rows match golden" "golden_match cursor-rc3.rows '$TMP_ROOT/cursor-rc3.rows'"

# --- A-26 (cursor part): cli-config dry run writes a row ------------------------
# No dotprofile (rc 1, defaults). First a dry run on a missing cli-config (would
# update), then a real run (created), then a dry run on the written file (verified).
if ! command -v node >/dev/null 2>&1; then
    printf 'SKIP cursor dry-run sh (node not on PATH)\n'; SKIP=$((SKIP + 1))
else
    setup_case "cursor-dry-$lang"
    run_script setup-user-cursor --dry-run
    check "cursor $lang dry (missing config): exit 0" "[ \"\$(rc)\" = 0 ]"
    check "cursor $lang dry (missing config): OK row dry-run: would update" "has_row 'OK|cursor cli|dry-run: would update'"
    check "cursor $lang dry (missing config): nothing written" "[ ! -e '$H/.cursor/cli-config.json' ]"
    rows > "$TMP_ROOT/cursor-dry1.rows"
    check "cursor dry parity (missing config): rows match golden" "golden_match cursor-dry1.rows '$TMP_ROOT/cursor-dry1.rows'"
    : > "$C/summary"
    run_script setup-user-cursor
    check "cursor $lang real run: OK row created" "has_row 'OK|cursor cli|created'"
    : > "$C/summary"
    run_script setup-user-cursor --dry-run
    check "cursor $lang dry (up to date): exit 0" "[ \"\$(rc)\" = 0 ]"
    check "cursor $lang dry (up to date): OK row verified" "has_row 'OK|cursor cli|verified'"
    rows > "$TMP_ROOT/cursor-dry2.rows"
    check "cursor dry parity (up to date): rows match golden" "golden_match cursor-dry2.rows '$TMP_ROOT/cursor-dry2.rows'"
fi

# --- A-24: check-lib reports a resolver error as a WARN step --------------------
# A minimal check script in the check-script block order (check-lib, init-logging,
# resolve_config, check_log_init), one PASS step, summary.
CL="$TMP_ROOT/mini-check.sh"
printf '%s\n' 'set -euo pipefail' \
    "source '$ROOT/scripts/check-lib.sh'" "source '$ROOT/scripts/init-logging.sh'" \
    'resolve_config' 'check_log_init "mini"' 'step_pass "1" "Something"' 'print_summary' > "$CL"
for mode in rc3 rc1; do
    setup_case "checklib-$mode-$lang"
    [ "$mode" = rc3 ] && CASE_ENV="$(nowhere)"
    # shellcheck disable=SC2086
    env HOME="$H" AITOOLS_LOG_DIR="$C/logs" $CASE_ENV "$TB" "$CL" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
    check "check-lib $lang $mode: exit 0" "[ \"\$(rc)\" = 0 ]"
    if [ "$mode" = rc3 ]; then
        check "check-lib $lang rc3: WARN step on console" "perl -pe 's/\e\[[0-9;]*m//g; s/\r//' '$C/out' | grep -E '^ +0\. Dotprofile resolution +\[WARN\] resolver error \(rc 3, see deploy.log\)' >/dev/null"
        check "check-lib $lang rc3: summary counts it" "perl -pe 's/\e\[[0-9;]*m//g' '$C/out' | grep -qF '=== SUMMARY: 1 PASS, 0 SKIP, 1 WARN, 0 FAIL ==='"
        check "check-lib $lang rc3: WARN step in checks.jsonl" "grep -q '\"label\":\"Dotprofile resolution\",\"result\":\"WARN\"' '$C/logs/checks.jsonl'"
    else
        check "check-lib $lang rc1: no dotprofile step" "! grep -q 'Dotprofile resolution' '$C/out'"
        check "check-lib $lang rc1: clean summary" "perl -pe 's/\e\[[0-9;]*m//g' '$C/out' | grep -qF '=== SUMMARY: 1 PASS, 0 SKIP, 0 WARN, 0 FAIL ==='"
    fi
done

printf '\n%d passed, %d failed, %d skipped (%s: %s scripts)\n' "$PASS" "$FAIL" "$SKIP" "$TEST_PLATFORM" "$lang"
[ "$FAIL" -eq 0 ]
