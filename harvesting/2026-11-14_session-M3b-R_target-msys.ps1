param([string]$Out, [string]$Variant = "raw", [string]$Extra = "2E8")
# Bash decision evidence: Git Bash (MSYS) `IFS= read -r x < /dev/tty` in a Windows
# console whose input mode a previous child left raw (-Variant raw) or not (-Variant none).
$ErrorActionPreference = "Stop"
$LogTag = "msys-$Variant"
. (Join-Path $PSScriptRoot "tcommon.ps1")
$bash = "C:\Program Files\Git\bin\bash.exe"
if ($Variant -eq "raw") {
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot "setraw.ps1") -Mode $Extra -Out $Out
}
$outUnix = ($Out -replace '\\', '/')
[Console]::Write("  msys prompt: ")
W "READY"
& $bash (($PSScriptRoot -replace '\\', '/') + "/msys-read.sh") $outUnix
W "bash exit code $LASTEXITCODE"
W "DONE"
Start-Sleep -Milliseconds 800
