# Shared setup for M3b-Finish-C2 targets (dot-sourced). Requires $Out, $LogTag, $Lib.
# Isolated HOME/USERPROFILE and AITOOLS_LOG_DIR under this scratch dir; a scratch bin\ first
# on PATH holds the stub AI CLI (claude.cmd) when $Stub is set.
#   $Lib = "main"  : origin/main e8ebd07 scripts/aitools-lib.ps1 (origin-aitools-lib.ps1 here)
#   $Lib = "nofin" : lib-nofinally.ps1 here (new spinner + file-only telemetry, no try/finally)
#   $Lib = "new"   : the worktree's scripts/aitools-lib.ps1 (this change)
function W([string]$s) {
    $line = "{0:HH:mm:ss.fff} {1}" -f (Get-Date), $s
    for ($i = 0; $i -lt 20; $i++) { try { Add-Content -LiteralPath $Out -Value $line -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds 25 } }
}
function RS { (Get-Runspace | ForEach-Object { "$($_.Id):$($_.RunspaceStateInfo.State)/$($_.RunspaceAvailability)" }) -join ',' }
$isoHome = Join-Path $PSScriptRoot "iso-home"
if (-not (Test-Path $isoHome)) { New-Item -ItemType Directory -Path $isoHome | Out-Null }
$env:HOME = $isoHome
$env:USERPROFILE = $isoHome
$env:AITOOLS_LOG_DIR = Join-Path $PSScriptRoot "logs\$LogTag"
if (Test-Path $env:AITOOLS_LOG_DIR) { Remove-Item -Recurse -Force $env:AITOOLS_LOG_DIR }
$libPath = switch ($Lib) {
    "main"  { Join-Path $PSScriptRoot "origin-aitools-lib.ps1" }
    "nofin" { Join-Path $PSScriptRoot "lib-nofinally.ps1" }
    default { "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input\scripts\aitools-lib.ps1" }
}
# Stub AI CLI on a scratch PATH: reads the prompt (discarded), waits ~$StubSeconds, prints a
# valid merge. Same shape as Stub-Claude in tests/managed-files/test-managed-files.ps1.
if ($Stub) {
    $bin = Join-Path $PSScriptRoot "bin-$LogTag"
    New-Item -ItemType Directory -Force -Path $bin | Out-Null
    $n = [int]$StubSeconds + 1
    [IO.File]::WriteAllText((Join-Path $bin "claude.cmd"), "@echo off`r`nmore > nul`r`nping -n $n 127.0.0.1 > nul`r`necho # Title`r`necho merged line`r`n")
    $env:PATH = $bin + [IO.Path]::PathSeparator + $env:PATH
}
. $libPath
Initialize-Logging "m3bc2-$LogTag"
W "lib=$Lib ($libPath)"
