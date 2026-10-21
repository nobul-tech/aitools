. (Join-Path $PSScriptRoot "../liba/lib.ps1")
Write-Output ("caller=" + $PSScriptRoot)
Write-Output ("fromLibFunction=" + (Get-LibRoot))
