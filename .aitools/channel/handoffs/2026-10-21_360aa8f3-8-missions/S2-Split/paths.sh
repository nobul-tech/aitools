#!/usr/bin/env bash
# paths.sh -- per-skill: frontmatter, repo-only path refs, existence of referenced paths (read-only)
set -euo pipefail
cd /Users/new-jose/repos/aitools
out=/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S2-Split/paths.txt
: > "$out"
for f in .claude/skills/*/SKILL.md shared/skills/*/SKILL.md; do
  echo "=================== $f ($(wc -l < "$f") lines)" >> "$out"
  perl -ne 'print if 1../^---$/ and $. < 15' "$f" | head -12 >> "$out"
  echo "--- repo path refs:" >> "$out"
  perl -nle 'while (/((?:registries|reference|scripts|plans|\.claude\/rules|\.claude\/skills|shared|deploy|ROADMAP\.md|RELEASE_NOTES\.md|harvesting|\.aitools\/channel)[\/A-Za-z0-9_.*<>{}-]*)/g) { print $1 }' "$f" | sort | uniq -c | sort -rn >> "$out"
  echo "--- missing referenced files (literal paths only):" >> "$out"
  for p in $(perl -nle 'while (/((?:registries|reference|scripts|plans|\.claude\/rules)\/[A-Za-z0-9_.-]+\.(?:json|md|sh|ps1|py))/g) { print $1 }' "$f" | sort -u); do
    [ -e "$p" ] || echo "MISSING $p" >> "$out"
  done
done
echo "=== diff .claude/skills vs shared/skills copies" >> "$out"
for d in .claude/skills/*; do
  n=$(basename "$d")
  if [ -d "shared/skills/$n" ]; then
    if diff -r "$d" "shared/skills/$n" > /dev/null; then echo "IDENTICAL $n" >> "$out"; else echo "DIFFERS $n" >> "$out"; fi
  fi
done
if diff .claude/rules/delegation.md /Users/new-jose/repos/aitools-nobul-jose/claude/rules/delegation.md > /dev/null; then echo "IDENTICAL delegation.md (project rule vs dotprofile)" >> "$out"; else echo "DIFFERS delegation.md" >> "$out"; fi
wc -l "$out"
