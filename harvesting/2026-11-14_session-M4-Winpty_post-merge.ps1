# M4-Winpty: post-merge verification -- new suites, managed-files suites, pre-commit / pre-push
$wt = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty'
$s = Join-Path $wt '.scratch\session-M4-Winpty'
$bash = 'C:\Program Files\Git\bin\bash.exe'
Set-Location $wt
$sum = Join-Path $s 'post-merge-summary.log'
"" | Out-File $sum
pwsh -NoProfile -File tests/pywinpty/test-setup-pywinpty.ps1 *> (Join-Path $s 'pm-pywinpty-ps1.log'); "pywinpty ps1 exit $LASTEXITCODE" | Out-File -Append $sum
& $bash tests/pywinpty/test-setup-pywinpty.sh *> (Join-Path $s 'pm-pywinpty-sh.log'); "pywinpty sh exit $LASTEXITCODE" | Out-File -Append $sum
& $bash tests/managed-files/test-managed-files.sh *> (Join-Path $s 'pm-mf-sh.log'); "mf sh exit $LASTEXITCODE" | Out-File -Append $sum
pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1 *> (Join-Path $s 'pm-mf-ps.log'); "mf ps exit $LASTEXITCODE" | Out-File -Append $sum
& $bash tests/os-guards/test-os-guards.sh *> (Join-Path $s 'pm-os-guards.log'); "os-guards exit $LASTEXITCODE" | Out-File -Append $sum
pwsh -NoProfile -File scripts/check-pre-commit.ps1 *> (Join-Path $s 'pm-pre-commit.log'); "pre-commit exit $LASTEXITCODE" | Out-File -Append $sum
pwsh -NoProfile -File scripts/check-pre-push.ps1 *> (Join-Path $s 'pm-pre-push.log'); "pre-push exit $LASTEXITCODE" | Out-File -Append $sum
