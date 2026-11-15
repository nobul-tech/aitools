# inproc-smoke.ps1 -- run setup-user-shell.ps1 the way aitools-install.ps1 Step 7 does
# (in-process with &, as Invoke-ValidatedScript does), against a scratch profile copy.
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile"
$dir = Join-Path $wt ".scratch\session-M3-A\inproc"
if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
New-Item -ItemType Directory -Path $dir | Out-Null
$p = Join-Path $dir "profile.ps1"
Copy-Item -LiteralPath "C:\Users\jdpal\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Destination $p
$env:AITOOLS_PROFILE_PATH = $p
$env:AITOOLS_LOG_DIR = Join-Path $dir "logs"
$env:AITOOLS_SUMMARY_FILE = Join-Path $dir "summary.txt"
$script = Join-Path $wt "scripts\setup-user-shell.ps1"
foreach ($n in 1..2) {
    $global:LASTEXITCODE = 0
    & $script *> (Join-Path $dir "run$n.log")
    Write-Output "run $n exit: $LASTEXITCODE"
}
Write-Output "Split-Lines leaked into caller: $([bool](Get-Command Split-Lines -ErrorAction SilentlyContinue))"
Write-Output ([IO.File]::ReadAllText($env:AITOOLS_SUMMARY_FILE))
$env:AITOOLS_PROFILE_PATH = $null; $env:AITOOLS_LOG_DIR = $null; $env:AITOOLS_SUMMARY_FILE = $null
