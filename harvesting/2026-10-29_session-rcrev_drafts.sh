#!/usr/bin/env bash
# Show the cited phrases inside the Manifest and MDM drafts (read-only).
set -euo pipefail
R=/Users/new-jose/repos/aitools
M=.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-Manifest/S3-H2-Manifest-drafts
for f in dot-claude/rules/managed-file-deployment.md reference/harness.md reference/managed-file-deployment.md; do
  echo "=== #110 $f"
  git -C "$R" show "origin/feature/harness-cursor-user-rules:$M/$f" | grep -n -i "fan-out consumers\|setup-user-claude" || echo "(no hit)"
  echo "--- same on #111? "
  git -C "$R" show "origin/feature/harness-cursor-user-rules:$M/$f" > /tmp/rcrev-a.txt
  git -C "$R" show "origin/feature/harness-mdm-followups:$M/$f" > /tmp/rcrev-b.txt
  git -C "$R" show "origin/feature/harness-rules-manifest:$M/$f" > /tmp/rcrev-c.txt
  cmp -s /tmp/rcrev-a.txt /tmp/rcrev-b.txt && echo "110==111" || echo "110!=111"
  cmp -s /tmp/rcrev-a.txt /tmp/rcrev-c.txt && echo "110==100" || echo "110!=100"
done
echo "=== MDM harness draft"
git -C "$R" show "origin/feature/harness-mdm-followups:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-MDM/S3-H2-MDM-drafts/reference/harness.md.edit.txt" | head -40
