#!/usr/bin/env bash
# Re-run the plan's section 7 counts in several scopes, so the scope the plan used can be identified.
set -euo pipefail
cd /Users/new-jose/repos/aitools

scopes=("scripts" "scripts shared" "scripts shared tests")
for s in "${scopes[@]}"; do
    echo "== scope: $s"
    # shellcheck disable=SC2086
    w=$(grep -rnE 'write_summary +"?WARN"?|Write-Summary +"?WARN"?' $s | wc -l)
    e=$(grep -rnE 'write_summary +"?ERROR"?|Write-Summary +"?ERROR"?' $s | wc -l)
    a=$(grep -rnE 'write_summary +"?ACTION"?|Write-Summary +"?ACTION"?' $s | wc -l)
    aw=$(grep -rnE '_aitlib_action_once |Write-AitLibActionOnce |ui_action |Write-UiAction ' $s | wc -l)
    lw=$(grep -rnE 'log_warn|LogWarn' $s | wc -l)
    echo "WARN=$w ERROR=$e ACTION=$a wrappers=$aw log_warn_lines=$lw"
done

echo "== scope: scripts excluding deploy-like and tests, only .sh/.ps1/extensionless"
files=$(git ls-files scripts | grep -vE '\.(py|pl|md|txt|json)$')
# shellcheck disable=SC2086
echo "WARN=$(grep -nE 'write_summary +"?WARN"?|Write-Summary +"?WARN"?' $files | wc -l)"
# shellcheck disable=SC2086
echo "ERROR=$(grep -nE 'write_summary +"?ERROR"?|Write-Summary +"?ERROR"?' $files | wc -l)"
# shellcheck disable=SC2086
echo "ACTION=$(grep -nE 'write_summary +"?ACTION"?|Write-Summary +"?ACTION"?' $files | wc -l)"
# shellcheck disable=SC2086
echo "wrappers=$(grep -nE '_aitlib_action_once|Write-AitLibActionOnce|ui_action|Write-UiAction' $files | wc -l)"
# shellcheck disable=SC2086
echo "log_warn=$(grep -nE 'log_warn|LogWarn' $files | wc -l)"
