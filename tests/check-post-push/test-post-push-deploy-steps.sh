#!/usr/bin/env bash
# test-post-push-deploy-steps.sh -- check-post-push steps 2, 6 and 14 never read
# the frozen aitools deploy/ (incident #176). Before, step 2 ran bash -n on
# deploy/*.sh and steps 6 and 14 added deploy/*.sh (and step 6 deploy/*.ps1) to
# their syntax and line-ending audits; build-deploy.sh has written the dotprofile
# deploy/ since 2c0fd32, so those reads proved nothing about the generated
# scripts. Step 2 is retired to a SKIP that points to check-pre-push step 7;
# steps 6 and 14 audit the source scripts (scripts/, shared/hooks/) only.
#
# Platform targeting (commander, 2026-11-14: "sh scripts and tests should only
# run on linux/mac and ps1 on windows"): this harness runs on macOS and Linux
# only and tests the .sh twin, scripts/check-post-push.sh, with bash. The .ps1
# twin is tested on Windows with native pwsh by
# tests/check-post-push/test-post-push-deploy-steps.ps1, which expects the same
# records for steps 2, 6 (.ps1) and 14 (the .ps1 twin SKIPs 6 (.sh): no Git
# Bash, PR #167) and runs the same static cases.
#
# Cases:
#   frozen   steps 2, 6 and 14 of check-post-push.sh (cut between their "# N."
#            headings and the next step's heading) run with stub step
#            functions, a temporary HOME and a fake repo whose source scripts
#            are clean and whose deploy/ holds a .sh with a syntax error, a .ps1
#            with a parse error and a CRLF .sh; scripts/build-deploy.sh only
#            writes a marker. Exactly: SKIP 2 with the retired text, PASS 6
#            (.sh), PASS 6 (.ps1), PASS 14; no marker
#   sources  the same steps on a fake repo with a syntax error in scripts/*.sh,
#            a parse error in scripts/*.ps1 and a CRLF shared/hooks/*.sh: FAIL 6
#            (.sh), FAIL 6 (.ps1) and FAIL 14, one file each (the steps still
#            audit the sources)
#   static   perl over the text of both twins (platform-neutral, so both
#            harnesses run them): no non-comment line reads the aitools deploy/
#   home     the temporary HOME is unchanged (every file, by checksum)
#
# The .sh twin's step 6 parses scripts/*.ps1 with pwsh (its require_pwsh): when
# pwsh is not installed the stub records SKIP 6 (.ps1) instead, and the frozen
# and sources cases expect that SKIP.
#
# Override the script under test with POST_PUSH_SH (the .sh twin) and
# POST_PUSH_PS1 (read by the static case only), absolute paths, e.g. to show
# that the pre-fix scripts fail. AITOOLS_TEST_BASH runs the .sh pieces with
# another bash (macOS /bin/bash 3.2). TEST_KEEP_TMP=1 keeps the temp dir. Safe
# to re-run: writes only to a temp dir, removed on exit; the real HOME and the
# real dotprofile are never read or written. Needs perl. Exit 1 if any case
# fails.
# Platform: macOS, Linux (CI: macos and linux jobs); refuses Windows.
# Usage: bash tests/check-post-push/test-post-push-deploy-steps.sh [--help]

set -uo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/check-post-push/test-post-push-deploy-steps.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/check-post-push/test-post-push-deploy-steps.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 46' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SH_SCRIPT="${POST_PUSH_SH:-$ROOT/scripts/check-post-push.sh}"
PS1_SCRIPT="${POST_PUSH_PS1:-$ROOT/scripts/check-post-push.ps1}"
TB="${AITOOLS_TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
if [ "${TEST_KEEP_TMP:-}" = 1 ]; then
    printf 'temp dir kept: %s\n' "$TMP_ROOT"
else
    trap 'rm -rf "$TMP_ROOT"' EXIT
fi

PASS=0
FAIL=0
SKIP=0
# The .sh twin's .ps1 audit runs pwsh (require_pwsh); without pwsh it is a SKIP
SH_PWSH=0
if command -v pwsh >/dev/null 2>&1; then SH_PWSH=1; fi

RETIRED='retired: check-pre-push step 7 rebuilds into a temp dotprofile copy'
SH_PS1_STUB='not exercised by this test'

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -f "$TMP_ROOT/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$TMP_ROOT/out" | tail -n 15
        fi
    fi
}

# section <script> <out>: steps 2, 6 and 14 (from each "# N." heading to the
# next step's heading), CRLF removed
section() {
    perl -ne 's/\r$//; $p = 1 if /^# (2|6|14)\. /; $p = 0 if /^# (3|7|15)\. /; print if $p' "$1" > "$2"
}

# snapshot <dir> <out>: every file under <dir> with its checksum, except pwsh's
# own state, which it writes under HOME at every start (the .sh twin's step 6
# runs pwsh): .cache/powershell/ (StartupProfileData, telemetry.uuid; seen in
# the Linux CI job) and .local/share/powershell/
snapshot() {
    ( cd "$1" && find . \( -path ./.cache/powershell -o -path ./.local/share/powershell \) -prune -o -type f -print \
        | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done ) > "$2"
}

# norm <rec> <out>: the record file without CR
norm() { if [ -f "$1" ]; then perl -pe 's/\r$//' "$1" > "$2"; else : > "$2"; fi; }

# expect <file> <lines...>: write the expected records, one per argument
expect() { local out="$1"; shift; : > "$out"; for l in "$@"; do printf '%s\n' "$l" >> "$out"; done; }

# --- Fixtures ------------------------------------------------------------------
# A fake repo: scripts/ and shared/hooks/ hold clean scripts; scripts/build-deploy.sh
# only writes a marker (no step may run it)
make_repo() {  # dir
    mkdir -p "$1/scripts" "$1/shared/hooks" "$1/deploy"
    printf '#!/usr/bin/env bash\nset -euo pipefail\necho ok\n' > "$1/scripts/ok.sh"
    printf 'Write-Output "ok"\n' > "$1/scripts/ok.ps1"
    printf '#!/usr/bin/env bash\nset -euo pipefail\necho hook\n' > "$1/shared/hooks/ok-hook.sh"
    printf '#!/usr/bin/env bash\nprintf ran > "$DEPLOY_STEPS_MARKER"\n' > "$1/scripts/build-deploy.sh"
}

# frozen: every problem sits in deploy/ (the frozen tree no step may read)
FROZEN="$TMP_ROOT/frozen"
make_repo "$FROZEN"
printf '#!/usr/bin/env bash\nif then fi (\n' > "$FROZEN/deploy/broken.sh"
printf 'function {\n' > "$FROZEN/deploy/broken.ps1"
printf '#!/usr/bin/env bash\r\necho crlf\r\n' > "$FROZEN/deploy/crlf.sh"

# sources: one problem of each kind in the source scripts, a clean deploy/
SOURCES="$TMP_ROOT/sources"
make_repo "$SOURCES"
printf '#!/usr/bin/env bash\nif then fi (\n' > "$SOURCES/scripts/bad.sh"
printf 'function {\n' > "$SOURCES/scripts/bad.ps1"
printf '#!/usr/bin/env bash\r\necho crlf\r\n' > "$SOURCES/shared/hooks/crlf-hook.sh"
printf '#!/usr/bin/env bash\necho deploy\n' > "$SOURCES/deploy/ok.sh"

mkdir -p "$TMP_ROOT/home"
printf 'keep\n' > "$TMP_ROOT/home/sentinel"

# Expected results (the .ps1 harness expects the same, except SKIP 6 (.sh)). The .sh twin's
# .ps1 audit is the stub SKIP when pwsh is not installed.
if [ "$SH_PWSH" = 1 ]; then
    SH_PS1_FROZEN="PASS 6 Full syntax (.ps1)|"
    SH_PS1_SOURCES="FAIL 6 Full syntax (.ps1)|1 file(s) failed"
else
    SH_PS1_FROZEN="SKIP 6 Full syntax (.ps1)|$SH_PS1_STUB"
    SH_PS1_SOURCES="$SH_PS1_FROZEN"
fi
expect "$TMP_ROOT/exp-frozen-sh" \
    "SKIP 2 Smoke-test deploy scripts|$RETIRED" \
    "PASS 6 Full syntax (.sh)|" \
    "$SH_PS1_FROZEN" \
    "PASS 14 Line ending audit|"
expect "$TMP_ROOT/exp-sources-sh" \
    "SKIP 2 Smoke-test deploy scripts|$RETIRED" \
    "FAIL 6 Full syntax (.sh)|1 file(s) failed" \
    "$SH_PS1_SOURCES" \
    "FAIL 14 Line ending audit|1 file(s) with CRLF"

snapshot "$TMP_ROOT/home" "$TMP_ROOT/home-before"

# --- .sh twin ------------------------------------------------------------------
if [ ! -f "$SH_SCRIPT" ]; then
    check "sh: $SH_SCRIPT exists" "false"
else
    section "$SH_SCRIPT" "$TMP_ROOT/steps.sh"
    check "sh: the step 2, 6 and 14 sections were found" \
        "[ \"\$(perl -ne '\$n++ if /^# (2|6|14)\\. /; END { print \$n + 0 }' '$TMP_ROOT/steps.sh')\" = 3 ]"
    cat > "$TMP_ROOT/run.sh" <<'EOF'
set -euo pipefail
step_pass() { printf 'PASS %s %s|%s\n' "$1" "$2" "${3:-}" >> "$DEPLOY_STEPS_REC"; }
step_fail() { printf 'FAIL %s %s|%s\n' "$1" "$2" "${3:-}" >> "$DEPLOY_STEPS_REC"; }
step_warn() { printf 'WARN %s %s|%s\n' "$1" "$2" "${3:-}" >> "$DEPLOY_STEPS_REC"; }
step_skip() { printf 'SKIP %s %s|%s\n' "$1" "$2" "${3:-}" >> "$DEPLOY_STEPS_REC"; }
require_pwsh() {
    if [ "$DEPLOY_STEPS_SH_PWSH" = 1 ]; then return 0; fi
    step_skip "$1" "$2" "$DEPLOY_STEPS_STUB"
    return 1
}
REPO_ROOT="$DEPLOY_STEPS_REPO"
SCRIPT_DIR="$REPO_ROOT/scripts"
cd "$REPO_ROOT"
. "$DEPLOY_STEPS_SECTION"
EOF
    for fx in frozen sources; do
        repo="$TMP_ROOT/$fx"
        rm -f "$TMP_ROOT/marker-sh-$fx" "$TMP_ROOT/rec-sh-$fx"
        RC=0
        HOME="$TMP_ROOT/home" DEPLOY_STEPS_MARKER="$TMP_ROOT/marker-sh-$fx" \
            DEPLOY_STEPS_REC="$TMP_ROOT/rec-sh-$fx" DEPLOY_STEPS_REPO="$repo" \
            DEPLOY_STEPS_SECTION="$TMP_ROOT/steps.sh" DEPLOY_STEPS_SH_PWSH="$SH_PWSH" \
            DEPLOY_STEPS_STUB="$SH_PS1_STUB" \
            "$TB" "$TMP_ROOT/run.sh" > "$TMP_ROOT/out" 2>&1 || RC=$?
        norm "$TMP_ROOT/rec-sh-$fx" "$TMP_ROOT/got-sh-$fx"
        check "sh $fx: exit 0" "[ $RC -eq 0 ]"
        check "sh $fx: build-deploy.sh was not run" "[ ! -e '$TMP_ROOT/marker-sh-$fx' ]"
        cp "$TMP_ROOT/got-sh-$fx" "$TMP_ROOT/out"
        check "sh $fx: results are exactly the expected ones" "diff '$TMP_ROOT/exp-$fx-sh' '$TMP_ROOT/got-sh-$fx' > /dev/null"
    done
fi

# --- static cases (perl over the text of both twins) -----------------------------
# No non-comment line globs or names the aitools deploy/ tree
if [ -f "$SH_SCRIPT" ]; then
    perl -ne 'next if /^\s*#/; print "$.: $_" if m{(?:REPO_ROOT|ROOT)"?/deploy\b|"deploy"}' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: no line reads the aitools deploy/" "[ ! -s '$TMP_ROOT/out' ]"
fi
if [ -f "$PS1_SCRIPT" ]; then
    perl -ne 's/\r$//; next if /^\s*#/; print "$.: $_" if /RepoRoot[^#]*["\\\/]deploy["\\\/]|"deploy"/i' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: no line reads the aitools deploy/" "[ ! -s '$TMP_ROOT/out' ]"
fi

# --- HOME ------------------------------------------------------------------------
snapshot "$TMP_ROOT/home" "$TMP_ROOT/home-after"
cp "$TMP_ROOT/home-after" "$TMP_ROOT/out"
check "home: the temporary HOME is unchanged" "diff '$TMP_ROOT/home-before' '$TMP_ROOT/home-after' > /dev/null"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
