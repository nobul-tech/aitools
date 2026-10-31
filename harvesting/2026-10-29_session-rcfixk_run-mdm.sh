#!/usr/bin/env bash
# run-mdm.sh -- rerun tests/deploy-harness-mdm on a COMMITTED export of
# origin/main (outside the repo), isolated HOME. Arg 1: optional ref.
set -uo pipefail
REPO=/Users/new-jose/repos/aitools
REF="${1:-origin/main}"
EXP="$(mktemp -d)"
OUTDIR="$REPO/.scratch/session-rcfixk"
git -C "$REPO" archive "$REF" | tar -x -C "$EXP"
git -C "$EXP" init -q
git -C "$EXP" add -A
git -C "$EXP" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit -q -m export
printf 'export: %s (%s)\n' "$EXP" "$REF"
FAKEHOME="$(mktemp -d)"
( cd "$EXP" && HOME="$FAKEHOME" bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh ) > "$OUTDIR/mdm-committed.log" 2>&1
printf 'rc=%s\n' "$?"
grep -E '^(FAIL|SKIP)|passed,' "$OUTDIR/mdm-committed.log"
