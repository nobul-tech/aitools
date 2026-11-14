# parse-check.ps1 -- PowerShell parser on the touched .ps1 files (and this session's scratch .ps1)
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$files = @(
    (Join-Path $wt "scripts\aitools-lib.ps1"),
    (Join-Path $wt "tests\aitools-entry\test-console-mode-guard.ps1")
) + @(Get-ChildItem -Path (Join-Path $wt ".scratch\session-M3b-C2") -Filter *.ps1 -File | ForEach-Object { $_.FullName })
$bad = 0
foreach ($f in $files) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$errs)
    if ($errs.Count -gt 0) {
        $bad++
        "FAIL $f"
        foreach ($e in $errs) { "  line $($e.Extent.StartLineNumber): $($e.Message)" }
    } else {
        "OK   $f"
    }
}
"parse errors in $bad file(s)"
if ($bad -gt 0) { exit 1 }
