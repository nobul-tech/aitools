# smoke2.ps1 -- extra M4-B cases: bad hash (pip failure), uncovered tag, unreadable pin,
# and the e2 re-run after the "tried:" message fix. Isolated APPDATA per case.
$ErrorActionPreference = 'Continue'
$wt = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty'
$script = Join-Path $wt 'scripts\setup-pywinpty.ps1'
$runRoot = Join-Path $wt ('.scratch\session-M4-B\run2-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
$pwshExe = (Get-Process -Id $PID).Path
$savedPath = $env:PATH
$pin = [IO.File]::ReadAllText((Join-Path $wt 'scripts\requirements-pywinpty.txt'))

# Bad hashes: every sha256 replaced by zeros -> pip must refuse (hash mismatch)
$badHash = Join-Path $runRoot 'pin-badhash.txt'
[IO.File]::WriteAllText($badHash, ($pin -replace 'sha256:[0-9a-f]{64}', ('sha256:' + ('0' * 64))), [Text.UTF8Encoding]::new($false))
# Uncovered tag: wheel-tags lists only cp312
$noTag = Join-Path $runRoot 'pin-cp312only.txt'
[IO.File]::WriteAllText($noTag, ($pin -replace '(?m)^# wheel-tags:.*$', '# wheel-tags: cp312-win_amd64'), [Text.UTF8Encoding]::new($false))
# Unreadable: no pywinpty== line
$noVer = Join-Path $runRoot 'pin-nover.txt'
[IO.File]::WriteAllText($noVer, "# wheel-tags: cp314-win_amd64`n# nothing pinned`n", [Text.UTF8Encoding]::new($false))

function Invoke-Case {
    param([string]$Name, [hashtable]$Env = @{}, [string]$PathValue = '')
    $caseDir = Join-Path $runRoot $Name
    $appData = Join-Path $caseDir 'appdata'
    New-Item -ItemType Directory -Force -Path $appData | Out-Null
    $vars = @{ APPDATA = $appData; AITOOLS_LOG_DIR = (Join-Path $caseDir 'logs'); AITOOLS_SUMMARY_FILE = (Join-Path $caseDir 'summary.txt'); PIP_CACHE_DIR = (Join-Path $caseDir 'pipcache'); AITOOLS_DRY_RUN = $null; AITOOLS_PYWINPTY_PIN = $null; AITOOLS_PYWINPTY_PYTHON = $null }
    foreach ($k in $Env.Keys) { $vars[$k] = $Env[$k] }
    $saved = @{}
    foreach ($k in $vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
    New-Item -ItemType File -Force -Path $vars.AITOOLS_SUMMARY_FILE | Out-Null
    if ($PathValue) { $env:PATH = $PathValue }
    $out = Join-Path $caseDir 'console.log'
    & $pwshExe -NoProfile -NonInteractive -File $script *> $out
    $code = $LASTEXITCODE
    $env:PATH = $savedPath
    foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    "=== case $Name : exit $code"
    "--- summary rows:"
    Get-Content $vars.AITOOLS_SUMMARY_FILE
    "--- console:"
    Get-Content $out
    ""
}

Invoke-Case -Name 'h-bad-hash' -Env @{ AITOOLS_PYWINPTY_PIN = $badHash }
Invoke-Case -Name 'i-tag-not-covered' -Env @{ AITOOLS_PYWINPTY_PIN = $noTag }
Invoke-Case -Name 'j-pin-unreadable' -Env @{ AITOOLS_PYWINPTY_PIN = $noVer }
Invoke-Case -Name 'e2-no-python-on-path' -PathValue 'C:\Windows\System32;C:\Windows'
"run root: $runRoot"
