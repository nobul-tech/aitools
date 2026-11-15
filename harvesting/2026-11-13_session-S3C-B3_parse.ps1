$rc = 0
foreach ($p in @('/Users/new-jose/repos/aitools/scripts/aitools-lib.ps1', '/Users/new-jose/repos/aitools/scripts/deploy-harness.ps1')) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    if ($e) { "$p"; $e; $rc = 1 } else { "OK $p" }
}
exit $rc
