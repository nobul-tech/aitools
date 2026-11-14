# Shared setup for M3b-Finish-R targets (dot-sourced). Requires $Out and $LogTag.
# Isolated HOME/USERPROFILE and AITOOLS_LOG_DIR under this scratch dir; loads the
# COPY of the worktree aitools-lib.ps1 that sits next to this file.
function W([string]$s) {
    $line = "{0:HH:mm:ss.fff} {1}" -f (Get-Date), $s
    for ($i = 0; $i -lt 20; $i++) { try { Add-Content -LiteralPath $Out -Value $line -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds 25 } }
}
$isoHome = Join-Path $PSScriptRoot "home"
if (-not (Test-Path $isoHome)) { New-Item -ItemType Directory -Path $isoHome | Out-Null }
$env:HOME = $isoHome
$env:USERPROFILE = $isoHome
$env:AITOOLS_LOG_DIR = Join-Path $PSScriptRoot "logs\$LogTag"
. (Join-Path $PSScriptRoot "aitools-lib.ps1")
Initialize-Logging "m3br-$LogTag"
