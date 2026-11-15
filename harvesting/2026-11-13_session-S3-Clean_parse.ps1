# Parse the touched .ps1 files; exit 1 on any parse error.
$files = @(
    '/Users/new-jose/repos/aitools/scripts/aitools-lib.ps1',
    '/Users/new-jose/repos/aitools/scripts/deploy-harness.ps1',
    '/Users/new-jose/repos/aitools/scripts/check-post-push.ps1'
)
$bad = 0
foreach ($f in $files) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$e)
    if ($e) { $e; $bad++ } else { Write-Output "pwsh parse OK $f" }
}
if ($bad -gt 0) { exit 1 }
