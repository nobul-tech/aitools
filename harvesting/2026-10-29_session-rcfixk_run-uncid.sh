#!/usr/bin/env bash
# run-uncid.sh -- export origin/main (subset) into a mktemp dir outside the repo
# and run the three un-CI'd suites there. Isolated HOME per suite.
set -uo pipefail
REPO=/Users/new-jose/repos/aitools
EXP="$(mktemp -d)"
OUTDIR="$REPO/.scratch/session-rcfixk"
git -C "$REPO" archive origin/main scripts tests shared .claude reference registries | tar -x -C "$EXP"
git -C "$EXP" init -q
printf 'export: %s\n' "$EXP"
for t in tests/deploy-harness/test-deploy-harness.sh tests/deploy-harness-mdm/test-deploy-harness-mdm.sh tests/rules-fanout-cursor/test-rules-fanout-cursor.sh; do
    name="$(basename "$t" .sh)"
    FAKEHOME="$(mktemp -d)"
    ( cd "$EXP" && HOME="$FAKEHOME" bash "$t" ) > "$OUTDIR/$name.log" 2>&1
    rc=$?
    printf '%s rc=%s\n' "$name" "$rc"
    grep -E '^(FAIL|SKIP)|passed,' "$OUTDIR/$name.log"
    # also macOS /bin/bash 3.2
    ( cd "$EXP" && HOME="$FAKEHOME" /bin/bash "$t" ) > "$OUTDIR/$name-b32.log" 2>&1
    rc=$?
    printf '%s (/bin/bash 3.2) rc=%s\n' "$name" "$rc"
    grep -E '^(FAIL|SKIP)|passed,' "$OUTDIR/$name-b32.log"
done
