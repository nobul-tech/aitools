param([string]$Out)
# Target for driver-reask.ps1: the integration tree's aitools-lib.ps1, one
# Deploy-ManagedFile review (LOCAL differs from SOURCE, adopt target given).
function W([string]$s) { Add-Content -LiteralPath $Out -Value ("{0:HH:mm:ss.fff} {1}" -f (Get-Date), $s) }
$env:AITOOLS_LOG_DIR = Join-Path $PSScriptRoot "liblogs"
if (Test-Path $env:AITOOLS_LOG_DIR) { Remove-Item -Recurse -Force $env:AITOOLS_LOG_DIR }
. (Join-Path $PSScriptRoot "..\..\..\scripts\aitools-lib.ps1")
Initialize-Logging "conpty-reask"
$work = Join-Path $PSScriptRoot "work"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$dest = Join-Path $work "menu-target.md"
$repo = Join-Path $work "repo-menu-target.md"
Set-Content -LiteralPath $dest -Value "line one`nlocal only line"
Set-Content -LiteralPath $repo -Value "line one`nsource only line"
W "READY"
$r = Deploy-ManagedFile -Content "line one`nsource only line" -DestPath $dest -ToolName "probe" -ItemName "menu-target.md" -AdoptPath $repo
W "Deploy-ManagedFile returned: $r"
W ("dest now: " + ((Get-Content -LiteralPath $dest -Raw) -replace "`r?`n", " | "))
Get-Content (Join-Path $env:AITOOLS_LOG_DIR "deploy.log") | Where-Object { $_ -match 'menu answer|\[warn\]|\[error\]' } | ForEach-Object { W "log: $_" }
W "DONE"
Start-Sleep -Seconds 1
