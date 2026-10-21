#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools

echo "######## bash sync engine ########"
bash .scratch/session-4c8d96ee-a/test-sync.sh 2>&1 | tail -3
echo ""
echo "######## bash apply branches ########"
bash .scratch/session-4c8d96ee-a/test-sync-applybranches.sh 2>&1 | tail -2
echo ""
echo "######## pwsh sync engine ########"
pwsh -NoProfile -File .scratch/session-4c8d96ee-a/test-sync.ps1 2>&1 | tail -2
echo ""
echo "######## batch3 e2e (settings sync + hooks) ########"
bash .scratch/session-4c8d96ee-a/verify-batch3.sh 2>&1 | tail -2
echo ""
echo "######## live settings.json: no deny rules, keys intact ########"
node -e "const s=JSON.parse(require('fs').readFileSync(process.env.HOME+'/.claude/settings.json','utf8'));console.log('permissions:',JSON.stringify(s.permissions));console.log('model/theme/verbose kept:',s.model,s.theme,s.verbose);console.log('hooks present:', !!s.hooks)"