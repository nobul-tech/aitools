# test-backup-literal.ps1 -- Backup-File with [ ] in the name (scratch test)
$ErrorActionPreference = 'Stop'
. /Users/new-jose/repos/aitools/scripts/aitools-lib.ps1
$dir = Join-Path ([IO.Path]::GetTempPath()) ("bk-test-" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $dir | Out-Null
$f = Join-Path $dir 'rule[1].md'
[IO.File]::WriteAllText($f, "x")
function LogWarn { param($m) Write-Output "WARN: $m" }
function Log { param($m) Write-Output "LOG: $m" }
for ($i = 0; $i -lt 3; $i++) {
    Backup-File -FilePath $f -MaxBackups 2
    Start-Sleep -Milliseconds 1100
}
$baks = @(Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -ne 'rule[1].md' })
Write-Output "BackupFileOk=$script:BackupFileOk backups=$($baks.Count)"
if ($script:BackupFileOk -and $baks.Count -eq 2) { Write-Output "PASS" } else { Write-Output "FAIL"; exit 1 }
$d = Join-Path $dir 'rules[x]'
New-Item -ItemType Directory -Path $d | Out-Null
[IO.File]::WriteAllText((Join-Path $d 'a.md'), "y")
Backup-Dir -DirPath $d
$dbaks = @(Get-ChildItem -LiteralPath $dir -Directory | Where-Object { $_.Name -like 'rules`[x`].bak.*' })
if ($dbaks.Count -eq 1) { Write-Output "PASS dir" } else { Write-Output "FAIL dir ($($dbaks.Count))"; exit 1 }
Remove-Item -LiteralPath $dir -Recurse -Force
