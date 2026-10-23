#!/usr/bin/env bash
# test-b8-consumers.sh -- dotprofile-resolver consumers outside tests/profile:
# setup-user-skills, setup-user-cursor (cli-config step) and check-lib, in bash
# and PowerShell, on a dotprofile resolver error (rc 3) and on the cursor dry run.
#
# Checks the S3-MF-Audit fixes: A-22 (skills .sh/.ps1 write the same rows and
# message on rc 3), A-23 (cursor counts its own rc 3 error, row "not merged:
# dotprofile error"), A-24 (a check run with a resolver error reports a WARN
# step), A-26 cursor part (the cli-config dry run writes a summary row).
#
# Safe to re-run: every case runs under its own temp HOME (removed on exit) with
# stub rg/agent on PATH; the real HOME is never read or written. The .ps1 setup
# scripts run as guard-stripped copies in a temp scripts/ copy (their OS guard
# exits on macOS/Linux), with AITOOLS_PROFILE_TEST_ANY_OS=1 for the resolver.
# Without pwsh the .ps1 cases are skipped. AITOOLS_TEST_BASH picks the bash that
# runs the .sh scripts (default: bash). Platform: macOS, Linux. Exit 1 on failure.
#
# Usage: bash tests/b8-consumers/test-b8-consumers.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 18' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TB="${AITOOLS_TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

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

HAVE_PWSH=false
if command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=true; fi

# Guard-stripped copy of scripts/ for the .ps1 cases (the copy, never the source)
PS_SCRIPTS="$TMP_ROOT/repo/scripts"
if $HAVE_PWSH; then
    mkdir -p "$TMP_ROOT/repo"
    cp -R "$ROOT/scripts" "$PS_SCRIPTS"
    for s in setup-user-skills.ps1 setup-user-cursor.ps1; do
        perl -pe 's/^if \(\$PSVersionTable\.PSVersion\.Major -ge 6 -and -not \$IsWindows\) \{\r?$/if (\$false) {  # OS guard stripped by test-b8-consumers.sh/' \
            "$ROOT/scripts/$s" > "$PS_SCRIPTS/$s"
        check "setup: OS guard stripped in the $s copy" "grep -q 'OS guard stripped by test-b8-consumers' '$PS_SCRIPTS/$s'"
    done
fi

# setup_case <name>: fresh HOME, logs, summary and stub bin (rg, agent: version only)
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

# run_sh <script> [args...] / run_ps1 <script> [args...]: non-interactive, case HOME.
# CASE_ENV (space-separated VAR=value words) is added to the environment.
run_sh() {
    local s="$1"; shift
    # shellcheck disable=SC2086  # CASE_ENV is a list of VAR=value words
    env HOME="$H" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
        PATH="$C/bin:$PATH" $CASE_ENV "$TB" "$ROOT/scripts/$s" "$@" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
}
run_ps1() {
    local s="$1"; shift
    # shellcheck disable=SC2086
    env HOME="$H" USERPROFILE="$H" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
        AITOOLS_PROFILE_TEST_ANY_OS=1 PATH="$C/bin:$PATH" $CASE_ENV \
        pwsh -NoProfile -File "$PS_SCRIPTS/$s" "$@" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
}

rc() { cat "$C/rc"; }
rows() { grep -v '^DETAIL' "$C/summary" | LC_ALL=C sort; }  # summary rows, order-free
has_row() { grep -qxF "$1" "$C/summary"; }
in_log() { perl -pe 's/\e\[[0-9;]*m//g' "$C/out" "$C/logs/deploy.log" 2>/dev/null | grep -qF -- "$1"; }

# --- A-22: setup-user-skills on a resolver error (rc 3) ------------------------
for lang in sh ps1; do
    if [ "$lang" = ps1 ] && ! $HAVE_PWSH; then
        printf 'SKIP skills ps1 (pwsh not on PATH)\n'; SKIP=$((SKIP + 1)); continue
    fi
    setup_case "skills-rc3-$lang"
    CASE_ENV="AITOOLS_USER_REPO_PATH=$C/nowhere"
    "run_$lang" "setup-user-skills.$lang"
    check "skills $lang rc3: exit 1" "[ \"\$(rc)\" = 1 ]"
    check "skills $lang rc3: lib ERROR row dotprofile" "grep -q '^ERROR|dotprofile|' '$C/summary'"
    check "skills $lang rc3: ERROR row claude skills" "has_row 'ERROR|claude skills|not deployed: dotprofile error'"
    check "skills $lang rc3: ERROR row cursor skills" "has_row 'ERROR|cursor skills|not deployed: dotprofile error'"
    check "skills $lang rc3: no non-canonical 'skills' row" "! grep -q '^[A-Z]*|skills|' '$C/summary'"
    check "skills $lang rc3: no 'skipped' detail" "! grep -qi 'skipped' '$C/summary'"
    check "skills $lang rc3: consumer error logged" "in_log 'Dotprofile unresolved (resolver error above) -- skills not deployed, so shared copies cannot replace dotprofile versions'"
    check "skills $lang rc3: nothing deployed" "[ ! -e '$H/.claude/skills' ] && [ ! -e '$H/.cursor/skills' ]"
    rows > "$TMP_ROOT/skills-rc3-$lang.rows"
done
if $HAVE_PWSH; then
    check "skills rc3 parity: identical summary rows sh/ps1" "cmp -s '$TMP_ROOT/skills-rc3-sh.rows' '$TMP_ROOT/skills-rc3-ps1.rows'"
fi

# --- A-23: setup-user-cursor cli-config on a resolver error (rc 3) -------------
# --dry-run keeps steps 1-2 to version checks; the rc 3 branch comes first.
for lang in sh ps1; do
    if [ "$lang" = ps1 ] && ! $HAVE_PWSH; then
        printf 'SKIP cursor rc3 ps1 (pwsh not on PATH)\n'; SKIP=$((SKIP + 1)); continue
    fi
    setup_case "cursor-rc3-$lang"
    CASE_ENV="AITOOLS_USER_REPO_PATH=$C/nowhere"
    if [ "$lang" = sh ]; then run_sh setup-user-cursor.sh --dry-run; else run_ps1 setup-user-cursor.ps1 -DryRun; fi
    check "cursor $lang rc3: exit 1" "[ \"\$(rc)\" = 1 ]"
    check "cursor $lang rc3: ERROR row not merged" "has_row 'ERROR|cursor cli|not merged: dotprofile error'"
    check "cursor $lang rc3: no 'skipped' detail" "! grep -qi 'skipped' '$C/summary'"
    check "cursor $lang rc3: consumer error logged as error" "perl -pe 's/\e\[[0-9;]*m//g' '$C/logs/deploy.log' | grep -E '\[error\] Dotprofile unresolved \(resolver error above\) -- .*cli-config.json not merged, so defaults cannot replace the profile preferences' >/dev/null"
    check "cursor $lang rc3: error counted (consumer + lib)" "in_log 'FAILED with 2 error(s)'"
    check "cursor $lang rc3: no cli-config written" "[ ! -e '$H/.cursor/cli-config.json' ]"
    rows > "$TMP_ROOT/cursor-rc3-$lang.rows"
done
if $HAVE_PWSH; then
    check "cursor rc3 parity: identical summary rows sh/ps1" "cmp -s '$TMP_ROOT/cursor-rc3-sh.rows' '$TMP_ROOT/cursor-rc3-ps1.rows'"
fi

# --- A-26 (cursor part): cli-config dry run writes a row ------------------------
# No dotprofile (rc 1, defaults). First a dry run on a missing cli-config (would
# update), then a real run (created), then a dry run on the written file (verified).
for lang in sh ps1; do
    if [ "$lang" = ps1 ] && ! $HAVE_PWSH; then
        printf 'SKIP cursor dry-run ps1 (pwsh not on PATH)\n'; SKIP=$((SKIP + 1)); continue
    fi
    if [ "$lang" = sh ] && ! command -v node >/dev/null 2>&1; then
        printf 'SKIP cursor dry-run sh (node not on PATH)\n'; SKIP=$((SKIP + 1)); continue
    fi
    setup_case "cursor-dry-$lang"
    if [ "$lang" = sh ]; then run_sh setup-user-cursor.sh --dry-run; else run_ps1 setup-user-cursor.ps1 -DryRun; fi
    check "cursor $lang dry (missing config): exit 0" "[ \"\$(rc)\" = 0 ]"
    check "cursor $lang dry (missing config): OK row dry-run: would update" "has_row 'OK|cursor cli|dry-run: would update'"
    check "cursor $lang dry (missing config): nothing written" "[ ! -e '$H/.cursor/cli-config.json' ]"
    rows > "$TMP_ROOT/cursor-dry1-$lang.rows"
    : > "$C/summary"
    if [ "$lang" = sh ]; then run_sh setup-user-cursor.sh; else run_ps1 setup-user-cursor.ps1; fi
    check "cursor $lang real run: OK row created" "has_row 'OK|cursor cli|created'"
    : > "$C/summary"
    if [ "$lang" = sh ]; then run_sh setup-user-cursor.sh --dry-run; else run_ps1 setup-user-cursor.ps1 -DryRun; fi
    check "cursor $lang dry (up to date): exit 0" "[ \"\$(rc)\" = 0 ]"
    check "cursor $lang dry (up to date): OK row verified" "has_row 'OK|cursor cli|verified'"
    rows > "$TMP_ROOT/cursor-dry2-$lang.rows"
done
if $HAVE_PWSH && command -v node >/dev/null 2>&1; then
    check "cursor dry parity (missing config): identical rows sh/ps1" "cmp -s '$TMP_ROOT/cursor-dry1-sh.rows' '$TMP_ROOT/cursor-dry1-ps1.rows'"
    check "cursor dry parity (up to date): identical rows sh/ps1" "cmp -s '$TMP_ROOT/cursor-dry2-sh.rows' '$TMP_ROOT/cursor-dry2-ps1.rows'"
fi

# --- A-24: check-lib reports a resolver error as a WARN step --------------------
# A minimal check script in the check-script block order (check-lib, init-logging,
# resolve_config, check_log_init), one PASS step, summary.
CL_SH="$TMP_ROOT/mini-check.sh"
printf '%s\n' 'set -euo pipefail' \
    "source '$ROOT/scripts/check-lib.sh'" "source '$ROOT/scripts/init-logging.sh'" \
    'resolve_config' 'check_log_init "mini"' 'step_pass "1" "Something"' 'print_summary' > "$CL_SH"
CL_PS1="$TMP_ROOT/mini-check.ps1"
printf '%s\n' "\$ErrorActionPreference = 'Stop'" \
    ". '$ROOT/scripts/check-lib.ps1'" ". '$ROOT/scripts/init-logging.ps1'" \
    'ResolveConfig' 'CheckLogInit "mini"' 'StepPass "1" "Something"' 'PrintSummary' > "$CL_PS1"

for lang in sh ps1; do
    if [ "$lang" = ps1 ] && ! $HAVE_PWSH; then
        printf 'SKIP check-lib ps1 (pwsh not on PATH)\n'; SKIP=$((SKIP + 1)); continue
    fi
    for mode in rc3 rc1; do
        setup_case "checklib-$mode-$lang"
        [ "$mode" = rc3 ] && CASE_ENV="AITOOLS_USER_REPO_PATH=$C/nowhere"
        if [ "$lang" = sh ]; then
            # shellcheck disable=SC2086
            env HOME="$H" AITOOLS_LOG_DIR="$C/logs" $CASE_ENV "$TB" "$CL_SH" < /dev/null > "$C/out" 2>&1
        else
            # shellcheck disable=SC2086
            env HOME="$H" USERPROFILE="$H" AITOOLS_LOG_DIR="$C/logs" AITOOLS_PROFILE_TEST_ANY_OS=1 $CASE_ENV \
                pwsh -NoProfile -File "$CL_PS1" < /dev/null > "$C/out" 2>&1
        fi
        echo $? > "$C/rc"
        check "check-lib $lang $mode: exit 0" "[ \"\$(rc)\" = 0 ]"
        if [ "$mode" = rc3 ]; then
            check "check-lib $lang rc3: WARN step on console" "perl -pe 's/\e\[[0-9;]*m//g' '$C/out' | grep -E '^ +0\. Dotprofile resolution +\[WARN\] resolver error \(rc 3, see deploy.log\)' >/dev/null"
            check "check-lib $lang rc3: summary counts it" "perl -pe 's/\e\[[0-9;]*m//g' '$C/out' | grep -qF '=== SUMMARY: 1 PASS, 0 SKIP, 1 WARN, 0 FAIL ==='"
            check "check-lib $lang rc3: WARN step in checks.jsonl" "grep -q '\"label\":\"Dotprofile resolution\",\"result\":\"WARN\"' '$C/logs/checks.jsonl'"
        else
            check "check-lib $lang rc1: no dotprofile step" "! grep -q 'Dotprofile resolution' '$C/out'"
            check "check-lib $lang rc1: clean summary" "perl -pe 's/\e\[[0-9;]*m//g' '$C/out' | grep -qF '=== SUMMARY: 1 PASS, 0 SKIP, 0 WARN, 0 FAIL ==='"
        fi
    done
done

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
