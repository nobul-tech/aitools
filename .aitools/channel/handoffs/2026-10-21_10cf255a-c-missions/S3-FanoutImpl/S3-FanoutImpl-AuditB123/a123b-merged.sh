#!/usr/bin/env bash
# a123b-merged.sh -- extract the merge of PR #123 head (880749e) and PR #124 head
# (282c28b) (git merge-tree, clean) into scratch/merged: scripts/ and tests/ only.
# No worktree, no tracked file touched.
set -euo pipefail
S="/Users/new-jose/repos/aitools/.claude/worktrees/fo-aud123b/.scratch/session-a123b"
TREE="${1:?usage: a123b-merged.sh TREE}"
mkdir -p "$S/merged"
git -C /Users/new-jose/repos/aitools archive "$TREE" scripts tests | tar -x -C "$S/merged"
ls "$S/merged"
