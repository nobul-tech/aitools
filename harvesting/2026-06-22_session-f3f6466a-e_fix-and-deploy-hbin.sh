#!/usr/bin/env bash
set -uo pipefail
REPO="/Users/new-jose/repos/aitools"

echo "== bash -n aitools-install.sh =="
if bash -n "$REPO/scripts/aitools-install.sh"; then echo "OK"; else echo "FAIL"; fi

echo "== powershell parse aitools-install.ps1 =="
pwsh -NoProfile -Command '$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("'"$REPO"'/scripts/aitools-install.ps1",[ref]$null,[ref]$e); if($e){$e|ForEach-Object{Write-Output ("FAIL " + $_.Message)}}else{Write-Output "OK"}'

echo "== running the new deploy block (real) =="
source "$REPO/scripts/aitools-lib.sh"
logging_init "fix-hbin"
SCRIPT_DIR="$REPO/scripts"
AITOOLS_BIN="$HOME/.aitools/bin"
mkdir -p "$AITOOLS_BIN"
_hbin_deployed=0
for _hcli in harness-db.py read-session.py read-session-full.py; do
    _src="$SCRIPT_DIR/$_hcli"
    _dst="$AITOOLS_BIN/$_hcli"
    if [ ! -f "$_src" ]; then
        log_warn "$_hcli not found at $(display_path "$_src") (MDM deploy — skipping)"
        continue
    fi
    if [ -f "$_dst" ] && diff -q "$_src" "$_dst" >/dev/null 2>&1; then
        echo "  $_hcli: identical, skipped"
        continue
    fi
    if [ -f "$_dst" ]; then
        backup_file "$_dst"
        diff -u "$_dst" "$_src" >> "$LOG_FILE" 2>/dev/null || true
    fi
    cp "$_src" "$_dst"
    echo "  $_hcli: deployed"
    _hbin_deployed=$((_hbin_deployed + 1))
done
echo "deployed=$_hbin_deployed"

echo "== verify deployed harness-db.py =="
grep -n "SCHEMA_VERSION = " "$AITOOLS_BIN/harness-db.py" | head -1
echo "backups:"
ls -1 "$AITOOLS_BIN"/harness-db.py.bak.* 2>/dev/null | wc -l | tr -d ' '
