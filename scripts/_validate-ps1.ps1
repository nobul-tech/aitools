$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($args[0], [ref]$null, [ref]$e)
if ($e.Count -gt 0) {
    foreach ($err in $e) { Write-Host "line $($err.Extent.StartLineNumber): $($err.Message)" }
    exit 1
} else {
    Write-Host "OK"
}
