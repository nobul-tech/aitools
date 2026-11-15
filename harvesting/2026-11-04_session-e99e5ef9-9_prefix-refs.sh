#!/usr/bin/env bash
# Find code that truncates session ids / scratch names to 10 (or 8) characters.
set -euo pipefail
cd /Users/new-jose/repos/aitools
git ls-files -co --exclude-standard -- scripts shared tests .claude bootstrap* \
  | grep -E '\.(sh|ps1|py|pl|js|json)$' \
  | while IFS= read -r f; do
      [ -f "$f" ] || continue
      perl -ne 'print "$ARGV:$.: $_" if /cut -c1-10|\[:10\]|\[:SCRATCH_PREFIX_LEN\]|SCRATCH_PREFIX_LEN|session_prefix|Substring\(0,\s*10\)|\.\.9\]|substr\([^)]*,\s*0,\s*10\)|slice\(0,\s*10\)|\{0,10\}|\{1,10\}|at most 10|10 char|10-char/' "$f"
    done
