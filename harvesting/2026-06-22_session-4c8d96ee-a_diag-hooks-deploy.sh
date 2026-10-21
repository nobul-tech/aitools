#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools

echo "=== trailing-newline check for every manifest hook + deploy helper ==="
files=$(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync("shared/hooks/hooks-manifest.json","utf8"));console.log([...m.hooks.map(h=>h.file),...((m.deploy)||[])].join("\n"))')
for f in $files; do
  src=""
  [ -f "shared/hooks/$f" ] && src="shared/hooks/$f"
  [ -z "$src" ] && [ -f "scripts/$f" ] && src="scripts/$f"
  if [ -z "$src" ]; then echo "MISSING SOURCE: $f"; continue; fi
  last=$(tail -c1 "$src" | od -An -c | tr -d ' ')
  if [ "$last" = '\n' ]; then nl="OK-newline"; else nl="NO-TRAILING-NEWLINE"; fi
  echo "  $nl  $src"
done

echo ""
echo "=== git status of dotprofile deploy/setup-user-hooks.sh (is the break new?) ==="
URP=$(grep -o '"userRepoPath"[^,}]*' "$HOME/.aitools/config.json" | head -1 | sed 's/.*: *"//; s/"$//')
cd "$URP"
git log --oneline -1 -- deploy/setup-user-hooks.sh 2>/dev/null || true
echo "--- show the embedded harness-db-sessionstart heredoc open/close lines in current generated file ---"
grep -nE "__EMB_HARNESS_DB_SESSIONSTART_SH__" deploy/setup-user-hooks.sh | head