param([string]$Out, [string]$Variant = "plain", [string]$Extra = "")
# Runs msys-stty.sh in Git Bash inside this (driver-owned) console.
$ErrorActionPreference = "Stop"
$LogTag = "stty-$Variant"
. (Join-Path $PSScriptRoot "tcommon.ps1")
$bash = "C:\Program Files\Git\bin\bash.exe"
[Console]::Write("  stty prompt: ")
W "READY"
& $bash (($PSScriptRoot -replace '\\', '/') + "/msys-stty.sh") ($Out -replace '\\', '/') $Variant
W "bash exit code $LASTEXITCODE"
W "DONE"
Start-Sleep -Milliseconds 800
