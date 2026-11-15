# M4-Winpty: parse every .ps1 given as an argument with the PowerShell parser
$bad = 0
foreach ($f in $args) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$e)
    if ($e) { "FAIL $f"; $e | ForEach-Object { "  $_" }; $bad++ } else { "parse OK $f" }
}
exit $bad
