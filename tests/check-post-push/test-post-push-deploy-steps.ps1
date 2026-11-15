# test-post-push-deploy-steps.ps1 -- check-post-push steps 2, 6 and 14 never
# read the frozen aitools deploy/ (incident #176). Before, step 2 ran bash -n on
# deploy/*.sh and steps 6 and 14 added deploy/*.sh (and step 6 deploy/*.ps1) to
# their syntax and line-ending audits; build-deploy.sh has written the dotprofile
# deploy/ since 2c0fd32, so those reads proved nothing about the generated
# scripts. Step 2 is retired to a SKIP that points to check-pre-push step 7;
# steps 6 and 14 audit the source scripts (scripts/, shared/hooks/) only.
#
# Platform targeting (commander, 2026-11-14: "sh scripts and tests should only
# run on linux/mac and ps1 on windows"; "tests should be .ps1 here on windows
# and executed as powershell scripts, git bash scripts cause known issues"):
# this harness runs on Windows only and tests the .ps1 twin,
# scripts/check-post-push.ps1, with native pwsh. It runs no .sh check section or
# script, and the .ps1 twin runs no Git Bash (PR #167): its step 6 (.sh) is a
# SKIP that leaves `bash -n` to CI and check-post-push.sh, even when a Git Bash
# is passed in as $bashExe. The .sh twin is tested on macOS and Linux by
# tests/check-post-push/test-post-push-deploy-steps.sh, which expects the same
# records for steps 2, 6 (.ps1) and 14 on the same fixtures and runs the same
# static cases.
#
# Cases:
#   static   perl over the text of both twins (perl is cross-platform; the .sh
#            harness runs the same programs): no non-comment line reads the
#            aitools deploy/. perl: the one on PATH, else Git for Windows'
#            usr\bin\perl.exe; without perl these cases FAIL.
#   frozen   steps 2, 6 and 14 of check-post-push.ps1 (cut between their "# N."
#            headings and the next step's heading) dot-sourced in a child pwsh
#            with stub step functions, a temporary HOME and a fake repo whose
#            source scripts are clean and whose deploy/ holds a .sh with a
#            syntax error, a .ps1 with a parse error and a CRLF .sh;
#            scripts/build-deploy.sh only writes a marker. Exactly: SKIP 2 with
#            the retired text, SKIP 6 (.sh), PASS 6 (.ps1), PASS 14; no marker
#   sources  the same steps on a fake repo with a syntax error in scripts/*.sh,
#            a parse error in scripts/*.ps1 and a CRLF shared/hooks/*.sh: SKIP 6
#            (.sh), FAIL 6 (.ps1) and FAIL 14, one file each (the steps still
#            audit the sources)
#   home     the temporary HOME is unchanged (every file, by checksum)
# SKIP 6 (.sh) carries the .ps1 twin's text "bash -n runs in CI (linux, macos)
# and check-post-push.sh, not on Windows" on both fake repos.
#
# Override the script under test with POST_PUSH_PS1 (the .ps1 twin) and
# POST_PUSH_SH (read by the static case only), absolute paths, e.g. to show
# that the pre-fix scripts fail. TEST_KEEP_TMP=1 keeps the temp dir. Safe to
# re-run: writes only to a temp dir, removed on exit; the real HOME and the real
# dotprofile are never read or written. Exit 1 if any case fails.
# Platform: Windows, pwsh 7 (CI: windows job); refuses macOS and Linux.
# Usage: pwsh -NoProfile -File tests/check-post-push/test-post-push-deploy-steps.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 47 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/check-post-push/test-post-push-deploy-steps.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$ps1Script = if ($env:POST_PUSH_PS1) { $env:POST_PUSH_PS1 } else { Join-Path $root "scripts/check-post-push.ps1" }
$shScript = if ($env:POST_PUSH_SH) { $env:POST_PUSH_SH } else { Join-Path $root "scripts/check-post-push.sh" }
$tmpRoot = New-TestTempRoot "post-push-deploy"
$keepTmp = ($env:TEST_KEEP_TMP -eq "1")
if ($keepTmp) { Write-Output "temp dir kept: $tmpRoot" }
$outFile = Join-Path $tmpRoot "out"

$script:pass = 0; $script:fail = 0; $script:skip = 0
$RETIRED = 'retired: check-pre-push step 7 rebuilds into a temp dotprofile copy'
$utf8 = [Text.UTF8Encoding]::new($false)

function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
function WriteText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $utf8) }

# Get-Lines PATH: the file's lines, CR removed; callers wrap it in @()
function Get-Lines([string]$Path) {
    $t = (ReadText $Path) -replace "`r", ""
    if ($t -eq "") { return }
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    $t -split "`n"
}

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if (Test-Path -LiteralPath $outFile -PathType Leaf) {
        $lines = @(((ReadText $outFile) -replace "`e\[[0-9;]*m", "" -replace "`r", "") -split "`n")
        $lines | Select-Object -Last 15 | ForEach-Object { Write-Output "      | $_" }
    }
}

# Get-Section SRC DST START STOP: the lines from a START match to a STOP match
# (perl: $p = 1 if /START/; $p = 0 if /STOP/; print if $p), CR removed
function Get-Section([string]$Src, [string]$Dst, [string]$Start, [string]$Stop) {
    $p = $false
    $sb = [Text.StringBuilder]::new()
    foreach ($line in ((ReadText $Src) -split "`n")) {
        $l = $line -replace "`r$", ""
        if ($l -cmatch $Start) { $p = $true }
        if ($l -cmatch $Stop) { $p = $false }
        if ($p) { [void]$sb.Append($l).Append("`n") }
    }
    WriteText $Dst $sb.ToString()
}

# Save-Snapshot DIR OUT: every file under DIR with its SHA-256, ordinal order,
# except AppData/Local/Microsoft/PowerShell/ (pwsh writes its startup profile
# cache under USERPROFILE at every start)
function Save-Snapshot([string]$Dir, [string]$Out) {
    $base = (Resolve-Path -LiteralPath $Dir).ProviderPath.TrimEnd('\') + '\'
    $rows = [Collections.Generic.List[string]]::new()
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force)) {
        $rel = $f.FullName.Substring($base.Length) -replace '\\', '/'
        if ($rel -like 'AppData/Local/Microsoft/PowerShell/*') { continue }
        $rows.Add("$((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash) ./$rel")
    }
    $arr = $rows.ToArray()
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    WriteText $Out (($arr -join "`n") + "`n")
}

# Write-Expect FILE LINES: the expected records, one per line
function Write-Expect([string]$File, [string[]]$Lines) { WriteText $File ((@($Lines | ForEach-Object { "$_`n" })) -join "") }

# perl for the static cases: the one on PATH, else Git for Windows' own
$gitBash = Resolve-TestGitBash
$perl = (Get-Command perl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $perl -and $gitBash) {
    $gitPerl = Join-Path (Split-Path -Parent (Split-Path -Parent $gitBash)) "usr\bin\perl.exe"
    if (Test-Path -LiteralPath $gitPerl -PathType Leaf) { $perl = $gitPerl }
}
# Invoke-PerlCheck CODE FILE: perl -n CODE over FILE, output to the out file;
# $true when perl ran (exit 0). Without perl the out file says so.
$script:perlN = 0
function Invoke-PerlCheck([string]$Code, [string]$File) {
    if (-not $perl) { WriteText $outFile "perl not found (PATH, Git for Windows usr\bin)`n"; return $false }
    $script:perlN++
    $pl = Join-Path $tmpRoot "static-$($script:perlN).pl"
    WriteText $pl ($Code + "`n")
    $rc = Invoke-TestScript -FilePath $perl -ArgumentList @("-n", $pl, $File) -Environment @{ PERLIO = ":perlio" } -OutFile $outFile
    return ($rc -eq 0)
}
function Test-OutEmpty { -not (ReadText $outFile).Trim() }

# --- Fixtures ------------------------------------------------------------------
# A fake repo: scripts/ and shared/hooks/ hold clean scripts; scripts/build-deploy.sh
# only writes a marker (no step may run it)
function New-FakeRepo([string]$Dir) {
    foreach ($d in @("scripts", "shared/hooks", "deploy")) { New-Item -ItemType Directory -Path (Join-Path $Dir $d) -Force | Out-Null }
    WriteText (Join-Path $Dir "scripts/ok.sh") "#!/usr/bin/env bash`nset -euo pipefail`necho ok`n"
    WriteText (Join-Path $Dir "scripts/ok.ps1") "Write-Output `"ok`"`n"
    WriteText (Join-Path $Dir "shared/hooks/ok-hook.sh") "#!/usr/bin/env bash`nset -euo pipefail`necho hook`n"
    WriteText (Join-Path $Dir "scripts/build-deploy.sh") "#!/usr/bin/env bash`nprintf ran > `"`$DEPLOY_STEPS_MARKER`"`n"
}

# frozen: every problem sits in deploy/ (the frozen tree no step may read)
$frozen = Join-Path $tmpRoot "frozen"
New-FakeRepo $frozen
WriteText (Join-Path $frozen "deploy/broken.sh") "#!/usr/bin/env bash`nif then fi (`n"
WriteText (Join-Path $frozen "deploy/broken.ps1") "function {`n"
WriteText (Join-Path $frozen "deploy/crlf.sh") "#!/usr/bin/env bash`r`necho crlf`r`n"

# sources: one problem of each kind in the source scripts, a clean deploy/
$sources = Join-Path $tmpRoot "sources"
New-FakeRepo $sources
WriteText (Join-Path $sources "scripts/bad.sh") "#!/usr/bin/env bash`nif then fi (`n"
WriteText (Join-Path $sources "scripts/bad.ps1") "function {`n"
WriteText (Join-Path $sources "shared/hooks/crlf-hook.sh") "#!/usr/bin/env bash`r`necho crlf`r`n"
WriteText (Join-Path $sources "deploy/ok.sh") "#!/usr/bin/env bash`necho deploy`n"

$homeDir = Join-Path $tmpRoot "home"
New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
WriteText (Join-Path $homeDir "sentinel") "keep`n"

# Expected results (the .sh harness expects the same records for steps 2,
# 6 (.ps1) and 14). Step 6 (.sh) of the .ps1 twin runs no Git Bash since PR
# #167 (commander, 2026-11-14: "id like to avoid calling git bash on thowse ps1
# scripts"): it is a SKIP on both fake repos, even with Git Bash installed and
# passed in as $bashExe.
$shFrozen = "SKIP 6 Full syntax (.sh)|bash -n runs in CI (linux, macos) and check-post-push.sh, not on Windows"
$shSources = $shFrozen
Write-Expect (Join-Path $tmpRoot "exp-frozen-ps1") @(
    "SKIP 2 Smoke-test deploy scripts|$RETIRED",
    $shFrozen,
    "PASS 6 Full syntax (.ps1)|",
    "PASS 14 Line ending audit|")
Write-Expect (Join-Path $tmpRoot "exp-sources-ps1") @(
    "SKIP 2 Smoke-test deploy scripts|$RETIRED",
    $shSources,
    "FAIL 6 Full syntax (.ps1)|1 file(s) failed",
    "FAIL 14 Line ending audit|1 file(s) with CRLF")

Save-Snapshot $homeDir (Join-Path $tmpRoot "home-before")

# The child pwsh that dot-sources the cut steps, with the step functions stubbed
$runPs1 = Join-Path $tmpRoot "run.ps1"
WriteText $runPs1 @'
$ErrorActionPreference = "Stop"
function Rec { param($s, $n, $name, $d) Add-Content -Path $env:DEPLOY_STEPS_REC -Value "$s $n $name|$d" }
function StepPass { param($n, $name, $d) Rec "PASS" $n $name $d }
function StepFail { param($n, $name, $d) Rec "FAIL" $n $name $d }
function StepWarn { param($n, $name, $d) Rec "WARN" $n $name $d }
function StepSkip { param($n, $name, $d) Rec "SKIP" $n $name $d }
function InvokeGit { $out = & git @args 2>$null; $out }
# A Git Bash offered to the step: since PR #167 step 6 must not use it
function ResolveGitBash { $env:DEPLOY_STEPS_BASH }
$bashExe = ResolveGitBash
$script:RepoRoot = $env:DEPLOY_STEPS_REPO
$scriptDir = Join-Path $script:RepoRoot "scripts"
Set-Location $script:RepoRoot
. $env:DEPLOY_STEPS_SECTION

'@

try {
    # --- static case: the .sh twin (CI order: before the .ps1 twin's cases) -------
    if (Test-Path -LiteralPath $shScript -PathType Leaf) {
        $ok = Invoke-PerlCheck 'next if /^\s*#/; print "$.: $_" if m{(?:REPO_ROOT|ROOT)"?/deploy\b|"deploy"}' $shScript
        Check "sh static: no line reads the aitools deploy/" ($ok -and (Test-OutEmpty))
    }

    # --- .ps1 twin -----------------------------------------------------------------
    if (-not (Test-Path -LiteralPath $ps1Script -PathType Leaf)) {
        Check "ps1: $ps1Script exists" $false
    } else {
        $steps = Join-Path $tmpRoot "steps.ps1"
        Get-Section $ps1Script $steps '^# (2|6|14)\. ' '^# (3|7|15)\. '
        Check "ps1: the step 2, 6 and 14 sections were found" (@(Get-Lines $steps | Where-Object { $_ -cmatch '^# (2|6|14)\. ' }).Count -eq 3)
        foreach ($fx in @("frozen", "sources")) {
            $repo = Join-Path $tmpRoot $fx
            $marker = Join-Path $tmpRoot "marker-ps1-$fx"
            $rec = Join-Path $tmpRoot "rec-ps1-$fx"
            $envs = @{
                HOME = $homeDir; USERPROFILE = $homeDir
                DEPLOY_STEPS_MARKER = $marker; DEPLOY_STEPS_REC = $rec; DEPLOY_STEPS_REPO = $repo
                DEPLOY_STEPS_SECTION = $steps; DEPLOY_STEPS_BASH = $(if ($gitBash) { $gitBash } else { "" })
            }
            $rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $runPs1) -Environment $envs -OutFile $outFile
            $got = Join-Path $tmpRoot "got-ps1-$fx"
            WriteText $got ((ReadText $rec) -replace "`r", "")
            Check "ps1 ${fx}: exit 0" ($rc -eq 0)
            Check "ps1 ${fx}: build-deploy.sh was not run" (-not (Test-Path -LiteralPath $marker))
            Copy-Item -LiteralPath $got -Destination $outFile -Force
            Check "ps1 ${fx}: results are exactly the expected ones" ((ReadText (Join-Path $tmpRoot "exp-$fx-ps1")) -ceq (ReadText $got))
        }
    }

    # --- static case: the .ps1 twin --------------------------------------------------
    if (Test-Path -LiteralPath $ps1Script -PathType Leaf) {
        $ok = Invoke-PerlCheck 's/\r$//; next if /^\s*#/; print "$.: $_" if /RepoRoot[^#]*["\\\/]deploy["\\\/]|"deploy"/i' $ps1Script
        Check "ps1 static: no line reads the aitools deploy/" ($ok -and (Test-OutEmpty))
    }

    # --- HOME ------------------------------------------------------------------------
    Save-Snapshot $homeDir (Join-Path $tmpRoot "home-after")
    Copy-Item -LiteralPath (Join-Path $tmpRoot "home-after") -Destination $outFile -Force
    Check "home: the temporary HOME is unchanged" ((ReadText (Join-Path $tmpRoot "home-before")) -ceq (ReadText (Join-Path $tmpRoot "home-after")))
} catch {
    Write-Output "FAIL harness error: $($_.Exception.Message) ($($_.InvocationInfo.PositionMessage -replace "`r?`n", ' '))"
    $script:fail++
} finally {
    if (-not $keepTmp) { Remove-TestTempRoot $tmpRoot }
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped" -f $script:pass, $script:fail, $script:skip)
if ($script:fail -ne 0) { exit 1 }
exit 0
