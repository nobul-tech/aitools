$ErrorActionPreference = "Stop"
. /Users/new-jose/repos/aitools/scripts/aitools-lib.ps1
$T = "/tmp/aitools-rottest-ps"
if (Test-Path $T) { Remove-Item $T -Recurse -Force }
New-Item -ItemType Directory -Path $T -Force | Out-Null
$env:AITOOLS_LOG_DIR = $T

function Mk6Mb($p) {
    $fs = [System.IO.File]::Create($p)
    $fs.SetLength(6MB)
    $fs.Close()
}

Mk6Mb (Join-Path $T "deploy.log")
Initialize-Logging "rot-test"
Write-Host "after 1st rotate: $((Get-ChildItem $T | Sort-Object Name | ForEach-Object Name) -join ' ')"

Mk6Mb (Join-Path $T "deploy.log")
Initialize-Logging "rot-test"
Write-Host "after 2nd rotate: $((Get-ChildItem $T | Sort-Object Name | ForEach-Object Name) -join ' ')"

Get-ChildItem $T | Remove-Item -Force
Set-Content -Path (Join-Path $T "deploy.log") -Value "small"
Initialize-Logging "rot-test"
Write-Host "small (expect no .1): $((Get-ChildItem $T | Sort-Object Name | ForEach-Object Name) -join ' ')"

Remove-Item $T -Recurse -Force
$env:AITOOLS_LOG_DIR = $null
