# test-relay-outbound.ps1 -- the [RELAY] prompt scripts on Windows: the OS guards
# of scripts/relay-outbound-prompt.sh and .ps1, and the bash entry point's
# dependency on the .sh (scripts/aitools must hand off to aitools.ps1 before it
# could source relay-outbound-prompt.sh).
#
# What it checks:
#   - relay-outbound-prompt.ps1 loads on Windows: dot-sourced in a child pwsh, it
#     defines Invoke-RelayOutboundPrompt and Read-RelayOutboundChoice, and with
#     AITOOLS_SKIP_RELAY_PROMPT=1 the prompt returns 0 and prints nothing.
#   - Its guard has the canonical Windows form the OS guard classifier reads
#     (tests/os-guards), placed before the first function.
#   - relay-outbound-prompt.sh refuses Windows (Git Bash, isolated HOME): run, it
#     exits 1 with the structured line "[<UTC>] [relay-outbound-prompt] [error]
#     This script is for macOS/Linux ..." on stderr and writes nothing; sourced,
#     the source returns 1, relay_outbound_prompt stays undefined and the caller's
#     shell goes on.
#   - scripts/aitools: inside main(), the Windows case that calls
#     aitools_win_forward (and returns 1 when the forward cannot run) comes before
#     the line that sources relay-outbound-prompt.sh, so on Windows the bash entry
#     point never loads the .sh.
# The .sh pass side (it loads and runs on macOS/Linux) is covered by
# tests/relay-outbound/test-relay-outbound.sh; the .ps1 refusal on macOS/Linux by
# that suite and tests/os-guards.
#
# Git Bash runs only the product script under test, to prove that it refuses
# Windows (the tests/os-guards pattern); every check is made here, in pwsh.
#
# Usage: pwsh -NoProfile -File tests/relay-outbound/test-relay-outbound.ps1 [-Help]
# Safe to re-run: everything is written under a temp dir, removed on exit.
# Platform: Windows only (pwsh 7; OS guard below). Exit 1 if any case fails.

param([switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 30
    exit 0
}

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/relay-outbound/test-relay-outbound.sh with bash.")
    exit 1
}

$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
$scripts = Join-Path $root "scripts"
$relaySh = Join-Path $scripts "relay-outbound-prompt.sh"
$relayPs1 = Join-Path $scripts "relay-outbound-prompt.ps1"
$entry = Join-Path $scripts "aitools"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-relay-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

$script:pass = 0
$script:fail = 0
$script:skip = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ }
    else { Write-Output "FAIL $Name$(if ($Detail) { " -- $Detail" })"; $script:fail++ }
}
function Skip([string]$Name, [string]$Why) { Write-Output "SKIP $Name ($Why)"; $script:skip++ }

# Run-Native FILE ARGS [ENV]: run a program with each argument passed as is
# (ProcessStartInfo.ArgumentList), stdin closed at once (end of input), stdout
# and stderr read as UTF-8 (no console code page); ENV entries are set for the
# child only. Returns rc, out, err.
function Run-Native([string]$File, [string[]]$Arguments, [hashtable]$Env = @{}) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    foreach ($k in $Env.Keys) { $psi.Environment[$k] = $Env[$k] }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(120000)) {
        $p.Kill($true)
        return [pscustomobject]@{ rc = -1; out = $outTask.Result; err = "timeout after 120 s`n" + $errTask.Result }
    }
    $p.WaitForExit()
    return [pscustomobject]@{ rc = $p.ExitCode; out = $outTask.Result; err = $errTask.Result }
}

# Files under DIR other than the given relative prefixes
function Get-Stray([string]$Dir) {
    @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force -ErrorAction Stop | ForEach-Object { $_.FullName.Substring($Dir.Length + 1) } |
        Where-Object { $_ -notmatch '^\.aitools\\logs\\' })
}

$pwshExe = [Environment]::ProcessPath

try {
    # -----------------------------------------------------------------------
    # relay-outbound-prompt.ps1 on Windows
    # -----------------------------------------------------------------------
    $ps1Text = [IO.File]::ReadAllText($relayPs1) -replace "`r", ""
    $guardRe = '-not \$IsWindows\)\s*\{[^}]{0,300}?This script is for Windows[^}]{0,200}?exit 1'
    Check "ps1 guard: canonical Windows form (classifier regex)" ($ps1Text -match $guardRe)
    $guardAt = ([regex]::Match($ps1Text, $guardRe)).Index
    $fnAt = $ps1Text.IndexOf("function ")
    Check "ps1 guard: before the first function" ($guardAt -gt 0 -and $fnAt -gt $guardAt) "guard at $guardAt, first function at $fnAt"
    $lineOk = ($ps1Text -match '\[Console\]::Error\.WriteLine\("\[" \+ \[DateTime\]::UtcNow\.ToString\("yyyy-MM-dd''T''HH:mm:ss''Z''"') -and
        ($ps1Text -match '\] \[relay-outbound-prompt\] \[error\] This script is for Windows\. On macOS/Linux, use relay-outbound-prompt\.sh\.')
    Check "ps1 guard: structured line on stderr ([relay-outbound-prompt] [error], UTC time)" $lineOk

    $probe = Join-Path $tmpRoot "probe-ps1.ps1"
    $probeText = @"
`$env:AITOOLS_SKIP_RELAY_PROMPT = '1'
. '$($relayPs1 -replace "'", "''")'
'defined=' + [bool](Get-Command Invoke-RelayOutboundPrompt -CommandType Function -ErrorAction SilentlyContinue) + ',' + [bool](Get-Command Read-RelayOutboundChoice -CommandType Function -ErrorAction SilentlyContinue)
'rc=' + (Invoke-RelayOutboundPrompt -RepoPath '$($root -replace "'", "''")')
"@
    [IO.File]::WriteAllText($probe, $probeText, (New-Object Text.UTF8Encoding($false)))
    $r = Run-Native $pwshExe @("-NoProfile", "-NonInteractive", "-File", $probe)
    Check "ps1 on Windows: dot-source exits 0" ($r.rc -eq 0) "rc=$($r.rc) err=$($r.err.Trim())"
    Check "ps1 on Windows: both functions defined" ($r.out -match 'defined=True,True') $r.out.Trim()
    $outJoined = (($r.out -split "`r?`n") | Where-Object { $_ }) -join "|"
    Check "ps1 on Windows: AITOOLS_SKIP_RELAY_PROMPT=1 returns 0, nothing else printed" ($outJoined -ceq "defined=True,True|rc=0") $outJoined
    Check "ps1 on Windows: no guard message" ($r.err -notmatch 'This script is for') $r.err.Trim()

    # -----------------------------------------------------------------------
    # relay-outbound-prompt.sh refuses Windows (Git Bash)
    # -----------------------------------------------------------------------
    . (Join-Path $scripts "check-lib.ps1")
    $gitBash = ResolveGitBash
    if (-not $gitBash) {
        Skip "sh refuses Windows (run and sourced)" "Git Bash not found (Git for Windows locations)"
    } else {
        $home1 = Join-Path $tmpRoot "home-run"
        New-Item -ItemType Directory -Path $home1 | Out-Null
        $shPath = $relaySh -replace '\\', '/'
        $r = Run-Native $gitBash @($shPath, ($root -replace '\\', '/')) @{ HOME = $home1; USERPROFILE = $home1 }
        Check "sh run on Windows: exit 1" ($r.rc -eq 1) "rc=$($r.rc)"
        Check "sh run on Windows: structured guard line on stderr" `
            ($r.err -match '(?m)^\[\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\] \[relay-outbound-prompt\] \[error\] This script is for macOS/Linux\. On Windows, use relay-outbound-prompt\.ps1') $r.err.Trim()
        Check "sh run on Windows: nothing on stdout" ($r.out -eq "") $r.out.Trim()
        $stray = Get-Stray $home1
        Check "sh run on Windows: writes nothing under HOME" ($stray.Count -eq 0) ($stray -join ", ")

        $home2 = Join-Path $tmpRoot "home-src"
        New-Item -ItemType Directory -Path $home2 | Out-Null
        $cmd = "source '$shPath'; rc=`$?; if type relay_outbound_prompt >/dev/null 2>&1; then echo defined; else echo undefined; fi; echo rc=`$rc; echo alive"
        $r = Run-Native $gitBash @("-c", $cmd) @{ HOME = $home2; USERPROFILE = $home2 }
        $lines = (($r.out -split "`r?`n") | Where-Object { $_ }) -join "|"
        Check "sh sourced on Windows: source returns 1, function undefined, caller goes on" ($lines -ceq "undefined|rc=1|alive") "stdout=$lines rc=$($r.rc)"
        Check "sh sourced on Windows: caller exits 0" ($r.rc -eq 0) "rc=$($r.rc)"
        Check "sh sourced on Windows: structured guard line on stderr" ($r.err -match '\[relay-outbound-prompt\] \[error\] This script is for macOS/Linux') $r.err.Trim()
    }

    # -----------------------------------------------------------------------
    # scripts/aitools: the Windows hand-off comes before the relay source
    # -----------------------------------------------------------------------
    $lines = [IO.File]::ReadAllLines($entry)
    $mainAt = -1; $fwdAt = -1; $retAt = -1; $robAt = -1; $srcAt = -1; $mainEnd = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($mainAt -lt 0 -and $l -match '^main\(\) \{') { $mainAt = $i }
        if ($mainAt -ge 0 -and $fwdAt -lt 0 -and $l -match '^\s+aitools_win_forward "\$@"\s*$') { $fwdAt = $i }
        if ($fwdAt -ge 0 -and $retAt -lt 0 -and $l -match '^\s+return 1 ;;') { $retAt = $i }
        if ($l -match '^_rob="\$repo_path/scripts/relay-outbound-prompt\.sh"') { $robAt = $i }
        if ($robAt -ge 0 -and $srcAt -lt 0 -and $l -match '^\s+source "\$_rob"') { $srcAt = $i }
        if ($l -match '^main "\$@"; exit') { $mainEnd = $i }
    }
    Check "entry: main() found" ($mainAt -ge 0)
    Check "entry: the Windows case calls aitools_win_forward inside main()" ($fwdAt -gt $mainAt -and $mainAt -ge 0) "main at $($mainAt + 1), forward at $($fwdAt + 1)"
    Check "entry: a failed forward returns 1 (the script goes no further on Windows)" ($retAt -eq $fwdAt + 1) "forward at $($fwdAt + 1), return at $($retAt + 1)"
    $caseOk = $false
    if ($fwdAt -ge 2) { $caseOk = ($lines[$fwdAt - 1] -match '^\s+MINGW\*\|MSYS\*\|CYGWIN\*\)\s*$') -and ($lines[$fwdAt - 2] -match '^case "\$\(uname -s\)" in\s*$') }
    Check "entry: the forward is the MINGW/MSYS/CYGWIN case of uname -s" $caseOk
    Check "entry: relay-outbound-prompt.sh is sourced only after the forward, inside main()" `
        ($robAt -gt $retAt -and $srcAt -gt $robAt -and $mainEnd -gt $srcAt) "forward $($fwdAt + 1), _rob $($robAt + 1), source $($srcAt + 1), main call $($mainEnd + 1)"
    $otherSources = @()
    for ($i = 0; $i -lt $fwdAt; $i++) { if ($lines[$i] -match 'relay-outbound-prompt') { $otherSources += ($i + 1) } }
    Check "entry: nothing before the forward names relay-outbound-prompt" ($otherSources.Count -eq 0) ("lines " + ($otherSources -join ", "))
} finally {
    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot }
}

Write-Output "---- $($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
