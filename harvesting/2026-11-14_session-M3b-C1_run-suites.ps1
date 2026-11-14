# run-suites.ps1 -- run tests/logging/test-logging.ps1 and tests/managed-files/test-managed-files.ps1
# from the worktree with an isolated HOME / log dir; each suite's output goes to <name>.log here.
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$sc = Join-Path $wt ".scratch\session-M3b-C1"
$iso = Join-Path $sc "iso-home"
New-Item -ItemType Directory -Force -Path $iso, (Join-Path $iso "logs") | Out-Null
$env:HOME = $iso; $env:USERPROFILE = $iso; $env:AITOOLS_LOG_DIR = Join-Path $iso "logs"
foreach ($s in @(@{ N = "suite-logging"; P = "tests\logging\test-logging.ps1" }, @{ N = "suite-managed-files"; P = "tests\managed-files\test-managed-files.ps1" })) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = & pwsh -NoProfile -File (Join-Path $wt $s.P) 2>&1 | Out-String
    $rc = $LASTEXITCODE
    $sw.Stop()
    $text = $out + "exit=$rc elapsed=$([int]$sw.Elapsed.TotalSeconds)s`n"
    [IO.File]::WriteAllText((Join-Path $sc "$($s.N).log"), $text)
    $tail = ($out -split "`r?`n" | Where-Object { $_ -match '^(FAIL|----|\d+ passed|PASS: |FAIL: )|passed|failed' } | Select-Object -Last 6) -join "`n"
    "=== $($s.N): exit=$rc ($([int]$sw.Elapsed.TotalSeconds)s)`n$tail"
}
