#!/usr/bin/env bash
# dump-mdc.sh - print every .cursor/rules/*.mdc on origin/main with line numbers (read-only)
set -euo pipefail
REPO=/Users/new-jose/repos/aitools
OUT=/Users/new-jose/repos/aitools/.scratch/session-rcdocs/mdc-dump.txt
: > "$OUT"
for f in agentic-standards config-file-safety cross-platform deploy-paths documentation-standards git-safety hook-rollout interactive-menus managed-file-deployment plan-execution relay-outbound script-standards smoke-test-pattern sources-of-truth tool-lifecycle web-sources general; do
  printf '\n######## %s.mdc\n' "$f" >> "$OUT"
  git -C "$REPO" show "origin/main:.cursor/rules/$f.mdc" | perl -ne 'printf "%4d  %s", $., $_' >> "$OUT"
done
wc -l "$OUT"
