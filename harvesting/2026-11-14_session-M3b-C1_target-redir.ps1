param([string]$Out, [string]$Variant = "new", [string]$Extra = "piped")
# Redirected stdin: Read-ConsoleChoice must compile nothing and keep its contract
# (the piped line, or "" + LogWarn at EOF); Save/Restore are a no-op.
$ErrorActionPreference = "Stop"
$Lib = $Variant
$LogTag = "redir-$Variant-$Extra"
. (Join-Path $PSScriptRoot "tcommon.ps1")
W ("stdin redirected={0}" -f [Console]::IsInputRedirected)
$sw = [Diagnostics.Stopwatch]::StartNew()
$line = Read-ConsoleChoice "overwrite"
$sw.Stop()
$shown = if ($null -eq $line) { '<null>' } else { "[$line]" }
W ("Read-ConsoleChoice returned {0} in {1} ms" -f $shown, $sw.Elapsed.TotalMilliseconds.ToString("0.00"))
W ("AitConsoleInput type loaded: {0}" -f [bool]('AitConsoleInput' -as [type]))
if (Get-Command Save-ConsoleInputMode -ErrorAction SilentlyContinue) {
    $s = Save-ConsoleInputMode
    W ("Save-ConsoleInputMode: Mode={0} Reason={1}" -f $s.Mode, $s.Reason)
    W ("Restore-ConsoleInputMode: {0}" -f (Restore-ConsoleInputMode $s "test"))
    W ("AitConsoleInput type loaded after Save/Restore: {0}" -f [bool]('AitConsoleInput' -as [type]))
} else {
    W "Save-ConsoleInputMode: not in this lib"
}
W ("counters: errors={0} warnings={1}" -f $errors, $warnings)
W "DONE"
