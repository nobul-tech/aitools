#!/usr/bin/env bash
# Second round of citation spot checks (scratch, read-only).
set -uo pipefail
S=/Users/new-jose/repos/aitools/scripts
chk() { printf '\n=== %s\n' "$1"; shift; "$@" 2>&1 | head -n 14; }
chk "mcp remove then add sh 119-145" grep -n 'claude mcp remove\|claude mcp add' $S/setup-user-mcp.sh
chk "skills SKILL.md only 124" grep -n 'SKILL.md' $S/setup-user-skills.sh
chk "lib ps1 New-Item 569" grep -n 'New-Item' $S/aitools-lib.ps1
chk "DH bin not gated 266-272" grep -n 'harness-db.py\|read-session' $S/deploy-harness.sh
chk "longpaths ps1 219-239" grep -n 'LongPathsEnabled' $S/aitools-install.ps1
chk "perl linux verify 87-106" grep -n 'apt-get\|ACTION' $S/setup-perl.sh
chk "rust msvc 66-85" grep -n 'BuildTools' $S/setup-rust.ps1
chk "claude scutil 99-103" grep -n 'scutil' $S/setup-user-claude.sh
chk "hooks includes(hookId)" grep -n 'includes(hookId)\|includes(' $S/setup-user-hooks.sh
chk "settings sync_managed_json profile" grep -n 'sync_managed_json' $S/setup-user-settings.sh
chk "aitools-install.ps1 git config longpaths 242" grep -n 'git config --global' $S/aitools-install.ps1
chk "bootstrap.ps1 UserInteractive" grep -n 'UserInteractive' $S/bootstrap.ps1
chk "bootstrap.sh -t 0" grep -n '\[ -t 0 \]' $S/bootstrap.sh
chk "install winget pwsh sh 96-116" grep -n 'Microsoft.PowerShell' $S/aitools-install.sh
chk "cimcp ps1 node exit 37-39" grep -n -A2 'Get-Command node' $S/setup-cursor-ide-mcp.ps1
chk "lib env warn text 675" grep -n 'valid: local' $S/aitools-lib.sh $S/aitools-lib.ps1
chk "deploy.jsonl jsonl_record" grep -n 'deploy.jsonl' $S/aitools-lib.sh
