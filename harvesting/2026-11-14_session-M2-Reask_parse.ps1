param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Paths)
$bad = 0
foreach ($p in $Paths) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    if ($e) { Write-Output "PARSE ERROR $p"; $e | ForEach-Object { Write-Output "  $_" }; $bad++ } else { Write-Output "parse OK: $p" }
}
exit $bad
