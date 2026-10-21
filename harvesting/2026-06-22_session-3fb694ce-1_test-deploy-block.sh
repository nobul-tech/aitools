#!/usr/bin/env bash
set -uo pipefail
REPO="/Users/new-jose/repos/aitools"

echo "== bash -n aitools-install.sh =="
if bash -n "$REPO/scripts/aitools-install.sh"; then echo "OK"; else echo "FAIL"; fi

echo "== powershell parse aitools-install.ps1 =="
pwsh -NoProfile -Command '$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("'"$REPO"'/scripts/aitools-install.ps1",[ref]$null,[ref]$e); if($e){$e|ForEach-Object{Write-Output ("FAIL " + $_.Message)}}else{Write-Output "OK"}'

echo "== DRY RUN of the deploy block (no writes) =="
source "$REPO/scripts/aitools-lib.sh"
logging_init "test-deploy-block"
export DRY_RUN=true
SCRIPT_DIR="$REPO/scripts"
AITOOLS_BIN="$HOME/.aitools/bin"
deploy_tracker_init
for _hcli in harness-db.py read-session.py read-session-full.py; do
    _src="$SCRIPT_DIR/$_hcli"
    if [ -f "$_src" ]; then
        _content=$(cat "$_src")
        deploy_managed_file "$_content" "$AITOOLS_BIN/$_hcli" "harness bin" "$_hcli"
        echo "  $_hcli -> result=$MANAGED_FILE_RESULT"
        deploy_tracker_record "$MANAGED_FILE_RESULT" "harness bin" "$_hcli"
    else
        echo "  $_hcli MISSING at $_src"
    fi
done
echo "tracker: added=$_DT_ADDED updated=$_DT_UPDATED verified=$_DT_VERIFIED skipped=$_DT_SKIPPED"
