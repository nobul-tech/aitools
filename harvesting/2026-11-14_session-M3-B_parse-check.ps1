param([string[]]$Paths)
# Parser check for each .ps1 path (pass one comma-separated string via -File)
$fail = 0
foreach ($p in ($Paths -join ',').Split(',')) {
    if (-not $p) { continue }
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    if ($e.Count -gt 0) { $fail++; foreach ($x in $e) { "PARSE ERROR ${p}:$($x.Extent.StartLineNumber): $($x.Message)" } } else { "OK $p" }
}
exit $fail
