# probe-relay.ps1 -- dot-source relay-outbound-prompt.ps1 (optionally the lib first),
# feed INPUT through [Console]::SetIn, call Read-RelayOutboundChoice, print results.
# Usage: <pwsh|powershell.exe> -NoProfile -File probe-relay.ps1 -Relay <path> -InputText <text> [-LoadLib <libpath>]
param([string]$Relay, [string]$InputText, [string]$LoadLib = "")
$ErrorActionPreference = "Stop"
if ($LoadLib) { . $LoadLib; Initialize-Logging "probe" }
. $Relay
$InputText = $InputText -replace '\\n', "`n"
[Console]::SetIn((New-Object IO.StringReader($InputText)))
$orig = [Console]::Out
$sw = New-Object IO.StringWriter
[Console]::SetOut($sw)
$trace = Join-Path $PSScriptRoot "trace.txt"
[IO.File]::WriteAllText($trace, "before`n")
try {
    $r = @(Read-RelayOutboundChoice)
    [IO.File]::AppendAllText($trace, "after r=$($r -join '|')`n")
} catch {
    [IO.File]::AppendAllText($trace, "catch $($_ | Out-String)`n")
} finally {
    [Console]::SetOut($orig)
    [IO.File]::AppendAllText($trace, "finally sw=[$($sw.ToString())]`n")
}
"PS $($PSVersionTable.PSVersion)"
"RESULT [$($r -join '|')] COUNT $($r.Count)"
"LEAKED Read-MenuChoice: $([bool](Get-Command Read-MenuChoice -ErrorAction SilentlyContinue))"
"CONSOLE:"
$sw.ToString()
