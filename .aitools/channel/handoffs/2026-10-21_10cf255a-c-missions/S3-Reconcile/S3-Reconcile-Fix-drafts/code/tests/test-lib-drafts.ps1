# test-lib-drafts.ps1 LIBDIR TMPHOME -- Backup-Dir (L181b/c) on a patched aitools-lib.ps1
param([string]$LibDir, [string]$TmpHome)
$env:HOME = $TmpHome
$env:USERPROFILE = $TmpHome
. (Join-Path $LibDir "aitools-lib.ps1")
Initialize-Logging "rcfixc-test"
$d = Join-Path $TmpHome "cursor-rules"
New-Item -ItemType Directory -Path $d -Force | Out-Null
Set-Content -LiteralPath (Join-Path $d "a.mdc") -Value "x"
Backup-Dir -DirPath $d
$n = @(Get-ChildItem -LiteralPath $TmpHome -Directory | Where-Object { $_.Name -like "cursor-rules.bak.*" }).Count
if ($n -eq 1) { [Console]::WriteLine("PASS: mdc-only dir backed up") } else { [Console]::WriteLine("FAIL: mdc-only dir backed up ($n)") }
foreach ($i in 1..6) { New-Item -ItemType Directory -Path (Join-Path $TmpHome "cursor-rules.bak.2020-01-0${i}T000000Z") -Force | Out-Null }
Start-Sleep -Seconds 1
Backup-Dir -DirPath $d
$n = @(Get-ChildItem -LiteralPath $TmpHome -Directory | Where-Object { $_.Name -like "cursor-rules.bak.*" }).Count
if ($n -eq 5) { [Console]::WriteLine("PASS: pruned to 5") } else { [Console]::WriteLine("FAIL: pruned to 5 ($n)") }
