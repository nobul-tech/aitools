#!/usr/bin/env bash
# anchors-all.sh -- check every checks draft's OLD anchors on origin/main.
set -uo pipefail
D=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Fix-drafts/checks
for f in "$D"/edits-*.txt; do
    printf '%s: ' "$(basename "$f")"
    perl /Users/new-jose/repos/aitools/.scratch/session-rcfixk/old-on-branches.pl "$f" origin/main
done
git -C /Users/new-jose/repos/aitools rev-parse --short origin/main
