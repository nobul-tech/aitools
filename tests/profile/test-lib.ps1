# test-lib.ps1 -- tests for the aitools-lib profile wrappers on Windows:
# Resolve-UserRepoPath, Resolve-MachineProfile, Get-ToolException,
# Set-ToolException, the resolver runner Invoke-AitLibProfile, the child-log
# relay helpers Write-JsonlRecord, Send-ChildLog and Invoke-ChildRelayed
# (scripts/aitools-lib.ps1 with scripts/aitools-profile.ps1, native pwsh), and
# the Git Bash pwsh branch of the aitools-lib.sh wrappers (resolve_user_repo_path,
# resolve_machine_profile, tool_exception_record, _aitlib_profile_run under Git
# Bash run scripts/aitools-profile.ps1 through pwsh, as build-deploy.sh and the
# scripts/aitools bash entry point do on Windows).
# The Windows harness of this suite; tests/profile/test-lib.sh is the
# macOS/Linux harness of the same wrappers in aitools-lib.sh.
#
# Each case runs a driver in a fresh child (pwsh, or Git Bash for the "gitbash"
# cases) with an isolated HOME, calls one wrapper, and prints its return code,
# $script:AitLib* / AITLIB_* results, warning/error counters and the summary
# rows; they must match the expectation. Check names, order and expectations
# are the ones test-lib.sh printed on Windows (CI "Profile lib wrapper tests").
# The one sh-vs-ps1 parity comparison (relay-record: identical deploy.jsonl
# records) is checked against the committed golden file
# tests/profile/golden/lib-relay-record.jsonl (Test-GoldenMatch in
# tests/lib/platform-lib.ps1; host and os replaced by <HOST> and <OS>).
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs on Windows only, with native pwsh. The "gitbash" cases
# test cross-platform bash library code that runs on Windows, so they run it
# with Git for Windows bash (Resolve-TestGitBash); without Git Bash they are
# reported as SKIP.
#
# Safe to re-run: every case runs under a temp HOME inside one temp directory
# (removed on exit); the real HOME is never read or written by a case. Exit 1
# if any check fails.
#
# Usage: pwsh -NoProfile -File tests/profile/test-lib.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 34 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/profile/test-lib.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$REPO = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $REPO "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$GitBash = Resolve-TestGitBash
$WORK = New-TestTempRoot "profile-lib"
$GoldenDir = Join-Path $REPO "tests/profile/golden"
$GoldenTmp = $WORK

$script:pass = 0; $script:fail = 0; $script:skip = 0
function Ok([string]$N) { $script:pass++; Write-Output "  ok   $N" }
function Bad([string]$N) { $script:fail++; Write-Output "  FAIL $N" }
function SkipLine([string]$Text) { $script:skip++; Write-Output "  skip $Text" }
function J { $args -join "`n" }   # J LINE... : the lines joined with LF (a multi-line expectation)

# Child output is UTF-8 (the Git Bash driver prints a non-ASCII identity name; the
# old Git Bash harness compared bytes). The console code page decides how pwsh
# decodes a native child's output, so it is set to UTF-8 here and restored on exit.
$savedOutputEncoding = [Console]::OutputEncoding

# The temp root in the spellings the drivers use: mixed (C:/..., what cygpath -m
# gave the old harness, passed to native pwsh) and MSYS (/c/..., passed to Git
# Bash). Expectations use the mixed form; ConvertFrom-NativeWork maps every
# spelling a child prints back to it.
$WM = $WORK -replace '\\', '/'
$WU = ConvertTo-MsysPath $WORK
$RepoM = $REPO -replace '\\', '/'
$RepoU = ConvertTo-MsysPath $REPO

$ID_MAC = "3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"
$ID_KEY = "3d4df2a5-7d91-5af9-9944-4feebaae3cf5"   # ID_MAC lower-cased: the profiles key (revision 2.2)
$H = Join-Path $WORK "home"                       # native, for this harness's own file operations
$DPn = Join-Path $H "repos/aitools-nobul-jose"
$DP = "$WM/home/repos/aitools-nobul-jose"         # the dotprofile as expectations spell it
$A_DP = "ACTION||see deploy.log -- the dotprofile could not be resolved"
$E_ACUTE = [string][char]0xE9; $CHECK = [string][char]0x2713   # ASCII source: the non-ASCII test characters by code

# WorkRegexes: every spelling of $WORK a child may print -- native C:\..., mixed
# C:/..., JSON-escaped C:\\..., MSYS /c/..., each also for the 8.3 short form --
# longest first, without regard to case (the old harness's from_native).
$workSpellings = @($WORK)
try {
    $short = (New-Object -ComObject Scripting.FileSystemObject).GetFolder($WORK).ShortPath
    if ($short) { $workSpellings += $short } else { Write-Output "  note: no 8.3 spelling of $WORK (that spelling is not mapped back)" }
} catch {
    Write-Output "  note: no 8.3 spelling of $WORK ($($_.Exception.Message)); that spelling is not mapped back"
}
$seen = @{}
foreach ($n in $workSpellings) {
    $bs = $n -replace '/', '\'
    $js = $bs -replace '\\', '\\'
    $mixed = $bs -replace '\\', '/'
    $us = ConvertTo-MsysPath $bs
    foreach ($s in @($js, $bs, $mixed, $us)) { if ($s) { $seen[$s.ToLowerInvariant()] = $s } }
}
# Git Bash's own spelling: cygpath -u turns a root under %TEMP% into /tmp/...
# (Git for Windows mounts /tmp there), and the lib's wrappers print what cygpath
# gives. The old Git Bash harness had this spelling as its $WORK.
if ($GitBash) {
    $gbWork = ((& $GitBash -c 'cygpath -u "$1"' cygpath-u $WM) | Out-String).Trim()
    if ($LASTEXITCODE -eq 0 -and $gbWork) { $seen[$gbWork.ToLowerInvariant()] = $gbWork }
    else { Write-Output "  note: Git Bash cygpath -u gave no spelling of $WORK (that spelling is not mapped back)" }
}
$script:WorkRegexes = @($seen.Values | Sort-Object -Property Length -Descending | ForEach-Object {
    [regex]::new([regex]::Escape($_) + '([^\s"''|()]*)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
})

# ConvertFrom-NativeWork TEXT -- TEXT with CRs removed and every spelling of $WORK
# replaced by $WM, the separators after it turned into slashes
function ConvertFrom-NativeWork([string]$Text) {
    $t = $Text -replace "`r", ""
    foreach ($re in $script:WorkRegexes) {
        $t = $re.Replace($t, { param($m) $WM + (($m.Groups[1].Value -replace '\\\\', '/') -replace '\\', '/') })
    }
    return $t
}
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
# Write-LfFile PATH TEXT -- UTF-8 without BOM, LF line ends (this file checks out
# CRLF; bash refuses a script with CRs)
function Write-LfFile([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}
# Select-Lines TEXT PATTERN -- the lines of TEXT that match PATTERN (case-sensitive,
# as grep -E), joined with LF; trailing newlines dropped as $(...) did
function Select-Lines([string]$Text, [string]$Pattern) {
    return (@($Text -split "`n" | Where-Object { $_ -cmatch $Pattern }) -join "`n")
}
$ResultPattern = '^(rc|path|alias|found|result|kept|warnings|key|notes|out|err|args)='

# Variables a case must not inherit from the caller's environment: each case sets
# the ones it needs (an explicit $null removes the rest in the child)
$CaseVars = @("AITOOLS_USER_REPO_PATH", "AITOOLS_MACHINE_ALIAS", "AITOOLS_PROFILE_FILE", "AITOOLS_PROFILE_SH",
    "AITOOLS_PROFILE_PS1", "AITOOLS_DRY_RUN", "AITOOLS_FORCE", "AITOOLS_ENVIRONMENT", "AITLIB_PROFILE_VIA_PWSH",
    "SHOW_NOTES", "RUN_ARGS", "FAKEBIN", "PRE_ROW", "RO_DIR", "AITOOLS_RUN_ID")
function New-CaseEnv {
    $e = @{}
    foreach ($v in $CaseVars) { $e[$v] = $null }
    return $e
}
# Add-Extra ENV EXTRA W -- EXTRA: "VAR=value" strings; "<W>" in a value becomes W
# (the temp root in the spelling the child reads)
function Add-Extra([hashtable]$Env, [string[]]$Extra, [string]$W) {
    foreach ($x in @($Extra)) {
        if (-not $x) { continue }
        $kv = $x -split '=', 2
        $Env[$kv[0]] = $kv[1].Replace("<W>", $W)
    }
}

$script:FixKind = ""
$script:FixName = "Jose"
# New-Fixture with-id|with-exc|hostname-only|id-key|other-id|none (identity name: $FixName)
# with-id / with-exc / hostname-only: legacy (revision 2.1) entry keyed by alias;
# id-key: this machine's entry keyed by its id (2.2); other-id: another machine's
# id-keyed entry that has this machine's hostname
function New-Fixture([string]$Kind) {
    $script:FixKind = $Kind
    if (Test-Path -LiteralPath $H) { Remove-Item -LiteralPath $H -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $H "repos"), (Join-Path $H ".aitools") -Force | Out-Null
    Write-LfFile (Join-Path $H ".aitools/config.json") "{ `"githubUser`": `"nobul-jose`" }`n"
    if ($Kind -eq "none") { return }
    New-Item -ItemType Directory -Path $DPn -Force | Out-Null
    $idline = ""; $excline = ""
    if ($Kind -eq "with-id" -or $Kind -eq "with-exc") { $idline = "`"id`": `"$ID_MAC`"," }
    if ($Kind -eq "with-exc") {
        $excline = ', "toolExceptions": { "go": { "decision": "keep", "detected": { "platform": "macos", "method": "pkg-installer", "path": "/usr/local/bin/go", "version": "1.22.5" }, "decidedAt": "2026-10-01T00:00:00Z", "decidedBy": "setup-go", "reason": null } }'
    }
    $entry = "`"nobul-mac`": { `"machine`": { $idline `"hostname`": `"nobul-mac`" }$excline }"
    if ($Kind -eq "id-key") {
        $entry = "`"$ID_KEY`": { `"alias`": `"nobul-mac`", `"company`": `"nobul-mac-co`", `"machine`": { `"id`": `"$ID_KEY`", `"hostname`": `"nobul-mac`" } }"
    } elseif ($Kind -eq "other-id") {
        $entry = "`"aaaaaaaa-1111-2222-3333-444444444444`": { `"alias`": `"old-mac`", `"machine`": { `"id`": `"aaaaaaaa-1111-2222-3333-444444444444`", `"hostname`": `"nobul-mac`" } }"
    }
    $json = J "{" `
        '  "version": 2,' `
        "  `"identity`": { `"github`": `"nobul-jose`", `"name`": `"$($script:FixName)`", `"company`": `"nobul-tech`", `"git`": { `"name`": `"Jose`", `"email`": `"jose@nobul.tech`" } }," `
        '  "profiles": {' `
        "    $entry" `
        '  }' `
        "}"
    Write-LfFile (Join-Path $DPn "profile.json") "$json`n"
    # git's stderr (e.g. a line-ending notice) is captured for the error message, not
    # turned into a terminating error; the exit code decides
    $ErrorActionPreference = "Continue"
    foreach ($g in @(@("init", "-q"), @("config", "user.name", "Test"), @("config", "user.email", "test@example.com"),
            @("add", "profile.json"), @("commit", "-q", "-m", "init"))) {
        $gout = & git -C $DPn @g 2>&1
        if ($LASTEXITCODE -ne 0) { throw "fixture ${Kind}: git $($g -join ' ') failed (exit $LASTEXITCODE): $gout" }
    }
}
# Set-NoMatch -- the with-id fixture's id and hostname changed (perl -pi in the
# .sh: the first occurrence on each line)
function Set-NoMatch {
    $pf = Join-Path $DPn "profile.json"
    $re1 = [regex]::new([regex]::Escape($ID_MAC)); $re2 = [regex]::new('"hostname": "nobul-mac"')
    $lines = ([IO.File]::ReadAllText($pf)) -split "`n"
    $lines = @($lines | ForEach-Object { $re2.Replace($re1.Replace($_, "OTHER-ID", 1), '"hostname": "elsewhere"', 1) })
    Write-LfFile $pf ($lines -join "`n")
}

# Resolver stubs for the AITOOLS_PROFILE_PS1 override cases (the .ps1 halves of the
# .sh harness's stubs; the bash resolvers are not used on Windows)
Write-LfFile "$WORK/stub.ps1" ('"path`t/stub/aitools-dp"' + "`n" + '"via`tenv"' + "`nexit 0`n")
# Broken resolvers (PR #80 review 2, M1): silent exit 0 / exit 1, a throw, a parse error
Write-LfFile "$WORK/silent0.ps1" "exit 0`n"
Write-LfFile "$WORK/silent1.ps1" "exit 1`n"
Write-LfFile "$WORK/throw.ps1" "throw `"boom`"`n"
Write-LfFile "$WORK/parse.ps1" "if (`n"
# Re-key batch 3: resolvers that exit 3 (refused) and 4 (alias in use), and a
# resolver that predates the id-key fields (no key/owner/legacy lines)
foreach ($n in 3, 4) {
    Write-LfFile "$WORK/exit$n.ps1" ('"via`tnone"' + "`n" + '"error`tstub says no"' + "`nexit $n`n")
}
Write-LfFile "$WORK/oldres.ps1" ((J '"alias`tnobul-mac"' '"via`tid"' '"hostname`tnobul-mac"' '"name`tJose"' '"company`tnobul-tech"' 'exit 0') + "`n")
# M3-FINISH item 3: commands that print a "result" line and no "via" line
# (register, migrate), a bare hostname value, a plain error exit, and a stub that
# echoes its arguments (the Git Bash path conversion)
Write-LfFile "$WORK/res0.ps1" ((J '"result`tcreated"' '"key`tk1"' 'exit 0') + "`n")
Write-LfFile "$WORK/res1.ps1" ((J '"result`tfailed"' '"error`tprofile.json not found"' 'exit 1') + "`n")
Write-LfFile "$WORK/host.ps1" ((J '"probe-host"' 'exit 0') + "`n")
Write-LfFile "$WORK/exit2.ps1" ((J '"error`tbad input"' 'exit 2') + "`n")
Write-LfFile "$WORK/args.ps1" ((J '"result`tok"' 'foreach ($x in $args) { "arg`t$x" }' 'exit 0') + "`n")
# A cygpath stub for the Git Bash cases: -w marks paths under /conv/ (W/conv/...);
# every other call goes to the real cygpath (the resolver path itself must be
# converted), or prints the path as is where there is none
New-Item -ItemType Directory -Path "$WORK/fakebin" -Force | Out-Null
$realCygpath = ""
if ($GitBash) {
    $realCygpath = ((& $GitBash -c 'command -v cygpath') | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { $realCygpath = "" }
    if (-not $realCygpath) { Write-Output "  note: Git Bash has no cygpath: the stub prints its argument unchanged" }
}
Write-LfFile "$WORK/fakebin/cygpath" ("#!/usr/bin/env bash`ncase `"`$2`" in /conv/*) printf `"W%s\n`" `"`$2`" ;; *) if [ -n `"$realCygpath`" ]; then exec `"$realCygpath`" `"`$@`"; fi; printf `"%s\n`" `"`$2`" ;; esac`n")

# Bash driver (the Git Bash cases): source the lib, run one call, print the results
Write-LfFile "$WORK/drive.sh" @'
set -euo pipefail
if [ "$CALL" = "keep" ]; then
    # A caller's own variables with the names the lib used before PR #80's fix
    USER_REPO_PATH=/caller/urp; PROFILE_FILE=/caller/pf; MACHINE_ALIAS=caller; PROFILE_NAME=caller-name
fi
source "$REPO/scripts/aitools-lib.sh"
logging_init "test-lib"
LOG_START=$(perl -ne 'END { print $. + 0 }' "$LOG_FILE")
rc=0
case "$CALL" in
    urp)  resolve_user_repo_path || rc=$? ;;
    urp2) resolve_user_repo_path || rc=$?; rc=0; resolve_user_repo_path || rc=$? ;;
    rmp|rmpk)  resolve_machine_profile || rc=$? ;;
    rmp2) resolve_machine_profile || rc=$?; rc=0; resolve_machine_profile || rc=$? ;;
    eget) tool_exception_get go || rc=$? ;;
    eset) tool_exception_record go pkg-installer /usr/local/bin/go 1.22.5 || rc=$? ;;
    eset2)
        tool_exception_record go pkg-installer /usr/local/bin/go 1.22.5 || rc=$?
        WARNINGS=0; : > "$AITOOLS_SUMMARY_FILE"; rc=0   # judge the second, identical call only
        tool_exception_record go pkg-installer /usr/local/bin/go 1.22.5 || rc=$? ;;
    keep) resolve_user_repo_path || rc=$?; resolve_machine_profile || rc=$? ;;
    run)
        # The runner itself: RUN_ARGS is comma-separated; FAKEBIN goes first on PATH
        if [ -n "${FAKEBIN:-}" ]; then PATH="$FAKEBIN:$PATH"; fi
        IFS=, read -r -a run_args <<< "$RUN_ARGS"
        _aitlib_profile_run "${run_args[@]}" || rc=$?
        printf 'rc=%s profrc=%s\n' "$rc" "$AITLIB_PROFILE_RC"
        v=$(_aitlib_profile_tag result); if [ -z "$v" ]; then v=$(_aitlib_profile_tag via); fi
        if [ -z "$v" ]; then v=$(printf '%s\n' "$AITLIB_PROFILE_OUT" | perl -ne 'print, exit if /^[^\t]+$/'); fi
        printf 'out=%s\n' "$v"
        printf 'err=%s\n' "$(_aitlib_profile_lines error | perl -ne 'print, exit if /\S/')"
        a=$(_aitlib_profile_lines arg | perl -pe 's/\n/ /' | perl -pe 's/ $//')
        if [ -n "$a" ]; then printf 'args=%s\n' "$a"; fi
        printf 'warnings=%s errors=%s\n' "$WARNINGS" "$ERRORS"
        exit 0 ;;
esac
printf 'rc=%s\n' "$rc"
case "$CALL" in
    urp|urp2)  printf 'path=%s via=%s\n' "$AITLIB_USER_REPO_PATH" "$AITLIB_USER_REPO_VIA" ;;
    rmp|rmp2) printf 'alias=%s via=%s company=%s name=%s\n' "$AITLIB_MACHINE_ALIAS" "$AITLIB_MACHINE_VIA" "$AITLIB_PROFILE_COMPANY" "$AITLIB_PROFILE_NAME" ;;
    rmpk)
        printf 'alias=%s via=%s company=%s\n' "$AITLIB_MACHINE_ALIAS" "$AITLIB_MACHINE_VIA" "$AITLIB_PROFILE_COMPANY"
        printf 'key=%s owner=%s legacy=%s host=%s\n' "$AITLIB_MACHINE_KEY" "$AITLIB_MACHINE_OWNER" "$AITLIB_MACHINE_LEGACY" "$AITLIB_MACHINE_HOSTNAME" ;;
    eget) printf 'found=%s method=%s path=%s\n' "$AITLIB_TOOL_EXC_FOUND" "$AITLIB_TOOL_EXC_METHOD" "$AITLIB_TOOL_EXC_PATH" ;;
    eset|eset2) printf 'result=%s pushed=%s\n' "$AITLIB_TOOL_EXC_RESULT" "$AITLIB_TOOL_EXC_PUSHED" ;;
    keep)
        printf 'kept=urp:%s pf:%s alias:%s name:%s\n' "$USER_REPO_PATH" "$PROFILE_FILE" "$MACHINE_ALIAS" "$PROFILE_NAME"
        printf 'alias=%s urp-via=%s\n' "$AITLIB_MACHINE_ALIAS" "$AITLIB_USER_REPO_VIA" ;;
esac
printf 'warnings=%s errors=%s\n' "$WARNINGS" "$ERRORS"
# SHOW_NOTES=1: how many log lines name a resolver exit 3 or 4 (batch 3 mapping)
if [ "${SHOW_NOTES:-}" = "1" ]; then
    printf 'notes=%s\n' "$(perl -ne '$n++ if $. > '"$LOG_START"' && /resolver exit [34]: /; END { print $n + 0 }' "$LOG_FILE")"
fi
'@

# PowerShell driver. The parameters reproduce PR #80 B1: setup-user-config.ps1
# declares [string]$UserRepoPath and dot-sources the lib; it must keep its value.
Write-LfFile "$WORK/drive.ps1" @'
param([string]$UserRepoPath = "", [string]$MachineAlias = "", [string]$ProfileFile = "")
$profileName = "caller-name"
. (Join-Path $env:REPO "scripts/aitools-lib.ps1")
Initialize-Logging "test-lib"
$logStart = @([IO.File]::ReadAllLines($logFile)).Count
$rc = 0
switch ($env:CALL) {
    "urp"  { $rc = Resolve-UserRepoPath }
    "urp2" { $null = Resolve-UserRepoPath; $rc = Resolve-UserRepoPath }
    { $_ -in "rmp", "rmpk" } { $rc = Resolve-MachineProfile }
    "rmp2" { $null = Resolve-MachineProfile; $rc = Resolve-MachineProfile }
    "eget" { $r = Get-ToolException "go"; $rc = if ($null -eq $r) { 1 } else { 0 } }
    "eset" { $rc = Set-ToolException "go" "pkg-installer" "/usr/local/bin/go" "1.22.5" }
    "eset2" {
        $null = Set-ToolException "go" "pkg-installer" "/usr/local/bin/go" "1.22.5"
        $script:warnings = 0; [IO.File]::WriteAllText($env:AITOOLS_SUMMARY_FILE, "")
        $rc = Set-ToolException "go" "pkg-installer" "/usr/local/bin/go" "1.22.5"
    }
    "keep" { $null = Resolve-UserRepoPath; $rc = Resolve-MachineProfile }
    "run" {
        # The runner itself: RUN_ARGS is comma-separated
        $ran = Invoke-AitLibProfile @($env:RUN_ARGS -split ',')
        $rc = if ($ran) { 0 } else { 1 }
        "rc=$rc profrc=$($script:AitLibProfileRc)"
        $v = Get-AitLibProfileTag "result"; if (-not $v) { $v = Get-AitLibProfileTag "via" }
        if (-not $v) { $v = @($script:AitLibProfileOut | Where-Object { $_ -and -not $_.Contains("`t") }) | Select-Object -First 1 }
        "out=$v"
        "err=$(@(Get-AitLibProfileLines 'error' | Where-Object { $_ -match '\S' }) | Select-Object -First 1)"
        $a = @(Get-AitLibProfileLines "arg")
        if ($a.Count) { "args=$($a -join ' ')" }
        "warnings=$($script:warnings) errors=$($script:errors)"
        exit 0
    }
}
"rc=$rc"
switch ($env:CALL) {
    { $_ -in "urp", "urp2" } { "path=$($script:AitLibUserRepoPath) via=$($script:AitLibUserRepoVia)" }
    { $_ -in "rmp", "rmp2" } { "alias=$($script:AitLibMachineAlias) via=$($script:AitLibMachineVia) company=$($script:AitLibProfileCompany) name=$($script:AitLibProfileName)" }
    "rmpk" {
        "alias=$($script:AitLibMachineAlias) via=$($script:AitLibMachineVia) company=$($script:AitLibProfileCompany)"
        $lg = if ($script:AitLibMachineLegacy) { "true" } else { "false" }
        "key=$($script:AitLibMachineKey) owner=$($script:AitLibMachineOwner) legacy=$lg host=$($script:AitLibMachineHostname)"
    }
    "eget" { $f = if ($r -and $r.Found) { "true" } else { "false" }; $m = if ($r) { $r.Method } else { "" }; $p = if ($r) { $r.Path } else { "" }; "found=$f method=$m path=$p" }
    { $_ -in "eset", "eset2" } { $pu = if ($script:AitLibToolExcPushed) { "true" } else { "false" }; "result=$($script:AitLibToolExcResult) pushed=$pu" }
    "keep" {
        "kept=urp:$UserRepoPath pf:$ProfileFile alias:$MachineAlias name:$profileName"
        "alias=$($script:AitLibMachineAlias) urp-via=$($script:AitLibUserRepoVia)"
    }
}
"warnings=$($script:warnings) errors=$($script:errors)"
if ($env:SHOW_NOTES -eq "1") {
    "notes=$(@([IO.File]::ReadAllLines($logFile) | Select-Object -Skip $logStart | Where-Object { $_ -cmatch 'resolver exit [34]: ' }).Count)"
}
'@

# Invoke-Case NAME CALL EXPECTED-OUTPUT EXPECTED-SUMMARY [EXTRA] [IMPL]
# EXTRA: "VAR=value" strings ("<W>" = the temp root as the child spells it).
# IMPL: "ps" (default; native pwsh, aitools-lib.ps1) or "gitbash" (aitools-lib.sh
# under Git Bash: its wrappers run aitools-profile.ps1 through native pwsh)
function Invoke-Case([string]$Name, [string]$Call, [string]$Want, [string]$WSum, [string[]]$Extra = @(), [string]$Impl = "ps") {
    if ($Impl -eq "gitbash" -and -not $GitBash) {
        SkipLine "$Name (gitbash): Git for Windows bash not found (the Git Bash pwsh branch is not tested)"
        return
    }
    $sumFile = Join-Path $H "summary.txt"
    [IO.File]::WriteAllText($sumFile, "")
    $out = Join-Path $WORK "case.out"
    $envs = New-CaseEnv
    $envs["CALL"] = $Call
    $envs["AITOOLS_PROFILE_TEST_MACHINE_ID"] = $ID_MAC
    $envs["AITOOLS_PROFILE_TEST_HOSTNAME"] = "nobul-mac"
    if ($Impl -eq "ps") {
        # Native pwsh: Windows paths in the mixed form the old harness passed (cygpath -m)
        $envs["HOME"] = "$WM/home"; $envs["USERPROFILE"] = "$WM/home"
        $envs["AITOOLS_LOG_DIR"] = "$WM/home/.aitools/logs"; $envs["AITOOLS_SUMMARY_FILE"] = "$WM/home/summary.txt"
        $envs["REPO"] = $RepoM
        Add-Extra $envs $Extra $WM
        $rc = Invoke-TestScript -FilePath $pwshExe -Environment $envs -OutFile $out -ArgumentList @(
            "-NoProfile", "-NonInteractive", "-File", "$WM/drive.ps1", "-UserRepoPath", "/caller/urp", "-MachineAlias", "caller", "-ProfileFile", "/caller/pf")
        $text = if ($rc -eq 0) { (ReadText $out) -replace "`e\[[0-9;]*m", "" } else { "driver failed: $rc" }
    } else {
        # Git Bash: MSYS paths for the bash code; USERPROFILE in Windows form (the
        # pwsh that the lib starts takes its $HOME from it)
        $envs["HOME"] = "$WU/home"; $envs["USERPROFILE"] = "$WM/home"
        $envs["AITOOLS_LOG_DIR"] = "$WU/home/.aitools/logs"; $envs["AITOOLS_SUMMARY_FILE"] = "$WU/home/summary.txt"
        $envs["REPO"] = $RepoU
        Add-Extra $envs $Extra $WU
        $rc = Invoke-TestScript -FilePath $GitBash -ArgumentList @("$WU/drive.sh") -Environment $envs -OutFile $out
        $text = if ($rc -eq 0) { ReadText $out } else { "driver failed: $rc" }
    }
    # Only the driver's result lines (log lines also reach the output)
    $got = Select-Lines (ConvertFrom-NativeWork $text) $ResultPattern
    Write-LfFile $sumFile (ConvertFrom-NativeWork (ReadText $sumFile))
    if ($got -ceq $Want) { Ok "$Name (${Impl}): result" }
    else {
        Bad "$Name (${Impl}): got"
        foreach ($l in ($got -split "`n")) { Write-Output "         $l" }
        Write-Output "       want"
        foreach ($l in ($Want -split "`n")) { Write-Output "         $l" }
    }
    $sum = (ReadText $sumFile).TrimEnd("`n")
    if ($sum -ceq $WSum) { Ok "$Name (${Impl}): summary rows" }
    else { Bad "$Name (${Impl}): summary '$sum', want '$WSum'" }
    if ($Call -like "eset*") { New-Fixture $script:FixKind }   # state changed: rebuild
}

# Child scripts for the relay cases: log through the lib, info, a warning with a
# quote, a backslash and a tab, a second warning, then by CHILD_FAIL:
#   0  the standard exit footer, exit 0
#   1  an error, its own ERROR row "child tool|child failed", footer, exit 1
#   2  an error, no row, exit 0 anyway (a child bug)
#   3  exit 1 before any row or footer
#   4  exit 127
#   5  a user abort: "Aborted by user", exit 2 (D-TS13)
#   6  throws
Write-LfFile "$WORK/child.ps1" @'
. (Join-Path $env:REPO "scripts/aitools-lib.ps1")
Initialize-Logging "child-ps"
Log "child info"
LogWarn "quote `" back \ tab`tend"
LogWarn "second warning"
switch ($env:CHILD_FAIL) {
    "1" { LogError "child error"; Write-Summary "ERROR" "child tool" "child failed" }
    "2" { LogError "child error" }
    "3" { exit 1 }
    "4" { exit 127 }
    "5" { LogError "Aborted by user"; exit 2 }
    "6" { throw "child died" }
}
# Review m4: the relay's own parameters and locals must not leak into the child (dynamic scope)
if ($Label -or $ChildScript -or $ChildArgs -or $SummaryTool -or $Detail -or $ErrRows) { LogError "parent's Invoke-ChildRelayed variables are visible" }
if ($errors -gt 0 -and $env:CHILD_FAIL -eq "1") { Log "FAILED with $errors error(s). See log: $logFile" "error"; exit 1 }
elseif ($warnings -gt 0) { Log "COMPLETED with $warnings warning(s)" "warn"; exit 0 }
else { Log "COMPLETED successfully" "ok"; exit 0 }
'@
# A child that does not parse (the relay sees a parse error)
Write-LfFile "$WORK/child-parse.ps1" "Log `"never`"`nif (`n"
# Parent: RMODE=record (one Write-JsonlRecord with CR, ESC, newline, tab, quote,
# backslash, non-ASCII), run (Invoke-ChildRelayed with the summary tool "child
# tool"), run-notool (no summary tool), parse (a child that does not parse),
# noargs (no command), captured (Send-ChildLog on captured output)
$relayPs1 = @'
. (Join-Path $env:REPO "scripts/aitools-lib.ps1")
Initialize-Logging "test-relay"
# PRE_ROW=1: an earlier step's ERROR row is in the summary before the child runs
if ($env:PRE_ROW -eq "1") { Write-Summary "ERROR" "earlier step" "failed before" }
$rc = 0
$child = Join-Path $env:REPO_WORK "child.ps1"
switch ($env:RMODE) {
    "record" { Write-JsonlRecord "2026-01-01T00:00:00Z" "test-relay" "warn" "q `" b \ t`tn`nl`r e$([char]27)[0m x Jos@E_ACUTE@ @CHECK@" }
    "noargs" {
        $rc = Invoke-ChildRelayed "no command" "" @{} "child tool"
        "rc=$rc child_rc=$($script:AitLibChildRc)"
    }
    "run" {
        $rc = Invoke-ChildRelayed "child step" $child @{} "child tool"
        "rc=$rc child_rc=$($script:AitLibChildRc)"
    }
    "run-notool" {
        $rc = Invoke-ChildRelayed "child step" $child @{}
        "rc=$rc child_rc=$($script:AitLibChildRc)"
    }
    "parse" {
        $rc = Invoke-ChildRelayed "child step" (Join-Path $env:REPO_WORK "child-parse.ps1") @{} "child tool"
        "rc=$rc child_rc=$($script:AitLibChildRc)"
    }
    "captured" {
        $global:LASTEXITCODE = 0
        $lines = @(& $child 6>&1 | ForEach-Object { [string]$_ })
        $crc = $LASTEXITCODE
        Send-ChildLog $lines
        "rc=$rc child_rc=$crc"
    }
}
"cw=$($script:AitLibChildWarnings) ce=$($script:AitLibChildErrors) warnings=$($script:warnings) errors=$($script:errors)"
'@
Write-LfFile "$WORK/relay.ps1" ($relayPs1.Replace("@E_ACUTE@", $E_ACUTE).Replace("@CHECK@", $CHECK))

# Get-JsonlCheck FILE WANT-MSG... -- every line valid JSON (strict UTF-8 and JSON)
# with the installers' key order; "records=N invalid=M" and, for each WANT-MSG,
# "msg-ok" / "msg-missing: MSG" (the .sh harness's check-jsonl.pl). A line whose
# top level is not an object is invalid.
function Get-JsonlCheck([string]$File, [string[]]$WantMsgs) {
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { return "records=0 (no file)" }
    $bytes = [IO.File]::ReadAllBytes($File)
    $strict = [Text.UTF8Encoding]::new($false, $true)
    $msgs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $n = 0; $bad = 0; $start = 0
    $segments = [Collections.Generic.List[byte[]]]::new()
    for ($i = 0; $i -le $bytes.Length; $i++) {
        if ($i -eq $bytes.Length -or $bytes[$i] -eq 10) {
            $len = $i - $start
            # a final segment counts only when it is not empty (Perl readline)
            if ($i -lt $bytes.Length -or $len -gt 0) {
                $seg = [byte[]]::new($len)
                [Array]::Copy($bytes, $start, $seg, 0, $len)
                $segments.Add($seg)
            }
            $start = $i + 1
        }
    }
    foreach ($seg in $segments) {
        $n++
        $doc = $null
        try {
            $s = $strict.GetString($seg)
            $doc = [Text.Json.JsonDocument]::Parse($s)
        } catch {
            $bad++; continue
        }
        try {
            if ($doc.RootElement.ValueKind -ne [Text.Json.JsonValueKind]::Object) { $bad++; continue }
            $keys = @([regex]::Matches($s, '"(ts|host|os|script|run_id|level|msg)":') | ForEach-Object { $_.Groups[1].Value }) -join ","
            if ($keys -cne "ts,host,os,script,run_id,level,msg") { $bad++ }
            $m = ""; $prop = [Text.Json.JsonElement]::new()
            if ($doc.RootElement.TryGetProperty("msg", [ref]$prop)) {
                if ($prop.ValueKind -eq [Text.Json.JsonValueKind]::String) { $m = $prop.GetString() }
                elseif ($prop.ValueKind -ne [Text.Json.JsonValueKind]::Null) { $m = $prop.GetRawText() }
            }
            $null = $msgs.Add($m)
        } finally {
            $doc.Dispose()
        }
    }
    $res = @("records=$n invalid=$bad")
    foreach ($w in @($WantMsgs)) { $res += if ($msgs.Contains($w)) { "msg-ok" } else { "msg-missing: $w" } }
    return ($res -join "`n")
}

$WARN_MSG = 'quote " back \ tab' + "`t" + 'end'
$RECORD_MSG = 'q " b \ t' + "`t" + 'n' + "`n" + 'l e[0m x Jos' + $E_ACUTE + ' ' + $CHECK

# Invoke-RelayCase NAME MODE CHILD_FAIL WANT-RESULT WANT-RECORDS [WANT-SUMMARY] [EXTRA]
# WANT-RECORDS "-": no deploy.jsonl expected (no child ran); "skip": the child
# printed nothing (no console or deploy.jsonl check). WANT-SUMMARY: the summary
# rows (default none). EXTRA: "VAR=value" strings.
function Invoke-RelayCase([string]$Name, [string]$Mode, [string]$Fail, [string]$Want, [string]$WRec, [string]$WSum = "", [string[]]$Extra = @()) {
    if (Test-Path -LiteralPath $H) { Remove-Item -LiteralPath $H -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $H ".aitools/logs") -Force | Out-Null
    $sumFile = Join-Path $H "summary.txt"
    [IO.File]::WriteAllText($sumFile, "")
    $jl = Join-Path $H ".aitools/logs/deploy.jsonl"
    $outFile = Join-Path $WORK "relay.out"
    $envs = New-CaseEnv
    $envs["HOME"] = "$WM/home"; $envs["USERPROFILE"] = "$WM/home"
    $envs["AITOOLS_LOG_DIR"] = "$WM/home/.aitools/logs"; $envs["AITOOLS_SUMMARY_FILE"] = "$WM/home/summary.txt"
    $envs["REPO"] = $RepoM; $envs["REPO_WORK"] = $WM
    $envs["RMODE"] = $Mode; $envs["CHILD_FAIL"] = $Fail; $envs["AITOOLS_RUN_ID"] = "run-fixed"
    Add-Extra $envs $Extra $WM
    $rc = Invoke-TestScript -FilePath $pwshExe -Environment $envs -OutFile $outFile -ArgumentList @(
        "-NoProfile", "-NonInteractive", "-File", "$WM/relay.ps1")
    # colour codes of the relayed console lines; CRs
    $out = if ($rc -eq 0) { ((ReadText $outFile) -replace "`e\[[0-9;]*m", "") -replace "`r", "" } else { "driver failed: $rc" }
    Write-LfFile $sumFile (ConvertFrom-NativeWork (ReadText $sumFile))
    $got = Select-Lines $out '^(rc|cw)='   # only the driver's result lines
    if ($got -ceq $Want) { Ok "$Name (ps): result" }
    else {
        Bad "$Name (ps): got"
        foreach ($l in ($got -split "`n")) { Write-Output "         $l" }
        Write-Output "       want"
        foreach ($l in ($Want -split "`n")) { Write-Output "         $l" }
    }
    $sum = (ReadText $sumFile).TrimEnd("`n")
    if ($sum -ceq $WSum) { Ok "$Name (ps): summary rows" }
    else { Bad "$Name (ps): summary '$sum', want '$WSum'" }
    if ($WRec -eq "-") {
        if (Test-Path -LiteralPath $jl) { Bad "$Name (ps): deploy.jsonl written without a child" } else { Ok "$Name (ps): no deploy.jsonl" }
        return
    }
    if ($WRec -eq "skip") { return }
    if ($Mode -ne "record") {
        if ($out.Contains("second warning")) { Ok "$Name (ps): child lines on the console" }
        else { Bad "$Name (ps): child lines not on the console" }
    }
    $gotRec = Get-JsonlCheck $jl @($WARN_MSG)
    if ($Mode -eq "record") {
        $gotRec = Get-JsonlCheck $jl @($RECORD_MSG)
        Copy-Item -LiteralPath $jl -Destination (Join-Path $WORK "record.jsonl") -Force
    }
    if ($gotRec -ceq $WRec) { Ok "$Name (ps): deploy.jsonl" }
    else { Bad "$Name (ps): deploy.jsonl '$gotRec', want '$WRec'" }
}

try {
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

    Write-Output "aitools-lib profile wrapper tests (windows: ps1)"

    New-Fixture with-id
    Invoke-Case urp-found urp (J "rc=0" "path=$DP via=convention" "warnings=0 errors=0") ""

    New-Fixture none
    Invoke-Case urp-none urp (J "rc=1" "path= via=none" "warnings=0 errors=0") ""

    New-Fixture with-id
    Invoke-Case rmp-id rmp (J "rc=0" "alias=nobul-mac via=id company=nobul-tech name=Jose" "warnings=0 errors=0") ""

    # hostname-only: resolver warnings are detail lines (no WARN promotion)
    New-Fixture hostname-only
    Invoke-Case rmp-hostname rmp (J "rc=0" "alias=nobul-mac via=hostname company=nobul-tech name=Jose" "warnings=0 errors=0") ""

    New-Fixture none
    Invoke-Case rmp-none rmp (J "rc=1" "alias= via=none company= name=" "warnings=0 errors=0") ""

    New-Fixture with-id
    Set-NoMatch
    Invoke-Case rmp-nomatch rmp (J "rc=3" "alias= via=none company=nobul-tech name=Jose" "warnings=0 errors=2") `
        (J "ERROR|machine profile|no machine match" "ACTION||Run: aitools user init (pick or register this machine's profile)")

    # m3: the same failure twice in one run -> two ERROR rows, one ACTION
    Invoke-Case rmp-nomatch-twice rmp2 (J "rc=3" "alias= via=none company=nobul-tech name=Jose" "warnings=0 errors=4") `
        (J "ERROR|machine profile|no machine match" "ACTION||Run: aitools user init (pick or register this machine's profile)" "ERROR|machine profile|no machine match")

    New-Fixture with-id
    Invoke-Case eget-none eget (J "rc=0" "found=false method= path=" "warnings=0 errors=0") ""

    New-Fixture none
    Invoke-Case eget-unavailable eget (J "rc=1" "found=false method= path=" "warnings=1 errors=0") ""

    # No remote: the push fails -> warning + ACTION
    New-Fixture with-id
    Invoke-Case eset-written eset (J "rc=0" "result=created pushed=false" "warnings=1 errors=0") "ACTION||run git push in $DP"

    # m1: an identical second record and a dry run write nothing: no warning, no ACTION
    New-Fixture with-id
    Invoke-Case eset-unchanged eset2 (J "rc=0" "result=unchanged pushed=false" "warnings=0 errors=0") ""

    New-Fixture with-id
    Invoke-Case eset-dry-run eset (J "rc=0" "result=dry-run pushed=false" "warnings=0 errors=0") "" @("AITOOLS_DRY_RUN=1")

    New-Fixture hostname-only
    Invoke-Case eset-refused eset (J "rc=3" "result=refused pushed=false" "warnings=1 errors=0") "ACTION||run aitools user init to remember tool choices"

    # B1/M1: the caller's own parameters and variables survive dot-sourcing the lib
    # and calling the wrappers (-UserRepoPath, -MachineAlias, -ProfileFile, $profileName)
    New-Fixture with-id
    Invoke-Case caller-vars-survive keep (J "rc=0" "kept=urp:/caller/urp pf:/caller/pf alias:caller name:caller-name" "alias=nobul-mac urp-via=convention" "warnings=0 errors=0") ""

    # AITOOLS_PROFILE_PS1 override: a missing resolver, then a stub
    New-Fixture with-id
    Invoke-Case override-missing urp (J "rc=3" "path= via=none" "warnings=0 errors=1") (J "ERROR|dotprofile|resolver missing" $A_DP) @("AITOOLS_PROFILE_PS1=<W>/none.ps1")

    Invoke-Case override-stub urp (J "rc=0" "path=/stub/aitools-dp via=env" "warnings=0 errors=0") "" @("AITOOLS_PROFILE_PS1=<W>/stub.ps1")

    New-Fixture with-exc
    Invoke-Case eget-found eget (J "rc=0" "found=true method=pkg-installer path=/usr/local/bin/go" "warnings=0 errors=0") ""

    # Review 2 M1: a resolver exit 0 or 1 without result lines is an error, not
    # "found" or "shared-only"; a throw or parse error is an error too
    New-Fixture with-id
    Invoke-Case broken-silent0-urp urp (J "rc=3" "path= via=" "warnings=0 errors=1") (J "ERROR|dotprofile|resolver failed" $A_DP) @("AITOOLS_PROFILE_PS1=<W>/silent0.ps1")

    Invoke-Case broken-silent1-urp urp (J "rc=3" "path= via=" "warnings=0 errors=1") (J "ERROR|dotprofile|resolver failed" $A_DP) @("AITOOLS_PROFILE_PS1=<W>/silent1.ps1")

    Invoke-Case broken-silent1-rmp rmp (J "rc=3" "alias= via= company= name=" "warnings=0 errors=2") `
        (J "ERROR|machine profile|no machine match" "ACTION||Run: aitools user init (pick or register this machine's profile)") @("AITOOLS_PROFILE_PS1=<W>/silent1.ps1")

    Invoke-Case broken-silent0-eget eget (J "rc=1" "found=false method= path=" "warnings=1 errors=0") "" @("AITOOLS_PROFILE_PS1=<W>/silent0.ps1")

    Invoke-Case broken-silent0-eset eset (J "rc=1" "result=failed pushed=false" "warnings=1 errors=0") "ACTION||see deploy.log -- a tool choice (tool exception) was not saved" @("AITOOLS_PROFILE_PS1=<W>/silent0.ps1")

    Invoke-Case broken-throw-urp urp (J "rc=3" "path= via=" "warnings=0 errors=1") (J "ERROR|dotprofile|resolver failed" $A_DP) @("AITOOLS_PROFILE_PS1=<W>/throw.ps1")

    Invoke-Case broken-parse-urp urp (J "rc=3" "path= via=" "warnings=0 errors=1") (J "ERROR|dotprofile|resolver failed" $A_DP) @("AITOOLS_PROFILE_PS1=<W>/parse.ps1")

    # Re-key batch 3, item 1: the id-key results
    New-Fixture id-key
    Invoke-Case rmpk-id-key rmpk (J "rc=0" "alias=nobul-mac via=id company=nobul-mac-co" "key=$ID_KEY owner=this legacy=false host=nobul-mac" "warnings=0 errors=0") ""

    New-Fixture with-id
    Invoke-Case rmpk-legacy rmpk (J "rc=0" "alias=nobul-mac via=id company=nobul-tech" "key=nobul-mac owner=this legacy=true host=nobul-mac" "warnings=0 errors=0") ""

    New-Fixture hostname-only
    Invoke-Case rmpk-unregistered rmpk (J "rc=0" "alias=nobul-mac via=hostname company=nobul-tech" "key=nobul-mac owner=unregistered legacy=true host=nobul-mac" "warnings=0 errors=0") ""

    # Another machine's id-keyed profile with this hostname: matched, owner other
    New-Fixture other-id
    Invoke-Case rmpk-other rmpk (J "rc=0" "alias=old-mac via=hostname company=nobul-tech" "key=aaaaaaaa-1111-2222-3333-444444444444 owner=other legacy=false host=nobul-mac" "warnings=0 errors=0") ""

    New-Fixture none
    Invoke-Case rmpk-none rmpk (J "rc=1" "alias= via=none company=" "key= owner=absent legacy=false host=nobul-mac" "warnings=0 errors=0") ""

    New-Fixture with-id
    Set-NoMatch
    Invoke-Case rmpk-nomatch rmpk (J "rc=3" "alias= via=none company=nobul-tech" "key= owner=absent legacy=false host=nobul-mac" "warnings=0 errors=2") `
        (J "ERROR|machine profile|no machine match" "ACTION||Run: aitools user init (pick or register this machine's profile)")

    # A resolver that predates the id-key fields (an older embedded copy): defaults
    New-Fixture with-id
    Invoke-Case rmpk-old-resolver rmpk (J "rc=0" "alias=nobul-mac via=id company=nobul-tech" "key= owner=absent legacy=false host=nobul-mac" "warnings=0 errors=0") "" @("AITOOLS_PROFILE_PS1=<W>/oldres.ps1")

    # Item 3: a dotprofile resolver error twice in one run -> two ERROR rows, one ACTION
    Invoke-Case urp-missing-twice urp2 (J "rc=3" "path= via=none" "warnings=0 errors=2") (J "ERROR|dotprofile|resolver missing" $A_DP "ERROR|dotprofile|resolver missing") @("AITOOLS_PROFILE_PS1=<W>/none.ps1")

    # FIX-1, A-2: the machine-profile wrapper's "resolver missing" path writes the
    # ACTION too; with the dotprofile wrapper in the same run, one ACTION in total
    Invoke-Case rmp-missing rmp (J "rc=3" "alias= via=none company= name=" "warnings=0 errors=1") (J "ERROR|machine profile|resolver missing" $A_DP) @("AITOOLS_PROFILE_PS1=<W>/none.ps1")
    Invoke-Case urp-rmp-missing keep (J "rc=3" "kept=urp:/caller/urp pf:/caller/pf alias:caller name:caller-name" "alias= urp-via=none" "warnings=0 errors=2") `
        (J "ERROR|dotprofile|resolver missing" $A_DP "ERROR|machine profile|resolver missing") @("AITOOLS_PROFILE_PS1=<W>/none.ps1")

    # Item 2: resolver exits 3 and 4 are mapped and logged with their meaning in
    # every wrapper; neither is read as "nothing found"
    foreach ($n in 3, 4) {
        $x = @("AITOOLS_PROFILE_PS1=<W>/exit$n.ps1", "SHOW_NOTES=1")
        New-Fixture with-id
        Invoke-Case "exit$n-urp" urp (J "rc=3" "path= via=none" "warnings=0 errors=1" "notes=1") (J "ERROR|dotprofile|resolver failed" $A_DP) $x
        Invoke-Case "exit$n-rmp" rmp (J "rc=3" "alias= via=none company= name=" "warnings=0 errors=2" "notes=1") `
            (J "ERROR|machine profile|no machine match" "ACTION||Run: aitools user init (pick or register this machine's profile)") $x
        Invoke-Case "exit$n-eget" eget (J "rc=1" "found=false method= path=" "warnings=1 errors=0" "notes=1") "" $x
    }
    New-Fixture with-id
    Invoke-Case exit3-eset eset (J "rc=3" "result=refused pushed=false" "warnings=1 errors=0" "notes=1") "ACTION||run aitools user init to remember tool choices" @("AITOOLS_PROFILE_PS1=<W>/exit3.ps1", "SHOW_NOTES=1")
    Invoke-Case exit4-eset eset (J "rc=1" "result=failed pushed=false" "warnings=1 errors=0" "notes=1") "ACTION||see deploy.log -- a tool choice (tool exception) was not saved" @("AITOOLS_PROFILE_PS1=<W>/exit4.ps1", "SHOW_NOTES=1")

    # M3-FINISH item 3: the runner itself (Invoke-AitLibProfile), as user init calls
    # it. register and migrate print a "result" line and no "via" line; hostname
    # prints a bare value. Each exit code 0-4 and a missing resolver.
    New-Fixture with-id
    function Stub([string]$Base) { "AITOOLS_PROFILE_PS1=<W>/$Base.ps1" }
    Invoke-Case run-register-result run (J "rc=0 profrc=0" "out=created" "err=" "warnings=0 errors=0") "" @("RUN_ARGS=register", (Stub res0))
    Invoke-Case run-migrate-result run (J "rc=0 profrc=0" "out=created" "err=" "warnings=0 errors=0") "" @("RUN_ARGS=migrate", (Stub res0))
    Invoke-Case run-register-exit1-result run (J "rc=0 profrc=1" "out=failed" "err=profile.json not found" "warnings=0 errors=0") "" @("RUN_ARGS=register", (Stub res1))
    Invoke-Case run-exit2 run (J "rc=0 profrc=2" "out=" "err=bad input" "warnings=0 errors=0") "" @("RUN_ARGS=register", (Stub exit2))
    foreach ($n in 3, 4) {
        Invoke-Case "run-exit$n" run (J "rc=0 profrc=$n" "out=none" "err=stub says no" "warnings=0 errors=0") "" @("RUN_ARGS=register", (Stub "exit$n"))
    }
    foreach ($n in 0, 1) {
        Invoke-Case "run-silent$n-register" run (J "rc=0 profrc=2" "out=" "err=resolver exited $n without result lines (see deploy.log)" "warnings=0 errors=0") "" @("RUN_ARGS=register", (Stub "silent$n"))
    }
    Invoke-Case run-hostname-stub run (J "rc=0 profrc=0" "out=probe-host" "err=" "warnings=0 errors=0") "" @("RUN_ARGS=hostname", (Stub host))
    Invoke-Case run-hostname-empty run (J "rc=0 profrc=2" "out=" "err=resolver exited 0 without result lines (see deploy.log)" "warnings=0 errors=0") "" @("RUN_ARGS=hostname", (Stub silent0))
    # A bare value is accepted only for hostname and machine-id
    Invoke-Case run-bare-value-resolve run (J "rc=0 profrc=2" "out=probe-host" "err=resolver exited 0 without result lines (see deploy.log)" "warnings=0 errors=0") "" @("RUN_ARGS=resolve", (Stub host))
    Invoke-Case run-missing run (J "rc=1 profrc=2" "out=" "err=resolver none.ps1 not found ($WM)" "warnings=0 errors=0") "" @("RUN_ARGS=register", (Stub none))
    Invoke-Case run-throw run (J "rc=0 profrc=2" "out=" "err=aitools-profile register threw: boom" "warnings=0 errors=0") "" @("RUN_ARGS=register", "AITOOLS_PROFILE_PS1=<W>/throw.ps1")
    # The real resolver (this fixture: this machine's id-keyed profile)
    New-Fixture id-key
    Invoke-Case run-real-register run (J "rc=0 profrc=0" "out=updated" "err=" "warnings=0 errors=0") "" @("RUN_ARGS=register,--profile,<W>/home/repos/aitools-nobul-jose/profile.json,--out,<W>/reg.tmp,--shell,zsh,--environment,local")
    if (Test-Path -LiteralPath "$WORK/reg.tmp") { Remove-Item -LiteralPath "$WORK/reg.tmp" -Force }
    Invoke-Case run-real-migrate run (J "rc=0 profrc=0" "out=unchanged" "err=" "warnings=0 errors=0") "" @("RUN_ARGS=migrate,--profile,<W>/home/repos/aitools-nobul-jose/profile.json")
    Invoke-Case run-real-hostname run (J "rc=0 profrc=0" "out=nobul-mac" "err=" "warnings=0 errors=0") "" @("RUN_ARGS=hostname")

    # m2: the bash -> pwsh branch of aitools-lib.sh, the one Git Bash takes on
    # Windows (build-deploy.sh, the scripts/aitools bash entry point): aitools-lib.sh
    # under Git Bash, AITOOLS_PLATFORM windows (AITLIB_PROFILE_VIA_PWSH=1 is a no-op
    # there). A non-ASCII identity value must arrive intact (UTF-8 output).
    $pwshEnv = "AITLIB_PROFILE_VIA_PWSH=1"
    New-Fixture with-id
    Invoke-Case via-pwsh-urp urp (J "rc=0" "path=$DP via=convention" "warnings=0 errors=0") "" @($pwshEnv) gitbash

    $script:FixName = "Jos$E_ACUTE"
    New-Fixture with-id
    Invoke-Case via-pwsh-rmp-utf8 rmp (J "rc=0" "alias=nobul-mac via=id company=nobul-tech name=Jos$E_ACUTE" "warnings=0 errors=0") "" @($pwshEnv) gitbash
    $script:FixName = "Jose"

    New-Fixture id-key
    Invoke-Case via-pwsh-rmpk-id-key rmpk (J "rc=0" "alias=nobul-mac via=id company=nobul-mac-co" "key=$ID_KEY owner=this legacy=false host=nobul-mac" "warnings=0 errors=0") "" @($pwshEnv) gitbash

    New-Fixture with-id
    Invoke-Case via-pwsh-exit4-urp urp (J "rc=3" "path= via=none" "warnings=0 errors=1" "notes=1") (J "ERROR|dotprofile|resolver failed" $A_DP) @($pwshEnv, "AITOOLS_PROFILE_PS1=<W>/exit4.ps1", "SHOW_NOTES=1") gitbash

    New-Fixture hostname-only
    Invoke-Case via-pwsh-eset-refused eset (J "rc=3" "result=refused pushed=false" "warnings=1 errors=0") "ACTION||run aitools user init to remember tool choices" @($pwshEnv) gitbash

    New-Fixture with-id
    Invoke-Case via-pwsh-stub urp (J "rc=0" "path=/stub/aitools-dp via=env" "warnings=0 errors=0") "" @($pwshEnv, "AITOOLS_PROFILE_PS1=<W>/stub.ps1") gitbash

    foreach ($broken in "silent0", "silent1", "throw", "parse") {
        Invoke-Case "via-pwsh-broken-$broken" urp (J "rc=3" "path= via=" "warnings=0 errors=1") (J "ERROR|dotprofile|resolver failed" $A_DP) @($pwshEnv, "AITOOLS_PROFILE_PS1=<W>/$broken.ps1") gitbash
    }

    # M3-FINISH item 3 through the pwsh branch: result lines, a bare hostname, a
    # throw (an "error" line, as in-process), a missing resolver, and the path
    # arguments that are converted (--path, --profile, --out, --config; --slug not)
    Invoke-Case via-pwsh-run-register-result run (J "rc=0 profrc=0" "out=created" "err=" "warnings=0 errors=0") "" @($pwshEnv, "RUN_ARGS=register", "AITOOLS_PROFILE_PS1=<W>/res0.ps1") gitbash
    Invoke-Case via-pwsh-run-exit1-result run (J "rc=0 profrc=1" "out=failed" "err=profile.json not found" "warnings=0 errors=0") "" @($pwshEnv, "RUN_ARGS=register", "AITOOLS_PROFILE_PS1=<W>/res1.ps1") gitbash
    Invoke-Case via-pwsh-run-hostname run (J "rc=0 profrc=0" "out=probe-host" "err=" "warnings=0 errors=0") "" @($pwshEnv, "RUN_ARGS=hostname", "AITOOLS_PROFILE_PS1=<W>/host.ps1") gitbash
    Invoke-Case via-pwsh-run-silent0 run (J "rc=0 profrc=2" "out=" "err=resolver exited 0 without result lines (see deploy.log)" "warnings=0 errors=0") "" @($pwshEnv, "RUN_ARGS=migrate", "AITOOLS_PROFILE_PS1=<W>/silent0.ps1") gitbash
    Invoke-Case via-pwsh-run-throw run (J "rc=0 profrc=2" "out=" "err=aitools-profile register threw: boom" "warnings=0 errors=0") "" @($pwshEnv, "RUN_ARGS=register", "AITOOLS_PROFILE_PS1=<W>/throw.ps1") gitbash
    Invoke-Case via-pwsh-run-missing run (J "rc=1 profrc=2" "out=" "err=resolver none.ps1 or pwsh not found ($WM)" "warnings=0 errors=0") "" @($pwshEnv, "RUN_ARGS=register", "AITOOLS_PROFILE_PS1=<W>/none.ps1") gitbash
    Invoke-Case via-pwsh-run-path-args run (J "rc=0 profrc=0" "out=ok" "err=" "args=register --profile W/conv/p.json --out W/conv/o.tmp --config W/conv/c.json --path W/conv/x --slug /conv/s" "warnings=0 errors=0") "" `
        @($pwshEnv, "FAKEBIN=<W>/fakebin", "RUN_ARGS=register,--profile,/conv/p.json,--out,/conv/o.tmp,--config,/conv/c.json,--path,/conv/x,--slug,/conv/s", "AITOOLS_PROFILE_PS1=<W>/args.ps1") gitbash
    New-Fixture id-key
    Invoke-Case via-pwsh-run-real-register run (J "rc=0 profrc=0" "out=updated" "err=" "warnings=0 errors=0") "" @($pwshEnv, "RUN_ARGS=register,--profile,<W>/home/repos/aitools-nobul-jose/profile.json,--out,<W>/reg.tmp,--shell,zsh,--environment,local") gitbash
    if (Test-Path -LiteralPath "$WORK/reg.tmp") { Remove-Item -LiteralPath "$WORK/reg.tmp" -Force }

    # -----------------------------------------------------------------------
    # Re-key batch 3, item 4: child-log relay helpers (deploy.jsonl)
    # -----------------------------------------------------------------------
    Write-Output "relay helpers"
    Invoke-RelayCase relay-record record 0 "cw= ce= warnings=0 errors=0" (J "records=1 invalid=0" "msg-ok")
    # Parity: the PowerShell record (Windows) and the bash record (macOS/Linux) equal
    # one golden file. host and os name the machine the record was written on:
    # placeholders here (the first occurrence on each line, as perl -pe s/// did).
    $rec = Join-Path $WORK "record.jsonl"
    if (Test-Path -LiteralPath $rec -PathType Leaf) {
        $reHost = [regex]::new('"host":"(?:[^"\\]|\\.)*"'); $reOs = [regex]::new('"os":"(?:[^"\\]|\\.)*"')
        $recLines = ([IO.File]::ReadAllText($rec, [Text.UTF8Encoding]::new($false))) -split "`n"
        $recLines = @($recLines | ForEach-Object { $reOs.Replace($reHost.Replace($_, '"host":"<HOST>"', 1), '"os":"<OS>"', 1) })
        $norm = Join-Path $WORK "record.norm.jsonl"
        [IO.File]::WriteAllText($norm, ($recLines -join "`n"), [Text.UTF8Encoding]::new($false))
        if (Test-GoldenMatch "lib-relay-record.jsonl" $norm) { Ok "relay-record: record matches golden (bash and PowerShell share it)" }
        else { Bad "relay-record: record differs from golden lib-relay-record.jsonl" }
    } else {
        Bad "relay-record: no deploy.jsonl record to compare"
    }
    Invoke-RelayCase relay-run-ok run 0 (J "rc=0 child_rc=0" "cw=2 ce=0 warnings=2 errors=0") (J "records=4 invalid=0" "msg-ok")
    # A failed child that wrote its own ERROR row gets no second one (FIX-1, A-3)
    Invoke-RelayCase relay-run-fail run 1 (J "rc=1 child_rc=1" "cw=2 ce=1 warnings=2 errors=1") (J "records=5 invalid=0" "msg-ok") "ERROR|child tool|child failed"
    # A child that logged an error but exited 0 and wrote no row: one ERROR row
    Invoke-RelayCase relay-run-error-exit0 run 2 (J "rc=1 child_rc=0" "cw=2 ce=1 warnings=2 errors=1") (J "records=5 invalid=0" "msg-ok") "ERROR|child tool|logged errors (exit 0)"
    # A-3: a child that died before its own rows (exit 1, exit 127) is in the panel
    # as ERROR; a user abort (exit 2) too
    Invoke-RelayCase relay-run-crash run 3 (J "rc=1 child_rc=1" "cw=2 ce=0 warnings=2 errors=1") (J "records=3 invalid=0" "msg-ok") "ERROR|child tool|script failed (exit 1)"
    Invoke-RelayCase relay-run-exit127 run 4 (J "rc=1 child_rc=127" "cw=2 ce=0 warnings=2 errors=1") (J "records=3 invalid=0" "msg-ok") "ERROR|child tool|script failed (exit 127)"
    Invoke-RelayCase relay-run-abort run 5 (J "rc=1 child_rc=2" "cw=2 ce=1 warnings=2 errors=1") (J "records=4 invalid=0" "msg-ok") "ERROR|child tool|aborted (exit 2)"
    # Review A m1: the dedupe compares with the rows before the child, not with zero:
    # an earlier step's ERROR row does not hide the crashed child's row
    Invoke-RelayCase relay-run-crash-prior-row run 3 (J "rc=1 child_rc=1" "cw=2 ce=0 warnings=2 errors=1") (J "records=3 invalid=0" "msg-ok") `
        (J "ERROR|earlier step|failed before" "ERROR|child tool|script failed (exit 1)") @("PRE_ROW=1")
    # Without a summary tool: no row (the caller writes its own)
    Invoke-RelayCase relay-run-crash-notool run-notool 3 (J "rc=1 child_rc=1" "cw=2 ce=0 warnings=2 errors=1") (J "records=3 invalid=0" "msg-ok") ""
    # A throw and a parse error (in-process) are one LogError and a row
    Invoke-RelayCase relay-run-throw run 6 (J "rc=1 child_rc=1" "cw=2 ce=0 warnings=2 errors=1") (J "records=3 invalid=0" "msg-ok") "ERROR|child tool|script failed (exception)"
    Invoke-RelayCase relay-run-parse parse 0 (J "rc=1 child_rc=1" "cw=0 ce=0 warnings=0 errors=1") "skip" "ERROR|child tool|script failed (exception)"
    # Review m3: no command is a failure, not a silent success; with a tool, a row
    Invoke-RelayCase relay-run-no-command noargs 0 (J "rc=1 child_rc=1" "cw=0 ce=0 warnings=0 errors=1") "-" "ERROR|child tool|not run (no command)"
    # The relay's own temp file is bash code (aitools-lib.sh); its cases
    # (relay-run-mktemp-fail, relay-run-rm-fail) run in test-lib.sh on macOS/Linux
    SkipLine "relay-run-rm-fail (bash relay temp file: macOS/Linux)"
    Invoke-RelayCase relay-captured captured 0 (J "rc=0 child_rc=0" "cw=2 ce=0 warnings=2 errors=0") (J "records=4 invalid=0" "msg-ok")
} catch {
    Bad "harness error: $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
} finally {
    [Console]::OutputEncoding = $savedOutputEncoding
    Remove-TestTempRoot $WORK
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: ps1)" -f $script:pass, $script:fail, $script:skip)
if ($script:fail -ne 0) { exit 1 }
exit 0
