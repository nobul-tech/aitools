param([string]$Label, [string]$Cmd = "", [string[]]$Keys = @("o`r", "o`r", "o`r", "o`r"), [int]$CmdTimeout = 90, [string]$Target = "target.ps1")
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\conmode.cs.ps1"
$out = Join-Path $PSScriptRoot "result-$Label.log"
if (Test-Path $out) { Remove-Item $out }
$argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot $Target), "-Out", $out)
if ($Target -eq "target.ps1") { $argList += @("-Reads", "2") }
if ($Cmd) { $argList += @("-Cmd", $Cmd) }
$p = Start-Process -FilePath "pwsh" -ArgumentList $argList -PassThru -WindowStyle Minimized
$deadline = (Get-Date).AddSeconds($CmdTimeout)
while (-not ((Test-Path $out) -and (Select-String -LiteralPath $out -Pattern "READY" -Quiet))) {
    if ((Get-Date) -gt $deadline -or $p.HasExited) { "TIMEOUT/EXIT waiting for READY"; if (Test-Path $out) { Get-Content $out }; exit 1 }
    Start-Sleep -Milliseconds 200
}
Start-Sleep -Milliseconds 500
[void][ConMode]::FreeConsole()
if (-not [ConMode]::AttachConsole([uint32]$p.Id)) { "AttachConsole failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; exit 1 }
foreach ($k in $Keys) {
    if ($p.HasExited) { break }
    Add-Content -LiteralPath $out -Value ("{0:HH:mm:ss.fff} DRIVER sends {1}" -f (Get-Date), ($k -replace "`r", '<CR>'))
    [void][ConMode]::SendKeys($k)
    Start-Sleep -Milliseconds 1500
    if (Select-String -LiteralPath $out -Pattern "DONE" -Quiet) { break }
}
[void][ConMode]::FreeConsole()
Start-Sleep -Milliseconds 500
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; Add-Content -LiteralPath $out -Value "KILLED (still waiting for input)" }
Get-Content $out
