# parse-check.ps1 -- pwsh parser on every given .ps1; prints error count per file
param([Parameter(ValueFromRemainingArguments)][string[]]$Paths)
$bad = 0
foreach ($p in $Paths) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    Write-Output ("{0}: {1} parse error(s)" -f $p, @($e).Count)
    foreach ($x in @($e)) { Write-Output "  line $($x.Extent.StartLineNumber): $($x.Message)" }
    if (@($e).Count -gt 0) { $bad++ }
}
exit $bad
