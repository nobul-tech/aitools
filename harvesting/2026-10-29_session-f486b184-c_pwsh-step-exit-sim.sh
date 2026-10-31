#!/usr/bin/env bash
# pwsh-step-exit-sim.sh -- reproduce the GitHub Actions pwsh step wrapper
# (prepend $ErrorActionPreference='stop', append exit $LASTEXITCODE) with and
# without a trailing `exit 0`, after a native command that exits 1 on purpose.
set -euo pipefail
dir=$(mktemp -d)
pre='$ErrorActionPreference = '"'"'stop'"'"''
post='if ((Test-Path -LiteralPath variable:\LASTEXITCODE)) { exit $LASTEXITCODE }'
body='& pwsh -NoProfile -Command "exit 1"
if ($LASTEXITCODE -ne 1) { exit 1 }
Write-Host "expected exit 1 seen"'
printf '%s\n%s\n%s\n' "$pre" "$body" "$post" > "$dir/before.ps1"
printf '%s\n%s\nexit 0\n%s\n' "$pre" "$body" "$post" > "$dir/after.ps1"
for f in before after; do
    rc=0
    pwsh -NoProfile -Command ". '$dir/$f.ps1'" || rc=$?
    printf '%s: step exit %s\n' "$f" "$rc"
done
rm -rf "$dir"
