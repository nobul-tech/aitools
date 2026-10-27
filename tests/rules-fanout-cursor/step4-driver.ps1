# step4-driver.ps1 -- test helper: run step 4 (Cursor user rules) of
# scripts/setup-user-cursor.ps1 on any pwsh 7 platform. The script's Windows OS
# guard would stop it on macOS/Linux, so this driver dot-sources aitools-lib.ps1,
# defines the variables step 4 reads ($cursorDir, $DryRun, $Force), and runs the
# script text from 'Log "Step 4: Cursor user rules"' up to the "END cursor body"
# marker. Steps 1-3 (installers, cli-config.json) never run. The exit code
# follows the script's exit footer (1 on errors). Used by test-rules-fanout-cursor.sh
# for the bash/PS1 parity cases; run it under an isolated USERPROFILE only.
# Platform: any pwsh 7 (macOS, Linux, Windows).
# Usage: pwsh -NoProfile -File step4-driver.ps1 <setup-user-cursor.ps1> [-DryRun] [-Force]
param([string]$Script, [switch]$DryRun, [switch]$Force)
$ErrorActionPreference = "Stop"

if (-not $env:USERPROFILE) { Write-Error "USERPROFILE is not set (use an isolated one)"; exit 1 }
$text = [System.IO.File]::ReadAllText($Script)
$start = $text.IndexOf('Log "Step 4: Cursor user rules"')
$end = $text.IndexOf('# --- END cursor body')
if ($start -lt 0 -or $end -lt $start) { Write-Error "step 4 not found in $Script"; exit 1 }

. (Join-Path (Split-Path -Parent $Script) "aitools-lib.ps1")
Initialize-Logging "setup-user-cursor"
$ErrorActionPreference = "Continue"
$cursorDir = Join-Path $env:USERPROFILE ".cursor"

. ([scriptblock]::Create($text.Substring($start, $end - $start)))

if ($errors -gt 0) { Log "FAILED with $errors error(s)" "error"; exit 1 }
exit 0
