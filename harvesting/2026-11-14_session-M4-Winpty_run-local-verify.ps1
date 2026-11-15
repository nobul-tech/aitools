# M4-Winpty: post-install verification on this workstation (probe + both managed-files suites)
$ErrorActionPreference = 'Continue'
$wt = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty'
$s = Join-Path $wt '.scratch\session-M4-Winpty'
Set-Location $wt
python tests\managed-files\winpty-probe.py 'C:\Program Files\Git\usr\bin\bash.exe' *> (Join-Path $s 'probe.log')
"probe exit $LASTEXITCODE" | Out-File (Join-Path $s 'verify-summary.log')
& 'C:\Program Files\Git\bin\bash.exe' tests/managed-files/test-managed-files.sh *> (Join-Path $s 'mf-sh.log')
"mf-sh exit $LASTEXITCODE" | Out-File -Append (Join-Path $s 'verify-summary.log')
pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1 *> (Join-Path $s 'mf-ps.log')
"mf-ps exit $LASTEXITCODE" | Out-File -Append (Join-Path $s 'verify-summary.log')
