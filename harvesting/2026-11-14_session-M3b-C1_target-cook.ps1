param([string]$Out, [string]$Variant = "new", [string]$Extra = "2E8")
# Fix-1 evidence target. A CHILD process (setraw.ps1) leaves this console's input
# mode raw (0x$Extra), then Read-ConsoleChoice reads one answer.
#   -Variant main : origin/main lib (plain ReadLine)
#   -Variant new  : the worktree lib; nothing is compiled before the read, so the
#                   first Read-ConsoleChoice compiles AitConsoleInput (lazy, cold)
$ErrorActionPreference = "Stop"
$Lib = $Variant
$LogTag = "cook-$Variant-$Extra"
. (Join-Path $PSScriptRoot "tcommon.ps1")
W ("type AitConsoleInput loaded before the read: {0}" -f [bool]('AitConsoleInput' -as [type]))
& pwsh -NoProfile -File (Join-Path $PSScriptRoot "setraw.ps1") -Mode $Extra -Out $Out
[Console]::Write("  choice [o/s]: ")
W "READY"
$sw = [Diagnostics.Stopwatch]::StartNew()
$line = Read-ConsoleChoice "overwrite"
$sw.Stop()
W ("GOT [{0}] after {1} ms" -f $line, $sw.ElapsedMilliseconds)
if ('AitConsoleInput' -as [type]) { W ("mode after Read-ConsoleChoice (AitConsoleInput::Get): 0x{0:X}" -f [AitConsoleInput]::Get()) }
W "DONE"
Start-Sleep -Milliseconds 800
