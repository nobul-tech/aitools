# test-resolve-git-bash.ps1 -- tests for ResolveGitBash in scripts/check-lib.ps1,
# the managed Windows bash (Git Bash from Git for Windows) that the check-*.ps1
# scripts run .sh steps with, and for its callers.
#
# Safe to re-run: the probe cases use fake bash.exe files in a temp dir, removed
# on exit; nothing outside it is written.
# Platform: Windows only (pwsh 7; OS guard below). check-lib.ps1 and the
# check-*.ps1 scripts are Windows-only (OS guard) and ResolveGitBash has no bash
# twin, so there is no macOS/Linux side. Commander, 2026-11-14: "sh scripts and
# tests should only run on linux/mac and ps1 on windows". Exit 1 if any case fails.
# What it checks: the first existing candidate wins; a missing candidate is
# skipped; no existing candidate gives $null, never a fallback; a candidate under
# %SystemRoot% or the WindowsApps alias directory (the WSL launchers) is refused
# even when it exists; the default probe returns a Git for Windows bash.exe, never
# the bash a native PATH resolves to when that is a WSL launcher; and no
# check-*.ps1 resolves bash through Get-Command or runs a bare `bash`.
#
# Usage: pwsh -NoProfile -File tests/check-lib/test-resolve-git-bash.ps1 [-Help]

param([switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 17
    exit 0
}

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. ResolveGitBash and the check-*.ps1 scripts it serves are Windows-only, so there is no macOS/Linux side to run.")
    exit 1
}

$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
$scripts = Join-Path $root "scripts"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-gitbash-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

$script:pass = 0
$script:fail = 0
$script:skip = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ }
    else { Write-Output "FAIL $Name$(if ($Detail) { " -- $Detail" })"; $script:fail++ }
}
function Skip([string]$Name, [string]$Why) { Write-Output "SKIP $Name ($Why)"; $script:skip++ }

# fake <relative path>: an empty file standing in for a bash.exe; returns its path
function New-FakeBash([string]$Rel) {
    $p = Join-Path $tmpRoot $Rel
    New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
    [IO.File]::WriteAllText($p, "")
    return $p
}

try {
    # check-lib dot-sources aitools-lib; both only define functions and variables here
    . (Join-Path $scripts "check-lib.ps1")
    Check "lib: ResolveGitBash is defined by check-lib.ps1" ([bool](Get-Command ResolveGitBash -CommandType Function -ErrorAction SilentlyContinue))

    $gitA = New-FakeBash "a\Git\bin\bash.exe"
    $gitB = New-FakeBash "b\Git\bin\bash.exe"
    $missing = Join-Path $tmpRoot "missing\Git\bin\bash.exe"

    # -----------------------------------------------------------------------
    # Probe order, missing candidates, nothing found
    # -----------------------------------------------------------------------
    $r = ResolveGitBash -Candidates @($missing, $gitA, $gitB)
    Check "probe: a missing candidate is skipped, the first existing one wins" ($r -eq $gitA) "got '$r'"
    $r = ResolveGitBash -Candidates @($gitB, $gitA)
    Check "probe: the list order decides" ($r -eq $gitB) "got '$r'"
    $r = ResolveGitBash -Candidates @($missing)
    Check "probe: no existing candidate gives `$null (no PATH fallback)" ($null -eq $r) "got '$r'"
    $r = ResolveGitBash -Candidates @()
    Check "probe: an empty list gives `$null" ($null -eq $r) "got '$r'"
    $r = ResolveGitBash -Candidates @("", $null, $gitA)
    Check "probe: empty entries are ignored" ($r -eq $gitA) "got '$r'"
    $dirOnly = Join-Path $tmpRoot "dir\Git\bin\bash.exe"
    New-Item -ItemType Directory -Path $dirOnly -Force | Out-Null
    $r = ResolveGitBash -Candidates @($dirOnly)
    Check "probe: a directory named bash.exe is not a bash" ($null -eq $r) "got '$r'"

    # -----------------------------------------------------------------------
    # The WSL launchers are refused, whether or not they exist
    # -----------------------------------------------------------------------
    $winRoot = if ($env:SystemRoot) { $env:SystemRoot } else { "C:\Windows" }
    $sys32 = Join-Path $winRoot "System32\bash.exe"
    $sys32Lower = $sys32.ToLowerInvariant()
    $appsBash = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\bash.exe" } else { "" }
    $r = ResolveGitBash -Candidates @($sys32)
    Check "refuse: %SystemRoot%\System32\bash.exe (exists: $(Test-Path -LiteralPath $sys32)) gives `$null" ($null -eq $r) "got '$r'"
    $r = ResolveGitBash -Candidates @($sys32Lower, $gitA)
    Check "refuse: the System32 launcher is skipped in any letter case, the next candidate wins" ($r -eq $gitA) "got '$r'"
    $r = ResolveGitBash -Candidates @($appsBash, $gitB)
    Check "refuse: %LOCALAPPDATA%\Microsoft\WindowsApps\bash.exe (exists: $(Test-Path -LiteralPath $appsBash)) is skipped, the next candidate wins" ($r -eq $gitB) "got '$r'"

    # -----------------------------------------------------------------------
    # Default probe (Git for Windows locations) against this machine
    # -----------------------------------------------------------------------
    $r = ResolveGitBash
    $gitInstalled = @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe") | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
    if (@($gitInstalled).Count -eq 0) {
        Check "default: no Git for Windows install, so `$null" ($null -eq $r) "got '$r'"
    } else {
        Check "default: returns a Git for Windows bash.exe (\Git\bin\bash.exe)" (($null -ne $r) -and ($r -match '\\Git\\bin\\bash\.exe$')) "got '$r'"
    }
    # The bash a native pwsh sees: PATH rebuilt from the registry (this suite may
    # run under Git Bash, whose PATH puts Git's own bash first)
    $nativePath = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    $nativeBash = $null
    foreach ($dir in ($nativePath -split ';')) {
        if (-not $dir) { continue }
        $cand = Join-Path ([Environment]::ExpandEnvironmentVariables($dir)) "bash.exe"
        if (Test-Path -LiteralPath $cand -PathType Leaf) { $nativeBash = $cand; break }
    }
    $isLauncher = $nativeBash -and ($nativeBash -match '\\(System32|Microsoft\\WindowsApps)\\bash\.exe$')
    if ($isLauncher) {
        Check "default: not the WSL launcher a native PATH resolves bash to ($nativeBash)" ($r -ne $nativeBash) "got '$r'"
    } else {
        Skip "default: never the bash a native PATH resolves to when that is a WSL launcher" "native PATH bash is '$nativeBash', not a WSL launcher"
    }

    # -----------------------------------------------------------------------
    # Callers: no check-*.ps1 resolves bash through PATH or runs a bare bash
    # -----------------------------------------------------------------------
    $checks = @(Get-ChildItem -Path $scripts -Filter "check-*.ps1" -File)
    Check "callers: check-*.ps1 scripts found" ($checks.Count -gt 0) "found $($checks.Count)"
    $offenders = @()
    foreach ($f in $checks) {
        $errs = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
        if ($errs.Count -gt 0) { $offenders += "$($f.Name): parse error"; continue }
        $cmds = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
        foreach ($c in $cmds) {
            $name = $c.GetCommandName()
            if ($name -eq "bash" -or $name -eq "bash.exe") { $offenders += "$($f.Name):$($c.Extent.StartLineNumber): bare bash" }
            if ($name -eq "Get-Command" -and $c.CommandElements.Count -ge 2 -and $c.CommandElements[1].Extent.Text -match '^["'']?bash(\.exe)?["'']?$') {
                $offenders += "$($f.Name):$($c.Extent.StartLineNumber): Get-Command bash"
            }
        }
    }
    Check "callers: no check-*.ps1 runs a bare bash or resolves it with Get-Command bash" ($offenders.Count -eq 0) ($offenders -join "; ")
    $users = @("check-pre-commit.ps1", "check-pre-push.ps1", "check-post-push.ps1")
    foreach ($u in $users) {
        $text = [IO.File]::ReadAllText((Join-Path $scripts $u))
        Check "callers: $u calls ResolveGitBash" ($text -match '(?m)=\s*ResolveGitBash\s*$')
    }
} finally {
    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot }
}

Write-Output "---- $($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
