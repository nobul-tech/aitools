param([string]$Out, [string]$Variant = "", [string]$Extra = "")
# Runs tests/aitools-entry/test-console-mode-guard.ps1 IN-PROCESS in this driver-owned console,
# so this process's stdin and stdout (inherited by the suite's children) are the console and the
# "console:" and "console spinner:" cases run instead of SKIP. The suite's PASS/FAIL lines go
# through the PowerShell pipeline into $Out (the process stdout stays the console).
$sc = $PSScriptRoot
$iso = Join-Path $sc "iso-home"
$env:HOME = $iso; $env:USERPROFILE = $iso; $env:AITOOLS_LOG_DIR = Join-Path $sc "logs\suite-console"
Add-Content -LiteralPath $Out -Value ("stdin redirected={0} stdout redirected={1}" -f [Console]::IsInputRedirected, [Console]::IsOutputRedirected)
& "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input\tests\aitools-entry\test-console-mode-guard.ps1" 2>&1 | ForEach-Object { Add-Content -LiteralPath $Out -Value "$_" }
Add-Content -LiteralPath $Out -Value "suite exit=$LASTEXITCODE"
Add-Content -LiteralPath $Out -Value "DONE"
