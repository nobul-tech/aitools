#!/usr/bin/env bash
# test-pre-commit-steps3-10.sh -- check-pre-commit steps 3 ("Build freshness")
# and 10 ("Deploy drift") never run build-deploy.sh and are retired to a SKIP
# that points to check-pre-push step 7 (incident #136). Before, --fix / -Fix ran
# build-deploy.sh under the caller's HOME (it rebuilds the real dotprofile
# deploy/; output and exit code were discarded), staged the frozen aitools
# deploy/ and reported PASS, and the step 3 WARN advised --fix / -Fix.
#
# Platform targeting (commander, 2026-11-14: "sh scripts and tests should only
# run on linux/mac and ps1 on windows"): this harness runs on macOS and Linux
# only and tests the .sh twin, scripts/check-pre-commit.sh, with bash. The .ps1
# twin is tested on Windows with native pwsh by
# tests/check-pre-commit/test-pre-commit-steps3-10.ps1 (the same section, step 6
# and run cases, and the same static cases).
#
# Cases:
#   section  steps 3 and 10 of check-pre-commit.sh (cut between the "# 3." and
#            "# 4." headings and between "# 10." and "# 11.") run with stub step
#            functions, a scripts/ file staged, a temporary HOME and a fake repo
#            whose scripts/build-deploy.sh only writes marker files (one in
#            HOME), a tracked deploy/ file modified. Fix mode on: no marker,
#            nothing staged under deploy/, exactly two results, SKIP 3 and SKIP
#            10, both naming check-pre-push step 7. Fix mode off: the same two
#            results, no WARN, no --fix advice.
#   step 6   step 6 (cut between "# 6." and "# 7.") run with the same stubs on
#            a fake repo with deploy/x.sh and scripts/y.sh both committed at
#            100644. Fix mode on: deploy/x.sh stays 100644 and nothing is
#            staged under deploy/, scripts/y.sh becomes 100755, the one result
#            is PASS 6 (fixed). Fix mode off: nothing changes, the one result is
#            FAIL 6 "1 file(s) missing +x" (scripts/y.sh only). The frozen
#            aitools deploy/ is neither repaired nor reported (PR #154 review B1).
#   static   perl over the text of both twins (platform-neutral, so both
#            harnesses run them): no non-comment line runs build-deploy or
#            stages deploy/; every line that lists tracked *.sh files (step 6)
#            excludes deploy/ (':!deploy/'); no step result text advises --fix /
#            -Fix; the usage line of the fix flag does not say it builds.
#   run      check-pre-commit.sh --fix, from a clone of this repo whose
#            build-deploy.sh is the fake. A scripts/ .sh is staged with CRLF and
#            mode 100644, a tracked deploy/ file is modified; HOME is temporary
#            and its config.json points at a fixture dotprofile. Steps 3 and 10
#            SKIP as above; the run ends with a summary; no marker; HOME and the
#            dotprofile working tree are unchanged (every file, by checksum);
#            nothing staged under deploy/; steps 4 and 6 still repair the staged
#            file (LF, 100755).
#
# Override the scripts under test with PRE_COMMIT_SH (the .sh twin) and
# PRE_COMMIT_PS1 (read by the static cases only), absolute paths, e.g. to show
# that the pre-fix scripts fail; the run case copies PRE_COMMIT_SH into the
# clone. TEST_RUN_TWIN=none skips the run case (default: sh). AITOOLS_TEST_BASH
# runs the .sh pieces with another bash (macOS /bin/bash 3.2).
# Safe to re-run: writes only to a temp dir, removed on exit; the real HOME and
# the real dotprofile are never read or written. Needs git and perl. Exit 1 if
# any case fails.
# Platform: macOS, Linux (CI: macos and linux jobs); refuses Windows.
# Usage: bash tests/check-pre-commit/test-pre-commit-steps3-10.sh [--help]

set -uo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/check-pre-commit/test-pre-commit-steps3-10.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/check-pre-commit/test-pre-commit-steps3-10.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 55' "$0"
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
RUN_TWIN="${TEST_RUN_TWIN:-sh}"

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

# section <script> <out>: steps 3 and 10 (the "# 3." to "# 4." and "# 10." to
# "# 11." heading spans), CRLF removed
section() {
    perl -ne 's/\r$//; $p = 1 if /^# (3|10)\. /; $p = 0 if /^# (4|11)\. /; print if $p' "$1" > "$2"
}

# snapshot <dir> <out>: every file under <dir> with its checksum, except .git/
# (git status refreshes the index)
snapshot() {
    ( cd "$1" && find . -path ./.git -prune -o -type f -print \
        | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done ) > "$2"
}

# has_cr <file>: the file contains a CR byte
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

# section6 <script> <out>: step 6 (the "# 6." to "# 7." heading span), CRLF removed
section6() {
    perl -ne 's/\r$//; $p = 1 if /^# 6\. /; $p = 0 if /^# 7\. /; print if $p' "$1" > "$2"
}

# mk_repo6 <dir>: a git repo with deploy/x.sh and scripts/y.sh committed at
# mode 100644 (git add --chmod=-x, so the mode does not depend on the file system)
mk_repo6() {
    mkdir -p "$1/deploy" "$1/scripts"
    printf 'echo frozen\n' > "$1/deploy/x.sh"
    printf 'echo source\n' > "$1/scripts/y.sh"
    git -C "$1" init -q
    git -C "$1" -c core.autocrlf=false add --chmod=-x -- deploy/x.sh scripts/y.sh
    git -C "$1" $GIT_ID commit -q -m fixture6
}

# rec_is <rec> <line>: the record file holds exactly that one line
rec_is() {
    [ -f "$1" ] &&
    [ "$(perl -ne 'END { print $. + 0 }' "$1")" = 1 ] &&
    grep -qxF "$2" "$1"
}

# mode_is <repo> <path> <mode>: the index mode of <path>
mode_is() { git -C "$1" ls-files -s -- "$2" | grep "^$3 " >/dev/null; }

# step6_checks <label> <repo> <fix true|false> <rec>: the step 6 assertions
step6_checks() {
    check "$1: deploy/x.sh still 100644 in the index" "mode_is '$2' deploy/x.sh 100644"
    check "$1: nothing staged under deploy/" \
        "[ -z \"\$(git -C '$2' diff --cached --name-only -- deploy)\" ]"
    if [ "$3" = true ]; then
        check "$1: scripts/y.sh repaired to 100755" "mode_is '$2' scripts/y.sh 100755"
        check "$1: exactly PASS 6 (fixed)" "rec_is '$4' 'PASS 6 (fixed)'"
    else
        check "$1: scripts/y.sh unchanged (100644)" "mode_is '$2' scripts/y.sh 100644"
        check "$1: exactly FAIL 6, scripts/y.sh only (1 file)" "rec_is '$4' 'FAIL 6 1 file(s) missing +x'"
    fi
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

    # Step 6: the frozen deploy/ is neither repaired nor reported (review B1)
    section6 "$SH_SCRIPT" "$TMP_ROOT/step6.sh"
    check "sh: the step 6 section was found" "grep -q '^# 6\\. ' '$TMP_ROOT/step6.sh'"
    for mode in true false; do
        repo="$TMP_ROOT/repo6-sh-$mode"
        mk_repo6 "$repo"
        rm -f "$TMP_ROOT/rec6-sh-$mode"
        RC=0
        HOME="$TMP_ROOT/home-sh-$mode" STEP_REC="$TMP_ROOT/rec6-sh-$mode" \
            STEP_REPO="$repo" STEP_FIX="$mode" STEP_SECTION="$TMP_ROOT/step6.sh" \
            "$TB" "$TMP_ROOT/run.sh" > "$TMP_ROOT/out" 2>&1 || RC=$?
        if [ "$mode" = true ]; then label="sh step 6 --fix"; else label="sh step 6 (no --fix)"; fi
        check "$label: exit 0" "[ $RC -eq 0 ]"
        step6_checks "$label" "$repo" "$mode" "$TMP_ROOT/rec6-sh-$mode"
    done
fi

# --- static cases (perl over the text of both twins) -----------------------------
if [ -f "$SH_SCRIPT" ]; then
    perl -ne 'next if /^\s*#/; print "$.: $_" if /(?:^|[\s;&|(])(?:bash|sh|source|\.)\s+[^#]*build-deploy/' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: no line runs build-deploy" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 'next if /^\s*#/; print "$.: $_" if /\bgit\s+add\s+[^#]*\bdeploy\b/' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: no line stages deploy/" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 'next if /^\s*#/; $n++ if /\bls-files\b.*\*\.sh/; print "$.: $_" if /\bls-files\b.*\*\.sh/ && !/:!deploy\//; END { print "no ls-files *.sh line found\n" unless $n }' "$SH_SCRIPT" > "$TMP_ROOT/out"
    check "sh static: the tracked *.sh listing (step 6) excludes deploy/" "[ ! -s '$TMP_ROOT/out' ]"
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
    perl -ne 's/\r$//; next if /^\s*#/; $n++ if /\bls-files\b.*\*\.sh/i; print "$.: $_" if /\bls-files\b.*\*\.sh/i && !/:!deploy\//; END { print "no ls-files *.sh line found\n" unless $n }' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: the tracked *.sh listing (step 6) excludes deploy/" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 's/\r$//; next if /^\s*#/; print "$.: $_" if /\bStep\w+\b.*-Fix/i' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: no step result advises -Fix" "[ ! -s '$TMP_ROOT/out' ]"
    perl -ne 's/\r$//; print "$.: $_" if /^#\s*-Fix:/' "$PS1_SCRIPT" > "$TMP_ROOT/out"
    check "ps1 static: the -Fix usage line exists and does not say it builds" \
        "[ -s '$TMP_ROOT/out' ] && ! grep -qi 'build' '$TMP_ROOT/out'"
fi

# --- run case: check-pre-commit.sh --fix ------------------------------------------
run_whole() {
    local clone="$TMP_ROOT/aitools" home="$TMP_ROOT/run-home" dot="$TMP_ROOT/run-dot"
    local logs="$TMP_ROOT/run-logs" staged="scripts/zz-m6b-staged.sh" dep rc=0
    # A clone of this repo, the working tree's scripts/ over it (uncommitted
    # changes are what gets tested), the script under test, the fake build
    git clone -q "$ROOT" "$clone"
    git -C "$clone" config core.autocrlf false
    cp -R "$ROOT/scripts/." "$clone/scripts/"
    cp "$SH_SCRIPT" "$clone/scripts/check-pre-commit.sh"
    cp "$FAKE_BUILD" "$clone/scripts/build-deploy.sh"
    # A staged scripts/ .sh with CRLF and mode 100644 (steps 4 and 6 repair it)
    printf 'echo staged\r\n' > "$clone/$staged"
    git -C "$clone" -c core.safecrlf=false add -- "$staged"
    git -C "$clone" update-index --chmod=-x -- "$staged"
    # A tracked aitools deploy/ file modified (the old step 3 staged deploy/)
    dep=$(git -C "$clone" ls-files deploy | sed -n '1p')
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
    mkdir -p "$home/.aitools" "$logs"
    printf '{"repoPath": "%s", "userRepoPath": "%s"}\n' "$clone" "$dot" > "$home/.aitools/config.json"
    snapshot "$home" "$TMP_ROOT/home-before"
    snapshot "$dot" "$TMP_ROOT/dot-before"
    rm -f "$TMP_ROOT/marker-run"
    env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
        HOME="$home" AITOOLS_LOG_DIR="$logs" M6B_MARKER="$TMP_ROOT/marker-run" \
        "$TB" "$clone/scripts/check-pre-commit.sh" --fix \
        < /dev/null > "$TMP_ROOT/run-out" 2>&1 || rc=$?
    cp "$TMP_ROOT/run-out" "$TMP_ROOT/out"
    snapshot "$home" "$TMP_ROOT/home-after"
    snapshot "$dot" "$TMP_ROOT/dot-after"
    # Step results from checks.log: "<RESULT> <num> <detail>"
    : > "$TMP_ROOT/run-rec"
    if [ -f "$logs/checks.log" ]; then
        perl -ne 's/\r$//; print "$2 $1 $3\n" if /\[pre-commit\]\s+(\d+)\.\s.*?\[(PASS|FAIL|WARN|SKIP)\]\s?(.*)$/' "$logs/checks.log" > "$TMP_ROOT/run-rec"
    fi
    perl -ne 'print if /^\S+ (3|10) /' "$TMP_ROOT/run-rec" > "$TMP_ROOT/run-rec-3-10"
    local label="run (sh, fix flag)"
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
        "git -C '$clone' ls-files -s -- '$staged' | grep '^100755' >/dev/null"
}

case "$RUN_TWIN" in
    sh) run_whole ;;
    *) printf 'SKIP run case: TEST_RUN_TWIN=%s\n' "$RUN_TWIN"; SKIP=$((SKIP + 1)) ;;
esac

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
