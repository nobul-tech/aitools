# parse-check.ps1 -- PowerShell parser on the files this mission touched
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$files = @("scripts\aitools-lib.ps1", "scripts\aitools.ps1", "tests\aitools-entry\test-console-mode-guard.ps1") + $args
$bad = 0
foreach ($f in $files) {
    $p = if ([IO.Path]::IsPathRooted($f)) { $f } else { Join-Path $wt $f }
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    if ($e -and $e.Count -gt 0) { $bad++; "PARSE FAIL $p"; $e | ForEach-Object { "  $($_.Extent.StartLineNumber): $($_.Message)" } }
    else { "PARSE OK $p" }
}
exit $bad
