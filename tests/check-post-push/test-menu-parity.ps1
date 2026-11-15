# test-menu-parity.ps1 -- tests for scripts/check-menu-parity.pl, the logic of
# check-post-push step 29 ("Deployment menu parity audit"), and for step 29
# itself in the .ps1 twin. The Windows harness of this suite;
# tests/check-post-push/test-menu-parity.sh is the macOS/Linux harness.
#
# Cases (same names and order as the .sh harness):
#   lib        the current scripts/aitools-lib.sh / .ps1 pair matches; every
#              menu-read call is found (4 per file today), the run-time prompt
#              counts as "?"
#   planted    a mismatch inside a read_menu_choice prompt (bash), inside a
#              Read-MenuChoice -Prompt (PowerShell), a letter dropped from a
#              [o/a/m/s/x] list, a printf menu line: each fails and is named;
#              the step 29 extraction before v0.77.2 misses the two prompt
#              mismatches (shown, so the gap stays visible)
#   fixtures   a prompt passed in a variable (bash p="...", PowerShell
#              $p = "...") resolves, a mismatch through it fails; calls in
#              comments and trailing comments do not count; Read-MenuChoice
#              in any letter case counts
#   errors     nothing found, usage, an unreadable file, -Help
#   twins      static: the step 29 section of each twin calls
#              scripts/check-menu-parity.pl (a perl read of the text); run: the
#              step 29 section of scripts/check-post-push.ps1 (the .ps1 twin),
#              run in a child pwsh with stub step functions against a copy of
#              the libs: PASS on the current pair, FAIL on a planted one
#
# Platform targeting (commander, 2026-11-14: "sh scripts and tests should only
# run on linux/mac and ps1 on windows", and perl scripts are cross-platform:
# "build-deploy.sh and all perl/python scripts"): this harness runs the perl
# cases and the .ps1 twin's step 29 natively on Windows and refuses other
# platforms. It never runs bash: the .sh twin's step 29 runs on macOS/Linux in
# the .sh harness. Perl: check-lib.ps1's Strawberry-first PATH block, then the
# perl on PATH (no Git-perl fallback: the suite FAILs); PERLIO=:perlio.
#
# Safe to re-run: writes only to a temp dir, removed on exit. Needs perl. Exit 1
# if any case fails. Platform: Windows, pwsh 7 (CI: windows job).
# Usage: pwsh -NoProfile -File tests/check-post-push/test-menu-parity.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 36 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/check-post-push/test-menu-parity.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$check = Join-Path $root "scripts/check-menu-parity.pl"
$shLib = Join-Path $root "scripts/aitools-lib.sh"
$ps1Lib = Join-Path $root "scripts/aitools-lib.ps1"
$pwshExe = (Get-Process -Id $PID).Path
$tmpRoot = New-TestTempRoot "menu-parity"
$out = Join-Path $tmpRoot "out"

$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:rc = 0
$script:progN = 0

function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path) { [IO.File]::ReadAllText($Path) } else { "" } }
# Lines FILE: the file's lines, CR removed, without the empty string after the last newline
function Lines([string]$Path) {
    $t = (ReadText $Path) -replace "`r", ""
    if ($t -eq "") { return @() }
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    return @($t -split "`n")
}
function LastLine([string]$Path) { $l = @(Lines $Path); if ($l.Count) { $l[-1] } else { "" } }
function HasLine([string]$Path, [string]$Pattern) { [bool](@(Lines $Path) | Where-Object { $_ -cmatch $Pattern }) }
function CountLines([string]$Path, [string]$Pattern) { @(@(Lines $Path) | Where-Object { $_ -cmatch $Pattern }).Count }

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
# perl: the one on PATH after that block, as step 29 finds it. No fallback to
# Git for Windows' bundled perl ("Fail, don't mask"; cross-platform.md "no
# fallback to bundled versions"): without perl on PATH the suite FAILs.
$perl = (Get-Command perl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $perl) {
    Write-Output "FAIL perl not found on PATH (after check-lib's Strawberry block): the cases need it"
    Remove-TestTempRoot $tmpRoot
    exit 1
}
Write-Output "perl: $perl"

# Test-CallsParity FILE: a line that is not a comment names check-menu-parity.pl
function Test-CallsParity([string]$Path) {
    [bool](@(Lines $Path) | Where-Object { $_ -notmatch '^\s*#' -and $_ -match 'check-menu-parity\.pl' })
}

# Run-Check BASH_LIB PS1_LIB: perl check-menu-parity.pl; exit code in $script:rc,
# stdout and stderr in $out
function Run-Check([string]$BashLib, [string]$Ps1Lib) {
    $script:rc = Invoke-TestScript -FilePath $perl -ArgumentList @($check, $BashLib, $Ps1Lib) -Environment @{ PERLIO = ":perlio" } -OutFile $out
}

# Invoke-PerlTo SWITCH PROGRAM OUTFILE FILES...: perl SWITCH (-n or -p) with
# PROGRAM (written to a file, so no command-line quoting) over FILES; perl itself
# writes stdout to OUTFILE byte for byte (no PowerShell re-encoding); stderr goes
# to OUTFILE.err. Returns perl's exit code.
function Invoke-PerlTo([string]$Switch, [string]$Program, [string]$OutFile, [string[]]$Files) {
    $script:progN++
    $prog = Join-Path $tmpRoot ("prog-" + $script:progN + ".pl")
    $text = 'BEGIN { open(STDOUT, ">", $ENV{AIT_PERL_OUT}) or die "cannot write $ENV{AIT_PERL_OUT}: $!\n" }' + "`n" + $Program + "`n"
    [IO.File]::WriteAllText($prog, $text)
    return (Invoke-TestScript -FilePath $perl -ArgumentList (@($Switch, $prog) + $Files) -Environment @{ PERLIO = ":perlio"; AIT_PERL_OUT = $OutFile } -OutFile ($OutFile + ".err"))
}

function SameBytes([string]$A, [string]$B) { (Get-FileHash -LiteralPath $A).Hash -eq (Get-FileHash -LiteralPath $B).Hash }

# Plant SRC DST PROGRAM: a copy with one change (perl -p PROGRAM); fails the
# case (anchor gone) when the copy equals the source
function Plant([string]$Src, [string]$Dst, [string]$Program) {
    $prc = Invoke-PerlTo "-p" $Program $Dst @($Src)
    if ($prc -ne 0 -or -not (Test-Path -LiteralPath $Dst) -or (SameBytes $Src $Dst)) {
        Write-Output ("FAIL plant anchor not found in {0} ({1})" -f $Src, $Program); $script:fail++
        return $false
    }
    return $true
}

# Old-Step29 BASH_LIB PS1_LIB: "match" or "mismatch" by the step 29 extraction
# before v0.77.2 (printf / Console lines only); the letters, unique and sorted,
# joined with commas, as the .sh harness's sort -u | paste -s -d ,
function Old-Letters([string]$Program, [string]$File) {
    $script:progN++
    $f = Join-Path $tmpRoot ("old-" + $script:progN)
    $null = Invoke-PerlTo "-n" $Program $f @($File)
    $set = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    foreach ($l in @(Lines $f)) { if ($l -ne "") { $null = $set.Add($l) } }
    return (@($set) -join ",")
}
function Old-Step29([string]$BashLib, [string]$Ps1Lib) {
    $oPs1 = Old-Letters 'print "$1\n" if /Console.*Write.*\[(\w)\]/' $Ps1Lib
    $oSh = Old-Letters 'print "$1\n" if /printf.*\[(\w)\]/' $BashLib
    if ($oPs1 -ceq $oSh) { "match" } else { "mismatch" }
}

# Section SCRIPT OUT: step 29, from its "# 29." heading to the "# 30." heading,
# CR removed (.ps1 files check out with CRLF)
function Section([string]$Script, [string]$OutFile) {
    $null = Invoke-PerlTo "-n" 's/\r$//; $p = 1 if /^# 29\. /; $p = 0 if /^# 30\. /; print if $p' $OutFile @($Script)
}

# Mk-Repo DIR BASH_LIB PS1_LIB: a fake repo root with scripts/check-menu-parity.pl and a lib pair
function Mk-Repo([string]$Dir, [string]$BashLib, [string]$Ps1Lib) {
    $s = Join-Path $Dir "scripts"
    New-Item -ItemType Directory -Path $s -Force | Out-Null
    Copy-Item -LiteralPath $check -Destination (Join-Path $s "check-menu-parity.pl")
    Copy-Item -LiteralPath $BashLib -Destination (Join-Path $s "aitools-lib.sh")
    Copy-Item -LiteralPath $Ps1Lib -Destination (Join-Path $s "aitools-lib.ps1")
}

try {
    # --- The current libraries ------------------------------------------------------
    Run-Check $shLib $ps1Lib
    Check "lib: the current pair matches (exit 0)" ($script:rc -eq 0)
    Check "lib: summary names the menus and the prompts" ((LastLine $out) -cmatch '^menus a,m,o,s,x; prompts ')
    Check "lib: the AI-merge preview prompt [y]es/[r]efine/[n]o is extracted on both sides" `
        ((HasLine $out '^  bash:[0-9]* n,r,y$') -and (HasLine $out '^  ps1:[0-9]* n,r,y$'))
    $nSh = CountLines $out '^  bash:'
    $nPs1 = CountLines $out '^  ps1:'
    Check "lib: every call found, same count each side ($nSh bash, $nPs1 PS1; at least 4)" ($nSh -ge 4 -and $nSh -eq $nPs1)
    Check 'lib: the run-time prompt (choice [$(...)]) counts as ?' ((HasLine $out '^  bash:[0-9]* \?$') -and (HasLine $out '^  ps1:[0-9]* \?$'))

    # --- Planted mismatches -----------------------------------------------------------
    $plantedPrompt = Join-Path $tmpRoot "planted-prompt.sh"
    if (Plant $shLib $plantedPrompt 's/\[n\]o reject: "/[q]uit reject: "/') {
        Run-Check $plantedPrompt $ps1Lib
        Check "planted: read_menu_choice prompt [n]o -> [q]uit (bash) fails, named" `
            ($script:rc -eq 1 -and (LastLine $out).Contains('prompts only in bash: [q,r,y]') -and (LastLine $out).Contains('prompts only in PS1: [n,r,y]'))
        Check "planted: the pre-v0.77.2 extraction misses that mismatch (the gap closed)" ((Old-Step29 $plantedPrompt $ps1Lib) -eq "match")
    }
    $plantedPromptPs1 = Join-Path $tmpRoot "planted-prompt.ps1"
    if (Plant $ps1Lib $plantedPromptPs1 's/-Prompt "  \[y\]es accept \/ \[r\]efine/-Prompt "  [y]es accept \/ [e]dit/') {
        Run-Check $shLib $plantedPromptPs1
        Check "planted: Read-MenuChoice -Prompt [r]efine -> [e]dit (PowerShell) fails, named" `
            ($script:rc -eq 1 -and (LastLine $out).Contains('prompts only in PS1: [e,n,y]'))
        Check "planted: the pre-v0.77.2 extraction misses that mismatch too" ((Old-Step29 $shLib $plantedPromptPs1) -eq "match")
    }
    $plantedList = Join-Path $tmpRoot "planted-list.sh"
    if (Plant $shLib $plantedList 's/"  choice \[o\/a\/m\/s\/x\]: "/"  choice [o\/a\/s\/x]: "/') {
        Run-Check $plantedList $ps1Lib
        Check "planted: [o/a/m/s/x] -> [o/a/s/x] in a bash prompt fails" `
            ($script:rc -eq 1 -and (LastLine $out).Contains('prompts only in bash: [a,o,s,x]'))
    }
    $plantedMenu = Join-Path $tmpRoot "planted-menu.sh"
    if (Plant $shLib $plantedMenu "s/printf '  \[s\]kip            :/printf '  [k]eep            :/") {
        Run-Check $plantedMenu $ps1Lib
        Check "planted: a printf menu line [s]kip -> [k]eep fails (menu letters)" `
            ($script:rc -eq 1 -and (LastLine $out).StartsWith('menu letters: bash '))
    }

    # --- Fixtures ------------------------------------------------------------------------
    # Written with LF line endings (this file may check out with CRLF)
    $varSh = Join-Path $tmpRoot "var.sh"
    $varPs1 = Join-Path $tmpRoot "var.ps1"
    $varShText = @'
# read_menu_choice x "y n" n "no" "ctx" "  [z]ap: "   (a comment: not a call)
ask() {
    local prompt="  [y]es / [n]o: " other="x"
    read_menu_choice ans "y n" n "no" "ask $1" "$prompt"
    case "$ans" in
        *) : ;;  # n (read_menu_choice returns only y or n)
    esac
}
'@
    $varPs1Text = @'
# $a = Read-MenuChoice -Valid @("z") -Prompt "  [z]ap: "   (a comment: not a call)
function Ask {
    $prompt = '  [y]es / [n]o: '
    $ans = read-menuchoice -Valid @("y", "n") -Default "n" -DefaultDesc "no" `
        -Context "ask $x" -Prompt $prompt   # trailing comment
}
'@
    [IO.File]::WriteAllText($varSh, ($varShText -replace "`r`n", "`n") + "`n")
    [IO.File]::WriteAllText($varPs1, ($varPs1Text -replace "`r`n", "`n") + "`n")
    Run-Check $varSh $varPs1
    Check "fixture: prompts in variables resolve and match (exit 0, n,y)" `
        ($script:rc -eq 0 -and (HasLine $out '^  bash:4 n,y$') -and (HasLine $out '^  ps1:4 n,y$'))
    Check "fixture: commented-out calls and the trailing comment do not count (one call each)" `
        ((CountLines $out '^  bash:') -eq 1 -and (CountLines $out '^  ps1:') -eq 1)
    $var2Ps1 = Join-Path $tmpRoot "var2.ps1"
    $null = Invoke-PerlTo "-p" 's/\[n\]o: /[c]ancel: /' $var2Ps1 @($varPs1)
    Run-Check $varSh $var2Ps1
    Check "fixture: a mismatch through a variable fails" ($script:rc -eq 1 -and (LastLine $out).Contains('prompts only in PS1: [c,y]'))

    # --- Errors ------------------------------------------------------------------------
    $emptySh = Join-Path $tmpRoot "empty.sh"
    $emptyPs1 = Join-Path $tmpRoot "empty.ps1"
    [IO.File]::WriteAllText($emptySh, "")
    [IO.File]::WriteAllText($emptyPs1, "")
    Run-Check $emptySh $emptyPs1
    Check "nothing found in either file: exit 1" ($script:rc -eq 1 -and (ReadText $out).Contains('extraction broken'))
    $script:rc = Invoke-TestScript -FilePath $perl -ArgumentList @($check, $shLib) -Environment @{ PERLIO = ":perlio" } -OutFile $out
    Check "one argument: exit 2 (usage)" ($script:rc -eq 2 -and (ReadText $out).Contains('usage'))
    Run-Check (Join-Path $tmpRoot "does-not-exist.sh") $ps1Lib
    Check "unreadable file: exit 2" ($script:rc -eq 2 -and (ReadText $out).Contains('cannot read'))
    $script:rc = Invoke-TestScript -FilePath $perl -ArgumentList @($check, "--help") -Environment @{ PERLIO = ":perlio" } -OutFile $out
    Check "--help: exit 0, prints the usage" ($script:rc -eq 0 -and (ReadText $out).Contains('check-menu-parity.pl BASH_LIB PS1_LIB'))

    # --- The twins' step 29 ------------------------------------------------------------
    $repoOk = Join-Path $tmpRoot "repo-ok"
    $repoBad = Join-Path $tmpRoot "repo-bad"
    Mk-Repo $repoOk $shLib $ps1Lib
    if (Test-Path -LiteralPath $plantedPrompt) { Mk-Repo $repoBad $plantedPrompt $ps1Lib }

    # The .sh twin: static only (its step 29 runs in the .sh harness, on macOS/Linux)
    $step29Sh = Join-Path $tmpRoot "step29.sh"
    Section (Join-Path $root "scripts/check-post-push.sh") $step29Sh
    # Comment lines are skipped: a comment that names the checker is not a call
    Check "sh twin: step 29 calls scripts/check-menu-parity.pl" (Test-CallsParity $step29Sh)

    $step29Ps1 = Join-Path $tmpRoot "step29.ps1"
    Section (Join-Path $root "scripts/check-post-push.ps1") $step29Ps1
    Check "ps1 twin: step 29 calls scripts/check-menu-parity.pl" (Test-CallsParity $step29Ps1)
    $run29 = Join-Path $tmpRoot "run29.ps1"
    $run29Text = @'
$ErrorActionPreference = "Stop"
function StepPass { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "PASS $n $d" }
function StepFail { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "FAIL $n $d" }
function StepSkip { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "SKIP $n $d" }
$Extensive = $true
$script:RepoRoot = $env:STEP_REPO
. $env:STEP_SECTION
'@
    [IO.File]::WriteAllText($run29, ($run29Text -replace "`r`n", "`n") + "`n")
    # The step runs "perl" from PATH: the same PATH that resolved $perl above
    $runPath = $env:PATH
    foreach ($v in @("ok", "bad")) {
        $repo = Join-Path $tmpRoot "repo-$v"
        if (-not (Test-Path -LiteralPath $repo)) { continue }
        $rec = Join-Path $tmpRoot "rec-ps1-$v"
        if (Test-Path -LiteralPath $rec) { Remove-Item -LiteralPath $rec -Force }
        $envs = @{ STEP_REC = $rec; STEP_REPO = $repo; STEP_SECTION = $step29Ps1; PATH = $runPath }
        $script:rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $run29) -Environment $envs -OutFile $out
        if ($v -eq "ok") { $want = '^PASS 29 PS1 and bash menus match: menus ' } else { $want = '^FAIL 29 .*prompts only in bash' }
        Check "ps1 twin: step 29 on the $v pair: exit 0, $want" ($script:rc -eq 0 -and (HasLine $rec $want))
    }
} finally {
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped" -f $script:pass, $script:fail, $script:skip)
if ($script:fail -ne 0) { exit 1 }
exit 0
