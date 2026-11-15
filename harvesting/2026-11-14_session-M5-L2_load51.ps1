# load51.ps1 -- dot-source a .ps1 under the running PowerShell and report whether a function got defined.
# Usage: powershell.exe -NoProfile -File load51.ps1 <file> <function-name>
param([string]$File, [string]$Fn)
try {
    . $File
    Write-Output ("dot-source OK [PS {0}]" -f $PSVersionTable.PSVersion)
} catch {
    Write-Output ("dot-source FAILED [PS {0}]: {1}" -f $PSVersionTable.PSVersion, $_.Exception.Message)
}
if (Get-Command $Fn -CommandType Function -ErrorAction SilentlyContinue) {
    Write-Output "$Fn defined"
} else {
    Write-Output "$Fn NOT defined"
}
