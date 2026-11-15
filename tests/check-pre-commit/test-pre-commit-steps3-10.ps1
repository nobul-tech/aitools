# test-pre-commit-steps3-10.ps1 -- check-pre-commit steps 3 ("Build freshness")
# and 10 ("Deploy drift") never run build-deploy.sh and are retired to a SKIP
# that points to check-pre-push step 7 (incident #136). Before, -Fix / --fix ran
# build-deploy.sh under the caller's HOME (it rebuilds the real dotprofile
# deploy/; output and exit code were discarded), staged the frozen aitools
# deploy/ and reported PASS, and the step 3 WARN advised -Fix / --fix.
#
# Platform targeting (commander, 2026-11-14: "sh scripts and tests should only
# run on linux/mac and ps1 on windows"; "tests should be .ps1 here on windows
# and executed as powershell scripts, git bash scripts cause known issues"):
# this harness runs on Windows only and tests the .ps1 twin,
# scripts/check-pre-commit.ps1, with native pwsh. No case runs bash. The .sh
# twin is tested on macOS and Linux by
# tests/check-pre-commit/test-pre-commit-steps3-10.sh (the same section, step 6
# and run cases, and the same static cases).
#
# Cases:
#   section  steps 3 and 10 of check-pre-commit.ps1 (cut between the "# 3." and
#            "# 4." headings and between "# 10." and "# 11.") dot-sourced in a
#            child pwsh with stub step functions, a scripts/ file staged, a
#            temporary HOME and a fake repo with a tracked deploy/ file
#            modified. $gitBash (the bash the pre-fix step 3 ran build-deploy.sh
#            with) is a PowerShell stub that writes marker files (one in HOME).
#            Fix mode on: no marker, nothing staged under deploy/, exactly two
#            results, SKIP 3 and SKIP 10, both naming check-pre-push step 7. Fix
#            mode off: the same two results, no WARN, no -Fix advice.
#   step 6   step 6 (cut between "# 6." and "# 7.") run with the same stubs on
#            a fake repo with deploy/x.sh and scripts/y.sh both committed at
#            100644. Fix mode on: deploy/x.sh stays 100644 and nothing is
#            staged under deploy/, scripts/y.sh becomes 100755, the one result
#            is PASS 6 (fixed). Fix mode off: nothing changes, the one result is
#            FAIL 6 "1 file(s) missing +x" (scripts/y.sh only). The frozen
#            aitools deploy/ is neither repaired nor reported (PR #154 review B1).
#   static   perl over the text of both twins (perl is cross-platform; the .sh
#            harness runs the same programs): no non-comment line runs
#            build-deploy or stages deploy/; every line that lists tracked *.sh
#            files (step 6) excludes deploy/ (':!deploy/'); no step result text
#            advises -Fix / --fix; the usage line of the fix flag does not say
#            it builds. perl: the one on PATH, else Git for Windows'
#            usr\bin\perl.exe; without perl these cases FAIL.
#   run      check-pre-commit.ps1 -Fix, from a clone of this repo whose
#            scripts/build-deploy.sh writes a marker if anything runs it. A
#            scripts/ .sh is staged with CRLF and mode 100644, a tracked deploy/
#            file is modified; HOME is temporary and its config.json points at a
#            fixture dotprofile. Steps 3 and 10 SKIP as above; the run ends with
#            a summary; no marker; HOME and the dotprofile working tree are
#            unchanged (every file, by checksum); nothing staged under deploy/;
#            steps 4 and 6 still repair the staged file (LF, 100755).
#
# Override the scripts under test with PRE_COMMIT_PS1 (the .ps1 twin) and
# PRE_COMMIT_SH (read by the static cases only), absolute paths, e.g. to show
# that the pre-fix scripts fail; the run case copies PRE_COMMIT_PS1 into the
# clone. TEST_RUN_TWIN=none skips the run case (default: ps1). TEST_KEEP_TMP=1
# keeps the temp dir (its path is printed).
# Safe to re-run: writes only to a temp dir, removed on exit; git runs with an
# empty global config and no system config; the real HOME and the real
# dotprofile are never read or written. Needs git; the static cases need perl.
# Exit 1 if any case fails.
# Platform: Windows, pwsh 7 (CI: windows job); refuses macOS and Linux.
# Usage: pwsh -NoProfile -File tests/check-pre-commit/test-pre-commit-steps3-10.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 60 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/check-pre-commit/test-pre-commit-steps3-10.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$ps1Script = if ($env:PRE_COMMIT_PS1) { $env:PRE_COMMIT_PS1 } else { Join-Path $root "scripts/check-pre-commit.ps1" }
$shScript = if ($env:PRE_COMMIT_SH) { $env:PRE_COMMIT_SH } else { Join-Path $root "scripts/check-pre-commit.sh" }
$runTwin = if ($env:TEST_RUN_TWIN) { $env:TEST_RUN_TWIN } else { "ps1" }
$tmpRoot = New-TestTempRoot "pre-commit-3-10"
$keepTmp = ($env:TEST_KEEP_TMP -eq "1")
if ($keepTmp) { Write-Output "temp dir kept: $tmpRoot" }
$outFile = Join-Path $tmpRoot "out"

# git: an empty global config and no system config (no autocrlf, no identity
# from the machine), inherited by every child process
$env:GIT_CONFIG_GLOBAL = Join-Path $tmpRoot "gitconfig"
[IO.File]::WriteAllText($env:GIT_CONFIG_GLOBAL, "")
$env:GIT_CONFIG_NOSYSTEM = "1"

$script:pass = 0; $script:fail = 0; $script:skip = 0
$RETIRED = 'retired: check-pre-push step 7 rebuilds into a temp dotprofile copy'
$utf8 = [Text.UTF8Encoding]::new($false)

function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
function WriteText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $utf8) }
# Mixed PATH: C:\a\b -> C:/a/b, the form the child environments get (the .sh
# harness passed cygpath -m paths in CI)
function Mixed([string]$Path) { $Path -replace '\\', '/' }

# Get-Lines PATH: the file's lines, CR removed (perl -n counts the same lines);
# callers wrap it in @()
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

# Invoke-Git ARGS: git with stderr dropped, never throwing; exit code in $script:gitRc
function Invoke-Git {
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try { $o = & git @args 2>$null; $script:gitRc = $LASTEXITCODE } finally { $ErrorActionPreference = $prev }
    $o
}
# Git-Fixture ARGS: a fixture git command that must succeed
function Git-Fixture {
    $null = Invoke-Git @args
    if ($script:gitRc -ne 0) { throw "fixture: git $($args -join ' ') failed (exit $($script:gitRc))" }
}
$GitId = @("-c", "user.name=test", "-c", "user.email=test@example.com")

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
function Has-Line([string]$Path, [string]$Pattern) { [bool](@(Get-Lines $Path) | Where-Object { $_ -cmatch $Pattern }) }

# Test-RecordsOk REC: exactly SKIP 3 and SKIP 10, both with the retired text
function Test-RecordsOk([string]$Rec) {
    if (-not (Test-Path -LiteralPath $Rec -PathType Leaf)) { return $false }
    $l = @(Get-Lines $Rec)
    return ($l.Count -eq 2 -and ($l -ccontains "SKIP 3 $RETIRED") -and ($l -ccontains "SKIP 10 $RETIRED"))
}
# Test-RecIs REC LINE: the record file holds exactly that one line
function Test-RecIs([string]$Rec, [string]$Line) {
    if (-not (Test-Path -LiteralPath $Rec -PathType Leaf)) { return $false }
    $l = @(Get-Lines $Rec)
    return ($l.Count -eq 1 -and $l[0] -ceq $Line)
}
# Test-ModeIs REPO PATH MODE: the index mode of PATH
function Test-ModeIs([string]$Repo, [string]$Path, [string]$Mode) {
    [bool](@(Invoke-Git -C $Repo ls-files -s '--' $Path) | Where-Object { $_ -match "^$Mode " })
}
function Test-NothingStagedUnderDeploy([string]$Repo) {
    $o = @(Invoke-Git -C $Repo diff --cached --name-only '--' deploy)
    return ($script:gitRc -eq 0 -and $o.Count -eq 0)
}
function Test-HasCr([string]$Path) { (Test-Path -LiteralPath $Path -PathType Leaf) -and ([IO.File]::ReadAllBytes($Path) -contains 13) }

# Save-Snapshot DIR OUT: every file under DIR with its SHA-256, ordinal order,
# except .git/ (git status refreshes the index) and AppData/Local/Microsoft/PowerShell/
# (pwsh itself writes its startup profile cache under USERPROFILE at every start)
function Save-Snapshot([string]$Dir, [string]$Out) {
    $base = (Resolve-Path -LiteralPath $Dir).ProviderPath.TrimEnd('\') + '\'
    $rows = [Collections.Generic.List[string]]::new()
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force)) {
        $rel = $f.FullName.Substring($base.Length) -replace '\\', '/'
        if ($rel -like '.git/*' -or $rel -like 'AppData/Local/Microsoft/PowerShell/*') { continue }
        $rows.Add("$((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash) ./$rel")
    }
    $arr = $rows.ToArray()
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    WriteText $Out (($arr -join "`n") + "`n")
}
# Write-SnapshotDiff A B: the difference of two snapshots to the out file
function Write-SnapshotDiff([string]$A, [string]$B) {
    $d = Compare-Object -ReferenceObject @(Get-Lines $A) -DifferenceObject @(Get-Lines $B) -CaseSensitive
    WriteText $outFile ((@($d | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join "`n") + "`n")
}

# Copy-Tree SRC DST: every file under SRC to the same relative path under DST
# (cp -R SRC/. DST/)
function Copy-Tree([string]$Src, [string]$Dst) {
    $base = (Resolve-Path -LiteralPath $Src).ProviderPath.TrimEnd('\') + '\'
    foreach ($f in @(Get-ChildItem -LiteralPath $Src -Recurse -File -Force)) {
        $target = Join-Path $Dst $f.FullName.Substring($base.Length)
        $dir = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -LiteralPath $f.FullName -Destination $target -Force
    }
}

# perl for the static cases: the one on PATH, else Git for Windows' own
$perl = (Get-Command perl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $perl) {
    $gb = Resolve-TestGitBash
    if ($gb) {
        $gitPerl = Join-Path (Split-Path -Parent (Split-Path -Parent $gb)) "usr\bin\perl.exe"
        if (Test-Path -LiteralPath $gitPerl -PathType Leaf) { $perl = $gitPerl }
    }
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

# The PowerShell stub for $gitBash: records that it ran, in HOME (as the real
# build-deploy.sh writes the dotprofile it resolves from HOME) and at an
# absolute marker path. No bash runs.
$fakeBash = Join-Path $tmpRoot "fake-bash.ps1"
WriteText $fakeBash "[IO.File]::WriteAllText((Join-Path `$env:HOME 'm6b-build-ran'), 'ran')`n[IO.File]::WriteAllText(`$env:M6B_MARKER, 'ran')`n"
# The fake scripts/build-deploy.sh of the fixture repos (the .sh harness's fake;
# never executed here unless a regressed step runs it)
$fakeBuild = Join-Path $tmpRoot "fake-build-deploy.sh"
WriteText $fakeBuild "#!/usr/bin/env bash`nprintf ran > `"`$HOME/m6b-build-ran`"`nprintf ran > `"`$M6B_MARKER`"`n"

# New-Repo DIR: a git repo with a committed deploy/ file, then modified (so a
# `git add deploy/` would stage it), and scripts/build-deploy.sh = the fake
function New-Repo([string]$Dir) {
    New-Item -ItemType Directory -Path (Join-Path $Dir "deploy"), (Join-Path $Dir "scripts") -Force | Out-Null
    WriteText (Join-Path $Dir "deploy/setup-x.sh") "frozen`n"
    Git-Fixture -C $Dir init -q
    Git-Fixture -C $Dir -c core.autocrlf=false add -A
    Git-Fixture -C $Dir @GitId commit -q -m fixture
    [IO.File]::AppendAllText((Join-Path $Dir "deploy/setup-x.sh"), "changed`n", $utf8)
    Copy-Item -LiteralPath $fakeBuild -Destination (Join-Path $Dir "scripts/build-deploy.sh") -Force
}

# New-Repo6 DIR: a git repo with deploy/x.sh and scripts/y.sh committed at
# mode 100644 (git add --chmod=-x, so the mode does not depend on the file system)
function New-Repo6([string]$Dir) {
    New-Item -ItemType Directory -Path (Join-Path $Dir "deploy"), (Join-Path $Dir "scripts") -Force | Out-Null
    WriteText (Join-Path $Dir "deploy/x.sh") "echo frozen`n"
    WriteText (Join-Path $Dir "scripts/y.sh") "echo source`n"
    Git-Fixture -C $Dir init -q
    Git-Fixture -C $Dir -c core.autocrlf=false add --chmod=-x '--' deploy/x.sh scripts/y.sh
    Git-Fixture -C $Dir @GitId commit -q -m fixture6
}

# Step6-Checks LABEL REPO FIX REC: the step 6 assertions
function Step6-Checks([string]$Label, [string]$Repo, [string]$Fix, [string]$Rec) {
    Check "${Label}: deploy/x.sh still 100644 in the index" (Test-ModeIs $Repo deploy/x.sh 100644)
    Check "${Label}: nothing staged under deploy/" (Test-NothingStagedUnderDeploy $Repo)
    if ($Fix -eq "true") {
        Check "${Label}: scripts/y.sh repaired to 100755" (Test-ModeIs $Repo scripts/y.sh 100755)
        Check "${Label}: exactly PASS 6 (fixed)" (Test-RecIs $Rec 'PASS 6 (fixed)')
    } else {
        Check "${Label}: scripts/y.sh unchanged (100644)" (Test-ModeIs $Repo scripts/y.sh 100644)
        Check "${Label}: exactly FAIL 6, scripts/y.sh only (1 file)" (Test-RecIs $Rec 'FAIL 6 1 file(s) missing +x')
    }
}

# The child pwsh that dot-sources a cut section, with the step functions stubbed
$runPs1 = Join-Path $tmpRoot "run.ps1"
WriteText $runPs1 @'
$ErrorActionPreference = "Stop"
function StepPass { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "PASS $n $d" }
function StepFail { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "FAIL $n $d" }
function StepWarn { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "WARN $n $d" }
function StepSkip { param($n, $name, $d) Add-Content -Path $env:STEP_REC -Value "SKIP $n $d" }
function InvokeGit { $out = & git @args 2>$null; $out }
$script:RepoRoot = $env:STEP_REPO
$scriptDir = Join-Path $env:STEP_REPO "scripts"
$stagedFiles = @("scripts/setup-x.sh")
$Fix = ($env:STEP_FIX -eq "true")
# The bash the pre-fix step 3 ran build-deploy.sh with: the PowerShell stub
$gitBash = $env:STEP_BASH
Set-Location $script:RepoRoot
. $env:STEP_SECTION

'@
function Invoke-Section([string]$Repo, [string]$HomeDir, [string]$Marker, [string]$Rec, [string]$Fix, [string]$Section) {
    $envs = @{
        HOME = (Mixed $HomeDir); USERPROFILE = (Mixed $HomeDir); M6B_MARKER = (Mixed $Marker); STEP_REC = (Mixed $Rec)
        STEP_REPO = (Mixed $Repo); STEP_FIX = $Fix; STEP_SECTION = (Mixed $Section); STEP_BASH = (Mixed $fakeBash)
    }
    return (Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $runPs1) -Environment $envs -OutFile $outFile)
}

function Invoke-RunWhole {
    $clone = Join-Path $tmpRoot "aitools"; $runHome = Join-Path $tmpRoot "run-home"; $dot = Join-Path $tmpRoot "run-dot"
    $logs = Join-Path $tmpRoot "run-logs"; $staged = "scripts/zz-m6b-staged.sh"
    $marker = Join-Path $tmpRoot "marker-run"
    # A clone of this repo, the working tree's scripts/ over it (uncommitted
    # changes are what gets tested), the twin under test, the fake build
    Git-Fixture clone -q $root $clone
    Git-Fixture -C $clone config core.autocrlf false
    Copy-Tree (Join-Path $root "scripts") (Join-Path $clone "scripts")
    Copy-Item -LiteralPath $ps1Script -Destination (Join-Path $clone "scripts/check-pre-commit.ps1") -Force
    Copy-Item -LiteralPath $fakeBuild -Destination (Join-Path $clone "scripts/build-deploy.sh") -Force
    # A staged scripts/ .sh with CRLF and mode 100644 (steps 4 and 6 repair it)
    WriteText (Join-Path $clone $staged) "echo staged`r`n"
    Git-Fixture -C $clone -c core.safecrlf=false add '--' $staged
    Git-Fixture -C $clone update-index --chmod=-x '--' $staged
    # A tracked aitools deploy/ file modified (the old step 3 staged deploy/)
    $dep = @(Invoke-Git -C $clone ls-files deploy) | Select-Object -First 1
    if (-not $dep) {
        New-Item -ItemType Directory -Path (Join-Path $clone "deploy") -Force | Out-Null
        $dep = "deploy/m6b.txt"
        WriteText (Join-Path $clone $dep) "x`n"
        Git-Fixture -C $clone add '--' $dep
        Git-Fixture -C $clone @GitId commit -q -m m6b-deploy
    }
    [IO.File]::AppendAllText((Join-Path $clone $dep), "# m6b`n", $utf8)
    # The fixture dotprofile (deploy/ gitignored and present, as on a real machine)
    New-Item -ItemType Directory -Path (Join-Path $dot "claude"), (Join-Path $dot "deploy") -Force | Out-Null
    WriteText (Join-Path $dot "claude/CLAUDE.md") "# Prefs`n"
    WriteText (Join-Path $dot ".gitignore") "deploy/`n"
    WriteText (Join-Path $dot "deploy/setup-user-claude.sh") "built`n"
    Git-Fixture -C $dot init -q
    Git-Fixture -C $dot -c core.autocrlf=false add -A
    Git-Fixture -C $dot @GitId commit -q -m fixture
    # The temporary HOME
    foreach ($d in @((Join-Path $runHome ".aitools"), $logs, (Join-Path $tmpRoot "run-appdata"), (Join-Path $tmpRoot "run-localappdata"))) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
    WriteText (Join-Path $runHome ".aitools/config.json") ('{"repoPath": "' + (Mixed $clone) + '", "userRepoPath": "' + (Mixed $dot) + '"}' + "`n")
    Save-Snapshot $runHome (Join-Path $tmpRoot "home-before")
    Save-Snapshot $dot (Join-Path $tmpRoot "dot-before")
    if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
    $envs = @{
        AITOOLS_USER_REPO_PATH = $null; AITOOLS_PROFILE_FILE = $null; AITOOLS_MACHINE_ALIAS = $null; AITOOLS_SUMMARY_FILE = $null
        HOME = (Mixed $runHome); USERPROFILE = (Mixed $runHome)
        APPDATA = (Mixed (Join-Path $tmpRoot "run-appdata")); LOCALAPPDATA = (Mixed (Join-Path $tmpRoot "run-localappdata"))
        AITOOLS_LOG_DIR = (Mixed $logs); M6B_MARKER = (Mixed $marker)
    }
    $runOut = Join-Path $tmpRoot "run-out"
    $rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", (Join-Path $clone "scripts/check-pre-commit.ps1"), "-Fix") -Environment $envs -OutFile $runOut
    Copy-Item -LiteralPath $runOut -Destination $outFile -Force
    Save-Snapshot $runHome (Join-Path $tmpRoot "home-after")
    Save-Snapshot $dot (Join-Path $tmpRoot "dot-after")
    # Step results from checks.log: "<RESULT> <num> <detail>"
    $checksLog = Join-Path $logs "checks.log"
    $rec = @()
    foreach ($l in @(Get-Lines $checksLog)) {
        if ($l -cmatch '\[pre-commit\]\s+(\d+)\.\s.*?\[(PASS|FAIL|WARN|SKIP)\]\s?(.*)$') { $rec += "$($Matches[2]) $($Matches[1]) $($Matches[3])" }
    }
    $rec310 = Join-Path $tmpRoot "run-rec-3-10"
    WriteText $rec310 ((@($rec | Where-Object { $_ -cmatch '^\S+ (3|10) ' }) | ForEach-Object { "$_`n" }) -join "")
    $label = "run (ps1, fix flag)"
    Check "${label}: the script ran to its summary (exit 0 or 1)" (($null -ne $rc) -and $rc -le 1 -and (ReadText $checksLog).Contains('SUMMARY'))
    Check "${label}: exactly SKIP 3 and SKIP 10, pointing to check-pre-push step 7" (Test-RecordsOk $rec310)
    Check "${label}: build-deploy.sh was not run (no marker)" (-not (Test-Path -LiteralPath $marker))
    # On a difference, the failure shows the snapshot diff (not the run output)
    Write-SnapshotDiff (Join-Path $tmpRoot "home-before") (Join-Path $tmpRoot "home-after")
    Check "${label}: HOME unchanged (every file, by checksum)" ((ReadText (Join-Path $tmpRoot "home-before")) -ceq (ReadText (Join-Path $tmpRoot "home-after")))
    Write-SnapshotDiff (Join-Path $tmpRoot "dot-before") (Join-Path $tmpRoot "dot-after")
    Check "${label}: the dotprofile working tree unchanged" ((ReadText (Join-Path $tmpRoot "dot-before")) -ceq (ReadText (Join-Path $tmpRoot "dot-after")))
    Copy-Item -LiteralPath $runOut -Destination $outFile -Force
    Check "${label}: nothing staged under deploy/" (Test-NothingStagedUnderDeploy $clone)
    Check "${label}: step 4 still repairs line endings (staged file is LF)" ((-not (Test-HasCr (Join-Path $clone $staged))) -and [bool](@($rec) | Where-Object { $_.StartsWith('PASS 4 (fixed CRLF)') }))
    Check "${label}: step 6 still repairs the exec bit (staged file is 100755)" (Test-ModeIs $clone $staged 100755)
}

try {
    # --- section cases: .ps1 twin ------------------------------------------------
    if (-not (Test-Path -LiteralPath $ps1Script -PathType Leaf)) {
        Check "ps1: $ps1Script exists" $false
    } else {
        $steps = Join-Path $tmpRoot "steps.ps1"
        Get-Section $ps1Script $steps '^# (3|10)\. ' '^# (4|11)\. '
        Check "ps1: the step 3 and step 10 sections were found" ((Has-Line $steps '^# 3\. ') -and (Has-Line $steps '^# 10\. '))
        foreach ($mode in @("true", "false")) {
            $repo = Join-Path $tmpRoot "repo-ps1-$mode"
            $homeDir = Join-Path $tmpRoot "home-ps1-$mode"
            New-Repo $repo
            New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
            $marker = Join-Path $tmpRoot "marker-ps1-$mode"
            $rec = Join-Path $tmpRoot "rec-ps1-$mode"
            $rc = Invoke-Section $repo $homeDir $marker $rec $mode $steps
            $label = if ($mode -eq "true") { "ps1 section -Fix" } else { "ps1 section (no -Fix)" }
            Check "${label}: exit 0" ($rc -eq 0)
            Check "${label}: build-deploy.sh was not run (no marker, HOME untouched)" ((-not (Test-Path -LiteralPath $marker)) -and (-not (Test-Path -LiteralPath (Join-Path $homeDir "m6b-build-ran"))))
            Check "${label}: nothing staged under deploy/" (Test-NothingStagedUnderDeploy $repo)
            Check "${label}: exactly SKIP 3 and SKIP 10, pointing to check-pre-push step 7" (Test-RecordsOk $rec)
            Check "${label}: no result advises -Fix" ((Test-Path -LiteralPath $rec -PathType Leaf) -and -not ((ReadText $rec) -match '-fix'))
        }

        # Step 6: the frozen deploy/ is neither repaired nor reported (review B1)
        $step6 = Join-Path $tmpRoot "step6.ps1"
        Get-Section $ps1Script $step6 '^# 6\. ' '^# 7\. '
        Check "ps1: the step 6 section was found" (Has-Line $step6 '^# 6\. ')
        foreach ($mode in @("true", "false")) {
            $repo = Join-Path $tmpRoot "repo6-ps1-$mode"
            New-Repo6 $repo
            $rec = Join-Path $tmpRoot "rec6-ps1-$mode"
            $rc = Invoke-Section $repo (Join-Path $tmpRoot "home-ps1-$mode") (Join-Path $tmpRoot "marker6-ps1-$mode") $rec $mode $step6
            $label = if ($mode -eq "true") { "ps1 step 6 -Fix" } else { "ps1 step 6 (no -Fix)" }
            Check "${label}: exit 0" ($rc -eq 0)
            Step6-Checks $label $repo $mode $rec
        }
    }

    # --- static cases (perl over the text of both twins) -------------------------
    if (Test-Path -LiteralPath $shScript -PathType Leaf) {
        $ok = Invoke-PerlCheck 'next if /^\s*#/; print "$.: $_" if /(?:^|[\s;&|(])(?:bash|sh|source|\.)\s+[^#]*build-deploy/' $shScript
        Check "sh static: no line runs build-deploy" ($ok -and (Test-OutEmpty))
        $ok = Invoke-PerlCheck 'next if /^\s*#/; print "$.: $_" if /\bgit\s+add\s+[^#]*\bdeploy\b/' $shScript
        Check "sh static: no line stages deploy/" ($ok -and (Test-OutEmpty))
        $ok = Invoke-PerlCheck 'next if /^\s*#/; $n++ if /\bls-files\b.*\*\.sh/; print "$.: $_" if /\bls-files\b.*\*\.sh/ && !/:!deploy\//; END { print "no ls-files *.sh line found\n" unless $n }' $shScript
        Check "sh static: the tracked *.sh listing (step 6) excludes deploy/" ($ok -and (Test-OutEmpty))
        $ok = Invoke-PerlCheck 'next if /^\s*#/; print "$.: $_" if /\bstep_\w+\b.*--fix/' $shScript
        Check "sh static: no step result advises --fix" ($ok -and (Test-OutEmpty))
        $ok = Invoke-PerlCheck 'print "$.: $_" if /^#\s*--fix:/' $shScript
        Check "sh static: the --fix usage line exists and does not say it builds" ($ok -and -not (Test-OutEmpty) -and -not ((ReadText $outFile) -match 'build'))
    }
    if (Test-Path -LiteralPath $ps1Script -PathType Leaf) {
        $ok = Invoke-PerlCheck 's/\r$//; next if /^\s*#/; print "$.: $_" if /(?:&|\bbash\b|Start-Process)[^#]*build-deploy/i' $ps1Script
        Check "ps1 static: no line runs build-deploy" ($ok -and (Test-OutEmpty))
        $ok = Invoke-PerlCheck 's/\r$//; next if /^\s*#/; print "$.: $_" if /\b(?:InvokeGit|git)\s+add\s+[^#]*\bdeploy\b/i' $ps1Script
        Check "ps1 static: no line stages deploy/" ($ok -and (Test-OutEmpty))
        $ok = Invoke-PerlCheck 's/\r$//; next if /^\s*#/; $n++ if /\bls-files\b.*\*\.sh/i; print "$.: $_" if /\bls-files\b.*\*\.sh/i && !/:!deploy\//; END { print "no ls-files *.sh line found\n" unless $n }' $ps1Script
        Check "ps1 static: the tracked *.sh listing (step 6) excludes deploy/" ($ok -and (Test-OutEmpty))
        $ok = Invoke-PerlCheck 's/\r$//; next if /^\s*#/; print "$.: $_" if /\bStep\w+\b.*-Fix/i' $ps1Script
        Check "ps1 static: no step result advises -Fix" ($ok -and (Test-OutEmpty))
        $ok = Invoke-PerlCheck 's/\r$//; print "$.: $_" if /^#\s*-Fix:/' $ps1Script
        Check "ps1 static: the -Fix usage line exists and does not say it builds" ($ok -and -not (Test-OutEmpty) -and -not ((ReadText $outFile) -match 'build'))
    }

    # --- run case: check-pre-commit.ps1 -Fix ---------------------------------------
    if ($runTwin -eq "ps1") {
        Invoke-RunWhole
    } else {
        Write-Output "SKIP run case: TEST_RUN_TWIN=$runTwin"; $script:skip++
    }
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
