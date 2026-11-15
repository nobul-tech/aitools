#!/usr/bin/env bash
# run-all-tests.sh -- run every tracked tests/**/test-* suite from the worktree,
# one log per suite in $OUT, one summary line per suite in $OUT/summary.txt.
set -uo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/json-review"
OUT="$WT/.scratch/session-M1-Ship/tests-${1:-run1}"
mkdir -p "$OUT"
: > "$OUT/summary.txt"
cd "$WT" || exit 1
git ls-files tests | grep -E '/test-[^/]*\.(sh|ps1|py)$' | while IFS= read -r t; do
    name=$(printf '%s' "$t" | tr '/' '_')
    start=$(date -u +%s)
    case "$t" in
        *.sh)  bash "$t" < /dev/null > "$OUT/$name.log" 2>&1 ;;
        *.ps1) pwsh -NoProfile -File "$t" < /dev/null > "$OUT/$name.log" 2>&1 ;;
        *.py)  python "$t" < /dev/null > "$OUT/$name.log" 2>&1 ;;
    esac
    rc=$?
    secs=$(( $(date -u +%s) - start ))
    tail_line=$(grep -E '[0-9]+ passed|passed|failed|OK|FAILED|Ran [0-9]+' "$OUT/$name.log" | tail -n 1)
    printf '%s rc=%s %ss | %s\n' "$t" "$rc" "$secs" "$tail_line" >> "$OUT/summary.txt"
done
printf 'done %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUT/summary.txt"
