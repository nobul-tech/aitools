# Fix-1 prototype, redirected stdin: "o" piped, and $null (EOF).
$here = $PSScriptRoot
$t = Join-Path $here "target-redir.ps1"
foreach ($v in @("piped", "eof")) {
    $log = Join-Path $here "result-redir-$v.log"
    if (Test-Path $log) { Remove-Item $log }
    $logDir = Join-Path $here "logs\redir-$v"
    if (Test-Path $logDir) { Remove-Item -Recurse -Force $logDir }
    if ($v -eq "piped") {
        $cap = "o" | & pwsh -NoProfile -File $t -Out $log -Variant $v 2>&1 | Out-String
    } else {
        $cap = $null | & pwsh -NoProfile -File $t -Out $log -Variant $v 2>&1 | Out-String
    }
    "=== $v (exit $LASTEXITCODE)"
    "console output: [" + ($cap -replace "`r", '<CR>' -replace "`n", '<LF>' -replace "`e", '<ESC>') + "]"
    Get-Content $log
    "--- deploy.log lines:"
    Get-ChildItem $logDir -File | ForEach-Object { Get-Content $_.FullName }
}
