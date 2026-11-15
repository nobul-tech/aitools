param([int]$TargetPid, [int]$Lines = 15, [string]$Send = "")
. "$PSScriptRoot\conmode.cs.ps1"
[void][ConMode]::FreeConsole()
if (-not [ConMode]::AttachConsole([uint32]$TargetPid)) { exit 3 }
$t = [ConMode]::ScreenTail($Lines)
$m = [ConMode]::ConinMode()
if ($Send) { [void][ConMode]::SendKeys(($Send -replace '<CR>', "`r")) }
[void][ConMode]::FreeConsole()
Set-Content -LiteralPath (Join-Path $PSScriptRoot "peek.txt") -Value (("mode=0x{0:X}" -f $m) + "`n" + $t)
