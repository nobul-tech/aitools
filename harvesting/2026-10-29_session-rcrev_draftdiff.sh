#!/usr/bin/env bash
# Diff the Manifest full-file drafts against origin/main and #101 versions (stat only).
set -euo pipefail
R=/Users/new-jose/repos/aitools
M=.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-Manifest/S3-H2-Manifest-drafts
T=/Users/new-jose/repos/aitools/.scratch/session-rcrev/dd
mkdir -p "$T"
for pair in "dot-claude/rules/managed-file-deployment.md:.claude/rules/managed-file-deployment.md" "reference/harness.md:reference/harness.md" "reference/managed-file-deployment.md:reference/managed-file-deployment.md"; do
  d=${pair%%:*}
  f=${pair#*:}
  n=$(echo "$f" | tr '/' '_')
  git -C "$R" show "origin/feature/harness-cursor-user-rules:$M/$d" > "$T/draft_$n"
  git -C "$R" show "origin/main:$f" > "$T/main_$n"
  git -C "$R" show "origin/docs/m3-approved-drafts:$f" > "$T/pr101_$n"
  echo "=== $f: draft vs main"
  diff "$T/main_$n" "$T/draft_$n" | grep -c "^[<>]" || true
  echo "=== $f: draft vs #101"
  diff "$T/pr101_$n" "$T/draft_$n" | grep -c "^[<>]" || true
  wc -l "$T/draft_$n" "$T/main_$n"
done
