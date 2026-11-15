#!/usr/bin/env bash
# List files that reference the /harvest skill (skill-name mentions or its SKILL.md path).
set -euo pipefail
cd /Users/new-jose/repos/aitools
git ls-files -co --exclude-standard \
  | grep -vE '^(harvesting/|\.scratch/|\.aitools/channel/handoffs/|sessions/)' \
  | grep -vE '\.(jsonl|tar|zip|db)$' \
  | while IFS= read -r f; do
      [ -f "$f" ] || continue
      n=$(perl -ne '$c++ if /`\/harvest(\s+\w+)?`|skills\/harvest\b|\/harvest skill|harvest\s+skill/; END { print $c+0 }' "$f")
      if [ "$n" -gt 0 ]; then printf '%4d  %s\n' "$n" "$f"; fi
    done | sort -k2
