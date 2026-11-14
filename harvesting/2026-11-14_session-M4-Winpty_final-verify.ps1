# M4-Winpty: final verification of the PEP 668 change before commit
$wt = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty'
$s = Join-Path $wt '.scratch\session-M4-Winpty'
$bash = 'C:\Program Files\Git\bin\bash.exe'
Set-Location $wt
$sum = Join-Path $s 'final-summary.log'
"" | Out-File $sum
pwsh -NoProfile -File (Join-Path $s 'parse.ps1') (Join-Path $wt 'scripts\setup-pywinpty.ps1') (Join-Path $wt 'tests\pywinpty\test-setup-pywinpty.ps1') *>> $sum
$nonAscii = Select-String -Path (Join-Path $wt 'scripts\setup-pywinpty.ps1') -Pattern '[^\x00-\x7F]'
"non-ascii lines in setup-pywinpty.ps1: $(@($nonAscii).Count)" | Out-File -Append $sum
pwsh -NoProfile -File tests/pywinpty/test-setup-pywinpty.ps1 *> (Join-Path $s 'f-ps1.log'); "pywinpty ps1 exit $LASTEXITCODE" | Out-File -Append $sum
Get-Content (Join-Path $s 'f-ps1.log') -Tail 1 | Out-File -Append $sum
& $bash tests/pywinpty/test-setup-pywinpty.sh *> (Join-Path $s 'f-sh.log'); "pywinpty sh exit $LASTEXITCODE" | Out-File -Append $sum
Get-Content (Join-Path $s 'f-sh.log') -Tail 1 | Out-File -Append $sum
& $bash tests/os-guards/test-os-guards.sh *> (Join-Path $s 'f-os.log'); "os-guards exit $LASTEXITCODE" | Out-File -Append $sum
Get-Content (Join-Path $s 'f-os.log') -Tail 1 | Out-File -Append $sum
pwsh -NoProfile -File (Join-Path $s 'verify-pep668.ps1') *> (Join-Path $s 'f-pep668.log'); "pep668 proof exit $LASTEXITCODE" | Out-File -Append $sum
pwsh -NoProfile -NonInteractive -File scripts/setup-pywinpty.ps1 *> (Join-Path $s 'real-run-3.log'); "real run exit $LASTEXITCODE" | Out-File -Append $sum
Get-Content (Join-Path $s 'real-run-3.log') | Select-String 'verified|installed|WARN|error' | ForEach-Object { "  $_" } | Out-File -Append $sum
pwsh -NoProfile -File scripts/check-pre-commit.ps1 *> (Join-Path $s 'f-pre-commit.log'); "pre-commit exit $LASTEXITCODE" | Out-File -Append $sum
Get-Content (Join-Path $s 'f-pre-commit.log') | Select-String 'FAIL|SUMMARY' | ForEach-Object { "  $_" } | Out-File -Append $sum
pwsh -NoProfile -File scripts/check-pre-push.ps1 *> (Join-Path $s 'f-pre-push.log'); "pre-push exit $LASTEXITCODE" | Out-File -Append $sum
Get-Content (Join-Path $s 'f-pre-push.log') | Select-String 'FAIL|SUMMARY' | ForEach-Object { "  $_" } | Out-File -Append $sum
