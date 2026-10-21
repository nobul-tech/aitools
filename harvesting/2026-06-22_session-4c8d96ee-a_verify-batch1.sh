#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools

echo "=== bash syntax check: setup-user-mcp.sh ==="
if bash -n scripts/setup-user-mcp.sh; then echo "OK bash parse"; else echo "FAIL bash parse"; fi

echo ""
echo "=== pwsh parse check: setup-user-mcp.ps1 ==="
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command '$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("scripts/setup-user-mcp.ps1",[ref]$null,[ref]$e); if($e){$e; exit 1} else {"OK ps1 parse"}'
else
  echo "pwsh not available -- skipping ps1 parse"
fi

echo ""
echo "=== dangling references (should be empty) in setup-user-mcp.sh ==="
grep -nE 'settings_file|settings\.json|deny|DENY|SORT_KEYS|backup_file' scripts/setup-user-mcp.sh || echo "(none)"

echo ""
echo "=== dangling references (should be empty) in setup-user-mcp.ps1 ==="
grep -nE 'settingsFile|settings\.json|deny|Deny|Normalize-Json|Backup-File|SORT_KEYS' scripts/setup-user-mcp.ps1 || echo "(none)"

echo ""
echo "=== dry-run smoke test: setup-user-mcp.sh ==="
AITOOLS_DRY_RUN=1 bash scripts/setup-user-mcp.sh --dry-run > /tmp/mcp-dryrun.log 2>&1
echo "exit: $?"
echo "--- mentions of deny/settings.json in output (should be none) ---"
grep -niE 'deny|settings\.json' /tmp/mcp-dryrun.log || echo "(none)"
echo "--- tail of dry-run log ---"
tail -6 /tmp/mcp-dryrun.log