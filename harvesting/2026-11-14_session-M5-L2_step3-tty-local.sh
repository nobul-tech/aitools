#!/usr/bin/env bash
# step3-tty-local.sh -- run the new step3-prompt cases of tests/profile/test-install.sh
# under Git Bash on Windows (the suite runs its bash half on macOS/Linux only).
# Extracts the harness and the case code from the suite itself, so it tests the
# committed text. Usage: bash step3-tty-local.sh [path-to-aitools-install.sh]
set -euo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
REPO_SRC="$WT"
INSTALLER="${1:-$WT/scripts/aitools-install.sh}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# A repo-shaped dir: the lib from the worktree, the installer under test
REPO="$WORK/repo"
mkdir -p "$REPO/scripts" "$REPO/tests/managed-files"
cp "$REPO_SRC/scripts/aitools-lib.sh" "$REPO/scripts/"
cp "$INSTALLER" "$REPO/scripts/aitools-install.sh"
cp "$REPO_SRC/tests/managed-files/pty-run.py" "$REPO/tests/managed-files/"
BASH_BIN=bash
LANG_RUN=sh
H="$WORK/home"
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
fresh() { rm -rf "$H"; mkdir -p "$H/.aitools/logs"; }
# harness.sh: the suite's heredoc, verbatim
perl -0777 -ne "print \$1 if /cat > \"\\\$WORK\/harness.sh\" <<'HARNESS'\n(.*?)^HARNESS\n/ms" "$REPO_SRC/tests/profile/test-install.sh" > "$WORK/harness.sh"
[ -s "$WORK/harness.sh" ] || { echo "harness not extracted"; exit 3; }
# the case code: from the "M5-Fixes item 10" comment to the end of its if/fi
perl -0777 -ne 'print $1 if /^(# M5-Fixes item 10:.*?^fi\n)/ms' "$REPO_SRC/tests/profile/test-install.sh" > "$WORK/cases.sh"
[ -s "$WORK/cases.sh" ] || { echo "cases not extracted"; exit 3; }
# shellcheck disable=SC1091
source "$WORK/cases.sh"
printf '\n%s passed, %s failed (Git Bash, local)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
