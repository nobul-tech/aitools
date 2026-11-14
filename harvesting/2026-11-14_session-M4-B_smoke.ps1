# smoke.ps1 -- M4-B smoke cases for scripts/setup-pywinpty.ps1, each in an isolated
# APPDATA (pip --user target), log dir, summary file and pip cache. Never the real APPDATA.
param([string[]]$Only = @())
$ErrorActionPreference = 'Continue'
$wt = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty'
$script = Join-Path $wt 'scripts\setup-pywinpty.ps1'
$scratch = Join-Path $wt '.scratch\session-M4-B'
$runRoot = Join-Path $scratch ('run-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
$pwshExe = (Get-Process -Id $PID).Path
$uvPy = 'C:\Users\jdpal\AppData\Roaming\uv\python\cpython-3.14-windows-x86_64-none\python.exe'
$savedPath = $env:PATH
$sharedAppData = Join-Path $runRoot 'appdata-shared'
New-Item -ItemType Directory -Force -Path $sharedAppData | Out-Null

# MDM simulation copy: the dot-source line replaced by the lib + the embedded pin, the
# way build-deploy.sh inline_lib_ps1 does it (perl, first ". ... aitools-lib.ps1" line).
$mdmDir = Join-Path $runRoot 'mdm'
New-Item -ItemType Directory -Force -Path $mdmDir | Out-Null
$blk = Join-Path $runRoot 'embed.blk'
$pinText = [IO.File]::ReadAllText((Join-Path $wt 'scripts\requirements-pywinpty.txt'))
[IO.File]::WriteAllText($blk, "`$AitoolsEmbeddedPywinptyPin = @'`n" + $pinText.TrimEnd() + "`n'@`n", [Text.UTF8Encoding]::new($false))
$mdmScript = Join-Path $mdmDir 'setup-pywinpty.ps1'
$perlCode = 'open my $lib, "<", $ARGV[0] or die; my $c = do { local $/; <$lib> }; close $lib; $c .= "\n" unless $c =~ /\n\z/; open my $b, "<", $ARGV[1] or die; $c .= do { local $/; <$b> }; close $b; my $d = 0; open my $s, "<", $ARGV[2] or die; open my $o, ">", $ARGV[3] or die; while (<$s>) { if (!$d && /^\s*\.\s.*aitools-lib\.ps1/) { print $o $c; $d = 1 } else { print $o $_ } } close $o; die "not inlined\n" unless $d;'
$env:PERLIO = ':perlio'
& perl -e $perlCode (Join-Path $wt 'scripts\aitools-lib.ps1') $blk $script $mdmScript
if ($LASTEXITCODE -ne 0) { "MDM build failed (perl exit $LASTEXITCODE)"; exit 1 }
"MDM copy: $mdmScript (lines: $((Get-Content $mdmScript).Count); embedded var lines: $((Select-String -Path $mdmScript -Pattern 'AitoolsEmbeddedPywinptyPin = @').Count))"

function Invoke-Case {
    param([string]$Name, [string]$ScriptPath, [string[]]$ScriptArgs = @(), [hashtable]$Env = @{}, [string]$AppData = '', [string]$PathValue = '')
    if ($Only.Count -gt 0 -and $Only -notcontains $Name) { return }
    $caseDir = Join-Path $runRoot $Name
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    if (-not $AppData) { $AppData = Join-Path $caseDir 'appdata'; New-Item -ItemType Directory -Force -Path $AppData | Out-Null }
    $saved = @{}
    $vars = @{ APPDATA = $AppData; AITOOLS_LOG_DIR = (Join-Path $caseDir 'logs'); AITOOLS_SUMMARY_FILE = (Join-Path $caseDir 'summary.txt'); PIP_CACHE_DIR = (Join-Path $caseDir 'pipcache'); AITOOLS_DRY_RUN = $null; AITOOLS_PYWINPTY_PIN = $null; AITOOLS_PYWINPTY_PYTHON = $null }
    foreach ($k in $Env.Keys) { $vars[$k] = $Env[$k] }
    foreach ($k in $vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
    New-Item -ItemType File -Force -Path $vars.AITOOLS_SUMMARY_FILE | Out-Null
    if ($PathValue) { $env:PATH = $PathValue }
    $out = Join-Path $caseDir 'console.log'
    & $pwshExe -NoProfile -NonInteractive -File $ScriptPath @ScriptArgs *> $out
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

Invoke-Case -Name 'a-dryrun' -ScriptPath $script -ScriptArgs @('-DryRun')
Invoke-Case -Name 'b-install' -ScriptPath $script -AppData $sharedAppData
Invoke-Case -Name 'c-rerun' -ScriptPath $script -AppData $sharedAppData
Invoke-Case -Name 'd-pin-missing' -ScriptPath $script -Env @{ AITOOLS_PYWINPTY_PIN = (Join-Path $runRoot 'no-such-pin.txt') }
Invoke-Case -Name 'e-python-override-missing' -ScriptPath $script -Env @{ AITOOLS_PYWINPTY_PYTHON = (Join-Path $runRoot 'no-such\python.exe') } -PathValue 'C:\Windows\System32;C:\Windows'
Invoke-Case -Name 'e2-no-python-on-path' -ScriptPath $script -PathValue 'C:\Windows\System32;C:\Windows'
Invoke-Case -Name 'f-mdm-dryrun' -ScriptPath $mdmScript -ScriptArgs @('-DryRun')
Invoke-Case -Name 'f2-mdm-env-dryrun' -ScriptPath $mdmScript -Env @{ AITOOLS_DRY_RUN = '1' }
Invoke-Case -Name 'f3-mdm-verified' -ScriptPath $mdmScript -AppData $sharedAppData
Invoke-Case -Name 'g-uv-externally-managed' -ScriptPath $script -Env @{ AITOOLS_PYWINPTY_PYTHON = $uvPy }
Invoke-Case -Name 'g2-uv-verified-shared-user-site' -ScriptPath $script -Env @{ AITOOLS_PYWINPTY_PYTHON = $uvPy } -AppData $sharedAppData
"run root: $runRoot"
