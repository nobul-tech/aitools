# Shared setup for M3b-Finish-C1 targets (dot-sourced). Requires $Out, $LogTag, $Lib.
# Isolated HOME/USERPROFILE and AITOOLS_LOG_DIR under this scratch dir.
#   $Lib = "new"  : the worktree's scripts/aitools-lib.ps1 (this change)
#   $Lib = "main" : origin/main e8ebd07 scripts/aitools-lib.ps1 (origin-aitools-lib.ps1 here)
function W([string]$s) {
    $line = "{0:HH:mm:ss.fff} {1}" -f (Get-Date), $s
    for ($i = 0; $i -lt 20; $i++) { try { Add-Content -LiteralPath $Out -Value $line -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds 25 } }
}
$isoHome = Join-Path $PSScriptRoot "iso-home"
if (-not (Test-Path $isoHome)) { New-Item -ItemType Directory -Path $isoHome | Out-Null }
$env:HOME = $isoHome
$env:USERPROFILE = $isoHome
$env:AITOOLS_LOG_DIR = Join-Path $PSScriptRoot "logs\$LogTag"
if (Test-Path $env:AITOOLS_LOG_DIR) { Remove-Item -Recurse -Force $env:AITOOLS_LOG_DIR }
$libPath = if ($Lib -eq "main") { Join-Path $PSScriptRoot "origin-aitools-lib.ps1" } else { "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input\scripts\aitools-lib.ps1" }
. $libPath
Initialize-Logging "m3bc1-$LogTag"
W "lib=$Lib ($libPath)"
