# Parse each argument with the PowerShell parser; exit 1 on any error.
$bad = 0
foreach ($p in $args) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    if ($e.Count -gt 0) {
        foreach ($x in $e) { [Console]::WriteLine("PARSE ERROR $p line $($x.Extent.StartLineNumber): $($x.Message)") }
        $bad++
    } else {
        [Console]::WriteLine("parse OK: $p")
    }
}
exit ([int]($bad -gt 0))
