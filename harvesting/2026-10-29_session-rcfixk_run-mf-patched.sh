#!/usr/bin/env bash
# run-mf-patched.sh -- tests/managed-files (bash) on an origin/main export
# with a patched scripts/aitools-lib.sh (arg 1), isolated HOME, outside the repo.
set -uo pipefail
REPO=/Users/new-jose/repos/aitools
LIB="$1"
EXP="$(mktemp -d)"
git -C "$REPO" archive origin/main | tar -x -C "$EXP"
cp "$LIB" "$EXP/scripts/aitools-lib.sh"
git -C "$EXP" init -q
git -C "$EXP" add -A
git -C "$EXP" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit -q -m export
FAKEHOME="$(mktemp -d)"
( cd "$EXP" && HOME="$FAKEHOME" bash tests/managed-files/test-managed-files.sh ) > "$REPO/.scratch/session-rcfixk/mf-patched.log" 2>&1
printf 'rc=%s\n' "$?"
grep -E '^(FAIL|SKIP)|passed|merge & adopt' "$REPO/.scratch/session-rcfixk/mf-patched.log"
