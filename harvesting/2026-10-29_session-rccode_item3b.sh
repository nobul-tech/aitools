#!/usr/bin/env bash
# Item 3: where the JSON-field menu abort text sits on each lib-touching branch
set -euo pipefail
R=/Users/new-jose/repos/aitools
for ref in origin/main origin/feature/harness-hookin origin/fix/mf-dotprofile-adopt-push origin/fix/mf-audit-claude-build origin/fix/mf-lib-runner-result origin/fix/mf-lib-relay origin/fix/mf-installer-relay; do
  echo "== $ref"
  git -C "$R" show "$ref:scripts/aitools-lib.sh" | grep -n -E "stop the run|abort \(x\) is global" || echo "  sh: none"
  git -C "$R" show "$ref:scripts/aitools-lib.ps1" | grep -n -E "stop the run|abort \(x\) exits" | tr -d '\r' || echo "  ps1: none"
done
echo "== hunks of lib-touching PRs near prompt_json_field_review (sh)"
for b in fix/mf-dotprofile-adopt-push fix/mf-audit-claude-build fix/mf-installer-relay; do
  echo "-- $b"
  git -C "$R" diff origin/main...origin/$b -- scripts/aitools-lib.sh | grep -E '^@@' || true
done
