# Spinner prototype with redirected stdout/stdin: must draw nothing into the pipe.
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
foreach ($v in @("rs", "job")) {
    $log = Join-Path $here "result-spin-redir-$v.log"
    if (Test-Path $log) { Remove-Item $log }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $captured = "y" | & pwsh -NoProfile -File (Join-Path $here "target-spin.ps1") -Out $log -Variant $v 2>&1 | Out-String
    $sw.Stop()
    $show = $captured -replace "`r", '<CR>' -replace "`n", '<LF>' -replace "`e", '<ESC>'
    "=== variant $v (exit $LASTEXITCODE, $($sw.ElapsedMilliseconds) ms)"
    "captured stdout+stderr ($($captured.Length) chars): [$show]"
    "contains 'merging test': $($captured.Contains('merging test'))"
    Get-Content $log
}
