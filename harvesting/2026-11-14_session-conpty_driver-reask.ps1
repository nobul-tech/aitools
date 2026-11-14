# driver-reask.ps1 -- real-console check of the review menu re-ask (adapted from
# the delegating session's driver.ps1): start the target in its own console,
# attach, inject keys with WriteConsoleInputW, dump the screen, print the log.
param([string]$Label = "reask", [string]$Target = "target-reask.ps1", [int]$CmdTimeout = 90)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\conmode.cs.ps1"
$Keys = @("`r", "skip`r", "q`r", "o`r")
$out = Join-Path $PSScriptRoot "result-$Label.log"
if (Test-Path $out) { Remove-Item $out }
$argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot $Target), "-Out", $out)
$p = Start-Process -FilePath "pwsh" -ArgumentList $argList -PassThru -WindowStyle Minimized
$deadline = (Get-Date).AddSeconds($CmdTimeout)
while (-not ((Test-Path $out) -and (Select-String -LiteralPath $out -Pattern "READY" -Quiet))) {
    if ((Get-Date) -gt $deadline -or $p.HasExited) { "TIMEOUT/EXIT waiting for READY"; if (Test-Path $out) { Get-Content $out }; exit 1 }
    Start-Sleep -Milliseconds 200
}
Start-Sleep -Milliseconds 800
[void][ConMode]::FreeConsole()
if (-not [ConMode]::AttachConsole([uint32]$p.Id)) { "AttachConsole failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; exit 1 }
foreach ($k in $Keys) {
    if ($p.HasExited) { break }
    Add-Content -LiteralPath $out -Value ("{0:HH:mm:ss.fff} DRIVER sends {1}" -f (Get-Date), ($k -replace "`r", '<CR>'))
    [void][ConMode]::SendKeys($k)
    Start-Sleep -Milliseconds 1500
    if (Select-String -LiteralPath $out -Pattern "DONE" -Quiet) { break }
}
$screen = [ConMode]::ScreenTail(30)
[void][ConMode]::FreeConsole()
Start-Sleep -Milliseconds 500
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; Add-Content -LiteralPath $out -Value "KILLED (still waiting for input)" }
Get-Content $out
"--- screen (last 30 lines) ---"
$screen
