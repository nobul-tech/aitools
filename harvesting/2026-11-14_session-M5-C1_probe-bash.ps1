# probe-bash.ps1 -- which bash does a native pwsh (registry PATH, not Git Bash's PATH) resolve?
"System32\bash.exe exists: $(Test-Path (Join-Path $env:SystemRoot 'System32\bash.exe'))"
"WindowsApps\bash.exe exists: $(Test-Path (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\bash.exe'))"
foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe")) {
    "candidate $p exists: $(Test-Path -LiteralPath $p)"
}
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
"native PATH Get-Command bash -All:"
(Get-Command bash -All -ErrorAction SilentlyContinue).Source
