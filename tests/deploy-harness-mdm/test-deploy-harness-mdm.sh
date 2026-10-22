#!/usr/bin/env bash
# test-deploy-harness-mdm.sh -- tests for the MDM deploy-harness that
# scripts/build-deploy.sh generates into <dotprofile>/deploy/
#
# Runs build-deploy.sh under an isolated HOME whose config.json points at a
# fixture dotprofile (a git repo in a temp directory), so the real HOME and the
# real dotprofile are never touched; the sources are this repo (read only).
# Then runs the dev path (scripts/deploy-harness.sh) and the generated MDM path
# (a copy of deploy/ outside any repo, with a git on PATH that always fails)
# under two more isolated HOMEs and compares the results.
# Cases: build output and parse (bash -n, pwsh parser), cursor header port and
# step 4 (MDM), no adopt target in MDM, first run / rerun / edit / dry run
# equivalence (trees, exec bits, summary rows, exit codes), no git needed at
# run time, --help, conflicts (same ERROR rows, exit 1), build from a non-git
# dotprofile (pre-push step 7's git-archive copy) gives the same output, and
# the .ps1 pair on pwsh with the OS guards disabled in temp copies.
# Platform: macOS, Linux (needs node, perl, git; pwsh optional). Exit 1 if any
# case fails.
#
# Usage: bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 20' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
SKIP=0
OUT=""

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "$OUT" ] && [ -f "$OUT" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$OUT" | tail -n 20
        fi
    fi
}

for t in node perl git; do
    if ! command -v "$t" >/dev/null 2>&1; then
        printf 'SKIP all cases (%s not found)\n' "$t"
        exit 0
    fi
done

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

DOT="$TMP_ROOT/dot"
mkdir -p "$DOT/claude/rules"
printf 'user rule one\n' > "$DOT/claude/rules/user1.md"
printf 'user rule two\n' > "$DOT/claude/rules/user2.md"
git -C "$DOT" init -q
gitc -C "$DOT" add -A
gitc -C "$DOT" commit -q -m fixture

write_config() {  # write_config HOME_DIR
    mkdir -p "$1/.aitools"
    printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "%s",\n  "userRepoPath": "%s"\n}\n' \
        "$TMP_ROOT" "$ROOT" "$DOT" > "$1/.aitools/config.json"
}

# build NAME -- build-deploy.sh into $DOT/deploy, then copy deploy/ to $TMP_ROOT/NAME
build() {
    local hb="$TMP_ROOT/home-build-$1"
    write_config "$hb"
    OUT="$TMP_ROOT/build-$1.out"
    HOME="$hb" bash "$ROOT/scripts/build-deploy.sh" > "$OUT" 2>&1
    echo $? > "$TMP_ROOT/build-$1.rc"
    rm -rf "$TMP_ROOT/$1"
    mkdir -p "$TMP_ROOT/$1"
    if [ -d "$DOT/deploy" ]; then cp -Rp "$DOT/deploy" "$TMP_ROOT/$1/deploy"; fi
}

# Failing git for the MDM runs: the MDM path must not need git.
mkdir -p "$TMP_ROOT/fakegit"
printf '#!/bin/sh\necho "$*" >> "%s/fakegit.calls"\nexit 99\n' "$TMP_ROOT" > "$TMP_ROOT/fakegit/git"
chmod +x "$TMP_ROOT/fakegit/git"

# run SIDE NAME ARGS... -- SIDE dev|mdm, NAME = case dir; HOME = $TMP_ROOT/NAME-SIDE
run() {
    local side="$1" name="$2" h; shift 2
    h="$TMP_ROOT/$name-$side"
    [ -f "$h/.aitools/config.json" ] || write_config "$h"
    OUT="$TMP_ROOT/$name-$side.out"
    : > "$TMP_ROOT/$name-$side.summary"
    if [ "$side" = dev ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" AITOOLS_LOG_DIR="$h/logs" \
            AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name-$side.summary" \
            bash "$ROOT/scripts/deploy-harness.sh" "$@" < /dev/null > "$OUT" 2>&1
    else
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" PATH="$TMP_ROOT/fakegit:$PATH" AITOOLS_LOG_DIR="$h/logs" \
            AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name-$side.summary" \
            bash "$TMP_ROOT/$BUILD/deploy/deploy-harness.sh" "$@" < /dev/null > "$OUT" 2>&1
    fi
    echo $? > "$TMP_ROOT/$name-$side.rc"
}

rc_of() { cat "$TMP_ROOT/$1.rc"; }
same_rc() { [ "$(rc_of "$1-dev")" = "$(rc_of "$1-mdm")" ]; }
same_summary() { cmp -s "$TMP_ROOT/$1-dev.summary" "$TMP_ROOT/$1-mdm.summary"; }
row() { grep -qxF "$2" "$TMP_ROOT/$1.summary"; }
same_trees() {  # same_trees NAME -- six directories and exec bits identical
    local k a="$TMP_ROOT/$1-dev/.aitools" b="$TMP_ROOT/$1-mdm/.aitools"
    for k in reference registries hooks rules skills bin; do
        diff -r -x '*.bak.*' "$a/$k" "$b/$k" > /dev/null 2>&1 || return 1
    done
    [ "$(cd "$a" && find reference registries hooks rules skills bin -type f -perm -u+x | sort)" = \
      "$(cd "$b" && find reference registries hooks rules skills bin -type f -perm -u+x | sort)" ]
}
no_fake_git() { [ ! -s "$TMP_ROOT/fakegit.calls" ]; }

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
BUILD=b1
build b1
G="$TMP_ROOT/b1/deploy"
check "build: exit 0" "[ \"\$(rc_of build-b1)\" = 0 ]"
check "build: deploy-harness.sh/.ps1 and the config writer bundle generated" \
    "[ -x '$G/deploy-harness.sh' ] && [ -f '$G/deploy-harness.ps1' ] && [ -x '$G/setup-user-config.sh' ] && [ -f '$G/setup-user-config.ps1' ] && [ -f '$G/aitools-profile.sh' ] && [ -f '$G/aitools-profile.ps1' ] && [ -f '$G/aitools-json.pl' ] && [ -f '$G/aitools-json.ps1' ]"
check "MDM parse: bash -n deploy-harness.sh" "bash -n '$G/deploy-harness.sh'"
if command -v pwsh >/dev/null 2>&1; then
    printf '%s\n' '$e = $null' \
        '$null = [System.Management.Automation.Language.Parser]::ParseFile($args[0], [ref]$null, [ref]$e)' \
        'if ($e.Count -gt 0) { $e | ForEach-Object { [Console]::WriteLine($_.Message) }; exit 1 }' > "$TMP_ROOT/parse.ps1"
    check "MDM parse: pwsh parser deploy-harness.ps1" "pwsh -NoProfile -File '$TMP_ROOT/parse.ps1' '$G/deploy-harness.ps1' > /dev/null"
else
    printf 'SKIP MDM parse .ps1 (pwsh not found)\n'; SKIP=$((SKIP + 1))
fi
check "cursor (MDM): step 4 once in .sh and .ps1" \
    "[ \"\$(grep -c 'Step 4: Cursor user rules' '$G/setup-user-cursor.sh')\" = 1 ] && [ \"\$(grep -c 'Step 4: Cursor user rules' '$G/setup-user-cursor.ps1')\" = 1 ]"
check "cursor (MDM): header ported from the source (four things, rules scope)" \
    "grep -q '^# Does four things:' '$G/setup-user-cursor.sh' && grep -q '^# Does four things:' '$G/setup-user-cursor.ps1' && grep -q 'Managed: one <name>.mdc per' '$G/setup-user-cursor.sh' && grep -q 'Managed: one <name>.mdc per' '$G/setup-user-cursor.ps1' && ! grep -q 'Does three things' '$G/setup-user-cursor.sh'"
check "MDM: no adopt target (.sh and .ps1)" \
    "grep -qF '\"\$TOOL\" \"\$item\" \"\"  # MDM' '$G/deploy-harness.sh' && ! grep -qF '\"\$item\" \"\$src\"' '$G/deploy-harness.sh' && grep -qF -- '-AdoptPath \"\"  # MDM' '$G/deploy-harness.ps1' && ! grep -qF -- '-AdoptPath \$p.Src' '$G/deploy-harness.ps1'"
check "MDM: dotprofile rules embedded" "grep -q '^# dotprofile/claude/rules/user1.md (' '$G/deploy-harness.sh'"

# ---------------------------------------------------------------------------
# Equivalence: first run, rerun, edit, dry run
# ---------------------------------------------------------------------------
run dev eq
run mdm eq
check "first run: dev exit 0, MDM same exit code" "[ \"\$(rc_of eq-dev)\" = 0 ] && same_rc eq"
check "first run: same six directories and exec bits" "same_trees eq"
check "first run: same summary rows" "same_summary eq"
check "first run: config.json written by the MDM writer, same as dev" "cmp -s '$TMP_ROOT/eq-dev/.aitools/config.json' '$TMP_ROOT/eq-mdm/.aitools/config.json'"
check "first run: dotprofile rule deployed by MDM" "grep -qx 'user rule one' '$TMP_ROOT/eq-mdm/.aitools/rules/user1.md'"
check "first run: MDM needed no git" "no_fake_git"
run dev eq
run mdm eq
check "rerun: everything verified, same rows" "grep -q '^OK|harness files|[0-9]* verified$' '$TMP_ROOT/eq-mdm.summary' && same_summary eq && same_rc eq"
printf 'local edit\n' > "$TMP_ROOT/eq-dev/.aitools/rules/user2.md"
printf 'local edit\n' > "$TMP_ROOT/eq-mdm/.aitools/rules/user2.md"
run dev eq
run mdm eq
# WARN, not OK: the non-interactive overwrite logs a warning and the library
# raises the row to WARN; the dev path does the same (next check).
check "edit then rerun (non-interactive): source wins in MDM, 1 updated" \
    "grep -qx 'user rule two' '$TMP_ROOT/eq-mdm/.aitools/rules/user2.md' && grep -q '^WARN|harness files|1 updated' '$TMP_ROOT/eq-mdm.summary'"
check "edit then rerun: same rows and files as dev" "same_summary eq && same_trees eq"
if ! same_summary eq; then diff "$TMP_ROOT/eq-dev.summary" "$TMP_ROOT/eq-mdm.summary" | perl -pe 's/^/      | /'; fi
PTY="$ROOT/tests/managed-files/pty-run.py"
if command -v python3 >/dev/null 2>&1 && [ -f "$PTY" ]; then
    printf 'local edit\n' > "$TMP_ROOT/eq-mdm/.aitools/rules/user1.md"
    OUT="$TMP_ROOT/pty-mdm.out"
    : > "$TMP_ROOT/pty-mdm.summary"
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$TMP_ROOT/eq-mdm" PATH="$TMP_ROOT/fakegit:$PATH" \
        AITOOLS_LOG_DIR="$TMP_ROOT/eq-mdm/logs" AITOOLS_SUMMARY_FILE="$TMP_ROOT/pty-mdm.summary" \
        python3 "$PTY" --input 's\n' --log "$OUT" -- bash "$TMP_ROOT/b1/deploy/deploy-harness.sh"
    echo $? > "$TMP_ROOT/pty-mdm.rc"
    check "terminal review (MDM): overwrite offered, adopt and merge not; skip keeps LOCAL" \
        "[ \"\$(rc_of pty-mdm)\" = 0 ] && grep -q '\[o\]verwrite' '$OUT' && ! grep -q 'accept & adopt :' '$OUT' && ! grep -q 'merge & adopt  :' '$OUT' && grep -qx 'local edit' '$TMP_ROOT/eq-mdm/.aitools/rules/user1.md' && grep -q '^WARN|harness files|1 skipped' '$TMP_ROOT/pty-mdm.summary'"
else
    printf 'SKIP terminal review case (python3 pty not available)\n'; SKIP=$((SKIP + 1))
fi

run dev dry --dry-run
run mdm dry --dry-run
check "dry run: same rows, nothing deployed" \
    "same_summary dry && same_rc dry && grep -q '^OK|harness files|dry-run: [0-9]* create, 0 update$' '$TMP_ROOT/dry-mdm.summary' && [ ! -e '$TMP_ROOT/dry-mdm/.aitools/rules' ]"
run mdm help --help
check "--help: exit 0, MDM header, nothing deployed" \
    "[ \"\$(rc_of help-mdm)\" = 0 ] && grep -q 'MDM path of scripts/deploy-harness.sh' '$TMP_ROOT/help-mdm.out' && [ ! -e '$TMP_ROOT/help-mdm/.aitools/rules' ]"
check "runs: MDM never called git" "no_fake_git"

# ---------------------------------------------------------------------------
# Conflicts: a dotprofile rule named like a project rule (case differs)
# ---------------------------------------------------------------------------
printf 'dotprofile copy\n' > "$DOT/claude/rules/Git-Safety.md"
gitc -C "$DOT" add -A
gitc -C "$DOT" commit -q -m dup
BUILD=b2
build b2
run dev dup
run mdm dup
check "conflict: both exit 1 with the same ERROR row" \
    "[ \"\$(rc_of dup-dev)\" = 1 ] && same_rc dup && row dup-mdm 'ERROR|harness files|Git-Safety.md: dup in dotpr...' && same_summary dup"
check "conflict: first source wins in MDM" "cmp -s '$ROOT/.claude/rules/git-safety.md' '$TMP_ROOT/dup-mdm/.aitools/rules/git-safety.md' && same_trees dup"

# ---------------------------------------------------------------------------
# Build from a non-git dotprofile (pre-push step 7 builds into a git-archive copy)
# ---------------------------------------------------------------------------
mv "$DOT/.git" "$TMP_ROOT/dot.git"
BUILD=b3
build b3
mv "$TMP_ROOT/dot.git" "$DOT/.git"
check "non-git dotprofile: build exit 0 with a warning" \
    "[ \"\$(rc_of build-b3)\" = 0 ] && grep -q 'not in a git work tree -- embedding every file on disk' '$TMP_ROOT/build-b3.out'"
check "non-git dotprofile: generated deploy-harness identical to the git build" \
    "cmp -s '$TMP_ROOT/b2/deploy/deploy-harness.sh' '$TMP_ROOT/b3/deploy/deploy-harness.sh' && cmp -s '$TMP_ROOT/b2/deploy/deploy-harness.ps1' '$TMP_ROOT/b3/deploy/deploy-harness.ps1'"

# ---------------------------------------------------------------------------
# PS1 pair on pwsh (OS guards disabled in temp copies, stub config writer)
# ---------------------------------------------------------------------------
if command -v pwsh >/dev/null 2>&1; then
    P="$TMP_ROOT/ps1"
    mkdir -p "$P/dev/scripts" "$P/dev/shared" "$P/dev/.claude" "$P/mdm/deploy"
    stub='param([switch]$DryRun, [switch]$Force)
exit 0'
    perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$ROOT/scripts/deploy-harness.ps1" > "$P/dev/scripts/deploy-harness.ps1"
    cp "$ROOT/scripts/aitools-lib.ps1" "$ROOT/scripts/harness-db.py" "$ROOT/scripts/read-session.py" "$ROOT/scripts/read-session-full.py" "$P/dev/scripts/"
    printf '%s\n' "$stub" > "$P/dev/scripts/setup-user-config.ps1"
    ln -s "$ROOT/reference" "$P/dev/reference"
    ln -s "$ROOT/registries" "$P/dev/registries"
    for d in hooks skills rules; do ln -s "$ROOT/shared/$d" "$P/dev/shared/$d"; done
    for d in skills rules; do ln -s "$ROOT/.claude/$d" "$P/dev/.claude/$d"; done
    perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$TMP_ROOT/b1/deploy/deploy-harness.ps1" > "$P/mdm/deploy/deploy-harness.ps1"
    printf '%s\n' "$stub" > "$P/mdm/deploy/setup-user-config.ps1"
    # The b1 snapshot has no dup; the dotprofile now has one: use b1's state.
    gitc -C "$DOT" rm -q claude/rules/Git-Safety.md
    gitc -C "$DOT" commit -q -m undup
    for side in dev mdm; do
        h="$TMP_ROOT/ps-$side"; write_config "$h"
        if [ "$side" = dev ]; then f="$P/dev/scripts/deploy-harness.ps1"; else f="$P/mdm/deploy/deploy-harness.ps1"; fi
        OUT="$TMP_ROOT/ps-$side.out"
        : > "$TMP_ROOT/ps-$side.summary"
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" \
            AITOOLS_SUMMARY_FILE="$TMP_ROOT/ps-$side.summary" \
            pwsh -NoProfile -File "$f" < /dev/null > "$OUT" 2>&1
        echo $? > "$TMP_ROOT/ps-$side.rc"
    done
    check "ps1: same exit code (0), summary rows and files" \
        "[ \"\$(rc_of ps-dev)\" = 0 ] && same_rc ps && same_summary ps && diff -r -x logs -x config.json '$TMP_ROOT/ps-dev/.aitools' '$TMP_ROOT/ps-mdm/.aitools' > /dev/null"
else
    printf 'SKIP ps1 pair (pwsh not found)\n'; SKIP=$((SKIP + 1))
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
