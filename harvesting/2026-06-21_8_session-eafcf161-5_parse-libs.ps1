$files = @(
    "/Users/new-jose/repos/aitools/scripts/aitools-lib.ps1",
    "/Users/new-jose/repos/aitools/scripts/check-lib.ps1"
)
foreach ($f in $files) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$e)
    if ($e.Count -gt 0) {
        Write-Host "FAIL: $(Split-Path $f -Leaf)"
        foreach ($x in $e) { Write-Host "  $($x.Message)" }
    } else {
        Write-Host "OK: $(Split-Path $f -Leaf)"
    }
}
