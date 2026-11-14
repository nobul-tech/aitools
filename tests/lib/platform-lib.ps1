# platform-lib.ps1 -- shared helpers for the Windows (.ps1) harnesses of the
# platform-targeted test suites (dot-sourced, not run).
#
# Commander, 2026-11-14: "sh scripts and tests should only run on linux/mac
# and ps1 on windows", unless a script or suite is explicitly marked
# cross-platform (the "OS guard exemptions" table of
# .claude/rules/cross-platform.md). A suite that covers a .sh/.ps1 script pair
# therefore has two harnesses:
#   tests/<dir>/test-<name>.sh    macOS/Linux: runs the .sh scripts (bash)
#   tests/<dir>/test-<name>.ps1   Windows: runs the .ps1 scripts (native pwsh)
# Both compare their results with the same committed golden files
# (tests/<dir>/golden/, plans/ci-platform-targeting.md "golden results").
# Test-GoldenMatch is the twin of golden_match in tests/lib/platform-lib.sh:
# the same lookup (NAME.windows before NAME) and the same normalization.
#
# Provides:
#   New-TestTempRoot PREFIX     a new empty temp directory, long path form, under
#                               RUNNER_TEMP when set (CI), else the user temp dir
#   Remove-TestTempRoot PATH    removes it; a failure is printed, not thrown
#   Test-GoldenMatch NAME FILE  $true when FILE, normalized, equals
#                               $GoldenDir/NAME.windows if that exists, else
#                               $GoldenDir/NAME; otherwise prints the difference
#                               (lines prefixed "      | ") and returns $false.
#                               Set $GoldenDir and $GoldenTmp (the suite's temp
#                               root) in the suite's script scope first. Never
#                               writes a golden file: they are written from a
#                               macOS/Linux .sh run (AITOOLS_TEST_UPDATE_GOLDEN=1).
#   ConvertTo-GoldenText TEXT TMP   the normalized text (Test-GoldenMatch's rule)
#   Invoke-TestScript -FilePath P [-ArgumentList A] [-Environment H] -OutFile F
#                     [-WorkingDirectory D]
#                               runs P with the variables in H set ($null value:
#                               removed) and restored afterwards, stdin at EOF,
#                               stdout and stderr to F; returns the exit code
#   Resolve-TestGitBash         Git for Windows bash.exe, never the WSL launcher;
#                               $null when Git for Windows is absent. For cases
#                               that test cross-platform bash code (build-deploy.sh,
#                               hooks, the scripts/aitools entry point). It is
#                               ResolveGitBash of scripts/check-lib.ps1, loaded
#                               from that file's syntax tree (one source).
#   ConvertTo-MsysPath PATH     C:\a\b -> /c/a/b (a path argument for Git Bash)
#
# Normalization (as _golden_normalize in platform-lib.sh): CR removed; the temp
# root in its native (C:\...), mixed (C:/...) and MSYS (/c/...) forms, matched
# without regard to case, replaced by <TMP>, with backslashes in the rest of
# that path (up to whitespace, | or ") turned into slashes.
# Platform: Windows, pwsh 7. The harnesses that dot-source it refuse other
# platforms with their own OS guard.

function New-TestTempRoot {
    param([Parameter(Mandatory)][string]$Prefix)
    $base = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
    $base = Get-TestLongPath $base
    $dir = Join-Path $base ($Prefix + "-" + [guid]::NewGuid().ToString("N").Substring(0, 12))
    New-Item -ItemType Directory -Path $dir -ErrorAction Stop | Out-Null
    return $dir
}

function Remove-TestTempRoot {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return }
    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host "      | could not remove the temp root ${Path}: $($_.Exception.Message)"
    }
}

# Get-TestLongPath PATH: PATH with 8.3 short components (RUNNER~1) expanded, so
# the temp root has one spelling for the golden normalization.
function Get-TestLongPath {
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -notmatch '~') { return $Path }
    if (-not ('AitTestLongPath' -as [type])) {
        Add-Type -Namespace '' -Name 'AitTestLongPath' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern uint GetLongPathName(string shortPath, System.Text.StringBuilder longPath, uint bufferLength);
'@
    }
    $sb = [Text.StringBuilder]::new(1024)
    $n = [AitTestLongPath]::GetLongPathName($Path, $sb, [uint32]$sb.Capacity)
    if ($n -eq 0 -or $n -gt $sb.Capacity) {
        throw "GetLongPathName failed for $Path (returned $n)"
    }
    return $sb.ToString()
}

function ConvertTo-GoldenText {
    param([AllowEmptyString()][string]$Text, [string]$Tmp)
    $t = $Text -replace "`r", ""
    if ($Tmp) {
        $native = $Tmp.TrimEnd('\', '/') -replace '/', '\'
        $mixed = $native -replace '\\', '/'
        $forms = @($native, $mixed)
        if ($native -match '^([A-Za-z]):\\(.*)$') {
            $forms += "/" + $Matches[1].ToLowerInvariant() + "/" + ($Matches[2] -replace '\\', '/')
        }
        foreach ($f in $forms) {
            $re = [regex]::new([regex]::Escape($f) + '([^\s|"]*)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $t = $re.Replace($t, { param($m) "<TMP>" + ($m.Groups[1].Value -replace '\\', '/') })
        }
    }
    return $t
}

function Test-GoldenMatch {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$File)
    $dir = Get-Variable -Name GoldenDir -ValueOnly -ErrorAction SilentlyContinue
    $tmp = Get-Variable -Name GoldenTmp -ValueOnly -ErrorAction SilentlyContinue
    if (-not $dir) {
        Write-Host "      | Test-GoldenMatch: `$GoldenDir is not set"
        return $false
    }
    if ($env:AITOOLS_TEST_UPDATE_GOLDEN -eq "1") {
        Write-Host "      | golden files are written from a macOS/Linux .sh run only"
        return $false
    }
    $golden = Join-Path $dir $Name
    if (Test-Path -LiteralPath "$golden.windows" -PathType Leaf) { $golden = "$golden.windows" }
    if (-not (Test-Path -LiteralPath $golden -PathType Leaf)) {
        Write-Host "      | missing golden file $golden (write it: AITOOLS_TEST_UPDATE_GOLDEN=1 on macOS/Linux)"
        return $false
    }
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        Write-Host "      | no result file $File"
        return $false
    }
    $want = [IO.File]::ReadAllText($golden)
    $got = ConvertTo-GoldenText ([IO.File]::ReadAllText($File)) $tmp
    if ($got -ceq $want) { return $true }
    $label = Split-Path -Leaf $golden
    Write-Host "      | differs from golden $label (- golden, + ps1):"
    $wantLines = @($want -split "`n")
    $gotLines = @($got -split "`n")
    $shown = 0
    $diff = Compare-Object -ReferenceObject $wantLines -DifferenceObject $gotLines -CaseSensitive -SyncWindow ([Math]::Max($wantLines.Count, $gotLines.Count))
    foreach ($d in $diff) {
        if ($shown -ge 30) { break }
        $sign = if ($d.SideIndicator -eq '<=') { '-' } else { '+' }
        Write-Host "      | $sign $($d.InputObject)"
        $shown++
    }
    if ($shown -eq 0) { Write-Host "      | (same lines, different order or trailing newline)" }
    return $false
}

function Invoke-TestScript {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [hashtable]$Environment = @{},
        [Parameter(Mandatory)][string]$OutFile,
        [string]$WorkingDirectory
    )
    $saved = @{}
    foreach ($k in @($Environment.Keys)) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $Environment[$k])
    }
    if ($WorkingDirectory) { Push-Location -LiteralPath $WorkingDirectory }
    try {
        $null | & $FilePath @ArgumentList *> $OutFile
        $rc = $LASTEXITCODE
    } finally {
        if ($WorkingDirectory) { Pop-Location }
        foreach ($k in @($saved.Keys)) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    return $rc
}

function ConvertTo-MsysPath {
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -match '^([A-Za-z]):[\\/](.*)$') {
        return "/" + $Matches[1].ToLowerInvariant() + "/" + ($Matches[2] -replace '\\', '/')
    }
    return ($Path -replace '\\', '/')
}

# ResolveGitBash, defined from its source in scripts/check-lib.ps1 without
# running that file (loading check-lib would also load aitools-lib and change
# PATH). A parse failure or a missing function throws: the suite cannot run.
# $PSScriptRoot is this file's directory (tests/lib) even when dot-sourced.
$_aitPlatformLibCheckLib = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "scripts/check-lib.ps1"
$_aitParseErrors = $null
$_aitAst = [System.Management.Automation.Language.Parser]::ParseFile($_aitPlatformLibCheckLib, [ref]$null, [ref]$_aitParseErrors)
if ($_aitParseErrors) { throw "platform-lib.ps1: cannot parse $_aitPlatformLibCheckLib" }
$_aitFn = $_aitAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'ResolveGitBash' }, $true)
if (-not $_aitFn) { throw "platform-lib.ps1: ResolveGitBash not found in $_aitPlatformLibCheckLib" }
. ([scriptblock]::Create($_aitFn.Extent.Text))
Remove-Variable -Name _aitPlatformLibCheckLib, _aitParseErrors, _aitAst, _aitFn

function Resolve-TestGitBash { ResolveGitBash }
