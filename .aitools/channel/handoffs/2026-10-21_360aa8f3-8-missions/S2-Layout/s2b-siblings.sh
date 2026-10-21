#!/usr/bin/env bash
# S2-Layout-B: grep sibling mission drafts for new/moved paths and registry/skill location assumptions
set -euo pipefail
M=/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions
OUT=$M/S2-Layout/s2b-siblings.out
: > "$OUT"
for d in S5-Tools S5-Profile S4-Review; do
  echo "##### $d new-path patterns" >> "$OUT"
  grep -rnIE "generated/tool-specs|gen-tool-specs|tool-adopt/|aitools-profile\.js|setup-user-config\.|schemaVersion|schema 1\.1|\(new\)|new file|reference/tool-support-decision-tree|framework-tool-lifecycle|deploy/setup-user-config|toolExceptions" "$M/$d" \
    --include=*.md --include=*.json --include=*.diff --include=*.txt \
    --exclude-dir=tests | cut -c1-260 | head -150 >> "$OUT" || true
  echo "##### $d registry/skill location assumptions" >> "$OUT"
  grep -rnIE "registries/[a-z-]+\.json|reference/[a-z-]+\.json|\.claude/skills/|shared/skills/|~/\.claude/skills" "$M/$d" \
    --include=*.md --include=*.json --include=*.diff --include=*.txt --include=*.js --include=*.sh --include=*.ps1 \
    --exclude-dir=tests | cut -c1-260 | head -200 >> "$OUT" || true
done
wc -l "$OUT"
