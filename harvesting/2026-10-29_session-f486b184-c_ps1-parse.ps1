# ps1-parse.ps1 -- parse-check each .ps1 path given; exit 1 on any parse error
$bad = 0
foreach ($f in $args) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$e)
    if ($e.Count -gt 0) {
        $bad++
        $e | ForEach-Object { Write-Output "FAIL $f line $($_.Extent.StartLineNumber): $($_.Message)" }
    } else {
        Write-Output "parse ok: $f"
    }
}
if ($bad -gt 0) { exit 1 }
