# test-deploy-harness-mdm.ps1 -- tests for the MDM deploy-harness that
# scripts/build-deploy.sh generates into <dotprofile>/deploy/, on Windows.
# The Windows harness of this suite; tests/deploy-harness-mdm/test-deploy-harness-mdm.sh
# is the macOS/Linux harness of the same cases for the .sh scripts.
#
# Runs build-deploy.sh under an isolated HOME with a fixture dotprofile (a git
# repo in a temp directory, passed as AITOOLS_USER_REPO_PATH), so the real HOME
# and the real dotprofile are never touched; the sources are this repo (read
# only). Then runs the dev path (scripts/deploy-harness.ps1) and the generated
# MDM path (deploy/deploy-harness.ps1 + deploy-harness.payload, a copy outside
# any repo, with a git on PATH that always fails) with native pwsh under more
# isolated HOMEs and compares the results. Cases: build output and parse,
# extraction by body markers (no marker line copied, section 5b kept; a missing
# or duplicated marker fails the build and leaves deploy/ as it was), the
# payload data file, the size gate (WARN with its fix hint, also forced with a
# padded fixture dotprofile), cursor header port and step 4, no adopt target in
# MDM, shared rules embedded and dotprofile rules and skills not, first run /
# rerun / edit / dry run equivalence (trees, summary rows, exit codes), the
# terminal review menu (pywinpty), no git needed at run time, -Help,
# config.json (no bootstrap, -SkipConfig, the writer), a damaged payload, a
# damaged or malformed record, a missing payload, a CRLF payload, the .ps1
# stage directory removed on exit 1, a dotprofile rule named like a shared
# rule, a build from a non-git dotprofile. The .sh-only cases (exec bits,
# bash -n, truncated .sh copies) run in the .sh harness.
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs the .ps1 scripts with native pwsh on Windows only.
# build-deploy.sh is a bash builder marked cross-platform (cross-platform.md
# exemptions; the commander's named example), so it is built here with Git for
# Windows bash (Resolve-TestGitBash, never a bare bash: in native pwsh that can
# be the WSL launcher), MSYS paths for HOME; without Git Bash every case is
# SKIP. Parity with the .sh scripts: the normalized summary rows must equal
# tests/deploy-harness-mdm/golden/ (Test-GoldenMatch in tests/lib/platform-lib.ps1),
# which the .sh harness checks on macOS/Linux.
#
# Safe to re-run: everything runs under a temp root (removed on exit;
# KEEP_TMP=1 keeps it); the real HOME is never read or written. Needs node and
# git on PATH and Git for Windows; python3 with pywinpty for the terminal case
# (SKIP otherwise). Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/deploy-harness-mdm/test-deploy-harness-mdm.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 42 | Select-Object -Skip 1 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/deploy-harness-mdm/test-deploy-harness-mdm.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$lang = "ps1"
$latin1 = [Text.Encoding]::Latin1   # byte-faithful text for the perl-style edits
$utf8 = [Text.UTF8Encoding]::new($false)

$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:OUT = ""
$script:RC = @{}

# The .sh harness needs node, perl and git. Here node and git run natively; perl
# is used only by build-deploy.sh, inside Git Bash (Git's usr/bin perl).
foreach ($t in @("node", "git")) {
    if (-not (Get-Command $t -CommandType Application -ErrorAction SilentlyContinue)) {
        # Get-Command exempt: command-existence check; the SKIP is the fallback
        Write-Output "SKIP all cases ($t not found)"
        exit 0
    }
}
$gitBash = Resolve-TestGitBash
if (-not $gitBash) {
    Write-Output "SKIP all cases (Git for Windows bash not found: build-deploy.sh cannot be built)"
    exit 0
}

# --- helpers -------------------------------------------------------------------
function Mixed([string]$P) { $P -replace '\\', '/' }          # cygpath -m (native_path)
function Msys([string]$P) { ConvertTo-MsysPath $P }           # cygpath -u, for Git Bash
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
function Strip([string]$Text) { ($Text -replace "`e\[[0-9;?]*[A-Za-z]", "") -replace "`r", "" }
function WriteLf([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $utf8) }
function ReadBytesText([string]$Path) { $latin1.GetString([IO.File]::ReadAllBytes($Path)) }
function WriteBytesText([string]$Path, [string]$Text) { [IO.File]::WriteAllBytes($Path, $latin1.GetBytes($Text)) }
# Remove-CR FILE: perl -pi -e 's/\r//g' FILE
function Remove-CR([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { WriteBytesText $Path ((ReadBytesText $Path) -replace "`r", "") }
}
function MakeDir([string]$Path) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if ($script:OUT -and (Test-Path -LiteralPath $script:OUT -PathType Leaf)) {
        @((Strip (ReadText $script:OUT)).TrimEnd("`n") -split "`n") | Select-Object -Last 20 | ForEach-Object { Write-Output "      | $_" }
    }
}
function Skip([string]$Text) { Write-Output "SKIP $Text"; $script:skip++ }

# FileLines PATH: PATH's lines, CR removed (Git for Windows grep strips CR before
# matching, which the .sh harness relied on); $null when PATH is not a file.
function FileLines([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $t = [IO.File]::ReadAllText($Path) -replace "`r", ""
    if ($t.Length -eq 0) { return , ([string[]]@()) }
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    return , ([string[]]($t -split "`n"))
}
# GrepQ PATH PATTERN [-Fixed] [-Whole]: grep -q (case-sensitive; -F, -x); a
# missing file is no match (grep exits 2).
function GrepQ([string]$Path, [string]$Pattern, [switch]$Fixed, [switch]$Whole) {
    $lines = FileLines $Path
    if ($null -eq $lines) { return $false }
    foreach ($l in $lines) {
        if ($Whole -and $Fixed) { if ($l -ceq $Pattern) { return $true } }
        elseif ($Whole) { if ($l -cmatch "^(?:$Pattern)$") { return $true } }
        elseif ($Fixed) { if ($l.Contains($Pattern)) { return $true } }
        elseif ($l -cmatch $Pattern) { return $true }
    }
    return $false
}
# GrepCount PATH LITERAL: grep -c (lines containing LITERAL); -1 for a missing file
function GrepCount([string]$Path, [string]$Literal) {
    $lines = FileLines $Path
    if ($null -eq $lines) { return -1 }
    return @($lines | Where-Object { $_.Contains($Literal) }).Count
}
function SameBytes([string]$A, [string]$B) {
    if (-not (Test-Path -LiteralPath $A -PathType Leaf) -or -not (Test-Path -LiteralPath $B -PathType Leaf)) { return $false }
    $x = [IO.File]::ReadAllBytes($A); $y = [IO.File]::ReadAllBytes($B)
    if ($x.Length -ne $y.Length) { return $false }
    return [Convert]::ToBase64String($x) -ceq [Convert]::ToBase64String($y)
}
function Sha256Hex([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant() }
# PerlLines PATH: lines as perl -n reads them (bytes, CR kept, no line for a final LF)
function PerlLines([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return , ([string[]]@()) }
    $t = ReadBytesText $Path
    if ($t.Length -eq 0) { return , ([string[]]@()) }
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    return , ([string[]]($t -split "`n"))
}

function Invoke-Git {
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try {
        $out = & git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false @args 2>&1
        $rc = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    if ($rc -ne 0) { throw "git $($args -join ' ') failed (exit $rc): $($out -join "`n")" }
}

$tmpRoot = New-TestTempRoot "deploy-harness-mdm"
$GoldenDir = Join-Path $root "tests/deploy-harness-mdm/golden"
$GoldenTmp = $tmpRoot

try {
    $DOT = Join-Path $tmpRoot "dot"
    MakeDir (Join-Path $DOT "claude/rules"); MakeDir (Join-Path $DOT "claude/skills/dskill/ref")
    WriteLf (Join-Path $DOT "claude/rules/user1.md") "user rule one`n"
    WriteLf (Join-Path $DOT "claude/rules/user2.md") "user rule two`n"
    WriteLf (Join-Path $DOT "claude/skills/dskill/SKILL.md") "dotprofile skill`n"
    WriteLf (Join-Path $DOT "claude/skills/dskill/ref/r.md") "dotprofile skill ref`n"
    Invoke-Git -C $DOT init -q
    Invoke-Git -C $DOT add -A
    Invoke-Git -C $DOT commit -q -m fixture
    # Probe rules: deployed from this repo's shared/rules (the dotprofile rules and
    # skills above are not harness sources and must never be embedded or deployed)
    $P1 = Join-Path $root "shared/rules/scratch.md"
    $P2 = Join-Path $root "shared/rules/tool-ops.md"

    # Write-Config HOME_DIR [native|posix] -- bootstrap config.json. native (the
    # default): C:/... paths, as pwsh reads them and as the .sh harness wrote them
    # (cygpath -m); posix: MSYS paths for build-deploy.sh (bash).
    function Write-Config([string]$HomeDir, [string]$Form = "native") {
        $cv = if ($Form -eq "posix") { { param($p) Msys $p } } else { { param($p) Mixed $p } }
        MakeDir (Join-Path $HomeDir ".aitools")
        WriteLf (Join-Path $HomeDir ".aitools/config.json") ("{`n  `"version`": 3,`n  `"reposPath`": `"" + (& $cv $tmpRoot) + "`",`n  `"repoPath`": `"" + (& $cv $root) + "`",`n  `"userRepoPath`": `"" + (& $cv $DOT) + "`"`n}`n")
    }

    # Run-Build HOME_DIR DOTPROFILE BUILD_SCRIPT -- one build-deploy.sh run in Git
    # Bash, output to $OUT; returns the exit code. HOME (MSYS form) and USERPROFILE
    # are both the isolated HOME: the resolver build-deploy runs is pwsh, whose
    # $HOME follows USERPROFILE (CI run 41265193554: "No dotprofile found"). The
    # dotprofile is passed as AITOOLS_USER_REPO_PATH in C:/... form, the way
    # scripts/aitools passes it.
    function Run-Build([string]$HomeDir, [string]$Dot, [string]$BuildScript) {
        $envs = @{ HOME = (Msys $HomeDir); USERPROFILE = (Mixed $HomeDir); AITOOLS_USER_REPO_PATH = (Mixed $Dot) }
        return Invoke-TestScript -FilePath $gitBash -ArgumentList @((Msys $BuildScript)) -Environment $envs -OutFile $script:OUT
    }

    # Build-Deploy NAME -- build-deploy.sh into $DOT/deploy, then copy deploy/ to $tmpRoot/NAME
    function Build-Deploy([string]$Name) {
        $hb = Join-Path $tmpRoot "home-build-$Name"
        Write-Config $hb "posix"
        $script:OUT = Join-Path $tmpRoot "build-$Name.out"
        $script:RC["build-$Name"] = Run-Build $hb $DOT (Join-Path $root "scripts/build-deploy.sh")
        $dest = Join-Path $tmpRoot $Name
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        MakeDir $dest
        if (Test-Path -LiteralPath (Join-Path $DOT "deploy") -PathType Container) {
            Copy-Item -LiteralPath (Join-Path $DOT "deploy") -Destination (Join-Path $dest "deploy") -Recurse -Force
        }
    }

    # Failing git for the MDM runs: the MDM path must not need git. One exception:
    # the terminal review menu displays its diff with `git diff --no-index` (#81);
    # without git it shows "(diff unavailable)" and the menu still works.
    # git.cmd records `& git` calls from native pwsh. The review diff starts git
    # through .NET ProcessStartInfo("git"), which finds only git.exe (CI run
    # 41267819083: it found the real one), so fakegit/git.exe is a copy of
    # where.exe: it rejects git's "-c ..." arguments and exits 2 (as Stub-Git-Fail
    # in tests/managed-files/test-managed-files.ps1). Calls to that git.exe are not
    # recorded in fakegit.calls; they fail, which is what the checks need. The
    # extensionless sh `git` is the .sh harness's (same directory as its Windows
    # run; native pwsh does not run it).
    $fakeGit = Join-Path $tmpRoot "fakegit"
    MakeDir $fakeGit
    WriteLf (Join-Path $fakeGit "git") ("#!/bin/sh`necho `"`$*`" >> `"" + (Msys $tmpRoot) + "/fakegit.calls`"`nexit 99`n")
    [IO.File]::WriteAllText((Join-Path $fakeGit "git.cmd"), ("@echo %*>> `"" + (Mixed $tmpRoot) + "/fakegit.calls`"`r`n@exit /b 99`r`n"), $utf8)
    $fakeGitExe = $true
    $whereExe = Join-Path $(if ($env:SystemRoot) { $env:SystemRoot } else { "C:\Windows" }) "System32\where.exe"
    try {
        Copy-Item -LiteralPath $whereExe -Destination (Join-Path $fakeGit "git.exe") -ErrorAction Stop
    } catch {
        Write-Output "WARN cannot copy $whereExe to fakegit/git.exe: pwsh can still find the real git.exe"
        $fakeGitExe = $false
    }

    # PsArgs ARGS: the .sh flags as the .ps1 spells them
    function PsArgs([string[]]$A) {
        foreach ($a in $A) {
            switch -CaseSensitive ($a) {
                "--dry-run" { "-DryRun" } "--force" { "-Force" } "--help" { "-Help" }
                "--skip-config" { "-SkipConfig" } default { $a }
            }
        }
    }

    # Run-Script SCRIPT HOME SUMMARY LOGDIR FAKEGIT ARGS [PSTMP] -- one native pwsh
    # run of a deploy-harness.ps1, non-interactive (stdin at EOF); console output
    # to $OUT; returns the exit code. CRs are removed from the summary and the
    # output afterwards. Paths in C:/... form, as the .sh harness passed them.
    # TERM: the .sh harness's pwsh was a child of Git Bash, which sets
    # TERM=xterm-256color; set here so the child sees the same terminal type.
    # PSTMP: the temp root for the MDM stage directory (TMP and TEMP for .NET);
    # otherwise TMP and TEMP are the runner's, as the .sh harness's /tmp was.
    function Run-Script([string]$Script, [string]$HomeDir, [string]$Sum, [string]$Logs, [bool]$FakeGitOn, [string[]]$ScriptArgs = @(), [string]$PsTmp = "") {
        $path = if ($FakeGitOn) { $fakeGit + [IO.Path]::PathSeparator + $env:PATH } else { $env:PATH }
        $envs = @{
            HOME = (Mixed $HomeDir); USERPROFILE = (Mixed $HomeDir); PATH = $path
            AITOOLS_LOG_DIR = (Mixed $Logs); AITOOLS_SUMMARY_FILE = (Mixed $Sum)
            AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null; TERM = "xterm-256color"
        }
        if ($PsTmp) { $envs.TMP = $PsTmp; $envs.TEMP = $PsTmp }
        $argv = @("-NoProfile", "-NonInteractive", "-File", (Mixed $Script)) + @(PsArgs $ScriptArgs)
        $rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile $script:OUT
        Remove-CR $Sum
        Remove-CR $script:OUT
        return $rc
    }

    # Run-Case SIDE NAME [ARGS] [PSTMP] -- SIDE dev|mdm, NAME = case dir; HOME = $tmpRoot/NAME-SIDE
    function Run-Case([string]$Side, [string]$Name, [string[]]$ScriptArgs = @(), [string]$PsTmp = "") {
        $h = Join-Path $tmpRoot "$Name-$Side"
        if (-not (Test-Path -LiteralPath (Join-Path $h ".aitools/config.json") -PathType Leaf)) { Write-Config $h }
        $script:OUT = Join-Path $tmpRoot "$Name-$Side.out"
        $sum = Join-Path $tmpRoot "$Name-$Side.summary"
        [IO.File]::WriteAllText($sum, "")
        if ($Side -eq "dev") {
            $s = Join-Path $root "scripts/deploy-harness.ps1"; $fg = $false
        } else {
            $s = Join-Path $tmpRoot "$($script:BUILD)/deploy/deploy-harness.ps1"; $fg = $true
        }
        $script:RC["$Name-$Side"] = Run-Script $s $h $sum (Join-Path $h "logs") $fg $ScriptArgs $PsTmp
    }

    function SameRc([string]$Name) { $script:RC["$Name-dev"] -eq $script:RC["$Name-mdm"] }
    function SameSummary([string]$Name) { SameBytes (Join-Path $tmpRoot "$Name-dev.summary") (Join-Path $tmpRoot "$Name-mdm.summary") }
    function Row([string]$Name, [string]$Text) { GrepQ (Join-Path $tmpRoot "$Name.summary") $Text -Fixed -Whole }
    function SumMatch([string]$Name, [string]$Pattern) { GrepQ (Join-Path $tmpRoot "$Name.summary") $Pattern }
    # TreeMap DIR: relative path -> "dir" or the file's sha256, without any
    # *.bak.* entry (diff -r -x '*.bak.*'); $null when DIR is not a directory
    function TreeMap([string]$Dir) {
        if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $null }
        $base = (Get-Item -LiteralPath $Dir -Force).FullName.TrimEnd('\', '/')
        $map = [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal)
        foreach ($i in @(Get-ChildItem -LiteralPath $Dir -Recurse -Force)) {
            $rel = $i.FullName.Substring($base.Length + 1) -replace '\\', '/'
            if (@($rel -split '/' | Where-Object { $_ -clike '*.bak.*' }).Count -gt 0) { continue }
            $map[$rel] = if ($i.PSIsContainer) { "dir" } else { Sha256Hex ([IO.File]::ReadAllBytes($i.FullName)) }
        }
        return , $map
    }
    # SameTrees NAME -- the six directories identical (names and content). The .sh
    # also compares the executable files; NTFS has no executable bit (Git Bash
    # derived it from the content), so identical content already covers it.
    function SameTrees([string]$Name) {
        foreach ($k in @("reference", "registries", "hooks", "rules", "skills", "bin")) {
            $a = TreeMap (Join-Path $tmpRoot "$Name-dev/.aitools/$k")
            $b = TreeMap (Join-Path $tmpRoot "$Name-mdm/.aitools/$k")
            if ($null -eq $a -or $null -eq $b -or $a.Count -ne $b.Count) { return $false }
            foreach ($key in $a.Keys) {
                if (-not $b.ContainsKey($key) -or $b[$key] -cne $a[$key]) { return $false }
            }
        }
        return $true
    }
    $fakeCalls = Join-Path $tmpRoot "fakegit.calls"
    function NoFakeGit { -not ((Test-Path -LiteralPath $fakeCalls -PathType Leaf) -and (Get-Item -LiteralPath $fakeCalls).Length -gt 0) }
    # Every recorded call is the review display's `git ... diff --no-index` (#81)
    function OnlyReviewDiffGit {
        if (NoFakeGit) { return $true }
        return -not (@(FileLines $fakeCalls) | Where-Object { -not $_.Contains(' diff --no-index ') })
    }
    # Rows-Golden FILE OUT -- summary rows for the cross-language golden: order-free
    # (ordinal, as LC_ALL=C sort), every number replaced by N
    function Rows-Golden([string]$In, [string]$Out) {
        $t = (ReadBytesText $In) -replace "`r", "" -replace '[0-9]+', 'N'
        $text = ""
        if ($t.Length -gt 0) {
            if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
            $rows = [string[]]($t -split "`n")
            [Array]::Sort($rows, [StringComparer]::Ordinal)
            $text = ($rows -join "`n") + "`n"
        }
        WriteBytesText $Out $text
    }
    # Set-PayloadSha DIR -- write the sha256 of DIR/deploy-harness.payload (CRs
    # removed) into the generated deploy-harness.ps1 (after a payload edit)
    function Set-PayloadSha([string]$Dir) {
        $sha = Sha256Hex ($latin1.GetBytes((ReadBytesText (Join-Path $Dir "deploy-harness.payload")).Replace("`r", "")))
        $ps = Join-Path $Dir "deploy-harness.ps1"
        WriteBytesText $ps ([regex]::Replace((ReadBytesText $ps), '(?m)^\$mdmPayloadSha256 = "[0-9a-f]+"', ('$mdmPayloadSha256 = "' + $sha + '"').Replace('$', '$$')))
    }
    # FirstCapture PATH REGEX: perl -ne 'print $1 if /REGEX/' (every line's capture, joined)
    function FirstCapture([string]$Path, [string]$Pattern) {
        $r = ""
        foreach ($l in (PerlLines $Path)) { if ($l -cmatch $Pattern) { $r += $Matches[1] } }
        return $r
    }

    # ---------------------------------------------------------------------------
    # Build
    # ---------------------------------------------------------------------------
    $script:BUILD = "b1"
    Build-Deploy b1
    $G = Join-Path $tmpRoot "b1/deploy"
    $GSh = Join-Path $G "deploy-harness.sh"
    $GPs = Join-Path $G "deploy-harness.ps1"
    $GPayload = Join-Path $G "deploy-harness.payload"
    # Exit 0 alone is not a build: a skipped build ("No dotprofile found") exits 0 too.
    Check "build: exit 0, not skipped" ($script:RC["build-b1"] -eq 0 -and -not (GrepQ (Join-Path $tmpRoot "build-b1.out") 'skipping deploy build'))
    Check "build: deploy-harness.sh/.ps1 and the config writer bundle generated" ((@("deploy-harness.sh", "deploy-harness.ps1", "setup-user-config.sh", "setup-user-config.ps1", "aitools-profile.sh", "aitools-profile.ps1", "aitools-json.pl", "aitools-json.ps1") | ForEach-Object { Test-Path -LiteralPath (Join-Path $G $_) -PathType Leaf }) -notcontains $false)
    # (The .sh harness's "generated .sh scripts are executable" and "bash -n" checks
    # run on macOS/Linux only: Windows has no executable bit.)
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($GPs, [ref]$null, [ref]$parseErrors)
    Check "MDM parse: pwsh parser deploy-harness.ps1" ((Test-Path -LiteralPath $GPs -PathType Leaf) -and @($parseErrors).Count -eq 0)
    Check "cursor (MDM): step 4 once in .sh and .ps1" ((GrepCount (Join-Path $G "setup-user-cursor.sh") 'Step 4: Cursor user rules') -eq 1 -and (GrepCount (Join-Path $G "setup-user-cursor.ps1") 'Step 4: Cursor user rules') -eq 1)
    $cs = Join-Path $G "setup-user-cursor.sh"; $cp = Join-Path $G "setup-user-cursor.ps1"
    Check "cursor (MDM): header ported from the source (five things, rules scope)" ((GrepQ $cs '^# Does five things:') -and (GrepQ $cp '^# Does five things:') -and (GrepQ $cs 'Managed: one <name>.mdc per') -and (GrepQ $cp 'Managed: one <name>.mdc per') -and -not (GrepQ $cs 'Does three things'))
    Check "MDM: no adopt target (.sh and .ps1)" ((GrepQ $GSh '"$TOOL" "$item" ""  # MDM' -Fixed) -and -not (GrepQ $GSh '"$item" "$src"' -Fixed) -and (GrepQ $GPs '-AdoptPath ""  # MDM' -Fixed) -and -not (GrepQ $GPs '-AdoptPath $p.Src' -Fixed))
    Check "MDM: shared rules embedded (payload record)" ([bool](@(PerlLines $GPayload) | Where-Object { $_ -cmatch '^aitools/shared/rules/scratch\.md\t0\t\d+\t[0-9a-f]{64}$' }))
    Check "MDM: no dotprofile, .claude/rules or .claude/skills record in the payload" (-not (GrepQ $GPayload '^(dotprofile/|aitools/\.claude/(rules|skills)/)'))
    Check "payload: data file beside the scripts, none inline" ((Test-Path -LiteralPath $GPayload -PathType Leaf) -and -not (GrepQ $GSh '^mdm_unpack ') -and -not (GrepQ $GPs '^Expand-MdmPayload ') -and (GrepQ $GSh '^MDM_PAYLOAD_SHA256=[0-9a-f]{64}$'))

    # SizeGateWarned DIR OUT -- every generated .ps1 (200000) / .sh (1000000) at or
    # over its Intune limit has its WARN in the build output, twice (inline and the
    # end-of-build list); one under it has none (FX-12: WARN, not a build FAIL).
    # Each over-limit WARN carries its fix hint (deploy-harness: the payload; the
    # others: FX-35). The end-of-build header counts them, and "ready for MDM
    # deployment" is printed only when none is over. $SizeGateOver is set to the
    # number of over-limit scripts found.
    $script:SizeGateOver = 0
    function SizeGateWarned([string]$Dir, [string]$Out) {
        $over = 0
        $outLines = FileLines $Out
        if ($null -eq $outLines) { $outLines = [string[]]@() }
        $files = @(Get-ChildItem -LiteralPath $Dir -File -Force | Where-Object { $_.Name -clike '*.ps1' }) + @(Get-ChildItem -LiteralPath $Dir -File -Force | Where-Object { $_.Name -clike '*.sh' })
        foreach ($f in $files) {
            $n = $f.Name
            $max = if ($n -clike '*.ps1') { 200000 } else { 1000000 }
            $sz = $f.Length
            $hint = if ($n -clike 'deploy-harness.*') { "move content to deploy-harness.payload" } else { "see FX-35 (inlined lib)" }
            $line = "deploy/$n is $sz bytes, over the Intune script limit ($max) -- $hint"
            if ($sz -ge $max) {
                if (@($outLines | Where-Object { $_.Contains('[warn]') -and $_.Contains($line) }).Count -ne 2) { return $false }
                $over++
            } elseif (@($outLines | Where-Object { $_.Contains("[warn] deploy/$n is ") -and $_.Contains("over the Intune script limit") }).Count -gt 0) {
                return $false
            }
        }
        $script:SizeGateOver = $over
        if ($over -gt 0) {
            if (-not (GrepQ $Out "[warn] $over generated script(s) over the Intune script limit (WARN only, the build does not fail):" -Fixed)) { return $false }
            if (GrepQ $Out 'ready for MDM deployment' -Fixed) { return $false }
        } else {
            if (-not (GrepQ $Out 'Scripts are self-contained and ready for MDM deployment' -Fixed)) { return $false }
            if (GrepQ $Out 'generated script(s) over the Intune script limit' -Fixed) { return $false }
        }
        return $true
    }
    Check "size gate: a generated script over its Intune limit is a WARN, not a build failure (FX-12)" ($script:RC["build-b1"] -eq 0 -and (SizeGateWarned $G (Join-Path $tmpRoot "build-b1.out")))

    # Forced over-limit case, independent of the real script sizes: a copy of the
    # fixture dotprofile whose claude/CLAUDE.md template is padded by ~1.2 MB.
    # build-deploy embeds that template in the generated setup-user-claude.sh (the
    # fallback template), so that .sh is over 1 MB. If the gate were removed or
    # stopped measuring .sh files, there would be no WARN and this check fails.
    $DOT_BIG = Join-Path $tmpRoot "dot-big"
    Copy-Item -LiteralPath $DOT -Destination $DOT_BIG -Recurse -Force
    if (Test-Path -LiteralPath (Join-Path $DOT_BIG "deploy")) { Remove-Item -LiteralPath (Join-Path $DOT_BIG "deploy") -Recurse -Force }
    MakeDir (Join-Path $DOT_BIG "claude")
    $pad = [Text.StringBuilder]::new()
    $null = $pad.Append("`n## Padding (size-gate test)`n`n")
    $xline = ("x" * 99) + "`n"
    for ($i = 0; $i -lt 12000; $i++) { $null = $pad.Append($xline) }
    [IO.File]::AppendAllText((Join-Path $DOT_BIG "claude/CLAUDE.md"), $pad.ToString(), $utf8)
    Invoke-Git -C $DOT_BIG add -A
    Invoke-Git -C $DOT_BIG commit -q -m padding
    $HB_BIG = Join-Path $tmpRoot "home-build-big"
    MakeDir (Join-Path $HB_BIG ".aitools")
    WriteLf (Join-Path $HB_BIG ".aitools/config.json") ("{`n  `"version`": 3,`n  `"reposPath`": `"" + (Msys $tmpRoot) + "`",`n  `"repoPath`": `"" + (Msys $root) + "`",`n  `"userRepoPath`": `"" + (Msys $DOT_BIG) + "`"`n}`n")
    $script:OUT = Join-Path $tmpRoot "build-big.out"
    $script:RC["build-big"] = Run-Build $HB_BIG $DOT_BIG (Join-Path $root "scripts/build-deploy.sh")
    function BigShOver {
        $f = Join-Path $DOT_BIG "deploy/setup-user-claude.sh"
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { return $false }
        if ((Get-Item -LiteralPath $f).Length -lt 1000000) { return $false }
        if (-not (SizeGateWarned (Join-Path $DOT_BIG "deploy") $script:OUT)) { return $false }
        return ($script:SizeGateOver -ge 1)
    }
    Check "size gate (forced): a .sh padded over 1 MB is a WARN with the FX-35 hint, build exit 0" ($script:RC["build-big"] -eq 0 -and (BigShOver))
    $script:OUT = ""
    $shSha = FirstCapture $GSh '^MDM_PAYLOAD_SHA256=(\S+)'
    $psSha = FirstCapture $GPs '^\$mdmPayloadSha256 = "([0-9a-f]+)"'
    $payloadSha = if (Test-Path -LiteralPath $GPayload -PathType Leaf) { Sha256Hex ($latin1.GetBytes((ReadBytesText $GPayload).Replace("`r", ""))) } else { "" }
    Check "payload: the scripts' sha256 (.sh and .ps1) is the payload's (CRs removed)" ((Test-Path -LiteralPath $GPayload -PathType Leaf) -and $shSha -ne "" -and $payloadSha -ceq $shSha -and $shSha -ceq $psSha)
    $markerRe = '^# --- (BEGIN|END) (scope|body|config bootstrap check|source setup) '
    Check "markers: no marker line copied into the MDM scripts" ((Test-Path -LiteralPath $GSh -PathType Leaf) -and (Test-Path -LiteralPath $GPs -PathType Leaf) -and -not (GrepQ $GSh $markerRe) -and -not (GrepQ $GPs $markerRe))
    $sectionsOk = $true
    foreach ($f in @($GSh, $GPs)) {
        if (-not ((GrepQ $f '^# 1\. config.json') -and (GrepQ $f '^# 3\. The six directories') -and (GrepQ $f '^# 5b\. Rules manifest') -and (GrepQ $f '^# 2\. \(MDM\) Embedded sources') -and -not (GrepQ $f '^# 2\. Sources') -and (GrepQ $f '^# Managed \('))) { $sectionsOk = $false }
    }
    Check "markers: sections 1, 3 and 5b extracted, section 2 replaced, scope in the header" $sectionsOk
    Check "markers: MDM bootstrap check replaced the dev comment" ((GrepQ $GSh 'SKIP_CONFIG="no bootstrap"' -Fixed) -and (GrepQ $GPs '$configSkip = "no bootstrap"' -Fixed) -and -not (GrepQ $GSh 'Dev path: aitools-install writes the bootstrap keys'))

    # ---------------------------------------------------------------------------
    # Equivalence: first run, rerun, edit, dry run (dev vs MDM)
    # ---------------------------------------------------------------------------
    Run-Case dev eq
    Run-Case mdm eq
    Check "first run: dev exit 0, MDM same exit code" ($script:RC["eq-dev"] -eq 0 -and (SameRc eq))
    Check "first run: same six directories and exec bits" (SameTrees eq)
    Check "first run: same summary rows" (SameSummary eq)
    Rows-Golden (Join-Path $tmpRoot "eq-mdm.summary") (Join-Path $tmpRoot "eq-first.rows")
    Check "first run parity: MDM summary rows (numbers as N) match golden (sh and ps1 share it)" (Test-GoldenMatch "eq-first.rows" (Join-Path $tmpRoot "eq-first.rows"))
    Check "first run: config.json written by the MDM writer, same as dev" (SameBytes (Join-Path $tmpRoot "eq-dev/.aitools/config.json") (Join-Path $tmpRoot "eq-mdm/.aitools/config.json"))
    Check "first run: shared rule deployed by MDM" (SameBytes $P1 (Join-Path $tmpRoot "eq-mdm/.aitools/rules/scratch.md"))
    Check "first run: dotprofile rules and skills deployed by neither path" (-not (Test-Path -LiteralPath (Join-Path $tmpRoot "eq-mdm/.aitools/rules/user1.md")) -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "eq-dev/.aitools/rules/user1.md")) -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "eq-mdm/.aitools/skills/dskill")) -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "eq-dev/.aitools/skills/dskill")))
    # Every manifest line is a comment or a shared source (perl: !/^#/ && !/\tshared\r?$/ is bad)
    function ManifestsShared([string[]]$Files) {
        foreach ($f in $Files) {
            foreach ($l in (PerlLines $f)) { if ($l -cnotmatch '^#' -and $l -cnotmatch '\tshared\r?$') { return $false } }
        }
        return $true
    }
    $skm = ".aitools/skills/.aitools-skills-manifest"; $rlm = ".aitools/rules/.aitools-rules-manifest"
    Check "first run: manifests written by MDM, same as dev, shared sources only" ((SameBytes (Join-Path $tmpRoot "eq-dev/$skm") (Join-Path $tmpRoot "eq-mdm/$skm")) -and (SameBytes (Join-Path $tmpRoot "eq-dev/$rlm") (Join-Path $tmpRoot "eq-mdm/$rlm")) -and (ManifestsShared @((Join-Path $tmpRoot "eq-mdm/$skm"), (Join-Path $tmpRoot "eq-mdm/$rlm"))))
    Check "first run: MDM needed no git" (NoFakeGit)
    Run-Case dev eq
    Run-Case mdm eq
    Check "rerun: everything verified, same rows" ((SumMatch eq-mdm '^OK\|harness files\|[0-9]* verified$') -and (SameSummary eq) -and (SameRc eq))
    WriteLf (Join-Path $tmpRoot "eq-dev/.aitools/rules/tool-ops.md") "local edit`n"
    WriteLf (Join-Path $tmpRoot "eq-mdm/.aitools/rules/tool-ops.md") "local edit`n"
    Run-Case dev eq
    Run-Case mdm eq
    # WARN, not OK: the non-interactive overwrite logs a warning and the library
    # raises the row to WARN; the dev path does the same (next check).
    Check "edit then rerun (non-interactive): source wins in MDM, 1 updated" ((SameBytes $P2 (Join-Path $tmpRoot "eq-mdm/.aitools/rules/tool-ops.md")) -and (SumMatch eq-mdm '^WARN\|harness files\|1 updated'))
    Check "edit then rerun: same rows and files as dev" ((SameSummary eq) -and (SameTrees eq))
    if (-not (SameSummary eq)) {
        Compare-Object @(FileLines (Join-Path $tmpRoot "eq-dev.summary")) @(FileLines (Join-Path $tmpRoot "eq-mdm.summary")) -CaseSensitive |
            ForEach-Object { Write-Output ("      | " + $(if ($_.SideIndicator -eq '<=') { '< ' } else { '> ' }) + $_.InputObject) }
    }
    Rows-Golden (Join-Path $tmpRoot "eq-mdm.summary") (Join-Path $tmpRoot "eq-edit.rows")
    Check "edit then rerun parity: MDM summary rows (numbers as N) match golden" (Test-GoldenMatch "eq-edit.rows" (Join-Path $tmpRoot "eq-edit.rows"))

    # Terminal review: pywinpty (ConPTY) through tests/managed-files/pty-run.py,
    # python3 as the .sh harness used it; a failing import means "not installed".
    $PTY = Join-Path $root "tests/managed-files/pty-run.py"
    $py = Get-Command python3 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    # Get-Command exempt: command-existence check; $havePty is the fallback branch
    $havePty = [bool]$py -and (Test-Path -LiteralPath $PTY -PathType Leaf)
    if ($havePty) {
        $havePty = (Invoke-TestScript -FilePath $py.Source -ArgumentList @("-c", "import winpty") -OutFile (Join-Path $tmpRoot "winpty-probe.out")) -eq 0
    }
    if ($havePty) {
        WriteLf (Join-Path $tmpRoot "eq-mdm/.aitools/rules/scratch.md") "local edit`n"
        $script:OUT = Join-Path $tmpRoot "pty-mdm.out"
        $ptySum = Join-Path $tmpRoot "pty-mdm.summary"
        [IO.File]::WriteAllText($ptySum, "")
        $envs = @{
            HOME = (Mixed (Join-Path $tmpRoot "eq-mdm")); USERPROFILE = (Mixed (Join-Path $tmpRoot "eq-mdm"))
            PATH = $fakeGit + [IO.Path]::PathSeparator + $env:PATH
            AITOOLS_LOG_DIR = (Mixed (Join-Path $tmpRoot "eq-mdm/logs")); AITOOLS_SUMMARY_FILE = (Mixed $ptySum)
            AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null; TERM = "xterm-256color"
        }
        # pty-run.py decodes the \n escape; the .sh ran `pwsh` by name, this the same pwsh by path
        $argv = @((Mixed $PTY), "--input", 's\n', "--log", (Mixed $script:OUT), "--", $pwshExe, "-NoProfile", "-File", (Mixed (Join-Path $tmpRoot "b1/deploy/deploy-harness.ps1")))
        $script:RC["pty-mdm"] = Invoke-TestScript -FilePath $py.Source -ArgumentList $argv -Environment $envs -OutFile (Join-Path $tmpRoot "pty-mdm.runner")
        Remove-CR $ptySum
        $plainFile = "$($script:OUT).plain"
        WriteLf $plainFile (Strip (ReadText $script:OUT))
        Check "terminal review (MDM): overwrite offered, adopt and merge not; skip keeps LOCAL" ($script:RC["pty-mdm"] -eq 0 -and (GrepQ $plainFile '\[o\]verwrite') -and -not (GrepQ $plainFile '\[a\]ccept & adopt') -and -not (GrepQ $plainFile '\[m\]erge & adopt') -and (GrepQ (Join-Path $tmpRoot "eq-mdm/.aitools/rules/scratch.md") 'local edit' -Fixed -Whole) -and (SumMatch pty-mdm '^WARN\|harness files\|1 skipped'))
        if ($fakeGitExe) {
            Check "terminal review (MDM) without git: diff unavailable, menu still shown" ((GrepQ $plainFile 'diff unavailable') -and (GrepQ $plainFile '\[o\]verwrite'))
        } else {
            Skip "terminal review without git (no fake git.exe: pwsh finds the real git)"
        }
    } else {
        Skip "terminal review case (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)"
    }

    Run-Case dev dry @("--dry-run")
    Run-Case mdm dry @("--dry-run")
    Check "dry run: same rows, nothing deployed" ((SameSummary dry) -and (SameRc dry) -and (SumMatch dry-mdm '^OK\|harness files\|dry-run: [0-9]* create, 0 update$') -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "dry-mdm/.aitools/rules")))
    Run-Case mdm help @("--help")
    Check "--help: exit 0, MDM header, nothing deployed" ($script:RC["help-mdm"] -eq 0 -and (GrepQ (Join-Path $tmpRoot "help-mdm.out") "MDM path of scripts/deploy-harness.$lang") -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "help-mdm/.aitools/rules")))
    Check "runs: MDM called git only to display the review diff" (OnlyReviewDiffGit)

    # ---------------------------------------------------------------------------
    # config.json (HARNESS Q3, -SkipConfig): one code path, OK "config.json" n/a rows
    # ---------------------------------------------------------------------------
    # A copy of deploy/ whose writer is a stub that records each call (one LF line).
    $stubDeploy = Join-Path $tmpRoot "stub/deploy"
    MakeDir $stubDeploy
    Copy-Item -Path (Join-Path $tmpRoot "b1/deploy/*") -Destination $stubDeploy -Recurse -Force
    $writerCalls = Join-Path $tmpRoot "writer.calls"
    # The .sh writer stub, as the .sh harness writes it (not run on Windows)
    WriteLf (Join-Path $stubDeploy "setup-user-config.sh") ("#!/usr/bin/env bash`necho `"`$*`" >> `"" + (Msys $tmpRoot) + "/writer.calls`"`nexit 0`n")
    WriteLf (Join-Path $stubDeploy "setup-user-config.ps1") ('param([switch]$DryRun, [switch]$Force)' + "`n" + "[IO.File]::AppendAllText('" + (Mixed $writerCalls) + "', `"called``n`")" + "`n" + 'exit 0' + "`n")
    function WriterCalls {
        if (-not (Test-Path -LiteralPath $writerCalls -PathType Leaf)) { return 0 }
        return @(PerlLines $writerCalls).Count
    }
    # Run-Fresh NAME [ARGS] -- the stub MDM copy under a HOME with no ~/.aitools at all
    function Run-Fresh([string]$Name, [string[]]$ScriptArgs = @()) {
        $h = Join-Path $tmpRoot "$Name-mdm"
        $script:OUT = Join-Path $tmpRoot "$Name-mdm.out"
        $sum = Join-Path $tmpRoot "$Name-mdm.summary"
        [IO.File]::WriteAllText($sum, "")
        $script:RC["$Name-mdm"] = Run-Script (Join-Path $stubDeploy "deploy-harness.ps1") $h $sum (Join-Path $tmpRoot "$Name-logs") $true $ScriptArgs
    }
    if (Test-Path -LiteralPath $writerCalls) { Remove-Item -LiteralPath $writerCalls -Force }
    Run-Fresh fresh
    Check "fresh HOME (MDM, no bootstrap): exit 0, OK config.json n/a row, no ERROR row" ($script:RC["fresh-mdm"] -eq 0 -and (Row fresh-mdm 'OK|config.json|n/a (no bootstrap)') -and -not (SumMatch fresh-mdm '^ERROR\|'))
    Check "fresh HOME (MDM): writer not called, harness files deployed" ((WriterCalls) -eq 0 -and (SameBytes $P1 (Join-Path $tmpRoot "fresh-mdm/.aitools/rules/scratch.md")) -and (SumMatch fresh-mdm '^OK\|harness files\|[0-9]* added') -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "fresh-mdm/.aitools/config.json")))
    Rows-Golden (Join-Path $tmpRoot "fresh-mdm.summary") (Join-Path $tmpRoot "fresh.rows")
    Check "fresh HOME parity: summary rows (numbers as N) match golden" (Test-GoldenMatch "fresh.rows" (Join-Path $tmpRoot "fresh.rows"))
    # Only one bootstrap key: still no bootstrap
    MakeDir (Join-Path $tmpRoot "half-mdm/.aitools")
    WriteLf (Join-Path $tmpRoot "half-mdm/.aitools/config.json") ("{`n  `"version`": 3,`n  `"reposPath`": `"" + (Mixed $tmpRoot) + "`"`n}`n")
    Run-Fresh half
    Check "MDM, config.json without repoPath: n/a (no bootstrap), writer not called" ($script:RC["half-mdm"] -eq 0 -and (Row half-mdm 'OK|config.json|n/a (no bootstrap)') -and (WriterCalls) -eq 0)
    # Bootstrap present: the MDM writer runs
    MakeDir (Join-Path $tmpRoot "boot-mdm")
    Write-Config (Join-Path $tmpRoot "boot-mdm")
    Run-Fresh boot
    Check "MDM with bootstrap keys: writer called once, no n/a row" ($script:RC["boot-mdm"] -eq 0 -and (WriterCalls) -eq 1 -and -not (SumMatch boot-mdm '^OK\|config.json\|'))
    if (Test-Path -LiteralPath $writerCalls) { Remove-Item -LiteralPath $writerCalls -Force }
    Run-Fresh skipm @("--skip-config")
    Check "--skip-config (MDM, fresh HOME): n/a (written by installer) wins, writer not called" ($script:RC["skipm-mdm"] -eq 0 -and (Row skipm-mdm 'OK|config.json|n/a (written by installer)') -and -not (SumMatch skipm-mdm 'no bootstrap') -and (WriterCalls) -eq 0)
    Check "dev path: the writer ran (its own rows), no config.json n/a row" ((SumMatch eq-dev '^[A-Z]*\|aitools config\|') -and -not (SumMatch eq-dev '\|config.json\|'))
    Run-Case dev skipd @("--skip-config")
    Copy-Item -LiteralPath (Join-Path $tmpRoot "skipd-dev/.aitools/config.json") -Destination (Join-Path $tmpRoot "skipd-config.before")
    Run-Case dev skipd @("--skip-config")
    Check "--skip-config (dev): exit 0, OK config.json n/a (written by installer), writer not run" ($script:RC["skipd-dev"] -eq 0 -and (Row skipd-dev 'OK|config.json|n/a (written by installer)') -and -not (SumMatch skipd-dev '\|aitools config\|') -and (SameBytes (Join-Path $tmpRoot "skipd-config.before") (Join-Path $tmpRoot "skipd-dev/.aitools/config.json")) -and -not (GrepQ (Join-Path $tmpRoot "skipd-dev/.aitools/config.json") '"meta"'))
    Run-Case dev helpd @("--help")
    $SKIP_FLAG = "-SkipConfig"
    $helpd = Join-Path $tmpRoot "helpd-dev.out"
    Check "--help (dev): documents $SKIP_FLAG, no marker lines" ($script:RC["helpd-dev"] -eq 0 -and (GrepQ $helpd $SKIP_FLAG) -and -not (GrepQ $helpd '--- BEGIN') -and -not (GrepQ $helpd '--- END'))

    # ---------------------------------------------------------------------------
    # Damaged payload: whole-file checksum, one damaged record, a malformed record
    # and a missing payload fail loudly (the truncated-.sh cases: .sh harness)
    # ---------------------------------------------------------------------------
    $badDeploy = Join-Path $tmpRoot "bad/deploy"
    MakeDir $badDeploy
    Copy-Item -Path (Join-Path $tmpRoot "b1/deploy/*") -Destination $badDeploy -Recurse -Force
    $badPayload = Join-Path $badDeploy "deploy-harness.payload"
    # Corrupt-Record FILE -- replace the line after scratch.md's record header with QUJD
    function Corrupt-Record([string]$Path) {
        $t = ReadBytesText $Path
        $lines = $t -split "`n"
        $skipNext = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -eq $lines.Count - 1 -and $lines[$i] -eq "") { break }   # after the final LF: not a line
            if ($skipNext) { $lines[$i] = "QUJD"; $skipNext = $false; continue }
            if ($lines[$i] -cmatch '^aitools/shared/rules/scratch\.md\t') { $skipNext = $true }
        }
        WriteBytesText $Path ($lines -join "`n")
    }
    # Restore-Bad -- the b1 payload and generated deploy-harness.ps1
    function Restore-Bad {
        Copy-Item -LiteralPath (Join-Path $tmpRoot "b1/deploy/deploy-harness.payload") -Destination $badPayload -Force
        Copy-Item -LiteralPath (Join-Path $tmpRoot "b1/deploy/deploy-harness.ps1") -Destination (Join-Path $badDeploy "deploy-harness.ps1") -Force
    }
    Corrupt-Record $badPayload
    $script:BUILD = "bad"
    Run-Case mdm corrupt
    Check "damaged payload (checksum): exit 1, ERROR payload damaged, nothing deployed" ($script:RC["corrupt-mdm"] -eq 1 -and (Row corrupt-mdm 'ERROR|harness files|payload damaged') -and (GrepQ (Join-Path $tmpRoot "corrupt-mdm.out") 'sha256 mismatch') -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "corrupt-mdm/.aitools/rules")))
    # The same damage with the script's sha256 updated: the record check catches it.
    # The stage directory goes under pstmp/ (TMP and TEMP, C:/... form with a
    # trailing slash, as the .sh harness passed it).
    Set-PayloadSha $badDeploy
    $pstmp = Join-Path $tmpRoot "pstmp"
    MakeDir $pstmp
    Run-Case mdm record @() ((Mixed $pstmp) + "/")
    Check "damaged record: exit 1, ERROR row, that file not deployed, the others are" ($script:RC["record-mdm"] -eq 1 -and (SumMatch record-mdm '^ERROR\|harness files\|1 embedded file\(s\) damaged') -and (GrepQ (Join-Path $tmpRoot "record-mdm.out") 'shared/rules/scratch.md is damaged') -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "record-mdm/.aitools/rules/scratch.md")) -and (Test-Path -LiteralPath (Join-Path $tmpRoot "record-mdm/.aitools/rules/tool-ops.md") -PathType Leaf))
    # .ps1: the stage directory is removed in a finally block, also on exit 1.
    # Where it was made: the "unpacked in" path's parent is pstmp, compared as the
    # same directory (long path, case-insensitive), not by spelling: .NET may print
    # an 8.3 short name or a long one, with \ (CI run 41267819083). Removed: no
    # aitools-harness-* entry is left in pstmp (other temp files that pwsh itself
    # makes there are not this script's).
    $stageW = ""
    foreach ($l in (PerlLines (Join-Path $tmpRoot "record-mdm.out"))) {
        $s = $l -replace "`e\[[0-9;?]*[A-Za-z]", ""
        if ($s -cmatch 'unpacked in (\S+)') { $stageW = $Matches[1]; break }
    }
    function SameDir([string]$A, [string]$B) {
        if (-not (Test-Path -LiteralPath $A -PathType Container) -or -not (Test-Path -LiteralPath $B -PathType Container)) { return $false }
        $la = (Get-TestLongPath ([IO.Path]::GetFullPath($A))).TrimEnd('\', '/')
        $lb = (Get-TestLongPath ([IO.Path]::GetFullPath($B))).TrimEnd('\', '/')
        return [string]::Equals($la, $lb, [StringComparison]::OrdinalIgnoreCase)
    }
    function StageOk {
        if (-not $stageW) { return $false }
        $leaf = ($stageW -split '[\\/]')[-1]
        if ($leaf -notlike 'aitools-harness-*') { return $false }
        $cut = [Math]::Max($stageW.LastIndexOf('/'), $stageW.LastIndexOf('\'))
        if ($cut -lt 1) { return $false }
        if (-not (SameDir $stageW.Substring(0, $cut) $pstmp)) { return $false }
        return -not (@(Get-ChildItem -LiteralPath $pstmp -Force -Name) | Where-Object { $_ -clike 'aitools-harness-*' })
    }
    Check "ps1 exit 1 after unpacking: the stage directory was created there and removed (finally)" (StageOk)
    if (-not (StageOk)) {
        Write-Output ("      | stage path from the output: " + $(if ($stageW) { $stageW } else { "(no 'unpacked in' line)" }))
        Write-Output "      | pstmp holds:"
        @(Get-ChildItem -LiteralPath $pstmp -Force -Name) | ForEach-Object { Write-Output "      |   $_" }
    }
    # A CRLF copy of the payload (Windows checkout with autocrlf) still verifies
    Restore-Bad
    WriteBytesText $badPayload ((ReadBytesText $badPayload).Replace("`n", "`r`n"))
    Run-Case mdm crlf
    Check "CRLF payload: verified and deployed (exit 0)" ($script:RC["crlf-mdm"] -eq 0 -and (SameBytes $P1 (Join-Path $tmpRoot "crlf-mdm/.aitools/rules/scratch.md")))
    Remove-Item -LiteralPath $badPayload -Force
    Run-Case mdm nopayload
    Check "missing payload: exit 1, ERROR payload missing, nothing deployed" ($script:RC["nopayload-mdm"] -eq 1 -and (Row nopayload-mdm 'ERROR|harness files|payload missing') -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "nopayload-mdm/.aitools/rules")))
    Restore-Bad
    # The truncation guard is the first command of the generated .sh (static check)
    function LineNo([string]$Path, [string[]]$Patterns) {
        $n = 0
        foreach ($l in (PerlLines $Path)) {
            $n++
            foreach ($p in $Patterns) { if ($l -cmatch $p) { return $n } }
        }
        return 0
    }
    $guardLine = LineNo $GSh @('^if command -v perl .*END OF GENERATED SCRIPT')
    $libLine = LineNo $GSh @('^logging_init\b', '^set -euo pipefail$')
    Check "truncation guard: the first command of the generated .sh (before the library)" ($guardLine -gt 0 -and $libLine -gt 0 -and $guardLine -lt $libLine)
    # A record line with a non-numeric size (sha updated): malformed, payload damaged
    WriteBytesText $badPayload ([regex]::Replace((ReadBytesText $badPayload), '(?m)^(aitools/shared/rules/scratch\.md\t0\t)[0-9]+', '${1}x'))
    Set-PayloadSha $badDeploy
    Run-Case mdm malformed
    Check "malformed record (size not a number): exit 1, ERROR payload damaged, nothing deployed" ($script:RC["malformed-mdm"] -eq 1 -and (Row malformed-mdm 'ERROR|harness files|payload damaged') -and (GrepQ (Join-Path $tmpRoot "malformed-mdm.out") 'malformed record') -and -not (Test-Path -LiteralPath (Join-Path $tmpRoot "malformed-mdm/.aitools/rules")))
    $script:BUILD = "b1"

    # ---------------------------------------------------------------------------
    # A dotprofile rule named like a shared rule (case differs): the dotprofile is
    # not a harness source, so no conflict and nothing deployed from it
    # ---------------------------------------------------------------------------
    WriteLf (Join-Path $DOT "claude/rules/Scratch.md") "dotprofile copy`n"
    Invoke-Git -C $DOT add -A
    Invoke-Git -C $DOT commit -q -m dup
    $script:BUILD = "b2"
    Build-Deploy b2
    Run-Case dev dup
    Run-Case mdm dup
    Check "dotprofile rule named like a shared rule: both exit 0, no ERROR row, same rows" ($script:RC["dup-dev"] -eq 0 -and (SameRc dup) -and -not (SumMatch dup-mdm '^ERROR\|') -and (SameSummary dup))
    $dupRules = Join-Path $tmpRoot "dup-mdm/.aitools/rules"
    $dupNames = if (Test-Path -LiteralPath $dupRules -PathType Container) { @(Get-ChildItem -LiteralPath $dupRules -Name) } else { @() }
    Check "dotprofile rule named like a shared rule: shared copy deployed in MDM, same trees" ((SameBytes $P1 (Join-Path $dupRules "scratch.md")) -and -not ($dupNames -ccontains 'Scratch.md') -and (SameTrees dup))

    # ---------------------------------------------------------------------------
    # Build from a non-git dotprofile (pre-push step 7 builds into a git-archive copy)
    # ---------------------------------------------------------------------------
    Move-Item -LiteralPath (Join-Path $DOT ".git") -Destination (Join-Path $tmpRoot "dot.git") -Force
    $script:BUILD = "b3"
    try {
        Build-Deploy b3
    } finally {
        Move-Item -LiteralPath (Join-Path $tmpRoot "dot.git") -Destination (Join-Path $DOT ".git") -Force
    }
    # The dotprofile holds no harness source (shared/ only since 2026-11-06), so the
    # snapshot never lists it and its git state cannot change the payload.
    Check "non-git dotprofile: build exit 0, no dotprofile directory snapshotted" ($script:RC["build-b3"] -eq 0 -and -not (GrepQ (Join-Path $tmpRoot "build-b3.out") 'not in a git work tree -- embedding every file on disk'))
    Check "non-git dotprofile: generated deploy-harness identical to the git build" ((SameBytes (Join-Path $tmpRoot "b2/deploy/deploy-harness.sh") (Join-Path $tmpRoot "b3/deploy/deploy-harness.sh")) -and (SameBytes (Join-Path $tmpRoot "b2/deploy/deploy-harness.ps1") (Join-Path $tmpRoot "b3/deploy/deploy-harness.ps1")) -and (SameBytes (Join-Path $tmpRoot "b2/deploy/deploy-harness.payload") (Join-Path $tmpRoot "b3/deploy/deploy-harness.payload")))

    # ---------------------------------------------------------------------------
    # Markers (HARNESS Q6): a missing or duplicated marker fails the build, and the
    # dotprofile deploy/ is left as it was (the build is staged)
    # ---------------------------------------------------------------------------
    # A copy of the sources build-deploy reads (not a git checkout: the snapshot
    # lists files on disk, as for pre-push step 7's copy).
    $RCopy = Join-Path $tmpRoot "repo-copy"
    MakeDir (Join-Path $RCopy ".claude")
    foreach ($d in @("scripts", "shared", "reference", "registries")) {
        Copy-Item -LiteralPath (Join-Path $root $d) -Destination (Join-Path $RCopy $d) -Recurse -Force
    }
    if (Test-Path -LiteralPath (Join-Path $root ".claude/hooks") -PathType Container) {
        Copy-Item -LiteralPath (Join-Path $root ".claude/hooks") -Destination (Join-Path $RCopy ".claude/hooks") -Recurse -Force
    }
    Copy-Item -LiteralPath (Join-Path $DOT "deploy/deploy-harness.sh") -Destination (Join-Path $tmpRoot "deploy-before.sh")
    # Marker-Build NAME REGEX REPLACEMENT FILE -- edit FILE in the copy (perl -pe
    # s///, multi-line anchors), build, restore it
    function Marker-Build([string]$Name, [string]$Pattern, [string]$Replacement, [string]$File) {
        $hb = Join-Path $tmpRoot "home-build-$Name"
        $src = Join-Path $RCopy "scripts/$File"
        $orig = Join-Path $tmpRoot "$File.orig"
        Copy-Item -LiteralPath $src -Destination $orig -Force
        try {
            WriteBytesText $src ([regex]::Replace((ReadBytesText $src), $Pattern, $Replacement))
            Write-Config $hb "posix"
            $script:OUT = Join-Path $tmpRoot "build-$Name.out"
            $script:RC["build-$Name"] = Run-Build $hb $DOT (Join-Path $RCopy "scripts/build-deploy.sh")
        } finally {
            Copy-Item -LiteralPath $orig -Destination $src -Force
        }
    }
    Marker-Build nomark '(?m)^# --- END source setup .*\n' '' deploy-harness.sh
    Check "markers: a missing END marker fails the build (.sh source)" ($script:RC["build-nomark"] -ne 0 -and (GrepQ (Join-Path $tmpRoot "build-nomark.out") 'END source setup.*matches 0 lines'))
    Marker-Build dupmark '(?m)^(# --- BEGIN scope .*)$' "`$1`n`$1" deploy-harness.ps1
    Check "markers: a duplicated BEGIN marker fails the build (.ps1 source)" ($script:RC["build-dupmark"] -ne 0 -and (GrepQ (Join-Path $tmpRoot "build-dupmark.out") 'BEGIN scope.*matches 2 lines'))
    Check "markers: failed builds left the dotprofile deploy/ as it was" ((SameBytes (Join-Path $tmpRoot "deploy-before.sh") (Join-Path $DOT "deploy/deploy-harness.sh")) -and (Test-Path -LiteralPath (Join-Path $DOT "deploy/deploy-harness.payload") -PathType Leaf))
} finally {
    if ($env:KEEP_TMP -eq "1") { Write-Output "kept: $tmpRoot" } else { Remove-TestTempRoot $tmpRoot }
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: {3} scripts)" -f $script:pass, $script:fail, $script:skip, $lang)
if ($script:fail -ne 0) { exit 1 }
exit 0
