#!/usr/bin/env bash
# stack-compare.sh -- for each lower PR branch, compare the files it owns with
# the staged merge in the B5 (#95) worktree. Prints "same" or the diff stat.
set -euo pipefail
repo=/Users/new-jose/repos/aitools
b5=$repo/.claude/worktrees/m3b5
cmp_branch() {
    local label="$1" branch="$2"; shift 2
    local out
    out=$(git -C "$b5" diff --cached --stat "$branch" -- "$@")
    if [ -z "$out" ]; then
        printf '%s (%s): same\n' "$label" "$branch"
    else
        printf '%s (%s): DIFFERS\n%s\n' "$label" "$branch" "$out"
    fi
}
cmp_branch "#83 B4"  feature/m3-b4-setup-user-claude scripts/setup-user-claude.sh scripts/setup-user-claude.ps1
cmp_branch "#90 B8c" feature/m3-b8c-consumers scripts/check-lib.sh scripts/check-lib.ps1 scripts/check-post-push.sh scripts/check-post-push.ps1 scripts/ait-harvest.py
cmp_branch "#91 B8a" feature/m3-b8a-consumers scripts/setup-user-settings.sh scripts/setup-user-settings.ps1 scripts/setup-user-skills.sh
cmp_branch "#92 B8b" origin/feature/m3-b8b-consumers scripts/setup-user-cursor.sh scripts/setup-user-cursor.ps1 scripts/setup-user-skills.ps1
