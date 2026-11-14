#!/usr/bin/env bash
# test-pre-push-step7.sh -- tests for check-pre-push step 7 ("deploy/ matches
# source") against a dotprofile that tracks deploy/ and one that gitignores it.
#
# Each case runs check-pre-push (.ps1 on Windows through pwsh, .sh on macOS and
# Linux) from a local clone of this repo with one commit ahead of a fake
# origin/main, under a temporary HOME whose config.json points at a fixture
# dotprofile. Nothing outside the temp dir is read or written; the real HOME and
# the real dotprofile are never touched (build-deploy rebuilds <dotprofile>/deploy).
#
# Cases:
#   untracked  the dotprofile has no committed deploy/ (gitignored): step 7 PASS,
#              "untracked, not compared"; the build and the dry runs still run
#   stale      the dotprofile commits a deploy/ that differs from a fresh build:
#              step 7 FAIL "stale" (the comparison still works)
#
# Safe to re-run. Needs git, node and (Windows) pwsh. Exit 1 if any case fails.
# Platform: macOS, Linux, Windows Git Bash.
# Usage: bash tests/check-pre-push/test-pre-push-step7.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 19' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
SKIP=0
IS_WINDOWS=false
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;; esac

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -f "$TMP_ROOT/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$TMP_ROOT/out" | tail -n 25
        fi
    fi
}

# native <path>: the path as the platform's tools want it (C:/... on Windows)
native() { if $IS_WINDOWS; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

if ! command -v node >/dev/null 2>&1 || { $IS_WINDOWS && ! command -v pwsh >/dev/null 2>&1; }; then
    printf 'SKIP step 7 cases: node (or pwsh on Windows) not installed\n'; SKIP=$((SKIP + 1))
    printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
    exit 0
fi

# A clone of this repo's HEAD with one commit ahead of a fake origin/main, so
# check-pre-push has something to push and runs every step.
GIT_ID=(-c user.name=test -c user.email=test@example.com)
git clone -q "$ROOT" "$TMP_ROOT/aitools"
git -C "$TMP_ROOT/aitools" update-ref refs/remotes/origin/main HEAD
git -C "$TMP_ROOT/aitools" "${GIT_ID[@]}" commit -q --allow-empty -m "test: step 7"
# The working tree's scripts/ over the clone's, so uncommitted script changes are
# what gets tested (the clone only has committed files).
cp -R "$ROOT/scripts/." "$TMP_ROOT/aitools/scripts/"

# mk_dot <dir> [with-deploy]: a fixture dotprofile (git repo, no remote)
mk_dot() {
    mkdir -p "$1/claude"
    printf '# Prefs\n' > "$1/claude/CLAUDE.md"
    if [ "${2:-}" = "with-deploy" ]; then
        mkdir -p "$1/deploy"
        printf 'stale\n' > "$1/deploy/stale.txt"
    else
        printf 'deploy/\n' > "$1/.gitignore"
    fi
    git -C "$1" init -q
    git -C "$1" -c core.autocrlf=false add -A
    git -C "$1" "${GIT_ID[@]}" commit -q -m fixture
}

# run_step7 <dotprofile>: check-pre-push under a temp HOME; output -> $TMP_ROOT/out
run_step7() {
    local h="$TMP_ROOT/home-$(basename "$1")"
    mkdir -p "$h/.aitools"
    printf '{"repoPath": "%s", "userRepoPath": "%s"}\n' "$(native "$TMP_ROOT/aitools")" "$(native "$1")" > "$h/.aitools/config.json"
    local envs=(HOME="$h" USERPROFILE="$(native "$h")" AITOOLS_LOG_DIR="$(native "$h/logs")")
    if $IS_WINDOWS; then
        env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE "${envs[@]}" \
            pwsh -NoProfile -NonInteractive -File "$(native "$TMP_ROOT/aitools/scripts/check-pre-push.ps1")" < /dev/null > "$TMP_ROOT/out" 2>&1
    else
        env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE "${envs[@]}" \
            bash "$TMP_ROOT/aitools/scripts/check-pre-push.sh" < /dev/null > "$TMP_ROOT/out" 2>&1
    fi
    # The step 7 result line, without colour codes
    perl -ne 's/\e\[[0-9;]*m//g; print if /^\s*7\. deploy\/ matches source/' "$TMP_ROOT/out" > "$TMP_ROOT/step7"
}

mk_dot "$TMP_ROOT/dot-untracked"
run_step7 "$TMP_ROOT/dot-untracked"
check "untracked deploy/: step 7 PASS, comparison skipped" \
    "grep -q '\[PASS\] fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean' '$TMP_ROOT/step7'"
check "untracked deploy/: the fixture dotprofile is left clean (deploy/ built there is ignored)" \
    "[ -z \"\$(git -C '$TMP_ROOT/dot-untracked' status --porcelain)\" ]"

mk_dot "$TMP_ROOT/dot-stale" with-deploy
run_step7 "$TMP_ROOT/dot-stale"
check "committed deploy/ that differs from a fresh build: step 7 FAIL, stale" \
    "grep -q '\[FAIL\] dotprofile deploy/ is stale' '$TMP_ROOT/step7'"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
