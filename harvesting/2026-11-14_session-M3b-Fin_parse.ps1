param([string[]]$Paths)
$bad = 0
foreach ($p in $Paths) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    if ($e -and $e.Count -gt 0) { $bad++; "PARSE FAIL $p"; $e | ForEach-Object { "  $_" } } else { "PARSE OK $p" }
}
exit $bad
