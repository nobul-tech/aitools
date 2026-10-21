#!/usr/bin/env bash
set -euo pipefail
cd /Users/new-jose/repos/aitools

echo "=== json/field-level review / adopt functions in aitools-lib.sh ==="
grep -niE 'deploy_managed_json|managed_json|field.?level|review.*json|json.*review|deploy_json|json_config_review|adopt_managed' scripts/aitools-lib.sh || echo "(none)"
echo ""
echo "=== same in aitools-lib.ps1 ==="
grep -niE 'Deploy-ManagedJson|ManagedJson|field.?level|review.*json|json.*review|Deploy-Json|JsonConfigReview|Adopt-Managed' scripts/aitools-lib.ps1 || echo "(none)"
echo ""
echo "=== '[a]dopt' / overwrite/skip/abort menu strings across setup + lib ==="
grep -rniE '\[a\]dopt|\[o\]verwrite|\[s\]kip|\[x\]abort|local values win|proposed values win' scripts/*.sh scripts/*.ps1 | head -40 || echo "(none)"
echo ""
echo "=== deploy_managed_file definition + signature in aitools-lib.sh ==="
grep -nE '^deploy_managed_file|^adopt_managed_file|^deploy_tracker|MANAGED_FILE_RESULT' scripts/aitools-lib.sh | head -30
echo ""
echo "=== build-deploy.sh: where settings.json merge templates live ==="
grep -nE 'setup-user-hooks|setup-user-mcp|sortKeys|SORT_KEYS|settings.json|Section 11|Section 12|Section 13|Section 14' scripts/build-deploy.sh | head -40