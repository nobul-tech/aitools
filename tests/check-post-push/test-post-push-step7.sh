#!/usr/bin/env bash
# test-post-push-step7.sh -- check-post-push step 7 ("deploy/ drift audit") never
# runs build-deploy.sh. The step used to run it with the caller's HOME, which
# replaces the real dotprofile deploy/; it is retired to a SKIP that points to
# check-pre-push step 7 (M5-Fixes item 3).
#
# Cases:
#   sh run   the step 7 section of scripts/check-post-push.sh (the .sh twin), cut
#            out between its "# 7." and "# 9." headings, runs in bash with stub
#            step functions, a temporary HOME and a fake scripts dir whose
#            build-deploy.sh only touches a marker file: the marker must not
#            exist and the only step result must be SKIP 7, naming
#            check-pre-push step 7
#   static   (perl reads of the file text, nothing is run) the step 7 section
#            of each twin is found, and no non-comment line of either whole
#            script runs build-deploy
#
# Platform targeting (commander, 2026-11-14: "sh scripts and tests should only
# run on linux/mac and ps1 on windows"): this harness runs the .sh twin's
# section on macOS/Linux and refuses Windows. The .ps1 twin's section runs on
# Windows in tests/check-post-push/test-post-push-step7.ps1 (native pwsh, the
# same static cases); this harness no longer runs any .ps1 code.
#
# Override the scripts under test with POST_PUSH_SH / POST_PUSH_PS1 (absolute
# paths), e.g. to show that the pre-fix scripts fail. AITOOLS_TEST_BASH picks
# the bash that runs the section (default: bash; e.g. /bin/bash for 3.2).
# Safe to re-run: writes only to a temp dir, removed on exit. Needs perl. Exit 1
# if any case fails. Platform: macOS, Linux (CI: macos and linux jobs).
# Usage: bash tests/check-post-push/test-post-push-step7.sh [--help]

set -uo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/check-post-push/test-post-push-step7.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/check-post-push/test-post-push-step7.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 29' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SH_SCRIPT="${POST_PUSH_SH:-$ROOT/scripts/check-post-push.sh}"
PS1_SCRIPT="${POST_PUSH_PS1:-$ROOT/scripts/check-post-push.ps1}"
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
        if [ -f "$TMP_ROOT/out" ]; then
            perl -pe 's/^/      | /' "$TMP_ROOT/out" | tail -n 15
        fi
    fi
}

# section <script> <out>: the step 7 section (from the "# 7." heading to the
# "# 9." heading), CRLF removed (.ps1 files check out with CRLF)
section() {
    perl -ne 's/\r$//; $p = 1 if /^# 7\. /; $p = 0 if /^# 9\. /; print if $p' "$1" > "$2"
}

# The fake scripts dir: build-deploy.sh only records that it ran
FAKE="$TMP_ROOT/fake"
mkdir -p "$FAKE/scripts" "$FAKE/repo" "$TMP_ROOT/home"
printf '#!/usr/bin/env bash\nprintf ran > "$STEP7_MARKER"\n' > "$FAKE/scripts/build-deploy.sh"
git -C "$FAKE/repo" init -q

# --- .sh twin ------------------------------------------------------------------
if [ ! -f "$SH_SCRIPT" ]; then
    check "sh: $SH_SCRIPT exists" "false"
else
    section "$SH_SCRIPT" "$TMP_ROOT/step7.sh"
    check "sh: the step 7 section was found" "grep -q '^# 7\\. ' '$TMP_ROOT/step7.sh'"
    cat > "$TMP_ROOT/run.sh" <<'EOF'
set -euo pipefail
step_pass() { printf 'PASS %s %s\n' "$1" "${3:-}" >> "$STEP7_REC"; }
step_fail() { printf 'FAIL %s %s\n' "$1" "${3:-}" >> "$STEP7_REC"; }
step_warn() { printf 'WARN %s %s\n' "$1" "${3:-}" >> "$STEP7_REC"; }
step_skip() { printf 'SKIP %s %s\n' "$1" "${3:-}" >> "$STEP7_REC"; }
SCRIPT_DIR="$STEP7_FAKE/scripts"
REPO_ROOT="$STEP7_FAKE/repo"
cd "$REPO_ROOT"
. "$STEP7_SECTION"
EOF
    rm -f "$TMP_ROOT/marker-sh" "$TMP_ROOT/rec-sh"
    RC=0
    HOME="$TMP_ROOT/home" STEP7_MARKER="$TMP_ROOT/marker-sh" STEP7_REC="$TMP_ROOT/rec-sh" \
        STEP7_FAKE="$FAKE" STEP7_SECTION="$TMP_ROOT/step7.sh" \
        "$TB" "$TMP_ROOT/run.sh" > "$TMP_ROOT/out" 2>&1 || RC=$?
    check "sh run: exit 0" "[ $RC -eq 0 ]"
    check "sh run: build-deploy.sh was not run" "[ ! -e '$TMP_ROOT/marker-sh' ]"
    check "sh run: one result, SKIP 7, pointing to check-pre-push step 7" \
        "[ -f '$TMP_ROOT/rec-sh' ] && [ \"\$(wc -l < '$TMP_ROOT/rec-sh' | tr -d ' ')\" = 1 ] && grep -q '^SKIP 7 retired: check-pre-push step 7' '$TMP_ROOT/rec-sh'"
    # Static: no non-comment line runs build-deploy (bash/sh/source/. <...build-deploy...>)
    perl -ne 'next if /^\s*#/; print "$.: $_" if /(?:^|[\s;&|(])(?:bash|sh|source|\.)\s+[^#]*build-deploy/' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: no line runs build-deploy" "[ ! -s '$TMP_ROOT/out' ]"
fi

# --- .ps1 twin: static only (its section runs in the .ps1 harness, on Windows) --
if [ ! -f "$PS1_SCRIPT" ]; then
    check "ps1: $PS1_SCRIPT exists" "false"
else
    section "$PS1_SCRIPT" "$TMP_ROOT/step7.ps1"
    check "ps1: the step 7 section was found" "grep -q '^# 7\\. ' '$TMP_ROOT/step7.ps1'"
    # Static: no non-comment line invokes build-deploy with & or bash
    perl -ne 's/\r$//; next if /^\s*#/; print "$.: $_" if /(?:&|\bbash\b|Start-Process)[^#]*build-deploy/i' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: no line runs build-deploy" "[ ! -s '$TMP_ROOT/out' ]"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
