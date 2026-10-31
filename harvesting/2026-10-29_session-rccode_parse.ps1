# parse.ps1 FILE... -- PowerShell parser check; prints errors, exit 1 on any
$bad = 0
foreach ($f in $args) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$e)
    if ($e.Count -gt 0) {
        foreach ($x in $e) { Write-Output "$f line $($x.Extent.StartLineNumber): $($x.Message)" }
        $bad++
    } else {
        Write-Output "parse ok: $f"
    }
}
exit $bad
