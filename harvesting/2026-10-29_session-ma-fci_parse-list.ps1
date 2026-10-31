# Parse every .ps1 listed in the file given as arg 0 (scratch, read-only)
$list = Get-Content -LiteralPath $args[0]
$bad = 0
foreach ($f in $list) {
    if (-not $f) { continue }
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $f).Path, [ref]$null, [ref]$errs)
    if ($errs.Count -gt 0) { $bad++; Write-Output "FAIL $f : $($errs[0].Message)" } else { Write-Output "ok $f" }
}
Write-Output "ps1 failed: $bad"
