#!/usr/bin/env bash
# count the Manifest draft OLD bullet in both files of the export
set -euo pipefail
T=/Users/new-jose/repos/aitools/.scratch/session-rcbar/tree
A='- **Rules**: additive deploy from `<userRepoPath>/claude/rules/` — managed files updated, unmanaged files in target preserved'
for f in .claude/rules/managed-file-deployment.md .cursor/rules/managed-file-deployment.mdc; do
  printf '%s: ' "$f"
  grep -c -F -- "$A" "$T/$f" || printf '(none)\n'
done
printf '%s\n' "== mdc content sources table"
grep -n "^|" "$T/.cursor/rules/managed-file-deployment.mdc" || printf '(none)\n'
