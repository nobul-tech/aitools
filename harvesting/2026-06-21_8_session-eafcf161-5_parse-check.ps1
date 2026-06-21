$files = @(
    "/Users/new-jose/repos/aitools/scripts/setup-user-hooks.ps1",
    "/Users/new-jose/repos/aitools/scripts/setup-user-shell.ps1",
    "/Users/new-jose/repos/aitools/scripts/setup-user-cursor.ps1",
    "/Users/new-jose/repos/aitools/scripts/aitools-lib.ps1",
    "/Users/new-jose/repos/aitools/scripts/aitools-dashboard.ps1",
    "/Users/new-jose/repos/aitools/scripts/aitools-install.ps1",
    "/Users/new-jose/repos/aitools-nobul-jose/deploy/setup-user-hooks.ps1"
)
$fail = 0
foreach ($f in $files) {
    if (-not (Test-Path $f)) { Write-Host "MISSING: $f"; $fail++; continue }
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$e)
    if ($e.Count -gt 0) {
        Write-Host "FAIL: $(Split-Path $f -Leaf)"
        foreach ($err in $e) { Write-Host "  line $($err.Extent.StartLineNumber): $($err.Message)" }
        $fail++
    } else {
        Write-Host "OK:   $(Split-Path $f -Leaf)"
    }
}
Write-Host "---"
Write-Host "failures: $fail"
