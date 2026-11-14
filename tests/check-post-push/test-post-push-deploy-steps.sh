#!/usr/bin/env bash
# test-post-push-deploy-steps.sh -- check-post-push steps 2, 6 and 14 never read
# the frozen aitools deploy/ (incident #176). Before, step 2 ran bash -n on
# deploy/*.sh and steps 6 and 14 added deploy/*.sh (and step 6 deploy/*.ps1) to
# their syntax and line-ending audits; build-deploy.sh has written the dotprofile
# deploy/ since 2c0fd32, so those reads proved nothing about the generated
# scripts. Step 2 is retired to a SKIP that points to check-pre-push step 7;
# steps 6 and 14 audit the source scripts (scripts/, shared/hooks/) only.
#
# Cases, for each twin (.sh in bash; .ps1 in pwsh when pwsh is installed):
#   frozen   steps 2, 6 and 14 (cut between their "# N." headings and the next
#            step's heading) run with stub step functions, a temporary HOME and
#            a fake repo whose source scripts are clean and whose deploy/ holds a
#            .sh with a syntax error, a .ps1 with a parse error and a CRLF .sh;
#            scripts/build-deploy.sh only writes a marker. Exactly: SKIP 2 with
#            the retired text, PASS 6 (.sh), PASS 6 (.ps1), PASS 14; no marker;
#            HOME unchanged (every file, by checksum)
#   sources  the same steps on a fake repo with a syntax error in scripts/*.sh,
#            a parse error in scripts/*.ps1 and a CRLF shared/hooks/*.sh: FAIL 6
#            (.sh), FAIL 6 (.ps1) and FAIL 14, one file each (the steps still
#            audit the sources)
#   twins    the .sh and .ps1 results of both fake repos are identical
#   static   no non-comment line of either twin reads the aitools deploy/
#
# Limits: on Windows the .sh twin's .ps1 audit (pwsh ParseFile on a POSIX path)
# is stubbed to a SKIP and its CRLF case is not checked (the Git for Windows
# grep strips CR before matching, so its grep $'\r' never fires; the .sh twin
# only runs on macOS and Linux). Both run in the macOS and Linux CI jobs.
#
# Override the scripts under test with POST_PUSH_SH / POST_PUSH_PS1 (absolute
# paths), e.g. to show that the pre-fix scripts fail. AITOOLS_TEST_BASH runs the
# .sh pieces with another bash (macOS /bin/bash 3.2). TEST_KEEP_TMP=1 keeps the
# temp dir. Safe to re-run: writes only to a temp dir, removed on exit; the real
# HOME and the real dotprofile are never read or written. Needs perl; the .ps1
# cases need pwsh (skipped without it). Exit 1 if any case fails.
# Platform: macOS, Linux, Windows Git Bash (CI: macos, linux and windows jobs).
# Usage: bash tests/check-post-push/test-post-push-deploy-steps.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 37' "$0"
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
IS_WINDOWS=false
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;; esac
HAVE_PWSH=false
if command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=true; fi
# The .sh twin's .ps1 audit runs pwsh on a POSIX path: real on macOS/Linux only
SH_PWSH=0
if $HAVE_PWSH && ! $IS_WINDOWS; then SH_PWSH=1; fi

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

# native <path>: the path as native tools want it (C:/... on Windows)
native() { if $IS_WINDOWS; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# section <script> <out>: steps 2, 6 and 14 (from each "# N." heading to the
# next step's heading), CRLF removed (.ps1 files check out with CRLF)
section() {
    perl -ne 's/\r$//; $p = 1 if /^# (2|6|14)\. /; $p = 0 if /^# (3|7|15)\. /; print if $p' "$1" > "$2"
}

# snapshot <dir> <out>: every file under <dir> with its checksum, except
# AppData/Local/Microsoft/PowerShell/ (pwsh writes its startup profile cache
# under USERPROFILE at every start)
snapshot() {
    ( cd "$1" && find . -path ./AppData/Local/Microsoft/PowerShell -prune -o -type f -print \
        | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done ) > "$2"
}

# norm <rec> <out>: the record file without CR (pwsh writes CRLF on Windows)
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

# Expected results. The .sh twin's .ps1 audit is a stub SKIP where it cannot run.
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
expect "$TMP_ROOT/exp-frozen-ps1" \
    "SKIP 2 Smoke-test deploy scripts|$RETIRED" \
    "PASS 6 Full syntax (.sh)|" \
    "PASS 6 Full syntax (.ps1)|" \
    "PASS 14 Line ending audit|"
expect "$TMP_ROOT/exp-sources-ps1" \
    "SKIP 2 Smoke-test deploy scripts|$RETIRED" \
    "FAIL 6 Full syntax (.sh)|1 file(s) failed" \
    "FAIL 6 Full syntax (.ps1)|1 file(s) failed" \
    "FAIL 14 Line ending audit|1 file(s) with CRLF"
if $IS_WINDOWS; then
    # Git for Windows grep cannot see CR: step 14 of the .sh twin is not checked here
    expect "$TMP_ROOT/exp-sources-sh" \
        "SKIP 2 Smoke-test deploy scripts|$RETIRED" \
        "FAIL 6 Full syntax (.sh)|1 file(s) failed" \
        "$SH_PS1_SOURCES"
else
    expect "$TMP_ROOT/exp-sources-sh" \
        "SKIP 2 Smoke-test deploy scripts|$RETIRED" \
        "FAIL 6 Full syntax (.sh)|1 file(s) failed" \
        "$SH_PS1_SOURCES" \
        "FAIL 14 Line ending audit|1 file(s) with CRLF"
fi

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
        if $IS_WINDOWS && [ "$fx" = sources ]; then
            # Drop step 14 of the .sh twin on Windows (see Limits in the header)
            perl -ni -e 'print unless /^\w+ 14 /' "$TMP_ROOT/got-sh-$fx"
        fi
        check "sh $fx: exit 0" "[ $RC -eq 0 ]"
        check "sh $fx: build-deploy.sh was not run" "[ ! -e '$TMP_ROOT/marker-sh-$fx' ]"
        cp "$TMP_ROOT/got-sh-$fx" "$TMP_ROOT/out"
        check "sh $fx: results are exactly the expected ones" "diff '$TMP_ROOT/exp-$fx-sh' '$TMP_ROOT/got-sh-$fx' > /dev/null"
    done
    # Static: no non-comment line globs or names the aitools deploy/ tree
    perl -ne 'next if /^\s*#/; print "$.: $_" if m{(?:REPO_ROOT|ROOT)"?/deploy\b|"deploy"}' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: no line reads the aitools deploy/" "[ ! -s '$TMP_ROOT/out' ]"
fi

# --- .ps1 twin -----------------------------------------------------------------
if [ ! -f "$PS1_SCRIPT" ]; then
    check "ps1: $PS1_SCRIPT exists" "false"
elif ! $HAVE_PWSH; then
    printf 'SKIP ps1 cases: pwsh not installed\n'; SKIP=$((SKIP + 1))
else
    section "$PS1_SCRIPT" "$TMP_ROOT/steps.ps1"
    check "ps1: the step 2, 6 and 14 sections were found" \
        "[ \"\$(perl -ne '\$n++ if /^# (2|6|14)\\. /; END { print \$n + 0 }' '$TMP_ROOT/steps.ps1')\" = 3 ]"
    cat > "$TMP_ROOT/run.ps1" <<'EOF'
$ErrorActionPreference = "Stop"
function Rec { param($s, $n, $name, $d) Add-Content -Path $env:DEPLOY_STEPS_REC -Value "$s $n $name|$d" }
function StepPass { param($n, $name, $d) Rec "PASS" $n $name $d }
function StepFail { param($n, $name, $d) Rec "FAIL" $n $name $d }
function StepWarn { param($n, $name, $d) Rec "WARN" $n $name $d }
function StepSkip { param($n, $name, $d) Rec "SKIP" $n $name $d }
function InvokeGit { $out = & git @args 2>$null; $out }
# The bash the steps run bash -n with (the pre-fix step 2 also resolved it)
function ResolveGitBash { $env:DEPLOY_STEPS_BASH }
$bashExe = ResolveGitBash
$script:RepoRoot = $env:DEPLOY_STEPS_REPO
$scriptDir = Join-Path $script:RepoRoot "scripts"
Set-Location $script:RepoRoot
. $env:DEPLOY_STEPS_SECTION
EOF
    bash_native=$(command -v bash)
    if $IS_WINDOWS; then bash_native=$(cygpath -w "$bash_native"); fi
    for fx in frozen sources; do
        repo="$TMP_ROOT/$fx"
        rm -f "$TMP_ROOT/marker-ps1-$fx" "$TMP_ROOT/rec-ps1-$fx"
        RC=0
        HOME="$TMP_ROOT/home" USERPROFILE="$(native "$TMP_ROOT/home")" \
            DEPLOY_STEPS_MARKER="$(native "$TMP_ROOT/marker-ps1-$fx")" \
            DEPLOY_STEPS_REC="$(native "$TMP_ROOT/rec-ps1-$fx")" DEPLOY_STEPS_REPO="$(native "$repo")" \
            DEPLOY_STEPS_SECTION="$(native "$TMP_ROOT/steps.ps1")" DEPLOY_STEPS_BASH="$bash_native" \
            pwsh -NoProfile -NonInteractive -File "$(native "$TMP_ROOT/run.ps1")" > "$TMP_ROOT/out" 2>&1 || RC=$?
        norm "$TMP_ROOT/rec-ps1-$fx" "$TMP_ROOT/got-ps1-$fx"
        check "ps1 $fx: exit 0" "[ $RC -eq 0 ]"
        check "ps1 $fx: build-deploy.sh was not run" "[ ! -e '$TMP_ROOT/marker-ps1-$fx' ]"
        cp "$TMP_ROOT/got-ps1-$fx" "$TMP_ROOT/out"
        check "ps1 $fx: results are exactly the expected ones" "diff '$TMP_ROOT/exp-$fx-ps1' '$TMP_ROOT/got-ps1-$fx' > /dev/null"
    done
fi
# Static (no pwsh needed): no non-comment line names the aitools deploy/ tree
if [ -f "$PS1_SCRIPT" ]; then
    perl -ne 's/\r$//; next if /^\s*#/; print "$.: $_" if /RepoRoot[^#]*["\\\/]deploy["\\\/]|"deploy"/i' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: no line reads the aitools deploy/" "[ ! -s '$TMP_ROOT/out' ]"
fi

# --- Twins and HOME ------------------------------------------------------------
if [ -f "$TMP_ROOT/got-sh-frozen" ] && [ -f "$TMP_ROOT/got-ps1-frozen" ]; then
    if [ "$SH_PWSH" = 1 ]; then
        for fx in frozen sources; do
            cp "$TMP_ROOT/got-ps1-$fx" "$TMP_ROOT/out"
            check "twins $fx: .sh and .ps1 results are identical" "diff '$TMP_ROOT/got-sh-$fx' '$TMP_ROOT/got-ps1-$fx' > /dev/null"
        done
    else
        # The .sh twin's .ps1 audit is stubbed here, and on Windows its step 14
        # cannot see CR: compare the results both twins really produced
        cmp_label="steps 2, 6 (.sh), 14"
        if $IS_WINDOWS; then cmp_label="steps 2, 6 (.sh)"; fi
        for fx in frozen sources; do
            for tw in sh ps1; do
                DS_WIN="$IS_WINDOWS" perl -ne 'print unless /^\w+ 6 Full syntax \(\.ps1\)/ || ($ENV{DS_WIN} eq "true" && /^\w+ 14 /)' \
                    "$TMP_ROOT/got-$tw-$fx" > "$TMP_ROOT/cmp-$tw-$fx"
            done
            cp "$TMP_ROOT/cmp-ps1-$fx" "$TMP_ROOT/out"
            check "twins $fx: .sh and .ps1 results are identical ($cmp_label)" "diff '$TMP_ROOT/cmp-sh-$fx' '$TMP_ROOT/cmp-ps1-$fx' > /dev/null"
        done
    fi
fi
snapshot "$TMP_ROOT/home" "$TMP_ROOT/home-after"
cp "$TMP_ROOT/home-after" "$TMP_ROOT/out"
check "home: the temporary HOME is unchanged" "diff '$TMP_ROOT/home-before' '$TMP_ROOT/home-after' > /dev/null"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
