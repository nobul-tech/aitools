#!/usr/bin/env bash
# prfiles.sh - list files each open PR branch changes vs origin/main (merge-base), read-only
set -euo pipefail
REPO=/Users/new-jose/repos/aitools
OUT=/Users/new-jose/repos/aitools/.scratch/session-rcdocs/prfiles.txt
: > "$OUT"
for b in docs/harness-approved-drafts feature/harness-rules-manifest docs/m3-approved-drafts feature/harness-hookin feature/harness-cursor-user-rules feature/harness-mdm-followups; do
  printf '=== %s\n' "$b" >> "$OUT"
  git -C "$REPO" diff --stat=200 "origin/main...origin/$b" -- . ':!.aitools/channel/handoffs' >> "$OUT"
done
wc -l "$OUT"
