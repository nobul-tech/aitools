#!/usr/bin/env bash
# run-probe-eof.sh -- the EOF case of probe-relay.ps1 alone, stderr shown
set -uo pipefail
S="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib/.scratch/session-M5-L2"
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
rm -rf "$S/plogs"; mkdir -p "$S/plogs"
AITOOLS_LOG_DIR="$S/plogs" pwsh -NoProfile -ExecutionPolicy Bypass -File "$S/probe-relay.ps1" -Relay "$WT/scripts/relay-outbound-prompt.ps1" -InputText "" < /dev/null > "$S/eof-out.txt" 2>&1
echo "rc=$?"
od -c "$S/eof-out.txt" | head -40
