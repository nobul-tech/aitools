foreach ($p in $args) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    if ($e) { "PARSE ERRORS in ${p}:"; $e } else { "parse OK: $p" }
}
