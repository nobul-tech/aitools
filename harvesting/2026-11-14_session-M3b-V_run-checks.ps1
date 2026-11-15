# run-checks.ps1 -- M3b-Finish-V: run check-pre-commit / check-pre-push /
# check-post-push (.ps1) from native pwsh, isolated: HOME/USERPROFILE point to a
# scratch home whose .aitools/config.json is a copy of the real one with
# userRepoPath -> a scratch clone of the dotprofile and repoPath -> the worktree,
# AITOOLS_LOG_DIR -> scratch, AITOOLS_USER_REPO_PATH -> the scratch clone.
# Reason: check-post-push step 7 runs build-deploy.sh unconditionally, and
# build-deploy rebuilds <dotprofile>/deploy/ (never the real one from an agent).
# No -Fix is passed.
$ErrorActionPreference = "Continue"
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$s = Join-Path $wt ".scratch\session-M3b-V"
$home2 = Join-Path $s "home-checks"
$logs = Join-Path $s "logs-checks"
$dot = Join-Path $s "dotprofile-checks"
New-Item -ItemType Directory -Force -Path (Join-Path $home2 ".aitools"), $logs | Out-Null

$cfg = [IO.File]::ReadAllText("C:\Users\jdpal\.aitools\config.json") | ConvertFrom-Json
$cfg.userRepoPath = $dot
$cfg.repoPath = $wt
[IO.File]::WriteAllText((Join-Path $home2 ".aitools\config.json"), ($cfg | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

$env:HOME = $home2
$env:USERPROFILE = $home2
$env:AITOOLS_LOG_DIR = $logs
$env:AITOOLS_USER_REPO_PATH = $dot

Set-Location $wt
foreach ($c in @("check-pre-commit", "check-pre-push", "check-post-push")) {
    $log = Join-Path $s "$c.log"
    $t0 = Get-Date
    & pwsh -NoProfile -File (Join-Path $wt "scripts\$c.ps1") *> $log
    $rc = $LASTEXITCODE
    $sec = [int]((Get-Date) - $t0).TotalSeconds
    Write-Output ("[{0}] {1} exit={2} ({3}s) log={4}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"), $c, $rc, $sec, $log)
}
