# parse.ps1 -- bash -n (Git Bash) and the PowerShell parser on the touched scripts
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\m5-lib"
$gitBash = "C:\Program Files\Git\bin\bash.exe"
$rc = 0
foreach ($f in @("scripts/aitools-lib.sh", "tests/logging/test-logging.sh", "tests/menus/test-menu-choice.sh")) {
    & $gitBash -n (Join-Path $wt $f)
    if ($LASTEXITCODE -ne 0) { Write-Output "BASH-N FAIL $f"; $rc = 1 } else { Write-Output "BASH-N OK   $f" }
}
foreach ($f in @("scripts/aitools-lib.ps1", "tests/logging/test-logging.ps1")) {
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $wt $f), [ref]$null, [ref]$e)
    if ($e) { Write-Output "PARSE FAIL $f"; $e | ForEach-Object { Write-Output "  $_" }; $rc = 1 } else { Write-Output "PARSE OK   $f" }
}
exit $rc
