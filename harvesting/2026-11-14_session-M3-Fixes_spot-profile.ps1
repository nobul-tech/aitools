# Orchestrator spot-check: run the new setup-user-shell.ps1 twice on a scratch COPY of
# the commander's current $PROFILE (the real file is only read).
$S = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile\.scratch\session-M3-Fixes\spot"
New-Item -ItemType Directory -Force -Path $S | Out-Null
$copy = Join-Path $S "profile.ps1"
Copy-Item -LiteralPath "C:\Users\jdpal\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Destination $copy -Force
$env:AITOOLS_PROFILE_PATH = $copy
$env:AITOOLS_LOG_DIR = Join-Path $S "logs"
$env:AITOOLS_SUMMARY_FILE = Join-Path $S "summary.txt"
$script = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile\scripts\setup-user-shell.ps1"
foreach ($run in 1, 2) {
    if (Test-Path $env:AITOOLS_SUMMARY_FILE) { Remove-Item $env:AITOOLS_SUMMARY_FILE }
    pwsh -NoProfile -File $script *> (Join-Path $S "run$run.log")
    "run $run exit $LASTEXITCODE"
    if (Test-Path $env:AITOOLS_SUMMARY_FILE) { Get-Content $env:AITOOLS_SUMMARY_FILE }
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($copy, [ref]$null, [ref]$e)
    "parse errors: $(@($e).Count); bytes: $((Get-Item $copy).Length)"
}
"---- final profile copy ----"
Get-Content $copy
