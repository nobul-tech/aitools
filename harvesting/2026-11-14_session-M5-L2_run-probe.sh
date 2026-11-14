#!/usr/bin/env bash
# run-probe.sh -- run probe-relay.ps1 under pwsh 7 and Windows PowerShell 5.1, hh path and lib-loaded path
set -uo pipefail
S="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib/.scratch/session-M5-L2"
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
RELAY="$WT/scripts/relay-outbound-prompt.ps1"
LIB="$WT/scripts/aitools-lib.ps1"
for exe in pwsh powershell.exe; do
    for inp in 'x\n\nShow\n' 'q\n' ''; do
        rm -rf "$S/plogs"; mkdir -p "$S/plogs" "$S/phome"
        echo "=== $exe hh-path input=[$inp]"
        AITOOLS_LOG_DIR="$S/plogs" "$exe" -NoProfile -ExecutionPolicy Bypass -File "$S/probe-relay.ps1" -Relay "$RELAY" -InputText "$inp" < /dev/null
        echo "rc=$?"
        echo "--- log:"; cat "$S/plogs/deploy.log" 2>/dev/null | grep -E "menu answer|warn" || echo "(no log lines)"
    done
    echo "=== $exe hh-path, 5.1-like: no AITOOLS_LOG_DIR, isolated HOME"
    rm -rf "$S/phome"; mkdir -p "$S/phome"
    env -u AITOOLS_LOG_DIR HOME="$S/phome" USERPROFILE="$(cygpath -w "$S/phome")" "$exe" -NoProfile -ExecutionPolicy Bypass -File "$S/probe-relay.ps1" -Relay "$RELAY" -InputText 'c\n' < /dev/null
    echo "rc=$?"
    find "$S/phome" -type f
    echo "=== $exe lib-loaded path input=[s]"
    rm -rf "$S/plogs"; mkdir -p "$S/plogs"
    AITOOLS_LOG_DIR="$S/plogs" "$exe" -NoProfile -ExecutionPolicy Bypass -File "$S/probe-relay.ps1" -Relay "$RELAY" -InputText 's\n' -LoadLib "$LIB" < /dev/null
    echo "rc=$?"
    echo "--- log:"; cat "$S/plogs/deploy.log" 2>/dev/null | grep -E "menu answer|warn" || echo "(no log lines)"
done
