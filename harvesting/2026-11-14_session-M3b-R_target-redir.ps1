param([string]$Out, [string]$Variant = "piped", [string]$Extra = "")
# Fix-1 prototype with redirected stdin: must compile nothing and keep the
# Read-ConsoleChoice contract (the piped line, or "" + LogWarn at EOF).
$ErrorActionPreference = "Stop"
$LogTag = "redir-$Variant"
. (Join-Path $PSScriptRoot "tcommon.ps1")
. (Join-Path $PSScriptRoot "proto-conin.ps1")
W ("stdin redirected={0}" -f [Console]::IsInputRedirected)
$sw = [Diagnostics.Stopwatch]::StartNew()
$line = Read-ConsoleChoice "overwrite"
$sw.Stop()
$shown = if ($null -eq $line) { '<null>' } else { "[$line]" }
W ("Read-ConsoleChoice returned {0} in {1} ms" -f $shown, $sw.Elapsed.TotalMilliseconds.ToString("0.00"))
W ("AitConsoleInput type loaded: {0}" -f [bool]('AitConsoleInput' -as [type]))
$s = Save-ConsoleInputMode
W ("Save-ConsoleInputMode: Mode={0} Reason={1}" -f $s.Mode, $s.Reason)
W ("Restore-ConsoleInputMode: {0}" -f (Restore-ConsoleInputMode $s "test"))
W ("AitConsoleInput type loaded after Save/Restore: {0}" -f [bool]('AitConsoleInput' -as [type]))
W "DONE"
