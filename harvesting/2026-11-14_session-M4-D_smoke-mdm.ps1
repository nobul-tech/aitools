# smoke-mdm.ps1 -- M4-D-Wire: run the GENERATED deploy/setup-pywinpty.ps1 (from the
# isolated build) from a temp dir with no requirements-pywinpty.txt beside it, in an
# isolated APPDATA / log dir / summary file / pip cache. Pattern from M4-B smoke.ps1.
$ErrorActionPreference = 'Continue'
$s = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty\.scratch\session-M4-D'
$gen = Join-Path $s 'dotprofile\deploy\setup-pywinpty.ps1'
$runRoot = Join-Path $s ('mdm-run-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
$bin = Join-Path $runRoot 'bin'
New-Item -ItemType Directory -Force -Path $bin | Out-Null
Copy-Item -LiteralPath $gen -Destination $bin
$script = Join-Path $bin 'setup-pywinpty.ps1'
"pin beside the copied script: $(Test-Path (Join-Path $bin 'requirements-pywinpty.txt'))"
$appData = Join-Path $runRoot 'appdata'
New-Item -ItemType Directory -Force -Path $appData | Out-Null
$pwshExe = (Get-Process -Id $PID).Path
"python3 on PATH: $((Get-Command python3 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source)"

function Invoke-Case {
    param([string]$Name, [string[]]$ScriptArgs = @())
    $caseDir = Join-Path $runRoot $Name
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    $vars = @{ APPDATA = $appData; AITOOLS_LOG_DIR = (Join-Path $caseDir 'logs'); AITOOLS_SUMMARY_FILE = (Join-Path $caseDir 'summary.txt'); PIP_CACHE_DIR = (Join-Path $runRoot 'pipcache'); AITOOLS_DRY_RUN = $null; AITOOLS_PYWINPTY_PIN = $null; AITOOLS_PYWINPTY_PYTHON = $null }
    $saved = @{}
    foreach ($k in $vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
    New-Item -ItemType File -Force -Path $vars.AITOOLS_SUMMARY_FILE | Out-Null
    $out = Join-Path $caseDir 'console.log'
    Push-Location $runRoot
    & $pwshExe -NoProfile -NonInteractive -File $script @ScriptArgs *> $out
    $code = $LASTEXITCODE
    Pop-Location
    foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    "=== case $Name : exit $code"
    "--- summary rows:"
    Get-Content $vars.AITOOLS_SUMMARY_FILE
    "--- console:"
    Get-Content $out
    ""
}

Invoke-Case -Name '1-dryrun' -ScriptArgs @('-DryRun')
Invoke-Case -Name '2-install'
Invoke-Case -Name '3-rerun'
"user site contents:"
Get-ChildItem -Recurse -Directory -Path $appData -Filter 'winpty' | ForEach-Object { $_.FullName }
"run root: $runRoot"
