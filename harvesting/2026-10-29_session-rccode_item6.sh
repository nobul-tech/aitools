#!/usr/bin/env bash
# Item 6: stale step-7 text, abort-docs claims, merge interactions
set -euo pipefail
R=/Users/new-jose/repos/aitools
echo "-- step 7 trigger wording on every open branch and main"
for b in main feature/harness-hookin docs/harness-approved-drafts feature/harness-mdm-followups docs/m3-approved-drafts docs/mf-audit feature/harness-rules-manifest feature/harness-cursor-user-rules; do
  git -C "$R" grep -n -E "does not trigger it|triggers only on|deploy-relevant source|no deploy-relevant" "origin/$b" -- .claude/rules .cursor/rules reference scripts plans 2>/dev/null || true
done
echo "-- interactive-menus profile-mirror abort note on #106"
git -C "$R" show origin/feature/harness-hookin:.claude/rules/interactive-menus.md | grep -n -E "abort" || true
echo "-- check-pre-push.ps1 step 7 node check (sh has one)"
git -C "$R" show origin/main:scripts/check-pre-push.ps1 | grep -n -E "node" || echo "  ps1: no node reference"
