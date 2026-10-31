#!/usr/bin/env bash
# test-pathrefs.sh -- apply edits-pathrefs.txt to a copy of a committed
# origin/main export, run the probe fixture and the full-tree check.
# Usage: test-pathrefs.sh <committed export dir> [edits file]
set -uo pipefail
BASE="$1"
D=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile
EDITS="${2:-$D/S3-Reconcile-Fix-drafts/checks/edits-pathrefs.txt}"
OUT="$(mktemp -d)"
cp -R "$BASE/." "$OUT/"
perl "$D/S3-Reconcile-Code-drafts/apply.pl" "$EDITS" "$BASE" "$OUT"
printf 'apply rc=%s\n' "$?"
python3 -m py_compile "$OUT/scripts/check-path-refs.py"
printf 'py_compile rc=%s\n' "$?"
printf -- '--- probe fixture\n'
bash /Users/new-jose/repos/aitools/.scratch/session-rcfixk/probe-pathrefs.sh "$OUT/scripts/check-path-refs.py"
printf -- '--- full tree (origin/main)\n'
python3 "$OUT/scripts/check-path-refs.py" --root "$OUT"
printf 'rc=%s\n' "$?"
