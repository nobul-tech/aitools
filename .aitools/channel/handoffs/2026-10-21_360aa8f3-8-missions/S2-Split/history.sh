#!/usr/bin/env bash
# history.sh -- dump git placement history for skills/rules (read-only)
set -euo pipefail
cd /Users/new-jose/repos/aitools
out=/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S2-Split/history.txt
: > "$out"
for d in .claude/skills/* shared/skills/*; do
  [ -d "$d" ] || continue
  echo "=== $d" >> "$out"
  git log --follow --format='%h %ad %s' --date=short -- "$d/SKILL.md" >> "$out" 2>&1 || echo "(no history)" >> "$out"
done
echo "=== RENAMES touching skills" >> "$out"
git log --format='--- %h %ad %s' --date=short -M --name-status --diff-filter=RAD -- '.claude/skills' 'shared/skills' >> "$out"
echo "=== .claude/rules adds/deletes/renames" >> "$out"
git log --format='--- %h %ad %s' --date=short -M --name-status --diff-filter=RAD -- '.claude/rules' '.cursor/rules' 'shared/cursor-rules' >> "$out"
echo "=== hooks adds/deletes" >> "$out"
git log --format='--- %h %ad %s' --date=short -M --name-status --diff-filter=RAD -- 'shared/hooks' >> "$out"
wc -l "$out"
