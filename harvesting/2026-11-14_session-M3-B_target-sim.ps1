param([string]$Out, [string]$Variant = "noguard", [string]$Extra = "2E8")
# (a) Simulated child leaves the console raw inside the guarded region.
# Variant: noguard | guard. Extra: the raw mode (hex) the child sets.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\conmode.cs.ps1"
function W([string]$s) { Add-Content -LiteralPath $Out -Value ("{0:HH:mm:ss.fff} {1}" -f (Get-Date), $s) }
$env:AITOOLS_LOG_DIR = Join-Path $PSScriptRoot "logs-sim-$Variant-$Extra"
. "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile\scripts\aitools-lib.ps1"
Initialize-Logging "m3b-sim"
. "$PSScriptRoot\extract-guard.ps1"
W ("start: mode=0x{0:X} stdinRedirected={1} variant={2}" -f [ConMode]::InMode(), [Console]::IsInputRedirected, $Variant)
W "READY"
Start-Sleep -Milliseconds 800
$saved = $null
$guard = $Variant -like "*guard" -and $Variant -notlike "*noguard"
if ($guard) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $saved = Save-ConsoleInputMode
    W ("Save-ConsoleInputMode: Mode=0x{0:X} Reason={1} ({2} ms, incl. Add-Type)" -f $saved.Mode, $saved.Reason, $sw.ElapsedMilliseconds)
}
try {
    if ($Variant -like "nullstdin-conin*") {
        # child with a pipe for stdin that opens CONIN$ itself
        $r = $null | & pwsh -NoProfile -File (Join-Path $PSScriptRoot "setraw.ps1") -Mode $Extra -Out $Out -Conin 2>&1 | Out-String
    } elseif ($Variant -like "nullstdin*") {
        # child with a pipe for stdin that uses its stdin handle (fails: not a console)
        $r = $null | & pwsh -NoProfile -File (Join-Path $PSScriptRoot "setraw.ps1") -Mode $Extra -Out $Out 2>&1 | Out-String
    } else {
        $r = & pwsh -NoProfile -File (Join-Path $PSScriptRoot "setraw.ps1") -Mode $Extra -Out $Out 2>&1 | Out-String
    }
    W ("after child exit: mode=0x{0:X} child rc={1}" -f [ConMode]::InMode(), $LASTEXITCODE)
} finally {
    if ($guard) {
        $res = Restore-ConsoleInputMode $saved "sim-child"
        W "Restore-ConsoleInputMode: $res"
    }
}
W ("final: mode=0x{0:X}" -f [ConMode]::InMode())
W "DONE"
Start-Sleep -Milliseconds 500
