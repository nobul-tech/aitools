# M4-Winpty: prove the --target path against uv's EXTERNALLY-MANAGED CPython, isolated APPDATA
$ErrorActionPreference = 'Continue'
$wt = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty'
$s = Join-Path $wt '.scratch\session-M4-Winpty'
$script = Join-Path $wt 'scripts\setup-pywinpty.ps1'
$uvpy = (uv python find 3.14 --managed-python 2>&1 | Out-String).Trim()
$root = Join-Path $s ("pep668-" + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
New-Item -ItemType Directory -Force $root | Out-Null
$uvSite = Join-Path (Split-Path $uvpy) 'Lib\site-packages'
"uv python: $uvpy"
"marker: $(Test-Path (Join-Path (Split-Path $uvpy) 'Lib\EXTERNALLY-MANAGED'))"
"uv site-packages has winpty before: $(Test-Path (Join-Path $uvSite 'winpty'))"
$uvBefore = (Get-ChildItem -LiteralPath $uvSite | Measure-Object).Count

function Run-Case([string]$name, [string]$appdata, [string[]]$extra, [hashtable]$envs) {
    $logDir = Join-Path $root "$name-logs"; New-Item -ItemType Directory -Force $logDir | Out-Null
    $sumFile = Join-Path $root "$name-summary.txt"
    $env:APPDATA = $appdata
    $env:AITOOLS_LOG_DIR = $logDir
    $env:AITOOLS_SUMMARY_FILE = $sumFile
    $env:PIP_CACHE_DIR = Join-Path $root 'pipcache'
    $env:AITOOLS_PYWINPTY_PYTHON = $uvpy
    Remove-Item Env:PYTHONNOUSERSITE -ErrorAction SilentlyContinue
    if ($envs) { foreach ($k in $envs.Keys) { Set-Item "Env:$k" $envs[$k] } }
    pwsh -NoProfile -NonInteractive -File $script @extra *> (Join-Path $root "$name.out")
    $rc = $LASTEXITCODE
    "=== $name exit $rc"
    if (Test-Path $sumFile) { Get-Content $sumFile | ForEach-Object { "  row: $_" } }
    Get-Content (Join-Path $root "$name.out") | Where-Object { $_ -match 'Install mode|Would run|Running:|Removed stale|verified|installed|EXTERNALLY|error' } | ForEach-Object { "  log: $_" }
}

$A = Join-Path $root 'appdata-A'; New-Item -ItemType Directory -Force $A | Out-Null
Run-Case 'a-dryrun' $A @('-DryRun') $null
Run-Case 'b-install' $A @() $null
$usA = Join-Path $A 'Python\Python314\site-packages'
"  target has winpty: $(Test-Path (Join-Path $usA 'winpty'))"
Run-Case 'c-verified' $A @() $null

# Stale older install in the target: a pywinpty-3.1.1.dist-info beside the current one
$stale = Join-Path $usA 'pywinpty-3.1.1.dist-info'
Copy-Item -Recurse -LiteralPath (Join-Path $usA 'pywinpty-3.1.2.dist-info') -Destination $stale
(Get-Content (Join-Path $stale 'METADATA')) -replace '^Version: 3\.1\.2$', 'Version: 3.1.1' | Set-Content (Join-Path $stale 'METADATA')
Remove-Item -Recurse -Force -LiteralPath (Join-Path $usA 'pywinpty-3.1.2.dist-info')
"  seeded: only pywinpty-3.1.1.dist-info present"
Run-Case 'd-replace' $A @() $null
"  dist-infos after: $((Get-ChildItem -LiteralPath $usA -Directory -Filter 'pywinpty-*.dist-info').Name -join ', ')"

$B = Join-Path $root 'appdata-B'; New-Item -ItemType Directory -Force $B | Out-Null
Run-Case 'e-nousersite' $B @() @{ PYTHONNOUSERSITE = '1' }
"  B has Python dir: $(Test-Path (Join-Path $B 'Python'))"

"uv site-packages has winpty after: $(Test-Path (Join-Path $uvSite 'winpty'))"
"uv site-packages entry count before/after: $uvBefore / $((Get-ChildItem -LiteralPath $uvSite | Measure-Object).Count)"
