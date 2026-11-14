#!/usr/bin/env bash
# test-pre-commit-steps3-10.sh -- check-pre-commit steps 3 ("Build freshness")
# and 10 ("Deploy drift") never run build-deploy.sh and are retired to a SKIP
# that points to check-pre-push step 7 (incident #136). Before, --fix / -Fix ran
# build-deploy.sh under the caller's HOME (it rebuilds the real dotprofile
# deploy/; output and exit code were discarded), staged the frozen aitools
# deploy/ and reported PASS, and the step 3 WARN advised --fix / -Fix.
#
# Cases, for each twin (.sh in bash; .ps1 in pwsh when pwsh is installed):
#   section  steps 3 and 10 (cut between the "# 3." and "# 4." headings and
#            between "# 10." and "# 11.") run with stub step functions, a
#            scripts/ file staged, a temporary HOME and a fake repo whose
#            scripts/build-deploy.sh only writes marker files (one in HOME), a
#            tracked deploy/ file modified. Fix mode on: no marker, nothing
#            staged under deploy/, exactly two results, SKIP 3 and SKIP 10, both
#            naming check-pre-push step 7. Fix mode off: the same two results,
#            no WARN, no --fix / -Fix advice.
#   static   no non-comment line runs build-deploy or stages deploy/; no step
#            result text advises --fix / -Fix; the usage line of the fix flag
#            does not say it builds.
#   run      the whole script with the fix flag, from a clone of this repo
#            whose build-deploy.sh is the fake: .sh on macOS and Linux, .ps1 on
#            Windows (each refuses the other platform). A scripts/ .sh is staged
#            with CRLF and mode 100644, a tracked deploy/ file is modified; HOME
#            is temporary and its config.json points at a fixture dotprofile.
#            Steps 3 and 10 SKIP as above; the run ends with a summary; no
#            marker; HOME and the dotprofile working tree are unchanged (every
#            file, by checksum); nothing staged under deploy/; steps 4 and 6
#            still repair the staged file (LF, 100755).
#
# Override the scripts under test with PRE_COMMIT_SH / PRE_COMMIT_PS1 (absolute
# paths), e.g. to show that the pre-fix scripts fail; the run case copies the
# override into the clone. TEST_RUN_TWIN=sh|ps1|none picks the twin of the run
# case (default: ps1 on Windows, sh elsewhere). AITOOLS_TEST_BASH runs the .sh
# pieces with another bash (macOS /bin/bash 3.2).
# Safe to re-run: writes only to a temp dir, removed on exit; the real HOME and
# the real dotprofile are never read or written. Needs git and perl; the .ps1
# cases need pwsh (skipped without it). Exit 1 if any case fails.
# Platform: macOS, Linux, Windows Git Bash (CI: macos, linux and windows jobs).
# Usage: bash tests/check-pre-commit/test-pre-commit-steps3-10.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 40' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SH_SCRIPT="${PRE_COMMIT_SH:-$ROOT/scripts/check-pre-commit.sh}"
PS1_SCRIPT="${PRE_COMMIT_PS1:-$ROOT/scripts/check-pre-commit.ps1}"
TB="${AITOOLS_TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
# TEST_KEEP_TMP=1 keeps the temp dir for debugging (its path is printed)
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
RUN_TWIN="${TEST_RUN_TWIN:-}"
if [ -z "$RUN_TWIN" ]; then
    if $IS_WINDOWS; then RUN_TWIN=ps1; else RUN_TWIN=sh; fi
fi
HAVE_PWSH=false
if command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=true; fi

RETIRED='retired: check-pre-push step 7 rebuilds into a temp dotprofile copy'
GIT_ID="-c user.name=test -c user.email=test@example.com"

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

# section <script> <out>: steps 3 and 10 (the "# 3." to "# 4." and "# 10." to
# "# 11." heading spans), CRLF removed (.ps1 files check out with CRLF)
section() {
    perl -ne 's/\r$//; $p = 1 if /^# (3|10)\. /; $p = 0 if /^# (4|11)\. /; print if $p' "$1" > "$2"
}

# snapshot <dir> <out>: every file under <dir> with its checksum, except .git/
# (git status refreshes the index) and AppData/Local/Microsoft/PowerShell/
# (pwsh itself writes its startup profile cache under USERPROFILE at every start)
snapshot() {
    ( cd "$1" && find . \( -path ./.git -o -path ./AppData/Local/Microsoft/PowerShell \) -prune -o -type f -print \
        | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done ) > "$2"
}

# has_cr <file>: the file contains a CR byte (perl, not grep: the Git for
# Windows grep strips CR before matching)
has_cr() { perl -ne '$c = 1 if /\r/; END { exit($c ? 0 : 1) }' "$1"; }

# records_ok <rec>: exactly SKIP 3 and SKIP 10, both with the retired text
records_ok() {
    [ -f "$1" ] &&
    [ "$(perl -ne 'END { print $. + 0 }' "$1")" = 2 ] &&
    grep -qxF "SKIP 3 $RETIRED" "$1" &&
    grep -qxF "SKIP 10 $RETIRED" "$1"
}

# The fake build-deploy.sh: records that it ran, in HOME (as the real one writes
# the dotprofile it resolves from HOME) and at an absolute marker path
FAKE_BUILD="$TMP_ROOT/fake-build-deploy.sh"
printf '#!/usr/bin/env bash\nprintf ran > "$HOME/m6b-build-ran"\nprintf ran > "$M6B_MARKER"\n' > "$FAKE_BUILD"

# mk_repo <dir>: a git repo with a committed deploy/ file, then modified (so a
# `git add deploy/` would stage it), and scripts/build-deploy.sh = the fake
mk_repo() {
    mkdir -p "$1/deploy" "$1/scripts"
    printf 'frozen\n' > "$1/deploy/setup-x.sh"
    git -C "$1" init -q
    git -C "$1" -c core.autocrlf=false add -A
    git -C "$1" $GIT_ID commit -q -m fixture
    printf 'changed\n' >> "$1/deploy/setup-x.sh"
    cp "$FAKE_BUILD" "$1/scripts/build-deploy.sh"
}

# --- section cases: .sh twin ---------------------------------------------------
if [ ! -f "$SH_SCRIPT" ]; then
    check "sh: $SH_SCRIPT exists" "false"
else
    section "$SH_SCRIPT" "$TMP_ROOT/steps.sh"
    check "sh: the step 3 and step 10 sections were found" \
        "grep -q '^# 3\\. ' '$TMP_ROOT/steps.sh' && grep -q '^# 10\\. ' '$TMP_ROOT/steps.sh'"
    cat > "$TMP_ROOT/run.sh" <<'EOF'
set -euo pipefail
step_pass() { printf 'PASS %s %s\n' "$1" "${3:-}" >> "$STEP_REC"; }
step_fail() { printf 'FAIL %s %s\n' "$1" "${3:-}" >> "$STEP_REC"; }
step_warn() { printf 'WARN %s %s\n' "$1" "${3:-}" >> "$STEP_REC"; }
step_skip() { printf 'SKIP %s %s\n' "$1" "${3:-}" >> "$STEP_REC"; }
REPO_ROOT="$STEP_REPO"
SCRIPT_DIR="$STEP_REPO/scripts"
STAGED_FILES="scripts/setup-x.sh"
FIX_MODE="$STEP_FIX"
cd "$REPO_ROOT"
. "$STEP_SECTION"
EOF
    for mode in true false; do
        repo="$TMP_ROOT/repo-sh-$mode"
        home="$TMP_ROOT/home-sh-$mode"
        mk_repo "$repo"
        mkdir -p "$home"
        rm -f "$TMP_ROOT/marker-sh-$mode" "$TMP_ROOT/rec-sh-$mode"
        RC=0
        HOME="$home" M6B_MARKER="$TMP_ROOT/marker-sh-$mode" STEP_REC="$TMP_ROOT/rec-sh-$mode" \
            STEP_REPO="$repo" STEP_FIX="$mode" STEP_SECTION="$TMP_ROOT/steps.sh" \
            "$TB" "$TMP_ROOT/run.sh" > "$TMP_ROOT/out" 2>&1 || RC=$?
        if [ "$mode" = true ]; then label="sh section --fix"; else label="sh section (no --fix)"; fi
        check "$label: exit 0" "[ $RC -eq 0 ]"
        check "$label: build-deploy.sh was not run (no marker, HOME untouched)" \
            "[ ! -e '$TMP_ROOT/marker-sh-$mode' ] && [ ! -e '$home/m6b-build-ran' ]"
        check "$label: nothing staged under deploy/" \
            "[ -z \"\$(git -C '$repo' diff --cached --name-only -- deploy)\" ]"
        check "$label: exactly SKIP 3 and SKIP 10, pointing to check-pre-push step 7" \
            "records_ok '$TMP_ROOT/rec-sh-$mode'"
        check "$label: no result advises --fix" \
            "[ -f '$TMP_ROOT/rec-sh-$mode' ] && ! grep -qi -- '--fix' '$TMP_ROOT/rec-sh-$mode'"
    done
fi

# --- section cases: .ps1 twin --------------------------------------------------
if [ ! -f "$PS1_SCRIPT" ]; then
    check "ps1: $PS1_SCRIPT exists" "false"
elif ! $HAVE_PWSH; then
    printf 'SKIP ps1 section cases: pwsh not installed\n'; SKIP=$((SKIP + 1))
else
    section "$PS1_SCRIPT" "$TMP_ROOT/steps.ps1"
    check "ps1: the step 3 and step 10 sections were found" \
        "grep -q '^# 3\\. ' '$TMP_ROOT/steps.ps1' && grep -q '^# 10\\. ' '$TMP_ROOT/steps.ps1'"
    cat > "$TMP_ROOT/run.ps1" <<'EOF'
$ErrorActionPreference = "Stop"
function StepPass { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "PASS $n $d" }
function StepFail { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "FAIL $n $d" }
function StepWarn { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "WARN $n $d" }
function StepSkip { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "SKIP $n $d" }
function InvokeGit { $out = & git @args 2>$null; $out }
$script:RepoRoot = $env:STEP_REPO
$scriptDir = Join-Path $env:STEP_REPO "scripts"
$stagedFiles = @("scripts/setup-x.sh")
$Fix = ($env:STEP_FIX -eq "true")
# The bash the old step ran build-deploy.sh with (check-lib ResolveGitBash)
$gitBash = $env:STEP_BASH
Set-Location $script:RepoRoot
. $env:STEP_SECTION
EOF
    bash_native=$(command -v bash)
    if $IS_WINDOWS; then bash_native=$(cygpath -w "$bash_native"); fi
    for mode in true false; do
        repo="$TMP_ROOT/repo-ps1-$mode"
        home="$TMP_ROOT/home-ps1-$mode"
        mk_repo "$repo"
        mkdir -p "$home"
        rm -f "$TMP_ROOT/marker-ps1-$mode" "$TMP_ROOT/rec-ps1-$mode"
        RC=0
        HOME="$(native "$home")" USERPROFILE="$(native "$home")" \
            M6B_MARKER="$(native "$TMP_ROOT/marker-ps1-$mode")" STEP_REC="$(native "$TMP_ROOT/rec-ps1-$mode")" \
            STEP_REPO="$(native "$repo")" STEP_FIX="$mode" STEP_SECTION="$(native "$TMP_ROOT/steps.ps1")" \
            STEP_BASH="$bash_native" \
            pwsh -NoProfile -NonInteractive -File "$(native "$TMP_ROOT/run.ps1")" > "$TMP_ROOT/out" 2>&1 || RC=$?
        # Add-Content writes CRLF on Windows
        if [ -f "$TMP_ROOT/rec-ps1-$mode" ]; then perl -pi -e 's/\r$//' "$TMP_ROOT/rec-ps1-$mode"; fi
        if [ "$mode" = true ]; then label="ps1 section -Fix"; else label="ps1 section (no -Fix)"; fi
        check "$label: exit 0" "[ $RC -eq 0 ]"
        check "$label: build-deploy.sh was not run (no marker, HOME untouched)" \
            "[ ! -e '$TMP_ROOT/marker-ps1-$mode' ] && [ ! -e '$home/m6b-build-ran' ]"
        check "$label: nothing staged under deploy/" \
            "[ -z \"\$(git -C '$repo' diff --cached --name-only -- deploy)\" ]"
        check "$label: exactly SKIP 3 and SKIP 10, pointing to check-pre-push step 7" \
            "records_ok '$TMP_ROOT/rec-ps1-$mode'"
        check "$label: no result advises -Fix" \
            "[ -f '$TMP_ROOT/rec-ps1-$mode' ] && ! grep -qi -- '-fix' '$TMP_ROOT/rec-ps1-$mode'"
    done
fi

# --- static cases --------------------------------------------------------------
if [ -f "$SH_SCRIPT" ]; then
    perl -ne 'next if /^\s*#/; print "$.: $_" if /(?:^|[\s;&|(])(?:bash|sh|source|\.)\s+[^#]*build-deploy/' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: no line runs build-deploy" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 'next if /^\s*#/; print "$.: $_" if /\bgit\s+add\s+[^#]*\bdeploy\b/' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: no line stages deploy/" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 'next if /^\s*#/; print "$.: $_" if /\bstep_\w+\b.*--fix/' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: no step result advises --fix" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 'print "$.: $_" if /^#\s*--fix:/' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: the --fix usage line exists and does not say it builds" \
        "[ -s '$TMP_ROOT/out' ] && ! grep -qi 'build' '$TMP_ROOT/out'"
fi
if [ -f "$PS1_SCRIPT" ]; then
    perl -ne 's/\r$//; next if /^\s*#/; print "$.: $_" if /(?:&|\bbash\b|Start-Process)[^#]*build-deploy/i' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: no line runs build-deploy" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 's/\r$//; next if /^\s*#/; print "$.: $_" if /\b(?:InvokeGit|git)\s+add\s+[^#]*\bdeploy\b/i' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: no line stages deploy/" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 's/\r$//; next if /^\s*#/; print "$.: $_" if /\bStep\w+\b.*-Fix/i' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: no step result advises -Fix" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 's/\r$//; print "$.: $_" if /^#\s*-Fix:/' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: the -Fix usage line exists and does not say it builds" \
        "[ -s '$TMP_ROOT/out' ] && ! grep -qi 'build' '$TMP_ROOT/out'"
fi

# --- run case: the whole script with the fix flag -------------------------------
run_whole() {
    local clone="$TMP_ROOT/aitools" home="$TMP_ROOT/run-home" dot="$TMP_ROOT/run-dot"
    local logs="$TMP_ROOT/run-logs" staged="scripts/zz-m6b-staged.sh" dep rc=0
    # A clone of this repo, the working tree's scripts/ over it (uncommitted
    # changes are what gets tested), the twin under test, the fake build
    git clone -q "$ROOT" "$clone"
    git -C "$clone" config core.autocrlf false
    cp -R "$ROOT/scripts/." "$clone/scripts/"
    cp "$SH_SCRIPT" "$clone/scripts/check-pre-commit.sh"
    cp "$PS1_SCRIPT" "$clone/scripts/check-pre-commit.ps1"
    cp "$FAKE_BUILD" "$clone/scripts/build-deploy.sh"
    # A staged scripts/ .sh with CRLF and mode 100644 (steps 4 and 6 repair it)
    printf 'echo staged\r\n' > "$clone/$staged"
    git -C "$clone" -c core.safecrlf=false add -- "$staged"
    git -C "$clone" update-index --chmod=-x -- "$staged"
    # A tracked aitools deploy/ file modified (the old step 3 staged deploy/)
    dep=$(git -C "$clone" ls-files deploy | head -n 1)
    if [ -z "$dep" ]; then mkdir -p "$clone/deploy"; dep="deploy/m6b.txt"; printf 'x\n' > "$clone/$dep"; git -C "$clone" add -- "$dep"; git -C "$clone" $GIT_ID commit -q -m m6b-deploy; fi
    printf '# m6b\n' >> "$clone/$dep"
    # The fixture dotprofile (deploy/ gitignored and present, as on a real machine)
    mkdir -p "$dot/claude" "$dot/deploy"
    printf '# Prefs\n' > "$dot/claude/CLAUDE.md"
    printf 'deploy/\n' > "$dot/.gitignore"
    printf 'built\n' > "$dot/deploy/setup-user-claude.sh"
    git -C "$dot" init -q
    git -C "$dot" -c core.autocrlf=false add -A
    git -C "$dot" $GIT_ID commit -q -m fixture
    # The temporary HOME
    mkdir -p "$home/.aitools" "$logs" "$TMP_ROOT/run-appdata" "$TMP_ROOT/run-localappdata"
    printf '{"repoPath": "%s", "userRepoPath": "%s"}\n' "$(native "$clone")" "$(native "$dot")" > "$home/.aitools/config.json"
    snapshot "$home" "$TMP_ROOT/home-before"
    snapshot "$dot" "$TMP_ROOT/dot-before"
    rm -f "$TMP_ROOT/marker-run"
    if [ "$RUN_TWIN" = ps1 ]; then
        env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
            HOME="$(native "$home")" USERPROFILE="$(native "$home")" \
            APPDATA="$(native "$TMP_ROOT/run-appdata")" LOCALAPPDATA="$(native "$TMP_ROOT/run-localappdata")" \
            AITOOLS_LOG_DIR="$(native "$logs")" M6B_MARKER="$(native "$TMP_ROOT/marker-run")" \
            pwsh -NoProfile -NonInteractive -File "$(native "$clone/scripts/check-pre-commit.ps1")" -Fix \
            < /dev/null > "$TMP_ROOT/run-out" 2>&1 || rc=$?
    else
        env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
            HOME="$home" AITOOLS_LOG_DIR="$logs" M6B_MARKER="$TMP_ROOT/marker-run" \
            "$TB" "$clone/scripts/check-pre-commit.sh" --fix \
            < /dev/null > "$TMP_ROOT/run-out" 2>&1 || rc=$?
    fi
    cp "$TMP_ROOT/run-out" "$TMP_ROOT/out"
    snapshot "$home" "$TMP_ROOT/home-after"
    snapshot "$dot" "$TMP_ROOT/dot-after"
    # Step results from checks.log: "<RESULT> <num> <detail>"
    : > "$TMP_ROOT/run-rec"
    if [ -f "$logs/checks.log" ]; then
        perl -ne 's/\r$//; print "$2 $1 $3\n" if /\[pre-commit\]\s+(\d+)\.\s.*?\[(PASS|FAIL|WARN|SKIP)\]\s?(.*)$/' "$logs/checks.log" > "$TMP_ROOT/run-rec"
    fi
    perl -ne 'print if /^\S+ (3|10) /' "$TMP_ROOT/run-rec" > "$TMP_ROOT/run-rec-3-10"
    local label="run ($RUN_TWIN, fix flag)"
    check "$label: the script ran to its summary (exit 0 or 1)" \
        "[ $rc -le 1 ] && grep -q 'SUMMARY' '$logs/checks.log'"
    check "$label: exactly SKIP 3 and SKIP 10, pointing to check-pre-push step 7" \
        "records_ok '$TMP_ROOT/run-rec-3-10'"
    check "$label: build-deploy.sh was not run (no marker)" "[ ! -e '$TMP_ROOT/marker-run' ]"
    # On a difference, the failure shows the snapshot diff (not the run output)
    diff "$TMP_ROOT/home-before" "$TMP_ROOT/home-after" > "$TMP_ROOT/out" 2>&1
    check "$label: HOME unchanged (every file, by checksum)" \
        "cmp -s '$TMP_ROOT/home-before' '$TMP_ROOT/home-after'"
    diff "$TMP_ROOT/dot-before" "$TMP_ROOT/dot-after" > "$TMP_ROOT/out" 2>&1
    check "$label: the dotprofile working tree unchanged" \
        "cmp -s '$TMP_ROOT/dot-before' '$TMP_ROOT/dot-after'"
    cp "$TMP_ROOT/run-out" "$TMP_ROOT/out"
    check "$label: nothing staged under deploy/" \
        "[ -z \"\$(git -C '$clone' diff --cached --name-only -- deploy)\" ]"
    check "$label: step 4 still repairs line endings (staged file is LF)" \
        "! has_cr '$clone/$staged' && grep -q '^PASS 4 (fixed CRLF)' '$TMP_ROOT/run-rec'"
    check "$label: step 6 still repairs the exec bit (staged file is 100755)" \
        "git -C '$clone' ls-files -s -- '$staged' | grep -q '^100755'"
}

case "$RUN_TWIN" in
    ps1)
        if ! $IS_WINDOWS; then
            printf 'SKIP run case: the .ps1 twin refuses to run off Windows\n'; SKIP=$((SKIP + 1))
        elif ! $HAVE_PWSH; then
            printf 'SKIP run case: pwsh not installed\n'; SKIP=$((SKIP + 1))
        else
            run_whole
        fi ;;
    sh) run_whole ;;
    *) printf 'SKIP run case: TEST_RUN_TWIN=%s\n' "$RUN_TWIN"; SKIP=$((SKIP + 1)) ;;
esac

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
