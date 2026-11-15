# probe-wrapper.ps1 -- logic probe of Read-MenuChoice (scratch copy) with
# [Console]::SetIn input, against the real Read-ConsoleChoice.
$ErrorActionPreference = "Stop"
$S = $PSScriptRoot
$env:AITOOLS_LOG_DIR = Join-Path $S "probe-logs-ps"
if (Test-Path $env:AITOOLS_LOG_DIR) { Remove-Item -Recurse -Force $env:AITOOLS_LOG_DIR }
. (Join-Path $S "../../scripts/aitools-lib.ps1")
Initialize-Logging "probe"
. (Join-Path $S "wrapper.ps1")
$origOut = [Console]::Out
function Run([string]$Name, [string]$In, [string[]]$Valid, [string]$Def) {
    [Console]::SetIn([IO.StringReader]::new($In))
    $sw = [IO.StringWriter]::new()
    [Console]::SetOut($sw)
    try { $r = @(Read-MenuChoice -Valid $Valid -Default $Def -DefaultDesc "the default" -Context $Name -Prompt "  choice: ") }
    finally { [Console]::SetOut($origOut) }
    $hints = ([regex]::Matches($sw.ToString(), "please type one of")).Count
    "{0,-10} -> [{1}] count={2} hints={3}" -f $Name, ($r -join "|"), $r.Count, $hints
}
Run "reask" "`n`nskip`nq`no`n" @("o","a","m","s","x") "o"
Run "upper" "  S `n" @("o","a","m","s","x") "o"
Run "eof" "" @("o","a","m","s","x") "o"
Run "eofafter" "`nfoo`n" @("o","s","x") "o"
Run "yesword" "Yes`n" @("y","yes","n","no") "n"
Run "nums" "3`n0`n2`n" @("1","2","n","s") "s"
Run "guard" ("junk`n" * 60) @("o","s","x") "o"
"--- log ---"
Get-Content (Join-Path $env:AITOOLS_LOG_DIR "deploy.log") | Where-Object { $_ -match 'menu answer|No valid|EOF' } | Select-Object -First 16 | ForEach-Object { $_ -replace '^\[[^]]+\] ', '' }
"warnings=$($script:warnings)"
