#!/usr/bin/env bash
# Item 3: exit-2 handling sites on main and #106
set -euo pipefail
R=/Users/new-jose/repos/aitools
for ref in origin/main origin/feature/harness-hookin; do
  for f in scripts/aitools scripts/aitools.ps1 scripts/aitools-install.sh scripts/aitools-install.ps1; do
    echo "== $ref $f"
    git -C "$R" show "$ref:$f" | grep -n -E 'script failed|exit 2\)|-eq 2|= 2 \]|rc -eq 2|aborted by user|deploy_abort|Invoke-DeployAbort|validate_and_run\(\)|function Invoke-ValidatedScript|deploy_configs\(\)|function Deploy-Configs' | tr -d '\r' || echo "  (no match)"
  done
done
