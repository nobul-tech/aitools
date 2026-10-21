#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools
pass=0; fail=0

echo "=== syntax ==="
for f in scripts/aitools-lib.sh scripts/setup-user-settings.sh; do
  bash -n "$f" && echo "OK $f" || { echo "FAIL $f"; fail=$((fail+1)); }
done
for f in scripts/aitools-lib.ps1 scripts/setup-user-settings.ps1; do
  pwsh -NoProfile -Command "\$e=\$null;\$null=[System.Management.Automation.Language.Parser]::ParseFile('$f',[ref]\$null,[ref]\$e);if(\$e){\$e;exit 1}" 2>/dev/null && echo "OK $f" || { echo "FAIL $f"; fail=$((fail+1)); }
done

echo ""
echo "=== regression: bash + pwsh sync tests ==="
bash .scratch/session-4c8d96ee-a/test-sync.sh 2>&1 | tail -1
pwsh -NoProfile -File .scratch/session-4c8d96ee-a/test-sync.ps1 2>&1 | tail -1

echo ""
echo "=== live no-op run: NO new backups, no error ==="
URP="/Users/new-jose/repos/aitools-nobul-jose"
pb_before=$(ls "$URP"/profile.json.bak.* 2>/dev/null | wc -l | tr -d ' ')
sb_before=$(ls "$HOME"/.claude/settings.json.bak.* 2>/dev/null | wc -l | tr -d ' ')
bash scripts/setup-user-settings.sh < /dev/null > /tmp/noop.log 2>&1
ec=$?
pb_after=$(ls "$URP"/profile.json.bak.* 2>/dev/null | wc -l | tr -d ' ')
sb_after=$(ls "$HOME"/.claude/settings.json.bak.* 2>/dev/null | wc -l | tr -d ' ')
echo "exit: $ec"
echo "profile backups: $pb_before -> $pb_after (expect equal)"
echo "settings backups: $sb_before -> $sb_after (expect equal)"
echo "--- log ---"; cat /tmp/noop.log
grep -qiE 'integer expected|error|not defined' /tmp/noop.log && { echo "FAIL: error in log"; fail=$((fail+1)); } || echo "PASS: no errors"

echo ""
echo "=== re-run build-deploy (propagate lib changes) ==="
bash scripts/build-deploy.sh > /tmp/bd3.log 2>&1
echo "build-deploy exit: $?"

echo ""
echo "=== RESULTS: fail=$fail ==="
[ "$fail" -eq 0 ]