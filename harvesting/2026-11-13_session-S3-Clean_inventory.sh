#!/usr/bin/env bash
# Inventory references to deleted/moved artifacts (tracked + relevant untracked files).
# Usage: inventory.sh [outfile]
set -euo pipefail
cd /Users/new-jose/repos/aitools
out="${1:-/Users/new-jose/repos/aitools/.scratch/session-S3-Clean/inventory.txt}"
terms='sources-of-truth|/audit\b|audit skill|\.claude/skills/audit|relay-outbound|artifact-harvesting|framework-artifact-harvesting|shared/skills/frameworks|shared/skills/glossary|shared/skills/incident|skills/audit'
: > "$out"
git ls-files -z | xargs -0 grep -nIE "$terms" 2>/dev/null \
  | grep -vE '^(RELEASE_NOTES\.md|harvesting/|\.aitools/channel/(handoffs/|session-|[0-9a-f]{8}-)|reference/do-what-feels-right\.md|reference/claude-code-effectiveness\.md|deploy/)' \
  >> "$out" || true
# count per file
cut -d: -f1 "$out" | sort | uniq -c | sort -rn
