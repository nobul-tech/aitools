#!/usr/bin/env bash
# S3-MA-RebuildVerify: independent checks of the PR #131 merge and the dotprofile rebuild.
set -euo pipefail
DP=/Users/new-jose/repos/aitools-nobul-jose
AT=/Users/new-jose/repos/aitools
TMP=/Users/new-jose/repos/aitools/.scratch/session-ma-rbver/tmp
rm -rf "$TMP"
mkdir -p "$TMP/old" "$TMP/new"

echo "== backup vs 20683a2:deploy (pre-rebuild committed tree)"
git -C "$DP" archive 20683a2 deploy | tar -x -C "$TMP/old"
if diff -rq "$TMP/old/deploy" "$DP/deploy.bak.2026-10-27T101222Z"; then echo "BACKUP_MATCHES_20683a2"; else echo "BACKUP_DIFFERS_20683a2"; fi

echo "== working deploy/ vs a7745dd:deploy"
git -C "$DP" archive a7745dd deploy | tar -x -C "$TMP/new"
if diff -rq "$TMP/new/deploy" "$DP/deploy"; then echo "WORKTREE_MATCHES_a7745dd"; else echo "WORKTREE_DIFFERS_a7745dd"; fi

echo "== leftover swap/backup dirs in dotprofile"
ls -a "$DP" | grep -E '^deploy' || echo "none"

echo "== personal paths / tokens in committed deploy"
if grep -rlE '/Users/new-jose|ghp_[A-Za-z0-9]{20,}|github_pat_' "$TMP/new/deploy"; then echo "FOUND_SENSITIVE"; else echo "NO_SENSITIVE"; fi

echo "== main checkout state"
git -C "$AT" rev-parse --abbrev-ref HEAD
git -C "$AT" rev-parse HEAD origin/main
echo "== build-deploy.sh on main equals PR head"
if git -C "$AT" diff --quiet 611396c origin/main -- scripts/build-deploy.sh tests/build-deploy/test-build-deploy-backup.sh .github/workflows/check.yml; then echo "SAME_AS_PR_HEAD"; else echo "DIFFERS_FROM_PR_HEAD"; fi

echo "== bash -n"
bash -n "$AT/scripts/build-deploy.sh"
/bin/bash -n "$AT/scripts/build-deploy.sh"
bash -n "$AT/tests/build-deploy/test-build-deploy-backup.sh"
echo "syntax ok"
echo "== log file present on origin/main"
git -C "$AT" cat-file -e origin/main:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MergeAll/S3-MA-Rebuild-log.md
echo "log present"
ls -l /Users/new-jose/repos/aitools/.claude/worktrees/bdbackup/.scratch/session-bdbackup/real-build.log
