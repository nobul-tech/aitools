#!/usr/bin/env bash
set -uo pipefail
REPO="/Users/new-jose/repos/aitools"
echo "== bash -n =="
for f in \
  shared/hooks/harness-db-sessionstart.sh \
  shared/hooks/harness-db-sessionend.sh \
  shared/hooks/scratch-init.sh \
  scripts/aitools-install.sh; do
  if bash -n "$REPO/$f" 2>/tmp/bn.err; then
    echo "OK   $f"
  else
    echo "FAIL $f"; cat /tmp/bn.err
  fi
done

echo "== python ast =="
python3 -c "import ast,sys; ast.parse(open('$REPO/scripts/harness-db.py').read()); print('OK   scripts/harness-db.py')"

echo "== powershell parse =="
pwsh -NoProfile -Command '$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("'"$REPO"'/scripts/aitools-install.ps1",[ref]$null,[ref]$e); if($e){$e|ForEach-Object{Write-Output ("FAIL " + $_.Message)}}else{Write-Output "OK   scripts/aitools-install.ps1"}'
