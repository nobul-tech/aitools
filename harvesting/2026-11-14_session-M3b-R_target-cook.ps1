param([string]$Out, [string]$Variant = "current", [string]$Extra = "2E8")
# Fix-1 evidence target. A CHILD process (setraw.ps1) leaves this console's input
# mode raw (0x$Extra), then Read-ConsoleChoice reads one answer.
#   -Variant current : the worktree lib's Read-ConsoleChoice (plain ReadLine)
#   -Variant proto   : proto-conin.ps1 (cooked mode for the read, restore after)
# This process loads no other Add-Type, so the proto's first Add-Type is cold.
$ErrorActionPreference = "Stop"
$LogTag = "cook-$Variant-$Extra"
. (Join-Path $PSScriptRoot "tcommon.ps1")
if ($Variant -eq "proto") {
    . (Join-Path $PSScriptRoot "proto-conin.ps1")
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $ok = Initialize-AitConsoleInput
    $sw.Stop()
    W ("cold Initialize-AitConsoleInput (Add-Type) = {0}: {1} ms" -f $ok, $sw.Elapsed.TotalMilliseconds.ToString("0.0"))
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $ok2 = Initialize-AitConsoleInput
    $sw.Stop()
    W ("warm Initialize-AitConsoleInput = {0}: {1} ms" -f $ok2, $sw.Elapsed.TotalMilliseconds.ToString("0.000"))
    $sw = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 50; $i++) { $m = [AitConsoleInput]::EnterCooked(); $null = [AitConsoleInput]::Set($m) }
    $sw.Stop()
    W ("warm EnterCooked+Set x50: {0} ms total, {1} ms each" -f $sw.Elapsed.TotalMilliseconds.ToString("0.0"), ($sw.Elapsed.TotalMilliseconds / 50).ToString("0.000"))
    W ("mode before child (AitConsoleInput::Get): 0x{0:X}" -f [AitConsoleInput]::Get())
}
& pwsh -NoProfile -File (Join-Path $PSScriptRoot "setraw.ps1") -Mode $Extra -Out $Out
if ($Variant -eq "proto") { W ("mode after child: 0x{0:X}" -f [AitConsoleInput]::Get()) }
[Console]::Write("  choice [o/s]: ")
W "READY"
$sw = [Diagnostics.Stopwatch]::StartNew()
$line = Read-ConsoleChoice "overwrite"
$sw.Stop()
W ("GOT [{0}] after {1} ms" -f $line, $sw.ElapsedMilliseconds)
if ($Variant -eq "proto") { W ("mode after Read-ConsoleChoice: 0x{0:X}" -f [AitConsoleInput]::Get()) }
W "DONE"
Start-Sleep -Milliseconds 800
