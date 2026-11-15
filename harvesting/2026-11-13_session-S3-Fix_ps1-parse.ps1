# Parse each .ps1 given as an argument with the PowerShell parser; exit 1 on any error.
$rc = 0
foreach ($p in $args) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    if ($e) {
        Write-Output "FAIL $p"
        $e | ForEach-Object { Write-Output "  $_" }
        $rc = 1
    } else {
        Write-Output "OK   $p"
    }
}
exit $rc
