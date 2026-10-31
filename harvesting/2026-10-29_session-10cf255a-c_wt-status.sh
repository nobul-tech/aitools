#!/usr/bin/env bash
# wt-status.sh -- show uncommitted changes and unpushed commits for the M3 worktrees.
set -euo pipefail
for w in m3cfg m3claude m3docs m3exc m3fix m3inst m3lib m3profile; do
    p="/Users/new-jose/repos/aitools/.claude/worktrees/$w"
    [ -d "$p" ] || continue
    st=$(git -C "$p" status --porcelain | wc -l | tr -d ' ')
    ahead=$(git -C "$p" rev-list --count '@{u}..HEAD' 2>/dev/null || echo "no-upstream")
    br=$(git -C "$p" rev-parse --abbrev-ref HEAD)
    echo "$w [$br] uncommitted=$st unpushed=$ahead"
done
