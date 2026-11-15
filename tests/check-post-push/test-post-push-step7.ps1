# test-post-push-step7.ps1 -- check-post-push step 7 ("deploy/ drift audit") never
# runs build-deploy.sh. The step used to run it with the caller's HOME, which
# replaces the real dotprofile deploy/; it is retired to a SKIP that points to
# check-pre-push step 7 (M5-Fixes item 3). The Windows harness of this suite;
# tests/check-post-push/test-post-push-step7.sh is the macOS/Linux harness.
#
# Cases (same names and order as the .sh harness):
#   static   (perl reads of the file text, nothing is run) the step 7 section
#            of each twin is found, and no non-comment line of either whole
#            script runs build-deploy
#   ps1 run  the step 7 section of scripts/check-post-push.ps1 (the .ps1 twin),
#            cut out between its "# 7." and "# 9." headings, runs in a child
#            pwsh with stub step functions, a temporary HOME and a fake
#            scripts dir; $bashExe (the bash the old step ran build-deploy.sh
#            with) and "bash" on PATH are a stub bash.cmd that only touches a
#            marker file: the marker must not exist and the only step result
#            must be SKIP 7, naming check-pre-push step 7
#
# Platform targeting (commander, 2026-11-14: "sh scripts and tests should only
# run on linux/mac and ps1 on windows"): this harness runs the .ps1 twin's
# section natively on Windows and refuses other platforms. It never runs bash
# (the stub is a .cmd): the .sh twin's section runs on macOS/Linux in the .sh
# harness. Perl (static cases): check-lib.ps1's Strawberry-first PATH block,
# then the perl on PATH, else Git for Windows' own; PERLIO=:perlio.
#
# Override the scripts under test with POST_PUSH_SH / POST_PUSH_PS1 (absolute
# paths), e.g. to show that the pre-fix scripts fail.
# Safe to re-run: writes only to a temp dir, removed on exit. Needs perl. Exit 1
# if any case fails. Platform: Windows, pwsh 7 (CI: windows job).
# Usage: pwsh -NoProfile -File tests/check-post-push/test-post-push-step7.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 30 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/check-post-push/test-post-push-step7.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$shScript = if ($env:POST_PUSH_SH) { $env:POST_PUSH_SH } else { Join-Path $root "scripts/check-post-push.sh" }
$ps1Script = if ($env:POST_PUSH_PS1) { $env:POST_PUSH_PS1 } else { Join-Path $root "scripts/check-post-push.ps1" }
$pwshExe = (Get-Process -Id $PID).Path
$tmpRoot = New-TestTempRoot "post-push-step7"
$out = Join-Path $tmpRoot "out"

$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:progN = 0

function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path) { [IO.File]::ReadAllText($Path) } else { "" } }
# Lines FILE: the file's lines, CR removed, without the empty string after the last newline
function Lines([string]$Path) {
    $t = (ReadText $Path) -replace "`r", ""
    if ($t -eq "") { return @() }
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    return @($t -split "`n")
}

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if (Test-Path -LiteralPath $out) {
        @(Lines $out) | Select-Object -Last 15 | ForEach-Object { Write-Output "      | $_" }
    }
}

# Perl as the check scripts get it: scripts/check-lib.ps1 puts Strawberry Perl
# first on PATH when it is installed ("Fail, don't mask": never Git's bundled
# perl ahead of it). Its top-level "if ($IsWindows)" block is loaded from that
# file's syntax tree and run here, not the whole library (as
# tests/lib/platform-lib.ps1 loads ResolveGitBash); a missing block throws.
$clErrors = $null
$clAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root "scripts/check-lib.ps1"), [ref]$null, [ref]$clErrors)
if ($clErrors) { Remove-TestTempRoot $tmpRoot; throw "cannot parse scripts/check-lib.ps1" }
$clPerlBlock = $clAst.Find({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.Contains('Strawberry') }, $false)
if (-not $clPerlBlock) { Remove-TestTempRoot $tmpRoot; throw "the Strawberry Perl PATH block of scripts/check-lib.ps1 was not found" }
. ([scriptblock]::Create($clPerlBlock.Extent.Text))
# perl: the one on PATH, else Git for Windows' own (Git\usr\bin\perl.exe)
$perl = (Get-Command perl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $perl) {
    $gitBash = Resolve-TestGitBash
    if ($gitBash) {
        $gitPerl = Join-Path (Split-Path -Parent (Split-Path -Parent $gitBash)) "usr\bin\perl.exe"
        if (Test-Path -LiteralPath $gitPerl -PathType Leaf) { $perl = $gitPerl }
    }
}
if (-not $perl) {
    Write-Output "FAIL perl not found (PATH, Git for Windows usr\bin): the cases need it"
    Remove-TestTempRoot $tmpRoot
    exit 1
}

# Invoke-PerlTo PROGRAM OUTFILE FILE: perl -n PROGRAM (written to a file, so no
# command-line quoting) over FILE; perl itself writes stdout to OUTFILE byte for
# byte; stderr goes to OUTFILE.err. Returns perl's exit code.
function Invoke-PerlTo([string]$Program, [string]$OutFile, [string]$File) {
    $script:progN++
    $prog = Join-Path $tmpRoot ("prog-" + $script:progN + ".pl")
    $text = 'BEGIN { open(STDOUT, ">", $ENV{AIT_PERL_OUT}) or die "cannot write $ENV{AIT_PERL_OUT}: $!\n" }' + "`n" + $Program + "`n"
    [IO.File]::WriteAllText($prog, $text)
    return (Invoke-TestScript -FilePath $perl -ArgumentList @("-n", $prog, $File) -Environment @{ PERLIO = ":perlio"; AIT_PERL_OUT = $OutFile } -OutFile ($OutFile + ".err"))
}

# Section SCRIPT OUT: the step 7 section (from the "# 7." heading to the "# 9."
# heading), CRLF removed (.ps1 files check out with CRLF)
function Section([string]$Script, [string]$OutFile) {
    $null = Invoke-PerlTo 's/\r$//; $p = 1 if /^# 7\. /; $p = 0 if /^# 9\. /; print if $p' $OutFile $Script
}
function SectionFound([string]$File) { [bool](@(Lines $File) | Where-Object { $_ -cmatch '^# 7\. ' }) }

# The fake scripts dir: build-deploy.sh as in the .sh harness, and a stub bash
# (bash.cmd) that only records that it ran
$fake = Join-Path $tmpRoot "fake"
$fakeBin = Join-Path $fake "bin"
$home7 = Join-Path $tmpRoot "home"
foreach ($d in @((Join-Path $fake "scripts"), (Join-Path $fake "repo"), $fakeBin, $home7)) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}
[IO.File]::WriteAllText((Join-Path $fake "scripts/build-deploy.sh"), "#!/usr/bin/env bash`nprintf ran > `"`$STEP7_MARKER`"`n")
$bashStub = Join-Path $fakeBin "bash.cmd"
[IO.File]::WriteAllText($bashStub, "@echo ran> `"%STEP7_MARKER%`"`r`n")
& git -C (Join-Path $fake "repo") init -q
if ($LASTEXITCODE -ne 0) { throw "git init failed in $fake\repo" }

try {
    # --- .sh twin: static only (its section runs in the .sh harness, on macOS/Linux) --
    if (-not (Test-Path -LiteralPath $shScript -PathType Leaf)) {
        Check "sh: $shScript exists" $false
    } else {
        $step7Sh = Join-Path $tmpRoot "step7.sh"
        Section $shScript $step7Sh
        Check "sh: the step 7 section was found" (SectionFound $step7Sh)
        # Static: no non-comment line runs build-deploy (bash/sh/source/. <...build-deploy...>)
        $prc = Invoke-PerlTo 'next if /^\s*#/; print "$.: $_" if /(?:^|[\s;&|(])(?:bash|sh|source|\.)\s+[^#]*build-deploy/' $out $shScript
        Check "sh static: no line runs build-deploy" ($prc -eq 0 -and (Test-Path -LiteralPath $out) -and (Get-Item -LiteralPath $out).Length -eq 0)
    }

    # --- .ps1 twin -----------------------------------------------------------------
    if (-not (Test-Path -LiteralPath $ps1Script -PathType Leaf)) {
        Check "ps1: $ps1Script exists" $false
    } else {
        $step7Ps1 = Join-Path $tmpRoot "step7.ps1"
        Section $ps1Script $step7Ps1
        Check "ps1: the step 7 section was found" (SectionFound $step7Ps1)
        $runPs1 = Join-Path $tmpRoot "run.ps1"
        $runText = @'
$ErrorActionPreference = "Stop"
function StepPass { param($n, $name, $d) Add-Content -Path $env:STEP7_REC -Value "PASS $n $d" }
function StepFail { param($n, $name, $d) Add-Content -Path $env:STEP7_REC -Value "FAIL $n $d" }
function StepWarn { param($n, $name, $d) Add-Content -Path $env:STEP7_REC -Value "WARN $n $d" }
function StepSkip { param($n, $name, $d) Add-Content -Path $env:STEP7_REC -Value "SKIP $n $d" }
function InvokeGit { $out = & git @args 2>$null; $out }
$scriptDir = Join-Path $env:STEP7_FAKE "scripts"
$script:RepoRoot = Join-Path $env:STEP7_FAKE "repo"
# The bash the old step ran build-deploy.sh with
$bashExe = $env:STEP7_BASH
Set-Location $script:RepoRoot
. $env:STEP7_SECTION
'@
        [IO.File]::WriteAllText($runPs1, ($runText -replace "`r`n", "`n") + "`n")
        $marker = Join-Path $tmpRoot "marker-ps1"
        $rec = Join-Path $tmpRoot "rec-ps1"
        $envs = @{
            HOME = $home7; USERPROFILE = $home7
            STEP7_MARKER = $marker; STEP7_REC = $rec; STEP7_FAKE = $fake; STEP7_SECTION = $step7Ps1; STEP7_BASH = $bashStub
            PATH = $fakeBin + [IO.Path]::PathSeparator + $env:PATH
        }
        $rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $runPs1) -Environment $envs -OutFile $out
        Check "ps1 run: exit 0" ($rc -eq 0)
        Check "ps1 run: build-deploy.sh was not run" (-not (Test-Path -LiteralPath $marker))
        $recLines = @(Lines $rec)
        Check "ps1 run: one result, SKIP 7, pointing to check-pre-push step 7" `
            ((Test-Path -LiteralPath $rec) -and $recLines.Count -eq 1 -and $recLines[0] -cmatch '^SKIP 7 retired: check-pre-push step 7')
        # Static: no non-comment line invokes build-deploy with & or bash
        $prc = Invoke-PerlTo 's/\r$//; next if /^\s*#/; print "$.: $_" if /(?:&|\bbash\b|Start-Process)[^#]*build-deploy/i' $out $ps1Script
        Check "ps1 static: no line runs build-deploy" ($prc -eq 0 -and (Test-Path -LiteralPath $out) -and (Get-Item -LiteralPath $out).Length -eq 0)
    }
} finally {
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped" -f $script:pass, $script:fail, $script:skip)
if ($script:fail -ne 0) { exit 1 }
exit 0
