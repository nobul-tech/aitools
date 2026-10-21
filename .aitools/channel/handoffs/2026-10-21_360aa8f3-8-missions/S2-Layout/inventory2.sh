#!/usr/bin/env bash
# S2-Layout inventory part 2 (read-only). No pipefail so ls misses don't abort.
set -uo pipefail
A=/Users/new-jose/repos/aitools
D=/Users/new-jose/repos/aitools-nobul-jose
echo "=== .aitools project"
find "$A/.aitools" -maxdepth 2 -not -path '*/channel/session-*' | sort | head -60
echo "=== harvesting count"
ls "$A/harvesting" | wc -l
ls -d "$A/.aitools/harvesting"
echo "=== dotprofile tree"
find "$D" -maxdepth 3 -not -path '*/.git/*' -not -path '*/deploy/*' -not -path '*/sessions/*' | sort | head -150
echo "=== dotprofile deploy list"
ls "$D/deploy"
echo "=== ~/.claude"
ls -la /Users/new-jose/.claude
echo "=== ~/.claude/skills"
ls -la /Users/new-jose/.claude/skills
echo "=== ~/.claude/rules"
ls -la /Users/new-jose/.claude/rules
echo "=== ~/.claude/hooks"
ls /Users/new-jose/.claude/hooks
echo "=== ~/.cursor/skills"
ls -la /Users/new-jose/.cursor/skills
echo "=== ~/.cursor/rules"
ls -la /Users/new-jose/.cursor/rules
echo "=== ~/.aitools"
find /Users/new-jose/.aitools -maxdepth 2 -not -path '*/logs/*' -not -path '*/deploy-state/*' | sort | head -60
echo "=== config.json"
cat /Users/new-jose/.aitools/config.json
echo "=== drift: shared/skills vs ~/.claude/skills vs ~/.cursor/skills"
for s in "$A"/shared/skills/*/; do
  n=$(basename "$s")
  a="SAME"; c="SAME"
  if [ ! -f "/Users/new-jose/.claude/skills/$n/SKILL.md" ]; then a="ABSENT"; elif ! cmp -s "$s/SKILL.md" "/Users/new-jose/.claude/skills/$n/SKILL.md"; then a="DIFF"; fi
  if [ ! -f "/Users/new-jose/.cursor/skills/$n/SKILL.md" ]; then c="ABSENT"; elif ! cmp -s "$s/SKILL.md" "/Users/new-jose/.cursor/skills/$n/SKILL.md"; then c="DIFF"; fi
  echo "$n claude=$a cursor=$c"
done
echo "=== drift: dotprofile claude/rules vs ~/.claude/rules"
for r in "$D"/claude/rules/*.md; do
  n=$(basename "$r")
  if [ ! -f "/Users/new-jose/.claude/rules/$n" ]; then echo "$n ABSENT"; elif cmp -s "$r" "/Users/new-jose/.claude/rules/$n"; then echo "$n SAME"; else echo "$n DIFF"; fi
done
echo "=== drift: shared/hooks vs ~/.claude/hooks"
for h in "$A"/shared/hooks/*; do
  n=$(basename "$h")
  if [ ! -f "/Users/new-jose/.claude/hooks/$n" ]; then echo "$n ABSENT"; elif cmp -s "$h" "/Users/new-jose/.claude/hooks/$n"; then echo "$n SAME"; else echo "$n DIFF"; fi
done
echo "=== dotprofile claude/hooks overrides"
ls "$D/claude/hooks"
echo "=== dotprofile deploy embeds which skills?"
grep -o 'skills/[a-z0-9-]*/SKILL.md' "$D/deploy/setup-user-skills.sh" | sort -u
echo "=== registry files in deploy?"
grep -l 'registries/' "$D"/deploy/*
echo "=== git log for shared/skills untracked copies? last commit on main"
git -C "$A" log --oneline -3
