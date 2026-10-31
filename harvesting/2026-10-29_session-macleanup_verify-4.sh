#!/usr/bin/env bash
# verify-4.sh -- evidence for #22 #24 #25 #31 (read-only)
set -euo pipefail
R=/Users/new-jose/repos/aitools
s() { git -C "$R" show "origin/main:$1"; }
printf -- '--- #22/#24 setup-rust.sh update block\n'
s scripts/setup-rust.sh | grep -nE "RUSTUP_OUTPUT|while|log_detail|tail|rustup update" || true
printf -- '--- #22 setup-rust.ps1\n'
s scripts/setup-rust.ps1 | grep -nE "rustup update|Select-Object|LogDetail|ForEach" || true
printf -- '--- #22 scripts/aitools pull_out context\n'
s scripts/aitools | grep -nE "pull_out" || true
printf -- '--- #22 scripts/aitools.ps1 pullOut context\n'
s scripts/aitools.ps1 | grep -nE "pullOut" || true
printf -- '--- #24 repair_uv_tool_env\n'
s scripts/aitools-lib.sh | grep -nE -A14 "^repair_uv_tool_env\(\)" | grep -nE "while|&& log|if \[" || true
printf -- '--- #24 any piped while with && log\n'
git -C "$R" grep -nE "\] && log" origin/main -- scripts | head -20 || true
printf -- '--- #25 setup-user-claude could not read config\n'
git -C "$R" grep -nE "could not read config" origin/main -- scripts | head || true
printf -- '--- #25 bare echo/Write-Host in aitools push failure\n'
s scripts/aitools | grep -nE "^\s*echo .*(push|Push)" | head || true
printf -- '--- #31 setup-user-settings missing settings.json\n'
s scripts/setup-user-settings.sh | grep -nE "settings.json|! -f|not exist|creat" | head -20 || true
printf -- '--- #31 sync_managed_json missing live\n'
s scripts/aitools-lib.sh | grep -nE -A40 "^sync_managed_json\(\)" | grep -nE "\-f |exist|creat|missing" | head -20 || true
