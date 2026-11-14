# test-profile.ps1 -- unit and parity tests for scripts/aitools-profile.ps1 (and
# its JSON engine scripts/aitools-json.ps1). The Windows harness of this suite;
# tests/profile/test-profile.sh is the macOS/Linux harness of the same cases for
# aitools-profile.sh and the perl engine aitools-json.pl.
#
# Every case runs the resolver in a child pwsh (-NoProfile -NonInteractive, stdin
# at EOF) with injected machine ids and hostnames, in an isolated HOME, and
# asserts expected values and exit codes.
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs aitools-profile.ps1 and aitools-json.ps1 with native pwsh on
# Windows only. HOME and USERPROFILE are both set; every path handed to the
# resolver (arguments, environment values, paths inside fixture files) is in the
# mixed form (C:/...), long (no 8.3 component), as the earlier Git Bash harness
# passed them (cygpath -m). Every spelling of the temp root the resolver prints
# (C:\..., C:/..., JSON-escaped C:\\..., /c/..., the 8.3 form) is mapped back to
# the mixed form, so one set of expectations serves every case. Parity with
# aitools-profile.sh is checked against the committed golden files
# tests/profile/golden/profile-* (Test-GoldenMatch in tests/lib/platform-lib.ps1):
# the .sh run on macOS/Linux and this run on Windows must both equal them.
# Invalid-JSON parser messages are cut after "is invalid JSON"; a written
# profile's own os and arch become <OS> and <ARCH>. Cases with no PowerShell
# partner (claude-code-web: Linux only; rev-m3-numbers and jr-keep-out: perl
# engine guarantees) and POSIX permission cases (chmod) are SKIP lines here.
# The read-only JSON checks (check, keys, get, json) and the canonical layout of
# the mig-run expectation use scripts/aitools-json.pl with the perl of Git for
# Windows, as the Git Bash harness did (perl scripts are cross-platform).
#
# Safe to re-run: every case runs under a temp HOME (removed on exit); the real
# HOME is never read or written by the resolver. Exit 1 on failure.
#
# Usage: pwsh -NoProfile -File tests/profile/test-profile.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content -LiteralPath $PSCommandPath -TotalCount 33 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/profile/test-profile.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $RepoRoot "tests/lib/platform-lib.ps1")
$PwshExe = (Get-Process -Id $PID).Path
$ProfilePs1 = Join-Path $RepoRoot "scripts/aitools-profile.ps1"
$JsonPs1 = Join-Path $RepoRoot "scripts/aitools-json.ps1"
$JsonPl = (Join-Path $RepoRoot "scripts/aitools-json.pl") -replace '\\', '/'
$LangRun = "ps1"
$Utf8 = [Text.UTF8Encoding]::new($false)

$script:PASS = 0; $script:FAIL = 0; $script:SKIP = 0
function ok([string]$Name) { $script:PASS++; Write-Output "  ok   $Name" }
function bad([string]$Name) { $script:FAIL++; Write-Output "  FAIL $Name" }
function skip([string]$Text) { $script:SKIP++; Write-Output "  skip $Text" }
# Show-Indented TEXT: TEXT with every line indented by 7 spaces (the .sh's sed 's/^/       /')
function Show-Indented([string]$Text) {
    if (-not $Text) { return }
    $lines = @($Text -split "`n")
    if ($lines.Count -gt 0 -and $lines[-1] -eq "") { $lines = @($lines | Select-Object -SkipLast 1) }
    foreach ($ln in $lines) { Write-Output "       $ln" }
}
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { $Utf8.GetString([IO.File]::ReadAllBytes($Path)) } else { "" } }
function WriteText([string]$Path, [string]$Text) { [IO.File]::WriteAllBytes($Path, $Utf8.GetBytes($Text)) }
# Get-Lines PATH -- the file's lines (perl -ne reading): split on LF, no trailing empty line
function Get-Lines([string]$Path) {
    $t = ReadText $Path
    if ($t -eq "") { return , [string[]]@() }
    $ls = $t -split "`n"
    if ($ls[-1] -eq "") { $ls = $ls[0..($ls.Count - 2)] }
    return , [string[]]$ls
}
# TrimNl TEXT -- TEXT without trailing newlines (bash command substitution)
function TrimNl([string]$Text) { return $Text.TrimEnd("`n") }
# SameBytes PATH TEXT -- PATH holds exactly TEXT, UTF-8 (cmp -s PATH <(...))
function SameBytes([string]$Path, [string]$Text) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    return ([Convert]::ToHexString([IO.File]::ReadAllBytes($Path)) -ceq [Convert]::ToHexString($Utf8.GetBytes($Text)))
}
function SameFile([string]$A, [string]$B) {
    (Test-Path -LiteralPath $A -PathType Leaf) -and (Test-Path -LiteralPath $B -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $A).Hash -ceq (Get-FileHash -LiteralPath $B).Hash)
}
function Remove-Tree([string]$Path) { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force } }
function MkDir([string]$Path) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
# NL LINE... -- the lines joined with LF (fixtures are written with LF: a .ps1
# checks out CRLF, so here-strings would carry CR)
function NL([string[]]$Lines) { return ($Lines -join "`n") }
# Edit-First TEXT REGEX REPLACEMENT -- the first match replaced (perl s/// without
# /g; $1 / ${1} in REPLACEMENT); TEXT unchanged without a match
function Edit-First([string]$Text, [string]$Pattern, [string]$Replacement) {
    $mt = [regex]::new($Pattern).Match($Text)
    if (-not $mt.Success) { return $Text }
    return $Text.Substring(0, $mt.Index) + $mt.Result($Replacement) + $Text.Substring($mt.Index + $mt.Length)
}
function Edit-FileFirst([string]$Path, [string]$Pattern, [string]$Replacement) { WriteText $Path (Edit-First (ReadText $Path) $Pattern $Replacement) }

# Get-LcsDiff A B -- the lines of a minimal diff from A to B ("< " removed, "> "
# added), as diff(1) counts them (longest common subsequence)
function Get-LcsDiff([string[]]$A, [string[]]$B) {
    $na = $A.Count; $nb = $B.Count
    $dp = New-Object 'int[,]' ($na + 1), ($nb + 1)
    for ($i = $na - 1; $i -ge 0; $i--) {
        for ($j = $nb - 1; $j -ge 0; $j--) {
            if ($A[$i] -ceq $B[$j]) { $dp[$i, $j] = $dp[($i + 1), ($j + 1)] + 1 }
            else { $dp[$i, $j] = [Math]::Max($dp[($i + 1), $j], $dp[$i, ($j + 1)]) }
        }
    }
    $res = [System.Collections.Generic.List[string]]::new()
    $i = 0; $j = 0
    while ($i -lt $na -and $j -lt $nb) {
        if ($A[$i] -ceq $B[$j]) { $i++; $j++ }
        elseif ($dp[($i + 1), $j] -ge $dp[$i, ($j + 1)]) { $res.Add("< " + $A[$i]); $i++ }
        else { $res.Add("> " + $B[$j]); $j++ }
    }
    while ($i -lt $na) { $res.Add("< " + $A[$i]); $i++ }
    while ($j -lt $nb) { $res.Add("> " + $B[$j]); $j++ }
    return , [string[]]$res.ToArray()
}
function Show-FileDiff([string]$A, [string]$B) { Show-Indented ((Get-LcsDiff (Get-Lines $A) (Get-Lines $B)) -join "`n") }

# --- External programs -----------------------------------------------------------
# Git for Windows: git for the harness's own fixture repositories, and its perl for
# aitools-json.pl (the Git Bash harness ran both from Git Bash's PATH).
$GitExe = $null
$gitCmd = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($gitCmd) { $GitExe = $gitCmd.Source }
$GitBash = Resolve-TestGitBash
$GitPerl = $null
if ($GitBash) {
    $perlCand = Join-Path (Split-Path -Parent (Split-Path -Parent $GitBash)) "usr\bin\perl.exe"
    if (Test-Path -LiteralPath $perlCand -PathType Leaf) { $GitPerl = $perlCand }
}
if (-not $GitExe -or -not $GitPerl) {
    Write-Output "aitools-profile tests (windows: aitools-profile.ps1)"
    if (-not $GitExe) { Write-Output "  FAIL git is not on PATH: the exception-set and migrate cases need it" }
    if (-not $GitPerl) { Write-Output "  FAIL Git for Windows perl (Git\usr\bin\perl.exe) not found: the aitools-json.pl checks need it" }
    exit 1
}

# Invoke-Proc EXE ARGS ENV OUTFILE ERRFILE [STDIN] -- run EXE with ARGS (each one
# argument), the variables in ENV set ($null: removed) for the child only, stdin
# STDIN then EOF, stdout and stderr to their own files (bytes as written). Returns
# the exit code. (Invoke-TestScript of platform-lib.ps1 writes both streams to one
# file; the resolver's goldens compare stdout only.)
function Invoke-Proc([string]$Exe, [string[]]$ArgList, [hashtable]$EnvSet, [string]$OutFile, [string]$ErrFile, [string]$StdinText = "") {
    $psi = [Diagnostics.ProcessStartInfo]::new($Exe)
    foreach ($a in $ArgList) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($k in @($EnvSet.Keys)) {
        if ($null -eq $EnvSet[$k]) { [void]$psi.Environment.Remove($k) } else { $psi.Environment[$k] = [string]$EnvSet[$k] }
    }
    $fo = [IO.File]::Create($OutFile)
    $fe = [IO.File]::Create($ErrFile)
    try {
        $p = [Diagnostics.Process]::Start($psi)
        try {
            $t1 = $p.StandardOutput.BaseStream.CopyToAsync($fo)
            $t2 = $p.StandardError.BaseStream.CopyToAsync($fe)
            if ($StdinText) { $sb = $Utf8.GetBytes($StdinText); $p.StandardInput.BaseStream.Write($sb, 0, $sb.Length) }
            $p.StandardInput.Close()
            $p.WaitForExit()
            $t1.Wait(); $t2.Wait()
            return $p.ExitCode
        } finally { $p.Dispose() }
    } finally { $fo.Dispose(); $fe.Dispose() }
}

$WORK = New-TestTempRoot "test-profile"
$GoldenDir = Join-Path $RepoRoot "tests/profile/golden"
$GoldenTmp = $WORK
# NWORK: the temp root in the mixed form (C:/...), long (New-TestTempRoot expands
# 8.3 components): every path handed to a child, and the form expectations use
$NWORK = $WORK -replace '\\', '/'
$HarnessGitConfig = "$NWORK/harness.gitconfig"
WriteText $HarnessGitConfig ""
# The os and arch values register writes for this machine: os win32, arch from
# RuntimeInformation.OSArchitecture lower-cased (aitools-profile.ps1 register)
$OSNAME = "win32"
$ARCH = ([string][System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture).ToLowerInvariant()

# WorkSpellings -- every spelling of the temp root a native program may print, in the
# mixed form: the long form, and its 8.3 short form when that differs (the CI temp
# root had both, C:/Users/RUNNER~1/... and C:/Users/runneradmin/...; PR #139 run
# 41265193554).
$WorkSpellings = [System.Collections.Generic.List[string]]::new()
$WorkSpellings.Add($NWORK)
try {
    if (-not ('AitTestShortPath' -as [type])) {
        Add-Type -Namespace '' -Name 'AitTestShortPath' -MemberDefinition (NL @(
                '[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]',
                'public static extern uint GetShortPathName(string longPath, System.Text.StringBuilder shortPath, uint bufferLength);'))
    }
    $ssb = [Text.StringBuilder]::new(1024)
    $sn = [AitTestShortPath]::GetShortPathName($WORK, $ssb, [uint32]$ssb.Capacity)
    if ($sn -gt 0 -and $sn -le $ssb.Capacity) {
        $short = $ssb.ToString() -replace '\\', '/'
        if ($short -cne $NWORK) { $WorkSpellings.Add($short) }
    } else { Write-Output "  note: GetShortPathName gave no short form of $WORK (that spelling is not mapped back)" }
} catch { Write-Output "  note: no short form of $WORK ($($_.Exception.Message)); that spelling is not mapped back" }
# NativeWorkRes -- for each spelling: C:/..., C:\..., JSON-escaped C:\\... and /c/...,
# longest first, letter case ignored (the .sh's from_native)
$nwSeen = @{}
foreach ($n in $WorkSpellings) {
    $bs = $n -replace '/', '\'
    $js = $bs -replace '\\', '\\'
    $us = $n
    if ($n -match '^([A-Za-z]):(.*)$') { $us = "/" + $Matches[1].ToLowerInvariant() + $Matches[2] }
    foreach ($s in @($js, $bs, $n, $us)) { if ($s) { $nwSeen[$s] = $true } }
}
$NativeWorkRes = @($nwSeen.Keys | Sort-Object -Property Length -Descending | ForEach-Object {
        [regex]::new([regex]::Escape($_) + '([^\s"''|()]*)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    })
$NativeWorkEval = [Text.RegularExpressions.MatchEvaluator] {
    param($mt)
    $r = $mt.Groups[1].Value.Replace('\\', '/').Replace('\', '/')
    return $NWORK + $r
}
# ConvertFrom-NativeWork FILE -- rewrite, in place, every spelling of the temp root
# (with the separators after it turned into slashes) to $NWORK, and remove CRs
function ConvertFrom-NativeWork([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $t = (ReadText $Path).Replace("`r", "")
    foreach ($re in $NativeWorkRes) { $t = $re.Replace($t, $NativeWorkEval) }
    WriteText $Path $t
}

$ID_MAC = "3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"
$ID_OTHER = "0B1C2D3E-0000-1111-2222-333344445555"
$ID_MAC_LC = $ID_MAC.ToLowerInvariant()
$ID_OTHER_LC = $ID_OTHER.ToLowerInvariant()

# ClearVars -- removed from every child's environment, so a developer shell cannot
# change a result (CI sets none of them): the AITOOLS_* variables aitools-lib.ps1
# and the resolver read, the Claude Code web markers the lib's environment check
# reads, and git variables that would redirect the resolver's git commands.
$ClearVars = @("AITOOLS_ENVIRONMENT", "AITOOLS_USER_REPO_PATH", "AITOOLS_MACHINE_ALIAS", "AITOOLS_PROFILE_FILE",
    "AITOOLS_PROFILE_PS1", "AITOOLS_PROFILE_SH", "AITOOLS_DRY_RUN", "AITOOLS_FORCE", "AITOOLS_RUN_ID",
    "AITOOLS_SUMMARY_FILE", "AITOOLS_PRESERVE_SUMMARY", "AITOOLS_TEST_UPDATE_GOLDEN", "AITOOLS_TEST_JSON_PS1",
    "AITOOLS_PROFILE_TEST_MACHINE_ID", "AITOOLS_PROFILE_TEST_HOSTNAME", "AITOOLS_LOG_DIR",
    "CLAUDE_CODE_REMOTE", "CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE",
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM", "GIT_CONFIG_NOSYSTEM")
function Get-ClearEnv { $e = @{}; foreach ($k in $ClearVars) { $e[$k] = $null }; return $e }

# Invoke-HGit ARGS -- the harness's own git command (fixture repositories): global
# config from an empty file, so a developer's ~/.gitconfig (signing, hooks) cannot
# change a fixture; a failure throws (the .sh runs under set -e). Returns stdout.
function Invoke-HGit([string[]]$GArgs) {
    $e = Get-ClearEnv
    $e["GIT_CONFIG_GLOBAL"] = $HarnessGitConfig
    $code = Invoke-Proc $GitExe $GArgs $e "$NWORK/hgit.out" "$NWORK/hgit.err"
    if ($code -ne 0) { throw "git $($GArgs -join ' ') failed (exit $code): $(ReadText "$NWORK/hgit.err")" }
    return (ReadText "$NWORK/hgit.out")
}
# Invoke-JsonPl ARGS [STDIN] -- perl aitools-json.pl ARGS with Git for Windows' perl;
# returns @{ Rc; Out } (Out: stdout, UTF-8)
function Invoke-JsonPl([string[]]$PlArgs, [string]$StdinText = "") {
    $e = Get-ClearEnv
    foreach ($k in @("PERL5LIB", "PERL5OPT", "PERLLIB", "PERLIO")) { $e[$k] = $null }
    $code = Invoke-Proc $GitPerl (@($JsonPl) + $PlArgs) $e "$NWORK/jpl.out" "$NWORK/jpl.err" $StdinText
    return @{ Rc = $code; Out = (ReadText "$NWORK/jpl.out") }
}
# JplText ARGS -- $(perl aitools-json.pl ARGS): stdout without trailing newlines
function JplText([string[]]$PlArgs) { return (TrimNl (Invoke-JsonPl $PlArgs).Out) }
# JplList ARGS -- $(perl aitools-json.pl ARGS | paste -sd ',' -)
function JplList([string[]]$PlArgs) {
    $t = (Invoke-JsonPl $PlArgs).Out
    if ($t -eq "") { return "" }
    $ls = @($t -split "`n")
    if ($ls[-1] -eq "") { $ls = @($ls | Select-Object -SkipLast 1) }
    return ($ls -join ",")
}

# fresh_home NAME -- isolated HOME with ~/repos and ~/.aitools; sets H (mixed form:
# the same string is the path inside fixture files, as HN was in the .sh)
function fresh_home([string]$Name) {
    $script:H = "$NWORK/$Name/home"
    MkDir "$($script:H)/repos"; MkDir "$($script:H)/.aitools"
}
function write_profile([string]$Dir, [string]$Text) { MkDir $Dir; WriteText "$Dir/profile.json" $Text }

function base_profile {
    return (NL @(
            '{',
            '  "version": 2,',
            '  "identity": {',
            '    "github": "nobul-jose",',
            '    "email": "jose@nobul.tech",',
            '    "name": "Jose",',
            '    "company": "nobul-tech",',
            '    "git": {',
            '      "name": "Jose",',
            '      "email": "jose@nobul.tech"',
            '    }',
            '  },',
            '  "profiles": {',
            '    "laptop": {',
            '      "company": "Nobul",',
            '      "machine": {',
            '        "hostname": "Joses-MBP",',
            '        "os": "darwin"',
            '      }',
            '    },',
            '    "nobul-mac": {',
            '      "machine": {',
            '        "hostname": "nobul-mac.local",',
            '        "os": "darwin"',
            '      }',
            '    },',
            '    "workstation": {',
            '      "name": "pepe",',
            '      "machine": {',
            '        "hostname": "NewcoPC",',
            '        "hostnames": ["newco-pc"],',
            '        "os": "win32"',
            '      }',
            '    }',
            '  }',
            '}')) + "`n"
}

# Get-ChildEnv -- the variables of a resolver run: ClearVars removed, HOME and
# USERPROFILE = the case home (taken from H at call time, never a saved value: a
# block that switches H and back, dc-host, must not leave a run on the other home;
# CI run 41265193554), AITOOLS_LOG_DIR under it, then the case's own (CaseEnv)
function Get-ChildEnv {
    $e = Get-ClearEnv
    $e["HOME"] = $script:H; $e["USERPROFILE"] = $script:H
    $e["AITOOLS_LOG_DIR"] = "$($script:H)/.aitools/logs"
    foreach ($k in @($script:CaseEnv.Keys)) { $e[$k] = $script:CaseEnv[$k] }
    return $e
}
# run_impl OUTFILE ARGS -- aitools-profile.ps1 ARGS in a child pwsh; sets RC; stdout
# in OUTFILE, stderr in OUTFILE.err, both passed through ConvertFrom-NativeWork
function run_impl([string]$OutFile, [string[]]$RArgs) {
    $argv = @("-NoProfile", "-NonInteractive", "-File", $ProfilePs1) + @($RArgs)
    $script:RC = Invoke-Proc $PwshExe $argv (Get-ChildEnv) $OutFile "$OutFile.err"
    ConvertFrom-NativeWork $OutFile
    ConvertFrom-NativeWork "$OutFile.err"
}

# normalize TEXT -- invalid-JSON parser messages cut after "is invalid JSON"
function normalize([string]$Path) { return [regex]::Replace((ReadText $Path), '( is invalid JSON).*', '$1') }
# plat_norm FILE -- the os and arch this machine writes into a profile -> <OS>, <ARCH>
function plat_norm([string]$Path) { return (ReadText $Path).Replace("`"os`": `"$OSNAME`"", '"os": "<OS>"').Replace("`"arch`": `"$ARCH`"", '"arch": "<ARCH>"') }

# golden_check NAME GOLDEN FILE -- one check: FILE equals tests/profile/golden/GOLDEN
function golden_check([string]$Name, [string]$Golden, [string]$File) {
    if (Test-GoldenMatch $Golden $File) { ok "${Name}: matches golden $Golden (sh and ps1 share it)" }
    else { bad "${Name}: differs from golden $Golden" }
}

# case_run NAME EXPECTED_RC ARGS [-NoParity] -- run the resolver, check the exit
# code and (unless -NoParity) the output against its golden file. Leaves the output
# in OUT for value assertions.
function case_run([string]$Name, [int]$Want, [string[]]$RArgs = @(), [switch]$NoParity) {
    $script:CASE = $Name
    $script:OUT = "$NWORK/$Name.out"
    run_impl $script:OUT $RArgs
    if ($script:RC -eq $Want) { ok "${Name}: $LangRun exit $($script:RC)" }
    else { bad "${Name}: $LangRun exit $($script:RC), want $Want"; Show-Indented (ReadText $script:OUT); Show-Indented (ReadText "$($script:OUT).err") }
    if (-not $NoParity) {
        WriteText "$NWORK/$Name.norm" (normalize $script:OUT)
        golden_check $Name "profile-$Name.out" "$NWORK/$Name.norm"
    }
}

# expect KEY VALUE -- the first KEY<TAB> line in OUT equals VALUE
function expect([string]$Key, [string]$Want) {
    $got = ""
    foreach ($ln in (Get-Lines $script:OUT)) { if ($ln.StartsWith("$Key`t", [StringComparison]::Ordinal)) { $got = $ln.Substring($Key.Length + 1); break } }
    if ($got -ceq $Want) { ok "$($script:CASE): $Key=$Want" } else { bad "$($script:CASE): $Key='$got', want '$Want'" }
}
function Test-AnyLine([string]$Pattern) {
    $re = [regex]::new($Pattern)
    foreach ($ln in (Get-Lines $script:OUT)) { if ($re.IsMatch($ln)) { return $true } }
    return $false
}
# expect_line PATTERN -- some line in OUT matches the regex
function expect_line([string]$Pattern) {
    if (Test-AnyLine $Pattern) { ok "$($script:CASE): line /$Pattern/" }
    else { bad "$($script:CASE): no line matches /$Pattern/"; Show-Indented (ReadText $script:OUT) }
}
function expect_no_line([string]$Pattern) {
    if (Test-AnyLine $Pattern) { bad "$($script:CASE): unexpected line /$Pattern/" }
    else { ok "$($script:CASE): no line /$Pattern/" }
}

$MA = @("--machine-id-value", $ID_MAC, "--hostname-value", "nobul-mac")
$script:CaseEnv = @{}
$SavedOutputEncoding = $null

try {
    # The children inherit this console: their output (and this harness's) is UTF-8
    # whatever the console code page (jr-unicode-* messages; a console without one
    # already writes UTF-8). Restored in finally.
    try { $SavedOutputEncoding = [Console]::OutputEncoding; [Console]::OutputEncoding = $Utf8 }
    catch { $SavedOutputEncoding = $null; Write-Output "  note: console output encoding not set to UTF-8 ($($_.Exception.Message))" }

    Write-Output "aitools-profile tests (windows: aitools-profile.$LangRun)"

    # --- Which dotprofile -------------------------------------------------------
    fresh_home urp-convention
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run urp-convention 0 @("user-repo-path")
    expect path "$H/repos/aitools-nobul-jose"; expect via convention

    fresh_home urp-scan
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    MkDir "$H/repos/aitools-empty"
    case_run urp-scan 0 @("user-repo-path")
    expect via scan; expect_line '^warn\tgithubUser unknown -- used the only dotprofile'

    fresh_home urp-scan-two
    write_profile "$H/repos/aitools-a" (base_profile)
    write_profile "$H/repos/aitools-b" (base_profile)
    case_run urp-scan-two 1 @("user-repo-path")
    expect via none; expect_line '^warn\tgithubUser unknown and 2 aitools-\* repos'

    fresh_home urp-none
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "someone" }' + "`n")
    case_run urp-none 1 @("user-repo-path")
    expect expected "$H/repos/aitools-someone"

    fresh_home urp-config
    write_profile "$H/elsewhere/dp" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "userRepoPath": "' + "$H/elsewhere/dp/" + '" }' + "`n")
    case_run urp-config 0 @("user-repo-path")
    expect path "$H/elsewhere/dp"; expect via config

    fresh_home urp-config-stale
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "userRepoPath": "' + "$H/gone" + '", "githubUser": "nobul-jose" }' + "`n")
    case_run urp-config-stale 0 @("user-repo-path")
    expect via convention; expect_line '^warn\tconfig.json userRepoPath does not exist'

    fresh_home urp-env
    write_profile "$H/envdp" (base_profile)
    $script:CaseEnv = @{ AITOOLS_USER_REPO_PATH = "$H/envdp" }
    case_run urp-env 0 @("user-repo-path", "--user-repo-path", "$H/nope")
    expect via env
    $script:CaseEnv = @{ AITOOLS_USER_REPO_PATH = "$H/missing" }
    case_run urp-env-missing 2 @("user-repo-path")
    expect_line '^error\tAITOOLS_USER_REPO_PATH does not exist'
    $script:CaseEnv = @{}

    fresh_home urp-arg
    case_run urp-arg-missing 2 @("user-repo-path", "--user-repo-path", "$H/nope")
    expect_line '^error\t--user-repo-path does not exist'

    fresh_home urp-plain
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run urp-plain 0 @("user-repo-path", "--plain")
    if ((TrimNl (ReadText $OUT)) -ceq "$H/repos/aitools-nobul-jose") { ok "urp-plain: path only" } else { bad "urp-plain: got '$(TrimNl (ReadText $OUT))'" }

    fresh_home urp-corrupt-config
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" '{ "githubUser": '
    case_run urp-corrupt-config 0 @("user-repo-path")
    expect via scan; expect_line '^warn\t.*config.json is invalid JSON'

    # `~` in config.json paths expands to HOME in both resolvers (S3-M3-B8c parity finding)
    fresh_home urp-tilde
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "userRepoPath": "~/repos/aitools-nobul-jose" }' + "`n")
    case_run urp-tilde 0 @("user-repo-path")
    expect via config; expect path "$H/repos/aitools-nobul-jose"
    WriteText "$H/.aitools/config.json" ('{ "reposPath": "~/repos", "githubUser": "nobul-jose" }' + "`n")
    case_run urp-tilde-repos 0 @("user-repo-path")
    expect via convention; expect path "$H/repos/aitools-nobul-jose"

    # A UTF-16 config.json or profile.json is rejected by both, with one message
    # (S3-M3-B8c parity finding: PowerShell used to decode it, perl could not)
    fresh_home urp-utf16
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    $bom = [byte[]](0xFF, 0xFE)
    [IO.File]::WriteAllBytes("$H/.aitools/config.json", [byte[]]($bom + [Text.Encoding]::Unicode.GetBytes('{ "userRepoPath": "' + "$H/repos/aitools-nobul-jose" + '" }' + "`n")))
    case_run urp-utf16 0 @("user-repo-path")
    expect via scan
    expect_line '^warn\t.*/\.aitools/config\.json is UTF-16 encoded, not UTF-8 -- save it as UTF-8 -- resolving without it$'
    # perl encoded each byte of the (ASCII) profile.json as one UTF-16LE unit
    [IO.File]::WriteAllBytes("$H/u16.json", [byte[]]($bom + [Text.Encoding]::Unicode.GetBytes((ReadText "$H/repos/aitools-nobul-jose/profile.json"))))
    case_run rm-utf16-profile 2 (@("resolve") + $MA + @("--profile", "$H/u16.json"))
    expect_line '^error\t.*/u16\.json is UTF-16 encoded, not UTF-8 -- save it as UTF-8$'

    # --- Which machine profile ---------------------------------------------------
    fresh_home rm-alias
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose", "machineAlias": "nobul-mac" }' + "`n")
    case_run rm-alias 0 (@("resolve") + $MA)
    expect alias nobul-mac; expect via alias; expect name Jose; expect company nobul-tech
    expect machineId $ID_MAC; expect hostname nobul-mac
    expect_line '^warn\tprofile "nobul-mac" has no machine.id'

    fresh_home rm-hostname
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run rm-hostname 0 (@("resolve") + $MA)
    expect alias nobul-mac; expect via hostname
    expect_line '^warn\tmatched by hostname only'
    expect_no_line 'has no machine.id'

    case_run rm-hostname-alt 0 @("resolve", "--machine-id-value", $ID_OTHER, "--hostname-value", "NEWCO-PC")
    expect alias workstation; expect name pepe; expect company nobul-tech

    case_run rm-profile-company 0 @("resolve", "--machine-id-value", $ID_OTHER, "--hostname-value", "joses-mbp")
    expect alias laptop; expect company Nobul; expect name Jose

    case_run rm-none 2 @("resolve", "--machine-id-value", $ID_OTHER, "--hostname-value", "some-other-host")
    expect alias ""; expect via none; expect company nobul-tech; expect name Jose
    expect_line '^error\tno profile matches this machine \(machine.id 0B1C2D3E.*hostname some-other-host\)'

    fresh_home rm-id
    write_profile "$H/repos/aitools-nobul-jose" (Edit-First (base_profile) '"hostname": "nobul-mac.local"' ('"id": "' + $ID_MAC_LC + '",' + "`n" + '        "hostname": "nobul-mac.local"'))
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose", "machineAlias": "laptop" }' + "`n")
    case_run rm-id 0 (@("resolve") + $MA)
    expect alias nobul-mac; expect via id
    expect_line '^warn\tconfig.json machineAlias "laptop" disagrees with machine.id match "nobul-mac"'

    $script:CaseEnv = @{ AITOOLS_MACHINE_ALIAS = "laptop" }
    case_run rm-override-env 0 (@("resolve") + $MA)
    expect alias laptop; expect via override
    expect_line '^warn\tprofile "laptop" has no machine.id'
    case_run rm-override-derive 0 (@("derive-config") + $MA)
    expect derived.machineAlias ""; expect_line '^warn\tmachine alias from AITOOLS_MACHINE_ALIAS -- not saved'
    $script:CaseEnv = @{}
    case_run rm-override-arg 0 (@("resolve") + $MA + @("--alias", "workstation"))
    expect alias workstation; expect via override
    expect_line '^warn\tprofile "workstation" has no machine.id'
    case_run rm-override-unknown 2 (@("resolve") + $MA + @("--alias", "nope"))
    expect_line '^error\toverride alias "nope" not in profiles \(laptop, nobul-mac, workstation\)'

    fresh_home rm-id-twice
    write_profile "$H/repos/aitools-nobul-jose" ([regex]::Replace((base_profile), '"hostname": "(nobul-mac.local|Joses-MBP)"', ('"id": "' + $ID_MAC + '",' + "`n" + '        "hostname": "$1"')))
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run rm-id-twice 2 (@("resolve") + $MA)
    expect_line '^error\tmachine.id 3D4DF2A5.* is registered on more than one profile: laptop, nobul-mac'

    fresh_home rm-host-twice
    write_profile "$H/repos/aitools-nobul-jose" (Edit-First (base_profile) '"Joses-MBP"' '"nobul-mac"')
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run rm-host-twice 2 (@("resolve") + $MA)
    expect_line '^error\thostname matches more than one profile: laptop, nobul-mac'

    fresh_home rm-stale-alias
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose", "machineAlias": "new-mac" }' + "`n")
    case_run rm-stale-alias 0 (@("resolve") + $MA)
    expect via hostname
    expect_line '^warn\tconfig.json machineAlias "new-mac" not in profiles \(laptop, nobul-mac, workstation\)'

    fresh_home rm-no-dotprofile
    case_run rm-no-dotprofile 1 (@("resolve") + $MA)
    expect via none; expect userRepoVia none

    fresh_home rm-corrupt-profile
    MkDir "$H/repos/aitools-nobul-jose"
    WriteText "$H/repos/aitools-nobul-jose/profile.json" '{ "version": 2, "profiles": { '
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run rm-corrupt-profile 2 (@("resolve") + $MA)
    expect_line '^error\t.*profile.json is invalid JSON'

    fresh_home rm-v1
    write_profile "$H/repos/aitools-nobul-jose" ('{ "name": "Jose", "machines": [] }' + "`n")
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run rm-v1 2 (@("resolve") + $MA)
    expect_line '^error\tprofile.json is not v2$'
    expect_no_line 'has no profiles object'
    # A v2 file without a profiles object has its own message (PR #98 review m1)
    write_profile "$H/repos/aitools-nobul-jose" ('{ "version": 2, "identity": { "github": "nobul-jose" } }' + "`n")
    case_run rm-v2-no-profiles 2 (@("resolve") + $MA)
    expect_line '^error\tprofile.json has no profiles object$'
    expect_no_line 'is not v2'
    write_profile "$H/repos/aitools-nobul-jose" ('{ "version": 2, "identity": { "github": "nobul-jose" }, "profiles": [] }' + "`n")
    case_run rm-v2-profiles-array 2 (@("resolve") + $MA)
    expect_line '^error\tprofile.json has no profiles object$'

    fresh_home rm-profile-file
    $script:CaseEnv = @{ AITOOLS_PROFILE_FILE = "$H/missing.json" }
    case_run rm-profile-file-missing 2 (@("resolve") + $MA)
    expect_line '^error\tprofile file set but missing: .*\(AITOOLS_PROFILE_FILE\)'
    WriteText "$H/snap.json" (base_profile)
    $script:CaseEnv = @{ AITOOLS_PROFILE_FILE = "$H/snap.json" }
    case_run rm-profile-file 0 (@("resolve") + $MA)
    expect alias nobul-mac; expect profileFile "$H/snap.json"
    $script:CaseEnv = @{}

    # claude-code-web exists only on Linux, and PowerShell never branches on the
    # environment (cross-platform.md "Environment branches"): .sh only, no golden
    skip "rm-web (claude-code-web exists only on Linux)"

    fresh_home rm-json
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run rm-json 0 (@("resolve") + $MA + @("--json", "--alias", "laptop"))
    expect_line '^\{"alias":"laptop","via":"override",.*"warnings":\["profile \\"laptop\\" has no machine.id.*"\],"errors":\[\]\}$'

    # --- derive-config -------------------------------------------------------------
    fresh_home dc
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "reposPath": "' + "$H/repos" + '" }' + "`n")
    case_run dc 0 (@("derive-config") + $MA + @("--github-user", "nobul-jose", "--alias", "nobul-mac"))
    expect derived.githubUser nobul-jose; expect derived.userRepoPath "$H/repos/aitools-nobul-jose"
    expect derived.machineAlias nobul-mac; expect via override; expect aliases "laptop, nobul-mac, workstation"

    fresh_home dc-none
    case_run dc-none 1 (@("derive-config") + $MA + @("--github-user", "ghost"))
    expect derived.githubUser ghost; expect derived.userRepoPath ""
    expect_line '^warn\tno dotprofile found -- only bootstrap keys written'

    fresh_home dc-env
    write_profile "$H/envdp" (base_profile)
    $script:CaseEnv = @{ AITOOLS_USER_REPO_PATH = "$H/envdp" }
    case_run dc-env 0 (@("derive-config") + $MA)
    expect derived.userRepoPath ""; expect derived.githubUser nobul-jose
    expect via hostname; expect derived.machineAlias ""   # a hostname match is not cached (PR #76 review M1)
    expect_line '^warn\tdotprofile from AITOOLS_USER_REPO_PATH -- not saved'
    $script:CaseEnv = @{}

    # --- snapshot ------------------------------------------------------------------
    fresh_home snap
    WriteText "$H/p.json" (Edit-First (base_profile) '"profiles"' ('"claude": { "settings": { "model": "opus" } },' + "`n" + '  "profiles"'))
    case_run snap 0 @("snapshot", "--profile", "$H/p.json")
    expect_line '^\{"version":2,"identity":\{"github":"nobul-jose".*\},"cursor":\{\},"profiles":\{"laptop"'
    expect_no_line 'settings'

    # --- register --------------------------------------------------------------------
    fresh_home reg
    # Escapes, unicode, nested arrays, a number with a fraction and empty containers:
    # a no-op registration must keep every other byte (node layout, key order). The
    # non-ASCII characters are built from code points (this file stays ASCII).
    WriteText "$H/p.json" ((NL @(
                '{',
                '  "version": 2,',
                '  "identity": {',
                '    "github": "nobul-jose",',
                '    "email": "jose@nobul.tech",',
                '    "git": {',
                ('      "name": "Jos' + [char]0xE9 + ' \"Pepe\" Palencia",'),
                '      "email": "jose@nobul.tech"',
                '    }',
                '  },',
                '  "claude": {',
                '    "settings": {',
                '      "z": [',
                '        1,',
                '        2.5,',
                '        {',
                '          "a": null,',
                '          "b": []',
                '        },',
                '        {}',
                '      ],',
                '      "path": "C:\\Users\\pepe\\repos",',
                '      "tab": "a\tb",',
                ('      "emoji": "' + [char]::ConvertFromUtf32(0x1F600) + '",'),
                '      "when": "2026-10-21T12:00:00Z"',
                '    }',
                '  },',
                '  "profiles": {',
                '    "nobul-mac": {',
                '      "name": "Jose",',
                '      "company": "nobul-tech",',
                '      "machine": {',
                '        "hostname": "nobul-mac",',
                '        "os": "darwin",',
                '        "arch": "ARCH",',
                '        "shell": "bash"',
                '      }',
                '    }',
                '  }',
                '}')) + "`n")
    # The JSON-engine cases below start from this file before os/arch are made this
    # machine's (their results must not depend on the platform)
    Copy-Item -LiteralPath "$H/p.json" -Destination "$NWORK/reg-template.json" -Force
    WriteText "$H/p.json" ((ReadText "$H/p.json").Replace('"ARCH"', "`"$ARCH`"").Replace('"os": "darwin"', "`"os`": `"$OSNAME`""))
    # --alias alone never claims an alias-keyed profile without machine.id (no terminal
    # choice behind it: design c); the refusal names the profile and the --claim way
    case_run reg-noclaim 4 (@("register", "--profile", "$H/p.json", "--alias", "nobul-mac", "--shell", "bash", "--out", "$H/out0.json") + $MA)
    expect result refused; expect owner unregistered; expect ownerKey nobul-mac
    expect_line '^error\talias "nobul-mac" is used by profile nobul-mac, which is not registered to any machine -- claim it \(--claim nobul-mac\) or choose another alias$'
    # --claim KEY (after the user picked it): re-keyed under this machine's id (position
    # kept), alias = the old key, machine.id added
    case_run reg-update 0 (@("register", "--profile", "$H/p.json", "--claim", "nobul-mac", "--shell", "bash", "--out", "$H/out.json") + $MA)
    expect result updated; expect machineId $ID_MAC; expect key $ID_MAC_LC; expect alias nobul-mac
    expect claimed nobul-mac; expect owner this
    $want = Edit-First (ReadText "$H/p.json") '"nobul-mac": \{' ('"' + $ID_MAC_LC + '": {')
    $want = Edit-First $want '("shell": "bash")\n      \}' ('$1,' + "`n" + '        "id": "' + $ID_MAC_LC + '"' + "`n" + '      },' + "`n" + '      "alias": "nobul-mac"')
    WriteText "$NWORK/reg-update.want.json" $want
    if (SameFile "$NWORK/reg-update.want.json" "$H/out.json") {
        ok "reg-update: only the key, machine.id and alias changed (other bytes kept)"
    } else {
        bad "reg-update: unexpected changes"; Show-FileDiff "$NWORK/reg-update.want.json" "$H/out.json"
    }
    # Parity: both resolvers write identical bytes (this machine's os/arch normalized)
    WriteText "$NWORK/reg-update.written.json" (plat_norm "$H/out.json")
    golden_check "reg-update (written file)" profile-reg-update.written.json "$NWORK/reg-update.written.json"
    case_run reg-unchanged 0 (@("register", "--profile", "$H/out.json", "--alias", "nobul-mac", "--shell", "bash", "--out", "$H/out2.json") + $MA)
    expect result unchanged
    if (SameFile "$H/out.json" "$H/out2.json") { ok "reg-unchanged: file bytes stable" } else { bad "reg-unchanged: file changed" }

    # A new id with a new alias: created without a terminal (Review3 #82-M1, resolver side)
    case_run reg-new-alias 0 @("register", "--profile", "$H/out.json", "--alias", "spare", "--name", "Pepe", "--company", "Other",
        "--out", "$H/out3.json", "--machine-id-value", $ID_OTHER, "--hostname-value", "spare-host")
    expect result created; expect key $ID_OTHER_LC; expect alias spare; expect claimed ""
    $script:OUT = "$H/out3.json"
    $script:CASE = "reg-new-alias-file"
    $k = [regex]::Escape($ID_OTHER_LC)
    if ([regex]::IsMatch((ReadText $OUT), ('"' + $k + '": \{\n      "alias": "spare",\n      "name": "Pepe",\n      "company": "Other",\n      "machine": \{\n        "id": "' + $k + '",\n        "hostname": "spare-host",'))) {
        ok "reg-new-alias-file: profiles.<id> = alias, name, company, machine (id = key, lower-cased)"
    } else { bad "reg-new-alias-file: entry shape"; Show-Indented (ReadText $OUT) }

    # The same id again with another alias: the alias field is renamed, nothing else
    case_run reg-rename-alias 0 (@("register", "--profile", "$H/out.json", "--alias", "mac2", "--shell", "bash", "--out", "$H/out4.json") + $MA)
    expect result updated; expect key $ID_MAC_LC; expect alias mac2; expect claimed ""
    if ((JplText @("get", "$H/out4.json", "profiles", $ID_MAC_LC, "alias")) -ceq "mac2") { ok "reg-rename-alias: alias field renamed" }
    else { bad "reg-rename-alias: alias not renamed" }

    # An alias another machine's profile answers to: refused, exit 4 (decision 1)
    case_run reg-alias-taken 4 (@("register", "--profile", "$H/out3.json", "--alias", "spare", "--out", "$H/out5.json") + $MA)
    expect result refused; expect owner other; expect ownerKey $ID_OTHER_LC
    expect_line '^error\talias "spare" is used by another machine.s profile \(0b1c2d3e-0000-1111-2222-333344445555\) -- choose another alias'
    if (Test-Path -LiteralPath "$H/out5.json") { bad "reg-alias-taken: wrote --out" } else { ok "reg-alias-taken: nothing written" }
    # ... unless confirmed interactively: the duplicate is allowed and warned about
    case_run reg-alias-dup 0 (@("register", "--profile", "$H/out3.json", "--alias", "spare", "--allow-duplicate-alias", "--out", "$H/out6.json") + $MA)
    expect result updated; expect alias spare
    expect_line ('^warn\talias "spare" is used by 2 machines \(' + $ID_OTHER_LC + ', ' + $ID_MAC_LC + '\)$')
    $otherBefore = JplText @("json", "$H/out3.json", "profiles", $ID_OTHER_LC)
    if ((JplText @("json", "$H/out6.json", "profiles", $ID_OTHER_LC)) -ceq $otherBefore) {
        ok "reg-alias-dup: the other machine's profile is untouched"
    } else { bad "reg-alias-dup: the other machine's profile changed" }
    # The legacy key of an alias-keyed profile registered to another machine: refused too (#82-M2)
    write_profile "$H/m2leg" ('{ "version": 2, "profiles": { "laptop": { "machine": { "id": "' + $ID_OTHER + '", "hostname": "joses-mbp" } } } }' + "`n")
    case_run reg-legacy-taken 4 (@("register", "--profile", "$H/m2leg/profile.json", "--alias", "laptop", "--out", "$H/out7.json") + $MA)
    expect owner other; expect ownerKey laptop

    # One machine id on an id-keyed and an alias-keyed profile: error, exit 2
    write_profile "$H/dupid" ((NL @(
                '{ "version": 2, "profiles": {',
                ('  "' + $ID_MAC_LC + '": { "alias": "nobul-mac", "machine": { "id": "' + $ID_MAC_LC + '" } },'),
                ('  "old-mac": { "machine": { "id": "' + $ID_MAC + '" } } } }'))) + "`n")
    case_run reg-dup-id 2 (@("register", "--profile", "$H/dupid/profile.json", "--alias", "nobul-mac", "--out", "$H/out8.json") + $MA)
    expect_line '^error\tmachine.id 3D4DF2A5.* is already registered on profile "old-mac"'

    # No detectable machine id: refused, exit 3 (there is no key to write under)
    case_run reg-no-id 3 @("register", "--profile", "$H/out3.json", "--alias", "x", "--out", "$H/out9.json", "--machine-id-value", "none", "--hostname-value", "nobul-mac")
    expect result refused
    expect_line '^error\tno machine id: no machine id \(test value\) -- a machine profile is keyed by this machine.s id$'

    # No --alias: a new profile takes the short hostname
    case_run reg-default-alias 0 @("register", "--profile", "$H/out3.json", "--out", "$H/out10.json", "--machine-id-value", "AAAA-BBBB", "--hostname-value", "Box-One.local")
    expect result created; expect key aaaa-bbbb; expect alias box-one

    # Review S3-M3-Resolver-Review (PR #86) fixes
    # M2: re-registering after a confirmed duplicate alias is not refused (safe to re-run)
    case_run reg-dup-rerun 0 (@("register", "--profile", "$H/out6.json", "--out", "$H/out11.json") + $MA)
    expect alias spare; expect_line '^warn\talias "spare" is used by 2 machines'
    case_run reg-dup-rerun-same 0 (@("register", "--profile", "$H/out6.json", "--alias", "spare", "--out", "$H/out12.json") + $MA)
    expect alias spare
    # M3: --claim refuses a profile registered to another machine, and an unknown key
    case_run reg-claim-foreign 4 (@("register", "--profile", "$H/m2leg/profile.json", "--claim", "laptop", "--out", "$H/out13.json") + $MA)
    expect owner other; expect ownerKey laptop
    expect_line '^error\t--claim: profile "laptop" is registered to another machine -- not claimed$'
    case_run reg-claim-missing 2 (@("register", "--profile", "$H/m2leg/profile.json", "--claim", "nope", "--out", "$H/out14.json") + $MA)
    expect_line '^error\t--claim: no profile "nope"$'
    # M4: a renamed machine's registration updates machine.hostname (clears the clone warning)
    case_run reg-hostname 0 @("register", "--profile", "$H/out3.json", "--out", "$H/out15.json", "--machine-id-value", $ID_MAC, "--hostname-value", "renamed-mac")
    expect result updated
    if ((JplText @("get", "$H/out15.json", "profiles", $ID_MAC_LC, "machine", "hostname")) -ceq "renamed-mac") { ok "reg-hostname: machine.hostname updated" }
    else { bad "reg-hostname: machine.hostname not updated" }
    # minor 6: aliases differing only in case conflict; nit 4: an id-shaped alias is refused
    case_run reg-alias-case 4 (@("register", "--profile", "$H/out3.json", "--alias", "SPARE", "--out", "$H/out16.json") + $MA)
    expect ownerKey $ID_OTHER_LC
    case_run reg-alias-idshape 2 (@("register", "--profile", "$H/out3.json", "--alias", $ID_OTHER, "--out", "$H/out17.json") + $MA)

    fresh_home reg-create
    case_run reg-create 0 (@("register", "--profile", "$H/new/profile.json", "--alias", "nobul-mac", "--create", "--github-user", "nobul-jose",
            "--email", "jose@nobul.tech", "--name", "Jose", "--company", "nobul-tech", "--shell", "zsh", "--out", "$H/created.json") + $MA)
    expect result created
    # Parity: both resolvers write identical bytes (this machine's os/arch normalized)
    WriteText "$NWORK/reg-create.written.json" (plat_norm "$H/created.json")
    golden_check "reg-create (written file)" profile-reg-create.written.json "$NWORK/reg-create.written.json"
    $script:OUT = "$H/created.json"; $script:CASE = "reg-create-file"
    expect_line '^  "version": 2,$'
    expect_line '^    "schemaRevision": "2.2"$'
    expect_line '^    "company": "nobul-tech",$'
    $k = [regex]::Escape($ID_MAC_LC)
    if ([regex]::IsMatch((ReadText $OUT), ('"' + $k + '": \{\n\s+"alias": "nobul-mac",\n\s+"machine": \{\n\s+"id": "' + $k + '",'))) {
        ok "reg-create-file: profiles.<id> with alias, no per-profile name/company (identity holds them)"
    } else { bad "reg-create-file: entry shape"; Show-Indented (ReadText $OUT) }

    case_run reg-missing-nocreate 1 (@("register", "--profile", "$H/none.json", "--alias", "x", "--out", "$H/o.json") + $MA)
    case_run reg-bad-alias 2 (@("register", "--profile", "$H/none.json", "--alias", "bad alias", "--out", "$H/o.json") + $MA)

    # --- tool exceptions -----------------------------------------------------------------
    # case_fresh NAME RC SETUP ARGS [-NormAt] -- like case_run, but SETUP (a function
    # name) rebuilds the fixture first (exception-set changes state). Checks the exit
    # code, the output and the resulting profile.json against their golden files. The
    # resulting profile.json is kept as NWORK/NAME.profile.json (empty when there is none).
    function case_fresh([string]$Name, [int]$Want, [string]$Setup, [string[]]$RArgs, [switch]$NormAt) {
        $script:CASE = $Name
        $script:OUT = "$NWORK/$Name.out"
        & $Setup
        run_impl $script:OUT $RArgs
        if (Test-Path -LiteralPath $script:EXC_PF -PathType Leaf) { Copy-Item -LiteralPath $script:EXC_PF -Destination "$NWORK/$Name.profile.json" -Force }
        else { WriteText "$NWORK/$Name.profile.json" "" }   # absent profile = empty copy
        if ($script:RC -eq $Want) { ok "${Name}: $LangRun exit $($script:RC)" }
        else { bad "${Name}: $LangRun exit $($script:RC), want $Want"; Show-Indented (ReadText $script:OUT); Show-Indented (ReadText "$($script:OUT).err") }
        golden_check $Name "profile-$Name.out" $script:OUT
        # -NormAt: a real clock wrote decidedAt
        $pj = ReadText "$NWORK/$Name.profile.json"
        if ($NormAt) { $pj = [regex]::Replace($pj, '"decidedAt": "[^"]*"', '"decidedAt": "<now>"') }
        WriteText "$NWORK/$Name.profile.golden.json" $pj
        golden_check "$Name (profile.json)" "profile-$Name.profile.json" "$NWORK/$Name.profile.golden.json"
    }

    fresh_home exc
    $script:EXC_DIR = "$H/repos/aitools-nobul-jose"
    $script:EXC_PF = "$($script:EXC_DIR)/profile.json"
    $script:EXC_REMOTE = "$NWORK/exc-remote.git"
    function exc_profile { return (Edit-First (base_profile) '"hostname": "nobul-mac.local"' ('"id": "' + $ID_MAC + '",' + "`n" + '        "hostname": "nobul-mac.local"')) }
    function setup_exc_git {
        Remove-Tree $script:EXC_DIR; Remove-Tree $script:EXC_REMOTE
        write_profile $script:EXC_DIR (exc_profile)
        WriteText "$($script:H)/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
        $null = Invoke-HGit @("init", "-q", "--bare", $script:EXC_REMOTE)
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "init", "-q")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "config", "user.name", "Test")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "config", "user.email", "test@example.com")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "add", "profile.json")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "commit", "-q", "-m", "init")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "remote", "add", "origin", $script:EXC_REMOTE)
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "push", "-q", "-u", "origin", "HEAD")  # bare remote in a temp dir; a failure throws
        WriteText "$($script:EXC_DIR)/other.txt" "unrelated`n"
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "add", "other.txt")
    }
    function setup_exc_plain {
        Remove-Tree $script:EXC_DIR
        write_profile $script:EXC_DIR (exc_profile)
        WriteText "$($script:H)/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    }
    function setup_exc_hostname {
        Remove-Tree $script:EXC_DIR
        write_profile $script:EXC_DIR (base_profile)
        WriteText "$($script:H)/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    }
    function setup_exc_none { Remove-Tree $script:EXC_DIR; WriteText "$($script:H)/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n") }
    $SET_ARGS = @("exception-set", "--slug", "go", "--platform", "macos", "--method", "pkg-installer", "--path", "/usr/local/bin/go", "--version", "1.22.5",
        "--by", "setup-go", "--decided-at", "2026-10-21T12:00:00Z")

    case_fresh exc-set-git 0 setup_exc_git ($SET_ARGS + $MA)
    expect result created; expect alias nobul-mac; expect via id; expect committed true; expect pushed true
    # A legacy alias-keyed profile with this machine's id: written, with a migrate warning (design d)
    expect key nobul-mac; expect legacy true; expect owner this
    expect_line '^warn\tprofile "nobul-mac" is keyed by alias -- run: aitools-profile migrate'
    $script:OUT = "$NWORK/exc-set-git.profile.json"; $script:CASE = "exc-set-git-file"
    if ([regex]::IsMatch((ReadText $OUT), '"toolExceptions": \{\n        "go": \{\n          "decision": "keep",\n          "detected": \{\n            "platform": "macos",\n            "method": "pkg-installer",\n            "path": "\/usr\/local\/bin\/go",\n            "version": "1.22.5"\n          \},\n          "decidedAt": "2026-10-21T12:00:00Z",\n          "decidedBy": "setup-go",\n          "reason": null\n        \}')) {
        ok "exc-set-git: entry shape and order as reference/user-repo.md"
    } else { bad "exc-set-git: entry shape"; Show-Indented (ReadText $OUT) }
    $committedFiles = (@((Invoke-HGit @("-C", $EXC_DIR, "show", "--name-only", "--format=%s", "HEAD")) -split "`n" | Where-Object { $_ -match '\S' })) -join "|"
    if ($committedFiles -ceq "Record tool exception: keep go (pkg-installer) on nobul-mac|profile.json") {
        ok "exc-set-git: commit holds only profile.json (staged other.txt left alone)"
    } else { bad "exc-set-git: commit was '$committedFiles'" }
    if ((Invoke-HGit @("-C", $EXC_REMOTE, "rev-parse", "HEAD")) -ceq (Invoke-HGit @("-C", $EXC_DIR, "rev-parse", "HEAD"))) { ok "exc-set-git: pushed to the remote" }
    else { bad "exc-set-git: remote not updated" }

    # The state left by that run feeds the reads below
    case_run exc-get 0 (@("exception-get", "--slug", "go") + $MA)
    expect found true; expect platform macos; expect method pkg-installer; expect path /usr/local/bin/go
    expect version "1.22.5"; expect decidedAt "2026-10-21T12:00:00Z"; expect decidedBy setup-go; expect reason ""
    case_run exc-get-other 0 (@("exception-get", "--slug", "typst") + $MA)
    expect found false; expect alias nobul-mac
    case_run exc-set-unchanged 0 ($SET_ARGS + $MA)
    expect result unchanged; expect committed false

    function setup_exc_noident {
        setup_exc_git
        # A distinctive owner, so the assertion cannot pass on the real global identity
        WriteText $script:EXC_PF ((ReadText $script:EXC_PF).Replace('jose@nobul.tech', 'owner@example.test'))
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "commit", "-q", "-m", "owner", "--", "profile.json")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "config", "--unset", "user.name")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "config", "--unset", "user.email")
    }
    case_fresh exc-set-noident 0 setup_exc_noident ($SET_ARGS + $MA)
    expect committed true
    $author = TrimNl (Invoke-HGit @("-C", $EXC_DIR, "log", "-1", "--format=%an <%ae>"))
    if ($author -ceq "Jose <owner@example.test>") { ok "exc-set-noident: committed as the profile's identity.git" }
    else { bad "exc-set-noident: author '$author'" }

    case_fresh exc-set-plain 0 setup_exc_plain ($SET_ARGS + $MA + @("--reason", "corporate MDM pin"))
    expect result created; expect committed false
    expect_line '^warn\t.* is not a git repository -- profile.json written but not committed$'
    $script:OUT = "$NWORK/exc-set-plain.profile.json"; $script:CASE = "exc-set-plain-file"
    expect_line '"reason": "corporate MDM pin"'

    case_fresh exc-set-hostname 3 setup_exc_hostname ($SET_ARGS + $MA)
    expect result refused; expect via hostname
    expect_line '^error\tmachine profile "nobul-mac" matched by hostname only -- run: aitools user init to remember tool choices$'
    if (SameBytes "$NWORK/exc-set-hostname.profile.json" (base_profile)) { ok "exc-set-hostname: profile.json untouched" }
    else { bad "exc-set-hostname: profile.json changed" }

    case_fresh exc-set-none 3 setup_exc_none ($SET_ARGS + $MA)
    expect result refused; expect_line '^error\tno dotprofile profile.json -- run: aitools user init'

    $script:CaseEnv = @{ AITOOLS_PROFILE_FILE = "$H/snap.json" }
    WriteText "$H/snap.json" (base_profile)
    case_fresh exc-set-snapshot 3 setup_exc_plain ($SET_ARGS + $MA)
    expect_line '^error\tprofile from AITOOLS_PROFILE_FILE is a read-only snapshot'
    $script:CaseEnv = @{ AITOOLS_DRY_RUN = "1" }
    case_fresh exc-set-dry 0 setup_exc_plain ($SET_ARGS + $MA)
    expect result dry-run
    if (SameBytes "$NWORK/exc-set-dry.profile.json" (exc_profile)) { ok "exc-set-dry: profile.json untouched" }
    else { bad "exc-set-dry: profile.json changed" }
    $script:CaseEnv = @{}

    case_fresh exc-get-none 2 setup_exc_hostname @("exception-get", "--slug", "go", "--machine-id-value", $ID_OTHER, "--hostname-value", "elsewhere")
    expect found false; expect_line '^error\tno profile matches this machine'
    # --- PR #76 review: alias writes, timestamps, dirty file, push failure ---------
    # via=alias with an unregistered profile (this machine has an id): refused
    function setup_exc_alias {
        setup_exc_hostname
        WriteText "$($script:H)/.aitools/config.json" ('{ "githubUser": "nobul-jose", "machineAlias": "laptop" }' + "`n")
    }
    case_fresh exc-set-alias 3 setup_exc_alias ($SET_ARGS + $MA)
    expect via alias
    expect_line '^error\tmachine profile "laptop" is not registered to this machine -- run: aitools user init to remember tool choices$'
    # via=alias with a profile registered to another machine: refused
    function setup_exc_foreign {
        setup_exc_alias
        Edit-FileFirst $script:EXC_PF '"hostname": "Joses-MBP"' ('"id": "OTHER-MACHINE",' + "`n" + '        "hostname": "Joses-MBP"')
    }
    # The cached alias names another machine's profile: ignored (step 4L), then the
    # hostname match is refused
    case_fresh exc-set-foreign 3 setup_exc_foreign ($SET_ARGS + $MA)
    expect_line '^warn\tconfig.json machineAlias "laptop" names a profile registered to another machine \(machine.id OTHER-MACHINE\) -- ignored$'
    expect via hostname
    expect_line '^error\tmachine profile "nobul-mac" matched by hostname only'
    # An override naming a profile that is not this machine's: refused (design b)
    $script:CaseEnv = @{ AITOOLS_MACHINE_ALIAS = "laptop" }
    case_fresh exc-set-override 3 setup_exc_alias ($SET_ARGS + $MA)
    expect via override; expect result refused; expect owner unregistered
    expect_line '^error\tmachine profile "laptop" is not registered to this machine'
    # An override naming this machine's own profile: allowed
    $script:CaseEnv = @{ AITOOLS_MACHINE_ALIAS = "nobul-mac" }
    case_fresh exc-set-override-own 0 setup_exc_plain ($SET_ARGS + $MA)
    expect via override; expect owner this; expect result created
    $script:CaseEnv = @{}
    # derive-config does not cache a hostname match
    $EXC_H = $H
    fresh_home dc-host
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run dc-hostname-not-saved 0 (@("derive-config") + $MA)
    expect via hostname; expect derived.machineAlias ""
    expect_line '^warn\tmachine alias "nobul-mac" matched by hostname only -- not saved to config.json$'
    $script:H = $EXC_H

    # Without --decided-at: an identical re-keep is unchanged; a changed one gets a new time
    $SET_NOW = @("exception-set", "--slug", "go", "--platform", "macos", "--method", "pkg-installer", "--path", "/usr/local/bin/go", "--version", "1.22.5", "--by", "setup-go")
    function setup_exc_existing {
        setup_exc_git
        Edit-FileFirst $script:EXC_PF '("hostname": "nobul-mac.local",\n        "os": "darwin")' ('$1,' + "`n" + '        "x": 1')
        Edit-FileFirst $script:EXC_PF '"x": 1' (NL @(
                '"x": 1',
                '      },',
                '      "toolExceptions": {',
                '        "go": {',
                '          "decision": "keep",',
                '          "detected": {',
                '            "platform": "macos",',
                '            "method": "pkg-installer",',
                '            "path": "/usr/local/bin/go",',
                '            "version": "1.22.5"',
                '          },',
                '          "decidedAt": "2026-01-01T00:00:00Z",',
                '          "decidedBy": "setup-go",',
                '          "reason": null',
                '        }'))
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "commit", "-q", "-m", "existing", "--", "profile.json")
    }
    case_fresh exc-set-same 0 setup_exc_existing ($SET_NOW + $MA)
    expect result unchanged; expect committed false
    case_fresh exc-set-changed 0 setup_exc_existing (@("exception-set", "--slug", "go", "--platform", "macos", "--method", "pkg-installer",
            "--path", "/usr/local/bin/go", "--version", "1.23.0", "--by", "setup-go") + $MA) -NormAt
    expect result updated; expect committed true
    if ((ReadText "$NWORK/exc-set-changed.profile.json").Contains('"decidedAt": "2026-01-01T00:00:00Z"')) { bad "exc-set-changed: kept the old decidedAt" }
    else { ok "exc-set-changed: new decidedAt" }

    # profile.json edited by hand and not committed: written, not auto-committed
    function setup_exc_dirty { setup_exc_git; Edit-FileFirst $script:EXC_PF '"Joses-MBP"' '"Joses-MBP-2"' }
    case_fresh exc-set-dirty 0 setup_exc_dirty ($SET_ARGS + $MA)
    expect result created; expect committed false
    expect_line '^warn\tprofile.json had uncommitted changes before this write -- not committed automatically'

    # Push fails (no remote): committed, not pushed, warning
    function setup_exc_noremote { setup_exc_git; $null = Invoke-HGit @("-C", $script:EXC_DIR, "remote", "remove", "origin") }
    case_fresh exc-set-nopush 0 setup_exc_noremote ($SET_ARGS + $MA)
    expect committed true; expect pushed false
    expect_line '^warn\tdotprofile push failed \(exit [0-9]+\) -- run git push in '

    case_run exc-bad-platform 2 (@("exception-set", "--slug", "go", "--platform", "darwin", "--method", "m", "--path", "/p", "--by", "setup-go") + $MA)
    case_run exc-bad-slug 2 (@("exception-get", "--slug", "Go Lang") + $MA)

    # --- id-keyed profiles (re-key design batch 2) -----------------------------------------
    # profiles.<machine id, lower-cased> with an alias field; legacy alias-keyed profiles
    # are still read. Fields: key, alias, via, owner, legacy.
    function id_profile {
        return (NL @(
                '{',
                '  "version": 2,',
                '  "identity": {',
                '    "github": "nobul-jose",',
                '    "email": "jose@nobul.tech",',
                '    "name": "Jose",',
                '    "company": "nobul-tech",',
                '    "git": {',
                '      "name": "Jose",',
                '      "email": "jose@nobul.tech"',
                '    }',
                '  },',
                '  "profiles": {',
                ('    "' + $ID_MAC_LC + '": {'),
                '      "alias": "nobul-mac",',
                '      "machine": {',
                ('        "id": "' + $ID_MAC_LC + '",'),
                '        "hostname": "nobul-mac",',
                '        "os": "darwin"',
                '      }',
                '    },',
                ('    "' + $ID_OTHER_LC + '": {'),
                '      "alias": "laptop",',
                '      "company": "Nobul",',
                '      "machine": {',
                ('        "id": "' + $ID_OTHER_LC + '",'),
                '        "hostname": "Joses-MBP",',
                '        "os": "darwin"',
                '      }',
                '    },',
                '    "old-pc": {',
                '      "machine": {',
                '        "hostname": "NewcoPC",',
                '        "os": "win32"',
                '      }',
                '    }',
                '  }',
                '}')) + "`n"
    }
    fresh_home idk
    write_profile "$H/repos/aitools-nobul-jose" (id_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run idk-resolve 0 (@("resolve") + $MA)
    expect key $ID_MAC_LC; expect alias nobul-mac; expect via id; expect owner this; expect legacy false
    expect company nobul-tech
    expect_no_line '^warn'
    case_run idk-json 0 (@("resolve") + $MA + @("--json"))
    expect_line ('^\{"alias":"nobul-mac","via":"id","key":"' + $ID_MAC_LC + '","owner":"this","legacy":"false",')
    # Override by alias field, by key (any case), and to a profile without an id
    case_run idk-override-other 0 (@("resolve") + $MA + @("--alias", "laptop"))
    expect key $ID_OTHER_LC; expect via override; expect owner other; expect company Nobul
    expect_line ('^warn\tprofile "laptop" is registered to another machine \(machine.id ' + $ID_OTHER_LC + ', this machine ' + $ID_MAC + '\)$')
    case_run idk-override-key 0 (@("resolve") + $MA + @("--alias", $ID_OTHER))
    expect key $ID_OTHER_LC; expect alias laptop; expect via override
    case_run idk-override-unreg 0 (@("resolve") + $MA + @("--alias", "old-pc"))
    expect key old-pc; expect owner unregistered; expect legacy true
    case_run idk-none 2 @("resolve", "--machine-id-value", "11111111-2222", "--hostname-value", "elsewhere")
    expect key ""; expect owner absent; expect via none; expect legacy false
    # A stored hostname that differs from the live one: the only clone signal
    case_run idk-host-mismatch 0 @("resolve", "--machine-id-value", $ID_MAC, "--hostname-value", "renamed-mac")
    expect via id
    expect_line ('^warn\tprofile "nobul-mac" was registered with hostname "nobul-mac", this machine is "renamed-mac" -- renamed \(run: aitools user init to update it\), or a clone that shares machine id ' + $ID_MAC + '$')
    # Hostname match on another machine's id-keyed profile: owner other (Review3 #82-M2 warning)
    case_run idk-host-other 0 @("resolve", "--machine-id-value", "99999999-0000", "--hostname-value", "joses-mbp")
    expect via hostname; expect key $ID_OTHER_LC; expect owner other
    expect_line '^warn\tprofile "laptop" is registered to another machine'
    # Upper-case key written by hand: found ignoring case
    fresh_home idk-upper
    write_profile "$H/repos/aitools-nobul-jose" (Edit-First (id_profile) ('"' + [regex]::Escape($ID_MAC_LC) + '": \{') ('"' + $ID_MAC + '": {'))
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run idk-upper 0 (@("resolve") + $MA)
    expect key $ID_MAC; expect via id; expect legacy false; expect owner this

    # config.json machineId: used only when the live id cannot be detected (step 4)
    fresh_home idk-cfg
    write_profile "$H/repos/aitools-nobul-jose" (id_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose", "machineId": "' + $ID_MAC_LC + '", "machineAlias": "nobul-mac" }' + "`n")
    case_run idk-cfg 0 @("resolve", "--machine-id-value", "none", "--hostname-value", "nobul-mac")
    expect via config; expect key $ID_MAC_LC; expect owner this
    expect_line '^warn\tmachine id unavailable: no machine id \(test value\)$'
    case_run idk-cfg-live 0 @("resolve", "--machine-id-value", $ID_OTHER, "--hostname-value", "nobul-mac")
    expect via id; expect key $ID_OTHER_LC
    expect_line ('^warn\tconfig.json machineId "' + $ID_MAC_LC + '" disagrees with machine.id match "' + $ID_OTHER_LC + '" -- machine.id wins$')
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose", "machineId": "gone-id" }' + "`n")
    case_run idk-cfg-stale 0 @("resolve", "--machine-id-value", "none", "--hostname-value", "nobul-mac")
    expect via hostname
    expect_line '^warn\tconfig.json machineId "gone-id" not in profiles -- ignored$'

    # derive-config: derived.machineId only for this machine's id-keyed profile
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run idk-derive 0 (@("derive-config") + $MA)
    expect derived.machineId $ID_MAC_LC; expect derived.machineAlias nobul-mac; expect key $ID_MAC_LC
    expect aliases "nobul-mac, laptop, old-pc"
    case_run idk-derive-other 0 (@("derive-config") + $MA + @("--alias", "laptop"))
    expect derived.machineId ""; expect derived.machineAlias laptop; expect owner other

    # One alias on two machines (after an interactive confirm): every resolve warns, and
    # an --alias lookup by that alias is an error that lists the keys
    fresh_home idk-dup
    write_profile "$H/repos/aitools-nobul-jose" (Edit-First (id_profile) '"alias": "laptop"' '"alias": "nobul-mac"')
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run idk-dup 0 (@("resolve") + $MA)
    expect via id; expect_line ('^warn\talias "nobul-mac" is used by 2 machines \(' + $ID_MAC_LC + ', ' + $ID_OTHER_LC + '\)$')
    case_run idk-dup-lookup 2 (@("resolve") + $MA + @("--alias", "nobul-mac"))
    expect_line ('^error\talias "nobul-mac" is used by more than one profile: ' + $ID_MAC_LC + ', ' + $ID_OTHER_LC + ' -- select one by its key$')
    case_run idk-dup-bykey 0 (@("resolve") + $MA + @("--alias", $ID_OTHER_LC))
    expect key $ID_OTHER_LC

    # Tool exceptions on an id-keyed profile: profiles.<id>.toolExceptions
    fresh_home idk-exc
    $script:EXC_DIR = "$H/repos/aitools-nobul-jose"
    $script:EXC_PF = "$($script:EXC_DIR)/profile.json"
    function setup_idk_exc {
        Remove-Tree $script:EXC_DIR
        write_profile $script:EXC_DIR (id_profile)
        WriteText "$($script:H)/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    }
    case_fresh idk-exc-set 0 setup_idk_exc ($SET_ARGS + $MA)
    expect result created; expect key $ID_MAC_LC; expect legacy false; expect via id
    if ((JplText @("get", $EXC_PF, "profiles", $ID_MAC_LC, "toolExceptions", "go", "decision")) -ceq "keep") {
        ok "idk-exc-set: written at profiles.<id>.toolExceptions.go"
    } else { bad "idk-exc-set: entry missing" }
    case_run idk-exc-get 0 (@("exception-get", "--slug", "go") + $MA)
    expect found true; expect key $ID_MAC_LC; expect owner this; expect method pkg-installer
    # Another machine's profile by override: refused; no id detectable: refused
    $script:CaseEnv = @{ AITOOLS_MACHINE_ALIAS = "laptop" }
    case_fresh idk-exc-other 3 setup_idk_exc ($SET_ARGS + $MA)
    expect owner other; expect_line '^error\tmachine profile "laptop" is not registered to this machine'
    $script:CaseEnv = @{}
    function setup_idk_exc_cfg { setup_idk_exc; WriteText "$($script:H)/.aitools/config.json" ('{ "githubUser": "nobul-jose", "machineId": "' + $ID_MAC_LC + '" }' + "`n") }
    case_fresh idk-exc-cfg 3 setup_idk_exc_cfg ($SET_ARGS + @("--machine-id-value", "none", "--hostname-value", "nobul-mac"))
    expect via config
    expect_line '^error\tmachine profile "nobul-mac" matched by config.json machineId only \(machine id unavailable\) -- tool choice not saved$'
    # Review minor 1: another machine's recorded decision is never returned
    function setup_idk_exc_other {
        setup_idk_exc
        Edit-FileFirst $script:EXC_PF '("hostname": "Joses-MBP",\n        "os": "darwin"\n      \})' (NL @(
                '$1,',
                '      "toolExceptions": {',
                '        "go": {',
                '          "decision": "keep",',
                '          "detected": {',
                '            "platform": "macos",',
                '            "method": "brew",',
                '            "path": "/x",',
                '            "version": "1"',
                '          },',
                '          "decidedAt": "2026-01-01T00:00:00Z",',
                '          "decidedBy": "setup-go",',
                '          "reason": null',
                '        }',
                '      }'))
    }
    case_fresh idk-exc-get-other 0 setup_idk_exc_other @("exception-get", "--slug", "go", "--machine-id-value", "99999999-0000", "--hostname-value", "joses-mbp")
    expect via hostname; expect owner other; expect found false; expect method ""
    expect_line '^warn\ttoolExceptions.go in profile "laptop" is not this machine.s \(owner other\) -- ignored$'
    # Review minor 2: owner unknown when this machine's id cannot be detected
    case_run idk-owner-unknown 0 @("resolve", "--machine-id-value", "none", "--hostname-value", "nobul-mac", "--alias", "nobul-mac")
    expect owner unknown; expect key $ID_MAC_LC
    # Review minor 3: a key that disagrees with its machine.id is reported; migrate refuses it
    fresh_home idk-mismatch
    $mm = Edit-First (id_profile) ('("id": ")' + [regex]::Escape($ID_MAC_LC) + '"') ('${1}' + $ID_OTHER + '"')
    $mm = Edit-First $mm ('"' + [regex]::Escape($ID_OTHER_LC) + '": \{') '"other-laptop": {'
    write_profile "$H/repos/aitools-nobul-jose" $mm
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    case_run idk-mismatch 0 (@("resolve") + $MA)
    expect via id; expect key $ID_MAC_LC
    expect_line ('^warn\tprofile key "' + $ID_MAC_LC + '" disagrees with its machine.id "' + $ID_OTHER + '" -- fix profile.json by hand$')
    Copy-Item -LiteralPath "$H/repos/aitools-nobul-jose/profile.json" -Destination "$NWORK/idk-mismatch.before.json" -Force
    case_run idk-mismatch-migrate 2 @("migrate")
    expect result failed
    expect_line ('^error\tprofile key "' + $ID_MAC_LC + '" disagrees with its machine.id "' + $ID_OTHER + '" -- fix profile.json by hand; nothing written$')
    if (SameFile "$NWORK/idk-mismatch.before.json" "$H/repos/aitools-nobul-jose/profile.json") { ok "idk-mismatch-migrate: nothing written" }
    else { bad "idk-mismatch-migrate: profile.json changed" }

    # --- migrate (re-key design section f) --------------------------------------------------
    fresh_home mig
    $script:EXC_DIR = "$H/repos/aitools-nobul-jose"
    $script:EXC_PF = "$($script:EXC_DIR)/profile.json"
    $script:EXC_REMOTE = "$NWORK/mig-remote.git"
    function mig_profile {
        $t = Edit-First (base_profile) '"hostname": "nobul-mac.local"' ('"id": "' + $ID_MAC + '",' + "`n" + '        "hostname": "nobul-mac.local"')
        $t = Edit-First $t '"hostname": "Joses-MBP"' ('"id": "' + $ID_OTHER_LC + '",' + "`n" + '        "hostname": "Joses-MBP"')
        return (Edit-First $t '(\n  \}\n\}\n)\z' (NL @(',', '    "web": {', '      "machine": {', '        "environment": "claude-code-web"', '      }', '    }$1')))
    }
    function setup_mig_plain {
        Remove-Tree $script:EXC_DIR
        write_profile $script:EXC_DIR (mig_profile)
        WriteText "$($script:H)/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    }
    function setup_mig_git {
        Remove-Tree $script:EXC_DIR; Remove-Tree $script:EXC_REMOTE
        setup_mig_plain
        $null = Invoke-HGit @("init", "-q", "--bare", $script:EXC_REMOTE)
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "init", "-q")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "config", "user.name", "Test")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "config", "user.email", "test@example.com")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "add", "profile.json")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "commit", "-q", "-m", "init")
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "remote", "add", "origin", $script:EXC_REMOTE)
        $null = Invoke-HGit @("-C", $script:EXC_DIR, "push", "-q", "-u", "origin", "HEAD")  # bare remote in a temp dir; a failure throws
    }
    $MIG_RENAMED = "laptop -> $ID_OTHER_LC, nobul-mac -> $ID_MAC_LC, web -> environment:claude-code-web"
    case_fresh mig-dry 0 setup_mig_plain @("migrate", "--dry-run")
    expect result dry-run; expect renamed $MIG_RENAMED; expect unclaimed workstation
    expect_line '^warn\tprofile "workstation" has no machine.id -- left as is \(aitools user init claims it\)$'
    if (SameBytes $EXC_PF (mig_profile)) { ok "mig-dry: profile.json untouched" } else { bad "mig-dry: profile.json changed" }

    case_fresh mig-run 0 setup_mig_git @("migrate")
    expect result migrated; expect renamed $MIG_RENAMED; expect committed true; expect pushed true
    $gotKeys = JplList @("keys", $EXC_PF, "profiles")
    if ($gotKeys -ceq "$ID_OTHER_LC,$ID_MAC_LC,workstation,environment:claude-code-web") { ok "mig-run: keys re-keyed in place ($gotKeys)" }
    else { bad "mig-run: keys '$gotKeys'" }
    # Exact bytes: keys renamed, `alias` appended to each re-keyed profile, nothing else
    # (machine.id keeps its upper case: content is not rewritten). The fixture is put in
    # the engine's layout first (an empty edit), as every writer does (aitools-json.pl
    # edit, empty stdin: the Git Bash harness's layout source on Windows too).
    WriteText "$NWORK/mig-run.in.json" (mig_profile)
    $canon = Invoke-JsonPl @("edit", "$NWORK/mig-run.in.json", "$NWORK/mig-run.canon.json")
    if ($canon.Rc -ne 0) { throw "aitools-json.pl edit (mig-run layout) failed (exit $($canon.Rc)): $(ReadText "$NWORK/jpl.err")" }
    $want = ReadText "$NWORK/mig-run.canon.json"
    $want = Edit-First $want '"nobul-mac": \{' ('"' + $ID_MAC_LC + '": {')
    $want = Edit-First $want '"laptop": \{' ('"' + $ID_OTHER_LC + '": {')
    $want = Edit-First $want '"web": \{' '"environment:claude-code-web": {'
    $want = Edit-First $want '("hostname": "Joses-MBP",\n        "os": "darwin"\n      \})' ('$1,' + "`n" + '      "alias": "laptop"')
    $want = Edit-First $want '("hostname": "nobul-mac.local",\n        "os": "darwin"\n      \})' ('$1,' + "`n" + '      "alias": "nobul-mac"')
    $want = Edit-First $want '("environment": "claude-code-web"\n      \})' ('$1,' + "`n" + '      "alias": "web"')
    WriteText "$NWORK/mig-run.want.json" $want
    if (SameFile "$NWORK/mig-run.want.json" $EXC_PF) { ok "mig-run: only keys renamed and alias lines added (other bytes kept)" }
    else { bad "mig-run: unexpected bytes"; Show-FileDiff "$NWORK/mig-run.want.json" $EXC_PF }
    $migCommit = (@((Invoke-HGit @("-C", $EXC_DIR, "show", "--name-only", "--format=%s", "HEAD")) -split "`n" | Where-Object { $_ -match '\S' })) -join "|"
    if ($migCommit -ceq "Migrate machine profiles to id keys|profile.json") { ok "mig-run: committed profile.json only" }
    else { bad "mig-run: commit '$migCommit'" }
    if ((Invoke-HGit @("-C", $EXC_REMOTE, "rev-parse", "HEAD")) -ceq (Invoke-HGit @("-C", $EXC_DIR, "rev-parse", "HEAD"))) { ok "mig-run: pushed" } else { bad "mig-run: not pushed" }
    if (@(Get-ChildItem -LiteralPath $EXC_DIR -Filter "profile.json.bak.*" -Force).Count -gt 0) { ok "mig-run: backup written" } else { bad "mig-run: no backup" }

    # After the migration: resolves via id, not legacy; a second run changes nothing
    case_run mig-resolve 0 (@("resolve") + $MA)
    expect via id; expect key $ID_MAC_LC; expect alias nobul-mac; expect legacy false
    expect_no_line 'keyed by alias'
    case_run mig-again 0 @("migrate")
    expect result unchanged; expect renamed ""; expect committed false

    # One machine id on two profiles: error, nothing written
    function setup_mig_dup {
        setup_mig_plain
        Edit-FileFirst $script:EXC_PF ('"' + [regex]::Escape($ID_OTHER_LC) + '"') ('"' + $ID_MAC + '"')
    }
    case_fresh mig-dup 2 setup_mig_dup @("migrate")
    expect result failed
    expect_line ('^error\tprofiles "laptop" and "nobul-mac" would both be keyed "' + $ID_MAC_LC + '" \(one machine id on two profiles\) -- nothing written$')
    if (SameBytes $EXC_PF (Edit-First (mig_profile) ('"' + [regex]::Escape($ID_OTHER_LC) + '"') ('"' + $ID_MAC + '"'))) { ok "mig-dup: profile.json untouched" }
    else { bad "mig-dup: profile.json changed" }
    $script:CaseEnv = @{ AITOOLS_PROFILE_FILE = "$H/snap.json" }
    WriteText "$H/snap.json" (mig_profile)
    case_fresh mig-snapshot 3 setup_mig_plain @("migrate")
    expect result refused
    $script:CaseEnv = @{}
    # Not v2, and v2 without a profiles object: one message each, nothing written (PR #98 m1)
    function setup_mig_v1 { Remove-Tree $script:EXC_DIR; write_profile $script:EXC_DIR ('{ "name": "Jose", "machines": [] }' + "`n") }
    case_fresh mig-v1 2 setup_mig_v1 @("migrate")
    expect result failed
    expect_line '^error\tprofile.json is not v2$'
    function setup_mig_noprof { Remove-Tree $script:EXC_DIR; write_profile $script:EXC_DIR ('{ "version": 2, "identity": { "github": "nobul-jose" } }' + "`n") }
    case_fresh mig-no-profiles 2 setup_mig_noprof @("migrate")
    expect result failed
    expect_line '^error\tprofile.json has no profiles object$'
    if ((TrimNl (ReadText $EXC_PF)) -ceq '{ "version": 2, "identity": { "github": "nobul-jose" } }') { ok "mig-no-profiles: profile.json untouched" }
    else { bad "mig-no-profiles: profile.json changed" }

    # --- regressions from the PR #73 review (S3-Profile-Review) --------------------------
    fresh_home rev
    write_profile "$H/repos/aitools-nobul-jose" (base_profile)
    WriteText "$H/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    $script:CaseEnv = @{ AITOOLS_ENVIRONMENT = "bogus" }
    case_run rev-m1-stdout 0 @("user-repo-path", "--plain")   # M1: the lib's environment warning must not reach stdout
    if ((TrimNl (ReadText $OUT)) -ceq "$H/repos/aitools-nobul-jose") { ok "rev-m1-stdout: stdout holds only the path" }
    else { bad "rev-m1-stdout: stdout was '$(TrimNl (ReadText $OUT))'" }
    $script:CaseEnv = @{}

    write_profile "$H/m2" ('{ "version": 2, "profiles": { "a": { "machine": null } } }' + "`n")
    case_run rev-m2-throw 2 (@("register", "--profile", "$H/m2/profile.json", "--claim", "a", "--out", "$H/m2.out") + $MA)
    expect_line "^error\tregister failed: set: 'machine' is not an object"

    write_profile "$H/m3" ((NL @(
                '{',
                '  "version": 2,',
                '  "claude": {',
                '    "settings": {',
                '      "a": 0.30000000000000004,',
                '      "b": 0.3333333333333333,',
                '      "c": 12345678901234567890',
                '    }',
                '  },',
                '  "profiles": {',
                '    "a": {',
                '      "machine": {',
                '        "id": "3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"',
                '      }',
                '    }',
                '  }',
                '}')) + "`n")
    # Number literals kept byte for byte: a perl-engine guarantee (aitools-profile.ps1
    # documents that non-integer literals are re-formatted), so macOS/Linux only
    skip "rev-m3-numbers (number literals byte for byte: the perl engine's guarantee, macOS/Linux)"

    case_run rev-help 0 @("--help") -NoParity   # help text names each platform's sources
    expect_line '^aitools-profile\.(sh|ps1) -- dotprofile and machine-profile resolver'
    case_run rev-opt-case 2 @("resolve", "--PROFILE", "$H/m2/profile.json")

    write_profile "$H/m7" ('{ "version": 2, "identity": { "github": "x" }, "profiles": { "a": { "machine": { "id": "3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5", "hostname": "nobul-mac", "os": "OS", "arch": "ARCH" } } } }' + "`n")
    WriteText "$H/m7/profile.json" ((ReadText "$H/m7/profile.json").Replace('"OS"', "`"$OSNAME`"").Replace('"ARCH"', "`"$ARCH`""))
    case_run rev-m7-name 0 (@("register", "--profile", "$H/m7/profile.json", "--alias", "a", "--name", "NewName", "--out", "$H/m7.out") + $MA)
    expect result updated
    case_run rev-m8-tab 2 (@("register", "--profile", "$H/m7/profile.json", "--alias", "a", "--name", "a`tb", "--out", "$H/m8.out") + $MA)

    write_profile "$H/m9" ('{ "version": 2, "identity": {}, "cursor": ["only"], "profiles": {} }' + "`n")
    case_run rev-m9-snapshot 0 @("snapshot", "--profile", "$H/m9/profile.json")
    expect_line '"cursor":\["only"\]'

    case_run rev-host-trim 0 @("resolve", "--machine-id-value", $ID_OTHER, "--hostname-value", "  NewcoPC.corp  ")
    expect alias workstation; expect via hostname

    # --- JSON engines: rename (re-key design batch 1) ------------------------------------
    # The perl edit op "rename<TAB>NEW<TAB>SEG..." and Rename-JKey in aitools-json.ps1
    # must keep the key's position and every other byte, and write identical bytes.
    # Each engine runs where its resolver runs: perl (aitools-profile.sh's engine) on
    # macOS/Linux, aitools-json.ps1 here; their results share golden files.
    # aitools-json.pl also serves as the read-only checker below (check, keys, get),
    # with the perl of Git for Windows.
    $JW = "$NWORK/jrename"
    MkDir $JW
    WriteText "$JW/driver.ps1" ((NL @(
                '# Test driver: IN OUT OP... ; each OP is "|"-separated:',
                '#   rename|NEW|SEG...   set|STRING-VALUE|SEG...',
                '. $env:AITOOLS_TEST_JSON_PS1',
                '$r = Read-JsonFile $args[0]',
                'if ($r.State -ne "valid") { [Console]::Error.WriteLine($r.Message); exit 2 }',
                'try {',
                '    for ($i = 2; $i -lt $args.Count; $i++) {',
                '        $f = ([string]$args[$i]).Split("|")',
                '        $segs = [string[]]@()',
                '        if ($f.Count -gt 2) { $segs = [string[]]$f[2..($f.Count - 1)] }',
                '        if ($f[0] -eq "rename") { Rename-JKey $r.Value $f[1] $segs }',
                '        elseif ($f[0] -eq "set") { Set-JValue $r.Value $f[1] $segs }',
                '        else { throw "driver: unknown op $($f[0])" }',
                '    }',
                '} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 2 }',
                '[IO.File]::WriteAllText($args[1], (ConvertTo-NodeJson $r.Value) + "`n", $script:Utf8NoBom)',
                'exit 0')) + "`n")
    # The register fixture above (as written, before os/arch were made this machine's):
    # escapes, unicode, nested arrays, a fraction, empty containers, a date string. Add
    # a profile before and after the one to rename.
    $jin = Edit-First (ReadText "$NWORK/reg-template.json") '("profiles": \{\n)' ('$1' + (NL @('    "first": {', '      "machine": {', '        "os": "linux"', '      }', '    },', '')))
    $jin = Edit-First $jin '(\n  \}\n\}\n)\z' (NL @(',', '    "last": {', '      "list": [', '        "a"', '      ]', '    }$1'))
    WriteText "$JW/in.json" $jin
    if ((Invoke-JsonPl @("check", "$JW/in.json")).Rc -eq 0) { ok "jr-fixture: valid JSON" } else { bad "jr-fixture: invalid"; Show-Indented (ReadText "$JW/in.json") }

    # jr_case NAME WANT_RC PS_OP... -- run aitools-json.ps1 (driver.ps1) on in.json (or
    # JR_IN); sets JOUT (the written file) and JERR (its stdout and stderr)
    $script:JR_IN = ""
    function jr_case([string]$Name, [int]$Want, [string[]]$PsOps) {
        $script:CASE = $Name
        $inFile = if ($script:JR_IN) { $script:JR_IN } else { "$JW/in.json" }
        $eng = "pwsh"; $script:JOUT = "$JW/$Name.ps.json"; $script:JERR = "$JW/$Name.ps.err"
        $e = Get-ClearEnv
        $e["AITOOLS_TEST_JSON_PS1"] = $JsonPs1
        $argv = @("-NoProfile", "-NonInteractive", "-File", "$JW/driver.ps1", $inFile, $script:JOUT) + @($PsOps)
        $script:RC = Invoke-Proc $PwshExe $argv $e "$($script:JERR).1" "$($script:JERR).2"
        # > JERR 2>&1: the driver writes nothing to stdout; stdout, then stderr
        [IO.File]::WriteAllBytes($script:JERR, [byte[]]([IO.File]::ReadAllBytes("$($script:JERR).1") + [IO.File]::ReadAllBytes("$($script:JERR).2")))
        ConvertFrom-NativeWork $script:JERR
        if ($script:RC -eq $Want) { ok "${Name}: $eng exit $($script:RC)" }
        else { bad "${Name}: $eng exit $($script:RC), want $Want"; Show-Indented (ReadText $script:JERR) }
        if ($Want -ne 0) {
            if (Test-Path -LiteralPath $script:JOUT) { bad "${Name}: $eng wrote $($script:JOUT) on failure" } else { ok "${Name}: $eng wrote nothing" }
            golden_check "$Name (message)" "profile-$Name.err" $script:JERR
        } else {
            golden_check "$Name (written file)" "profile-$Name.json" $script:JOUT
        }
    }
    # jr_keys WANT SEG... -- keys of the object at SEG in JOUT, joined with ","
    function jr_keys([string]$Want, [string[]]$Segs = @()) {
        $got = JplList (@("keys", $script:JOUT) + @($Segs))
        if ($got -ceq $Want) { ok "$($script:CASE): keys $Want" } else { bad "$($script:CASE): keys '$got', want '$Want'" }
    }
    # jr_msg TEXT -- the engine's output is exactly TEXT
    function jr_msg([string]$Text) {
        $got = TrimNl (ReadText $script:JERR)
        if ($got -ceq $Text) { ok "$($script:CASE): message '$Text'" }
        else { bad "$($script:CASE): message '$got', want '$Text'" }
    }

    jr_case jr-middle 0 @("rename|$ID_MAC_LC|profiles|nobul-mac")
    jr_keys "first,$ID_MAC_LC,last" @("profiles")
    if ((JplText @("get", $JOUT, "profiles", $ID_MAC_LC, "machine", "hostname")) -ceq "nobul-mac") { ok "jr-middle: value moved with the key" }
    else { bad "jr-middle: value lost" }
    $jd = Get-LcsDiff (Get-Lines "$JW/in.json") (Get-Lines $JOUT)
    WriteText "$JW/jr-middle.diff" (($jd -join "`n") + "`n")
    $keyLineRe = [regex]::new('^> +"' + [regex]::Escape($ID_MAC_LC) + '": \{$')
    $kn = @($jd | Where-Object { $keyLineRe.IsMatch($_) }).Count
    if ($jd.Count -eq 2 -and $kn -eq 1) {
        ok "jr-middle: only the key line changed (other bytes kept)"
    } else { bad "jr-middle: unexpected changes"; Show-Indented (ReadText "$JW/jr-middle.diff") }

    jr_case jr-first 0 @("rename|first-renamed|profiles|first")
    jr_keys "first-renamed,nobul-mac,last" @("profiles")
    jr_case jr-last 0 @("rename|z|profiles|last")
    jr_keys "first,nobul-mac,z" @("profiles")
    jr_case jr-top 0 @("rename|ident|identity")
    jr_keys "version,ident,claude,profiles"
    jr_case jr-then-set 0 @("rename|new-key|profiles|nobul-mac", "set|nobul-mac|profiles|new-key|alias")
    jr_keys "name,company,machine,alias" @("profiles", "new-key")
    jr_case jr-case-only 0 @("rename|NOBUL-MAC|profiles|nobul-mac")
    jr_keys "first,NOBUL-MAC,last" @("profiles")
    jr_case jr-same 0 @("rename|nobul-mac|profiles|nobul-mac")
    if (SameFile "$JW/in.json" $JOUT) { ok "jr-same: no-op, bytes unchanged" } else { bad "jr-same: file changed" }

    jr_case jr-missing 2 @("rename|x|profiles|nope")
    jr_msg "rename: 'nope' not found"
    jr_case jr-exists 2 @("rename|last|profiles|first")
    jr_msg "rename: 'last' already exists"
    jr_case jr-exists-case 2 @("rename|LAST|profiles|first")
    jr_msg "rename: 'LAST' already exists"
    jr_case jr-old-case 2 @("rename|x|profiles|NOBUL-MAC")
    jr_msg "rename: 'NOBUL-MAC' not found"
    jr_case jr-path-missing 2 @("rename|x|nope|nobul-mac")
    jr_msg "rename: 'nope' not found"
    jr_case jr-not-object 2 @("rename|x|version|y")
    jr_msg "rename: 'version' is not an object"
    jr_case jr-no-key 2 @("rename|x")
    jr_msg "rename: no key given"
    jr_case jr-empty-new 2 @("rename||profiles|first")
    jr_msg "rename: new key is empty"

    # Scalar and array values two levels down (review S3-M3-JsonRename-Review, nit 2)
    jr_case jr-deep-scalar 0 @("rename|p2|claude|settings|path")
    jr_keys "z,p2,tab,emoji,when" @("claude", "settings")
    jr_case jr-deep-array 0 @("rename|zz|claude|settings|z")
    jr_keys "zz,path,tab,emoji,when" @("claude", "settings")

    # Null, empty-array, single-item-array and object values three levels deep; non-ASCII
    # keys (built from code points: E-acute U+00C9, e-acute U+00E9)
    $UcEte = [string][char]0xC9 + "t" + [char]0xE9      # the key E-acute,t,e-acute
    $LcEte = [string][char]0xE9 + "t" + [char]0xE9      # its lower-case form
    WriteText "$JW/uni.json" ((NL @('{', '  "a": {', '    "b": {', '      "n": null,', '      "e": [],', '      "one": [', '        1', '      ],',
                ('      "' + $UcEte + '": {},'), '      "k": true', '    }', '  }', '}')) + "`n")
    $script:JR_IN = "$JW/uni.json"
    jr_case jr-null 0 @("rename|nn|a|b|n")
    jr_keys "nn,e,one,$UcEte,k" @("a", "b")
    jr_case jr-empty-array 0 @("rename|ee|a|b|e")
    jr_case jr-one-array 0 @("rename|oo|a|b|one")
    jr_case jr-unicode-key 0 @("rename|${LcEte}2|a|b|$UcEte")
    jr_keys "n,e,one,${LcEte}2,k" @("a", "b")
    # Another key equal ignoring Unicode case: refused by both (PowerShell could not read the result)
    jr_case jr-unicode-exists 2 @("rename|$LcEte|a|b|k")
    jr_msg "rename: '$LcEte' already exists"
    $script:JR_IN = ""

    # A failed rename leaves an existing output file untouched (perl writes only on
    # success): the perl engine's own guarantee, macOS/Linux
    skip "jr-keep-out (the perl engine's edit command: macOS/Linux)"

    # --- S3-MF-Audit A-6..A-9: write failures, key case, detail logging ------------------
    # JSON engines: a set whose new segment equals an existing key ignoring case is
    # refused by both, with one message (A-9; perl used to add a sibling key that
    # ConvertFrom-Json cannot read, PowerShell overwrote the other key)
    jr_case jr-set-case-last 2 @("set|v|profiles|NOBUL-MAC")
    jr_msg "set: 'NOBUL-MAC' differs only in case from existing key 'nobul-mac'"
    jr_case jr-set-case-mid 2 @("set|v|profiles|NOBUL-MAC|alias")
    jr_msg "set: 'NOBUL-MAC' differs only in case from existing key 'nobul-mac'"
    jr_case jr-set-case-top 2 @("set|v|Profiles")
    jr_msg "set: 'Profiles' differs only in case from existing key 'profiles'"
    jr_case jr-set-exact 0 @("set|v|profiles|nobul-mac|brand-new")
    if ((JplText @("get", $JOUT, "profiles", "nobul-mac", "brand-new")) -ceq "v") { ok "jr-set-exact: new key written" }
    else { bad "jr-set-exact: new key missing" }
    $script:JR_IN = "$JW/uni.json"
    jr_case jr-set-case-unicode 2 @("set|v|a|b|$LcEte")
    jr_msg "set: '$LcEte' differs only in case from existing key '$UcEte'"
    $script:JR_IN = ""

    fresh_home a69
    $script:EXC_DIR = "$H/repos/aitools-nobul-jose"
    $script:EXC_PF = "$($script:EXC_DIR)/profile.json"
    # (the .sh's `writable` undoes a chmod 555 fixture; nothing here is read-only)
    function exc_case_profile { return (Edit-First (exc_profile) '("hostname": "nobul-mac.local",\n        "os": "darwin"\n      \})' ('$1,' + "`n" + '      "ToolExceptions": {}')) }
    function setup_a69_case {
        Remove-Tree $script:EXC_DIR
        write_profile $script:EXC_DIR (exc_case_profile)
        WriteText "$($script:H)/.aitools/config.json" ('{ "githubUser": "nobul-jose" }' + "`n")
    }
    # exception-set on a profile with a hand-written "ToolExceptions": refused by both,
    # same lines, profile.json untouched
    case_fresh a9-exc-case 2 setup_a69_case ($SET_ARGS + $MA)
    expect result failed
    expect_line "^error\texception-set failed: set: 'toolExceptions' differs only in case from existing key 'ToolExceptions'$"
    if (SameBytes "$NWORK/a9-exc-case.profile.json" (exc_case_profile)) { ok "a9-exc-case: profile.json untouched" }
    else { bad "a9-exc-case: profile.json changed" }

    # A temp file that cannot be written: same message in both (A-8), no temp file left (A-7).
    # A read-only directory (chmod 555) is POSIX: on Windows chmod does not stop a file
    # being created in a directory, so these cases run on macOS/Linux only.
    skip "a78-exc-ro, a8-mig-ro (a read-only directory needs POSIX permissions: macOS/Linux)"
    # register --out that cannot be written (read-only directory, missing directory)
    write_profile "$H/a8reg" (exc_profile)
    skip "a8-reg-ro (a read-only directory needs POSIX permissions: macOS/Linux)"
    case_run a8-reg-nodir 2 (@("register", "--profile", "$H/a8reg/profile.json", "--alias", "nobul-mac", "--out", "$H/a8none/sub/out.json") + $MA)
    expect_line "^error\tregister failed: cannot write $H/a8none/sub/out.json: No such file or directory$"

    # snapshot failures reach deploy.log at detail, not only stderr (A-6): one line for
    # the one resolver run
    $A6_RUNS = 1
    # a6_logged NAME TEXT -- deploy.log has TEXT on A6_RUNS detail lines (the log's
    # native paths read back as NWORK paths)
    function a6_logged([string]$Name, [string]$Text) {
        Copy-Item -LiteralPath "$($script:H)/.aitools/logs/deploy.log" -Destination "$NWORK/a6-deploy.log" -Force
        ConvertFrom-NativeWork "$NWORK/a6-deploy.log"
        # (a loop, not a pipeline: Get-Lines returns its array as one object)
        $cnt = 0
        foreach ($ln in (Get-Lines "$NWORK/a6-deploy.log")) { if ($ln.Contains("[detail] $Text")) { $cnt++ } }
        if ($cnt -eq $A6_RUNS) { ok "${Name}: logged at detail ($cnt)" }
        else { bad "${Name}: $cnt detail lines in deploy.log, want $A6_RUNS" }
    }
    case_run a6-snap-missing 1 @("snapshot", "--profile", "$H/a6none/profile.json")
    a6_logged a6-snap-missing "snapshot: profile.json not found: $H/a6none/profile.json"
    WriteText "$H/a6bad.json" ('{ "version": ' + "`n")
    case_run a6-snap-invalid 2 @("snapshot", "--profile", "$H/a6bad.json")
    a6_logged a6-snap-invalid "snapshot: $H/a6bad.json is invalid JSON"

    # --- Fail-safe log writes (reference/logging.md section 5; incident #174) -----------
    # A deploy.log that cannot be written must not end the resolver. AITOOLS_ENVIRONMENT
    # =bogus makes Initialize-Logging log a warning through the resolver's own log
    # override before the command runs; the command must still answer (exit 0, its
    # data on stdout) and the warning must still reach stderr, with no write error.
    # Writable: the warning is also in deploy.log. A lock held by another process:
    # tests/logging/test-logging.ps1.
    # log_case NAME -- the hostname command with an injected name; the checks above
    function log_case([string]$Name) {
        $script:CaseEnv = @{ AITOOLS_ENVIRONMENT = "bogus" }
        case_run $Name 0 @("hostname", "--hostname-value", "probe-host") -NoParity
        $script:CaseEnv = @{}
        if ((TrimNl ((ReadText $script:OUT).Replace("`r", ""))) -ceq "probe-host") { ok "${Name}: stdout is the data only" }
        else { bad "${Name}: stdout '$(TrimNl (ReadText $script:OUT))', want probe-host" }
        if ((ReadText "$($script:OUT).err").Contains("[aitools-profile] [warn] AITOOLS_ENVIRONMENT='bogus' ignored")) { ok "${Name}: the warning reached stderr" }
        else { bad "${Name}: no warning on stderr"; Show-Indented (ReadText "$($script:OUT).err") }
        if ([regex]::IsMatch((ReadText "$($script:OUT).err"), 'Exception|AppendAllText|Is a directory|Permission denied|cannot access')) {
            bad "${Name}: a write error reached stderr"; Show-Indented (ReadText "$($script:OUT).err")
        } else { ok "${Name}: no write error on stderr" }
    }
    fresh_home log-written
    log_case log-written
    if ((ReadText "$H/.aitools/logs/deploy.log").Contains("[aitools-profile] [warn] AITOOLS_ENVIRONMENT='bogus' ignored")) { ok "log-written: the warning is in deploy.log" }
    else { bad "log-written: the warning is not in deploy.log" }
    fresh_home log-blocked
    MkDir "$H/.aitools/logs/deploy.log"
    log_case log-blocked
    # POSIX permission case (bash, macOS/Linux): mode 000
    skip "log-unwritable (POSIX permissions: macOS/Linux)"

    # --- usage ------------------------------------------------------------------------
    case_run usage-unknown 2 @("resolve", "--bogus")
    case_run usage-nocmd 2 @() -NoParity   # help text names each platform's sources
} catch {
    # A harness step failed (a fixture git command, a file write): the .sh stops under
    # set -e; here it is one FAIL, and the summary still prints
    bad "harness error: $($_.Exception.Message)"
    Show-Indented ($_.ScriptStackTrace)
} finally {
    if ($null -ne $SavedOutputEncoding) { try { [Console]::OutputEncoding = $SavedOutputEncoding } catch { Write-Output "  note: console output encoding not restored ($($_.Exception.Message))" } }
    Remove-TestTempRoot $WORK
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: aitools-profile.{3})" -f $script:PASS, $script:FAIL, $script:SKIP, $LangRun)
if ($script:FAIL -ne 0) { exit 1 }
exit 0
