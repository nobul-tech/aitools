# run-suite.ps1 -- parse-check and run tests/pywinpty/test-setup-pywinpty.ps1, output to a log
param([Parameter(Mandatory)][string]$Out)
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty"
$suite = Join-Path $wt "tests\pywinpty\test-setup-pywinpty.ps1"
$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($suite, [ref]$null, [ref]$e)
if ($e) { $e | Out-String | Set-Content -LiteralPath $Out; Write-Output "PARSE ERRORS: $($e.Count)"; exit 1 }
$nonAscii = Select-String -LiteralPath $suite -Pattern '[^\x00-\x7F]' -AllMatches
Write-Output "parser: ok; non-ASCII lines: $(@($nonAscii).Count)"
Push-Location -LiteralPath $wt
$t0 = Get-Date
& (Get-Process -Id $PID).Path -NoProfile -File $suite *> $Out
$rc = $LASTEXITCODE
Pop-Location
Write-Output "suite exit $rc in $([int]((Get-Date) - $t0).TotalSeconds) s"
Get-Content -LiteralPath $Out | Select-String -Pattern '^(FAIL|SKIP)|passed, ' | ForEach-Object { $_.Line }
