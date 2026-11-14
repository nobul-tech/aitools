# parse-touched.ps1 -- pwsh parser over every touched .ps1
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\m5-checks"
$files = @("scripts\check-lib.ps1", "scripts\check-pre-commit.ps1", "scripts\check-pre-push.ps1",
    "scripts\check-post-push.ps1", "tests\check-lib\test-resolve-git-bash.ps1")
$bad = 0
foreach ($f in $files) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $wt $f), [ref]$null, [ref]$e)
    if ($e.Count -gt 0) { $bad++; "FAIL $f"; $e | ForEach-Object { "  line $($_.Extent.StartLineNumber): $($_.Message)" } }
    else { "OK   $f" }
}
"parse failures: $bad"
