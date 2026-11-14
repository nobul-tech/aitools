#!/usr/bin/env bash
# syntax-check.sh -- bash -n and the pwsh parser on every touched script
set -uo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/json-review"
cd "$WT" || exit 1
rc=0
for f in scripts/aitools-lib.sh scripts/deploy-harness.sh scripts/check-pre-push.sh scripts/build-deploy.sh \
         tests/managed-files/test-managed-files.sh tests/deploy-harness/test-deploy-harness.sh; do
    if bash -n "$f"; then echo "OK   bash -n $f"; else echo "FAIL bash -n $f"; rc=1; fi
done
for f in scripts/aitools-lib.ps1 scripts/deploy-harness.ps1 scripts/check-pre-push.ps1 tests/managed-files/test-managed-files.ps1; do
    out=$(pwsh -NoProfile -Command "\$e = \$null; \$null = [System.Management.Automation.Language.Parser]::ParseFile('$f', [ref]\$null, [ref]\$e); if (\$e) { \$e | ForEach-Object { \$_.ToString() }; exit 1 }")
    if [ $? -eq 0 ]; then echo "OK   pwsh parse $f"; else echo "FAIL pwsh parse $f: $out"; rc=1; fi
done
perl "C:/Users/jdpal/repos/aitools/.scratch/session-87795dc3-e9b0-4f82-937b-139b3f13fa81/node-parity.pl" "$WT" || rc=1
git diff --summary origin/main
exit $rc
