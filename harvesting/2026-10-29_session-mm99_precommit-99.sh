#!/usr/bin/env bash
# precommit-99.sh -- run check-pre-commit.sh in the clean clone under an isolated HOME.
set -euo pipefail
S=/Users/new-jose/repos/aitools/.scratch/session-mm99
C=$S/export-3c4f8fefe2bb8cdcc0dc20334d7a4a82232740e4
cd "$C"
rc=0
HOME=$S/home bash scripts/check-pre-commit.sh > "$S/precommit.log" 2>&1 || rc=$?
echo "pre-commit exit: $rc"
grep -E "PASS|FAIL|WARN|SKIP" "$S/precommit.log" | tail -40
