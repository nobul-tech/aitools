#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools
pass=0; fail=0
echo "=== bash -n on edited bash sources ==="
for f in scripts/aitools scripts/aitools-install.sh scripts/build-deploy.sh scripts/setup-user-mcp.sh scripts/setup-user-hooks.sh scripts/setup-user-settings.sh scripts/aitools-lib.sh; do
  if bash -n "$f" 2>/dev/null; then echo "OK $f"; pass=$((pass+1)); else echo "FAIL $f"; bash -n "$f"; fail=$((fail+1)); fi
done
echo ""
echo "=== pwsh parse on edited ps1 sources ==="
for f in scripts/aitools.ps1 scripts/aitools-install.ps1 scripts/setup-user-mcp.ps1 scripts/setup-user-hooks.ps1 scripts/setup-user-settings.ps1 scripts/aitools-lib.ps1; do
  if pwsh -NoProfile -Command "\$e=\$null;\$null=[System.Management.Automation.Language.Parser]::ParseFile('$f',[ref]\$null,[ref]\$e);if(\$e){\$e;exit 1}" 2>/dev/null; then echo "OK $f"; pass=$((pass+1)); else echo "FAIL $f"; fail=$((fail+1)); fi
done
echo ""
echo "=== RESULTS: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]