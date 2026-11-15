# mdm-run.ps1 -- run the GENERATED deploy/setup-user-shell.ps1 (scratch build) on a scratch profile
$s = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile\.scratch\session-M3-A"
$dir = Join-Path $s "mdm-run"
if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
New-Item -ItemType Directory -Path $dir | Out-Null
$p = Join-Path $dir "profile.ps1"
[IO.File]::WriteAllText($p, "# mine`n# aitools shell integration`n. `"C:\x\aliases.ps1`"`n")
$env:AITOOLS_PROFILE_PATH = $p
$env:AITOOLS_LOG_DIR = Join-Path $dir "logs"
$env:AITOOLS_SUMMARY_FILE = Join-Path $dir "summary.txt"
& pwsh -NoProfile -File (Join-Path $s "bd\dotprofile\deploy\setup-user-shell.ps1") *> (Join-Path $dir "run.log")
Write-Output "exit: $LASTEXITCODE"
Write-Output ([IO.File]::ReadAllText($env:AITOOLS_SUMMARY_FILE))
Write-Output "---- profile"
Write-Output ([IO.File]::ReadAllText($p))
$env:AITOOLS_PROFILE_PATH = $null; $env:AITOOLS_LOG_DIR = $null; $env:AITOOLS_SUMMARY_FILE = $null
