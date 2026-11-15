# M4-Winpty: run pre-commit and pre-push checks (.ps1 twins on Windows) from the worktree, logs to scratch
$wt = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty'
$s = Join-Path $wt '.scratch\session-M4-Winpty'
Set-Location $wt
pwsh -NoProfile -File (Join-Path $wt 'scripts\check-pre-commit.ps1') *> (Join-Path $s 'pre-commit.log')
"pre-commit exit $LASTEXITCODE" | Out-File (Join-Path $s 'checks-summary.log')
pwsh -NoProfile -File (Join-Path $wt 'scripts\check-pre-push.ps1') *> (Join-Path $s 'pre-push.log')
"pre-push exit $LASTEXITCODE" | Out-File -Append (Join-Path $s 'checks-summary.log')
