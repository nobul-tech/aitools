$bad = 0
foreach ($p in $args) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    if ($e) { $bad++; [Console]::WriteLine("PARSE FAIL $p"); $e | ForEach-Object { [Console]::WriteLine("  $_") } }
    else { [Console]::WriteLine("PARSE OK $p") }
}
exit $bad
