$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile("/Users/pepe/repos/aitools/scripts/setup-user-hooks.ps1", [ref]$null, [ref]$e)
if ($e.Count -gt 0) {
    foreach ($err in $e) { Write-Host "line $($err.Extent.StartLineNumber): $($err.Message)" }
    exit 1
}
Write-Host "PS1 syntax OK"
