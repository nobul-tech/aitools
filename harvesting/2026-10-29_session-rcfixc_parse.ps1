# parse.ps1 FILE... -- PowerShell parser check (cross-platform.md "Pre-validation convention")
$bad = 0
foreach ($f in $args) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$e)
    if ($e) {
        $bad++
        foreach ($x in $e) { [Console]::WriteLine("PARSE-ERROR ${f}: $($x.Extent.StartLineNumber): $($x.Message)") }
    } else {
        [Console]::WriteLine("parse ok: $f")
    }
}
exit $bad
