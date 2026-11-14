# Parse each given .ps1 with the PowerShell parser; print OK/FAIL per file.
foreach ($f in $args) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f).ProviderPath, [ref]$null, [ref]$e)
    if ($e -and $e.Count -gt 0) { "parse FAIL $f : $($e[0].Message)" } else { "parse OK  $f" }
}
