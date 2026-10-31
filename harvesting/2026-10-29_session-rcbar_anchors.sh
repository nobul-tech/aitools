#!/usr/bin/env bash
# count R2a anchors in the export tree
set -euo pipefail
T=/Users/new-jose/repos/aitools/.scratch/session-rcbar/tree
A1='Rules reach the tools through the `setup-user-claude` / `setup-user-cursor` fan-out.'
A3='CLAUDE.md template, user rules, profile.json ('
for f in .claude/rules/managed-file-deployment.md .cursor/rules/managed-file-deployment.mdc; do
  printf '%s\n' "== $f"
  printf 'A1 count: '
  grep -c -F "$A1" "$T/$f" || printf '(none)\n'
  printf 'A3 count: '
  grep -c -F "$A3" "$T/$f" || printf '(none)\n'
  printf 'fan-out count: '
  grep -c "fan-out" "$T/$f" || printf '(none)\n'
done
printf '%s\n' "== mdc Rules bullets / deploy-harness mentions"
grep -n -i "rules\*\*\|^- \*\*Rules\|deploy-harness\|~/.aitools" "$T/.cursor/rules/managed-file-deployment.mdc" || printf '(none)\n'
