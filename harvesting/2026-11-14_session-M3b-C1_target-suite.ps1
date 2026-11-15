param([string]$Out, [string]$Variant = "", [string]$Extra = "")
# Runs tests/aitools-entry/test-console-mode-guard.ps1 with this (driver-owned) console as
# stdin, so its "console:" cases run instead of SKIP. Isolated HOME / log dir.
$sc = $PSScriptRoot
$iso = Join-Path $sc "iso-home"
$env:HOME = $iso; $env:USERPROFILE = $iso; $env:AITOOLS_LOG_DIR = Join-Path $sc "logs\suite-console"
Add-Content -LiteralPath $Out -Value ("stdin redirected={0}" -f [Console]::IsInputRedirected)
$res = & pwsh -NoProfile -File "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input\tests\aitools-entry\test-console-mode-guard.ps1" 2>&1 | Out-String
Add-Content -LiteralPath $Out -Value $res
Add-Content -LiteralPath $Out -Value "suite exit=$LASTEXITCODE"
Add-Content -LiteralPath $Out -Value "DONE"
