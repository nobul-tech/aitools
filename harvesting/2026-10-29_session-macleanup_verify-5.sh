#!/usr/bin/env bash
# verify-5.sh -- regions for #22 #24 #31 (read-only)
set -euo pipefail
R=/Users/new-jose/repos/aitools
s() { git -C "$R" show "origin/main:$1"; }
printf -- '--- aitools 2066-2090\n'; s scripts/aitools | sed -n '2066,2090p'
printf -- '--- aitools.ps1 1960-1990\n'; s scripts/aitools.ps1 | sed -n '1960,1990p'
printf -- '--- repair_uv_tool_env\n'; git -C "$R" grep -nE "repair_uv_tool_env|Repair-UvToolEnv" origin/main -- scripts | head
printf -- '--- sync_managed_json create path\n'
git -C "$R" grep -nE "^sync_managed_json\(\)|^function Sync-ManagedJson" origin/main -- scripts/aitools-lib.sh scripts/aitools-lib.ps1
git -C "$R" grep -nE "SYNC_MANAGED_RESULT=\"?created|SyncManagedResult = \"created|return \"created\"" origin/main -- scripts/aitools-lib.sh scripts/aitools-lib.ps1 | head
printf -- '--- setup-user-settings.sh 76-92\n'; s scripts/setup-user-settings.sh | sed -n '76,92p'
printf -- '--- setup-user-settings.ps1 created\n'; git -C "$R" grep -nE "created|missing settings" origin/main -- scripts/setup-user-settings.ps1 | head
printf -- '--- tests for created settings\n'; git -C "$R" grep -nlE "settings.json" origin/main -- tests | head
printf -- '--- commit that added missing-settings create\n'
git -C "$R" log origin/main --format='%h %ad %s' --date=short -S"A missing settings.json is not skipped" -- scripts/setup-user-settings.sh | tail -2
printf -- '--- commit setup-rust exit code (C-F2)\n'
git -C "$R" log origin/main --format='%h %ad %s' --date=short -S"rustup-update: " -- scripts/setup-rust.sh | tail -2
