#!/usr/bin/env bash
# cmp-issue9.sh -- compare the detached worktree's uncommitted diff with the
# preserved recon/local-issue9.patch before deleting the worktree.
set -euo pipefail
WT="/Users/new-jose/repos/aitools/.claude/worktrees/wf_4ae752d8-def-5"
OUT="/Users/new-jose/repos/aitools/.scratch/session-10cf255a-c/wf4ae-diff.patch"
PRES="/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions/recon/local-issue9.patch"
git -C "$WT" diff > "$OUT"
echo "worktree diff lines: $(wc -l < "$OUT")"
if [ -f "$PRES" ]; then
    echo "preserved patch lines: $(wc -l < "$PRES")"
    if cmp -s "$OUT" "$PRES"; then
        echo "IDENTICAL"
    else
        echo "DIFFERENT -- changed-line comparison (ignoring index/hunk headers):"
        diff <(grep -E '^[+-][^+-]' "$OUT") <(grep -E '^[+-][^+-]' "$PRES") > /dev/null && echo "same +/- lines" || echo "+/- lines differ"
    fi
else
    echo "preserved patch not found at $PRES"
fi
