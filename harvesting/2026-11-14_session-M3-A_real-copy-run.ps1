# real-copy-run.ps1 -- run the fixed setup-user-shell.ps1 against SCRATCH COPIES of the
# commander's real profile and his corrupted 41 KB backup (never the originals).
$ErrorActionPreference = "Stop"
$scratch = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile\.scratch\session-M3-A"
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile"
$src = "C:\Users\jdpal\Documents\PowerShell"
$name = "Microsoft.PowerShell_profile.ps1"
$runId = (Get-Date).ToUniversalTime().ToString("HHmmss")

function Run-Case([string]$Case, [string]$ProfileSource) {
    $dir = Join-Path $scratch "real-$Case-$runId"
    New-Item -ItemType Directory -Path $dir | Out-Null
    # copy the backups that existed before the corruption run (read-only source)
    foreach ($b in Get-ChildItem -LiteralPath $src -File -Filter "$name.bak.*") {
        Copy-Item -LiteralPath $b.FullName -Destination (Join-Path $dir $b.Name)
    }
    $p = Join-Path $dir $name
    Copy-Item -LiteralPath $ProfileSource -Destination $p
    # The corrupted backup's own copy is the "current" profile here; drop it and newer
    # backups from the backup list so the run sees what the commander saw at that time.
    if ($Case -eq "corrupt") {
        foreach ($n in @("$name.bak.2026-11-13T214623Z", "$name.bak.2026-11-13T225245Z", "$name.bak.2026-11-13T225359Z")) {
            Remove-Item -LiteralPath (Join-Path $dir $n)
        }
    }
    Write-Output "== $Case (before)"
    & pwsh -NoProfile -File (Join-Path $scratch "analyze.ps1") $p
    $env:AITOOLS_PROFILE_PATH = $p
    $env:AITOOLS_LOG_DIR = Join-Path $dir "logs"
    $env:AITOOLS_SUMMARY_FILE = Join-Path $dir "summary.txt"
    & pwsh -NoProfile -File (Join-Path $wt "scripts\setup-user-shell.ps1") *> (Join-Path $dir "run.log")
    $rc = $LASTEXITCODE
    Write-Output "== $Case (after) exit $rc"
    & pwsh -NoProfile -File (Join-Path $scratch "analyze.ps1") $p
    Write-Output ([IO.File]::ReadAllText($env:AITOOLS_SUMMARY_FILE))
    $env:AITOOLS_PROFILE_PATH = $null; $env:AITOOLS_LOG_DIR = $null; $env:AITOOLS_SUMMARY_FILE = $null
    Write-Output "dir: $dir"
}

Run-Case "current" (Join-Path $src $name)
Run-Case "corrupt" (Join-Path $src "$name.bak.2026-11-13T214623Z")
