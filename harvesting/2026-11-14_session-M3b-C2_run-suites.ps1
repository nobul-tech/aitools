# run-suites.ps1 -- run the logging and managed-files PowerShell suites from the worktree with an
# isolated HOME / log dir; each suite's output goes to suite-<name>.log here.
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$sc = Join-Path $wt ".scratch\session-M3b-C2"
$iso = Join-Path $sc "iso-home"
New-Item -ItemType Directory -Force -Path $iso, (Join-Path $iso "logs") | Out-Null
$env:HOME = $iso; $env:USERPROFILE = $iso; $env:AITOOLS_LOG_DIR = Join-Path $iso "logs"
$suites = @(
    @{ N = "suite-logging"; P = "tests\logging\test-logging.ps1" },
    @{ N = "suite-managed-files"; P = "tests\managed-files\test-managed-files.ps1" },
    @{ N = "suite-adopt-push"; P = "tests\managed-files\test-adopt-push.ps1" }
)
foreach ($s in $suites) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = & pwsh -NoProfile -File (Join-Path $wt $s.P) 2>&1 | Out-String
    $rc = $LASTEXITCODE
    $sw.Stop()
    $text = $out + "exit=$rc elapsed=$([int]$sw.Elapsed.TotalSeconds)s`n"
    [IO.File]::WriteAllText((Join-Path $sc "$($s.N).log"), $text)
    $lines = @($out -split "`r?`n")
    $fails = @($lines | Where-Object { $_ -match '^FAIL' })
    $skips = @($lines | Where-Object { $_ -match '^SKIP' })
    $total = @($lines | Where-Object { $_ -match '^----|passed' } | Select-Object -Last 2) -join " / "
    "=== $($s.N): exit=$rc ($([int]$sw.Elapsed.TotalSeconds)s) $total fails=$($fails.Count) skips=$($skips.Count)"
    $fails | ForEach-Object { "    $_" }
}
