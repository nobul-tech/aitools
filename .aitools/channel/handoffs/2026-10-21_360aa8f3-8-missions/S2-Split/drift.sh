#!/usr/bin/env bash
# drift.sh -- compare shared/skills source vs deployed ~/.claude/skills and ~/.cursor/skills (read-only)
set -euo pipefail
src=/Users/new-jose/repos/aitools/shared/skills
for d in "$src"/*/; do
  n=$(basename "$d")
  for dest in "$HOME/.claude/skills" "$HOME/.cursor/skills"; do
    if [ ! -f "$dest/$n/SKILL.md" ]; then
      echo "NOT-DEPLOYED $dest/$n"
    elif ! diff -q "$d/SKILL.md" "$dest/$n/SKILL.md" > /dev/null; then
      echo "STALE        $dest/$n"
    else
      echo "CURRENT      $dest/$n"
    fi
  done
done
echo "--- deployed rules"
ls -la "$HOME/.claude/rules"
echo "--- does ~/.claude/CLAUDE.md mention delegate rule"
grep -c "delegation.md" "$HOME/.claude/CLAUDE.md" || echo "0 matches"
echo "--- dotprofile deploy dir"
ls /Users/new-jose/repos/aitools-nobul-jose/deploy | head -40
echo "--- last-deploy timestamps of hooks"
ls -la "$HOME/.claude/hooks" | head -40
