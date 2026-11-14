# get-libs.ps1 -- copies of the lib for the before/after runs (scratch only):
#   origin-aitools-lib.ps1 : origin/main e8ebd07 (Start-Job spinner, console telemetry)
#   lib-nofinally.ps1      : the worktree lib as it is when this runs (new spinner + file-only
#                            telemetry, Invoke-AiMerge not yet wrapped in try/finally)
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$sc = Join-Path $wt ".scratch\session-M3b-C2"
$orig = Join-Path $sc "origin-aitools-lib.ps1"
& cmd /c "git -C `"$wt`" show e8ebd07:scripts/aitools-lib.ps1 > `"$orig`""
if ($LASTEXITCODE -ne 0) { throw "git show failed ($LASTEXITCODE)" }
"origin lib: $((Get-Item $orig).Length) bytes"
if ($args -contains "-snapshot") {
    Copy-Item -LiteralPath (Join-Path $wt "scripts\aitools-lib.ps1") -Destination (Join-Path $sc "lib-nofinally.ps1") -Force
    "snapshot: $((Get-Item (Join-Path $sc 'lib-nofinally.ps1')).Length) bytes"
}
