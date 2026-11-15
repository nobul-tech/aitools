# test-skills-fanout.ps1 -- tests for the skills fan-out (lib Invoke-HarnessSkillsFanout)
# as scripts/setup-user-claude.ps1 runs it: ~/.aitools/skills -> ~/.claude/skills.
# Every skill directory is fanned out except the ones the skills manifest retires;
# every file under it (nested too), *.bak.* names and hidden entries skipped; a
# directory in ~/.claude/skills the fan-out did not deploy (a third-party skill) is
# preserved; the copy of a retired skill removed only when it holds the harness
# copy's files, after a backup beside ~/.claude/skills; adopt target from the
# manifest source. One case fills ~/.aitools/skills with the real
# scripts/deploy-harness.ps1 (FO-2 manifest) from this checkout. Cursor cases
# (FO-5): scripts/setup-user-cursor.ps1 step 5 fans out to ~/.cursor/skills with
# no adopt target (stub rg/agent .cmd files on PATH).
# The Windows harness of this suite; tests/skills-fanout/test-skills-fanout.sh is
# the macOS/Linux harness of the same cases for the .sh scripts.
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs the .ps1 scripts with native pwsh on Windows only. Parity
# with the .sh scripts is checked against the committed golden records in
# tests/skills-fanout/golden/ (Test-GoldenMatch in tests/lib/platform-lib.ps1),
# which the .sh harness writes and checks on macOS/Linux. Cases Windows cannot
# build (symlinks; chmod 000 reads; case-only duplicates on a case-insensitive
# file system) are SKIP, with the reason, as in the former Git Bash run.
#
# Safe to re-run: every case runs a copy of scripts/ in a temp aitools checkout,
# in a child pwsh under its own temp HOME, with a temp git dotprofile (all
# removed on exit); the real HOME, ~/.aitools and dotprofile are never touched.
# Needs git; python3 with pywinpty for the pty cases. Exit 1 if any case fails.
# Spec: plans/skills-and-rules-fanout.md 3.4.
#
# Usage: pwsh -NoProfile -File tests/skills-fanout/test-skills-fanout.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 30 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/skills-fanout/test-skills-fanout.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$ptyScript = Join-Path $root "tests/managed-files/pty-run.py"
$L = "ps"   # tag of the language under test (check names, HOME $C\ps, output $C\ps.out)
$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:C = ""
$script:H = ""

function Strip([string]$Text) { ($Text -replace "`e\[[0-9;]*m", "") -replace "`r", "" }
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if ($script:C) {
        $out = Join-Path $script:C "$L.out"
        if (Test-Path -LiteralPath $out -PathType Leaf) {
            @((Strip ([IO.File]::ReadAllText($out))) -split "`n") | Select-Object -Last 25 | ForEach-Object { Write-Output "      | $_" }
        }
    }
}
function Skip([string]$Name) { Write-Output "SKIP $Name"; $script:skip++ }

# git is the one tool this harness needs (fixture repos; the adopt checks).
# In CI a missing tool is a broken runner, not a reason to pass.
if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
    # Get-Command exempt: command-existence check; this branch is the fallback
    if ($env:CI) { Write-Output "FAIL git not found (CI=$($env:CI))"; exit 1 }
    Write-Output "SKIP all cases (git not found)"
    exit 0
}

# Pty cases: tests/managed-files/pty-run.py with pywinpty (ConPTY); a failing
# import means pywinpty is not installed.
$python3 = $null
$havePty = $false
$noPtyWhy = "python3 not found"
$py = Get-Command python3 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
# Get-Command exempt: command-existence check; $havePty stays $false without it
if ($py -and (Test-Path -LiteralPath $ptyScript -PathType Leaf)) {
    $python3 = $py.Source
    $havePty = $true
    & $python3 -c "import winpty" *> $null
    if ($LASTEXITCODE -ne 0) { $havePty = $false; $noPtyWhy = "pywinpty not installed (scripts/setup-pywinpty.ps1)" }
}

# Windows has no symlinks the fixtures could rely on (Developer Mode or admin
# only) and no chmod: the symlink and unreadable-file cases stay SKIP, as in the
# former Git Bash run of this suite.
$canSymlink = $false
$canChmodRead = $false

$tmpRoot = New-TestTempRoot "skills-fanout"
$GoldenDir = Join-Path $root "tests/skills-fanout/golden"
$GoldenTmp = $tmpRoot
# The temp root as the logs may print it once backslashes are slashes: native
# (C:/...) and MSYS (/c/...); longest first (lognorm in the .sh)
$tmpForms = @(($tmpRoot -replace '\\', '/'), (ConvertTo-MsysPath $tmpRoot)) | Sort-Object -Property Length -Descending

# --- Paths and files -----------------------------------------------------------
function PJ { [IO.Path]::Combine([string[]]$args) }
# Mixed: the path with forward slashes (cygpath -m, native_path in the .sh): the
# form the .sh handed native pwsh for config.json, logs, summary and git config
function Mixed([string]$Path) { $Path -replace '\\', '/' }
# MsysName: a name as Git Bash stores it on NTFS. Characters Win32 file names
# cannot hold (* ? : < > | ") become U+F000 + the character (probe 2026-11-14:
# a file Git Bash named a*b?.md is a U+F02A b U+F03F .md). The .sh fixture
# '[x]/a*b?.md' therefore was such a file on Windows; this harness builds the same.
function MsysName([string]$Name) {
    $sb = [Text.StringBuilder]::new()
    foreach ($ch in $Name.ToCharArray()) {
        if ('*?:<>|"'.IndexOf($ch) -ge 0) { [void]$sb.Append([char](0xF000 + [int]$ch)) } else { [void]$sb.Append($ch) }
    }
    $sb.ToString()
}
function WriteText([string]$Path, [string]$Text) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path, $Text)   # UTF-8, no BOM, LF as given (printf in the .sh)
}
function WriteBytes([string]$Path, [byte[]]$Bytes) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllBytes($Path, $Bytes)
}
# Bytes "a", 0xED, ... : text parts as ASCII bytes, integers as bytes
function B {
    $list = [Collections.Generic.List[byte]]::new()
    foreach ($a in $args) {
        if ($a -is [string]) { $list.AddRange([Text.Encoding]::ASCII.GetBytes($a)) } else { $list.Add([byte]$a) }
    }
    , $list.ToArray()
}
function IsFile([string]$Path) { Test-Path -LiteralPath $Path -PathType Leaf }
function IsDir([string]$Path) { Test-Path -LiteralPath $Path -PathType Container }
function Exists([string]$Path) { Test-Path -LiteralPath $Path }
# HasLine FILE LINE: grep -qx LINE FILE (Git for Windows grep ignored a CR before
# the newline; so does this)
function HasLine([string]$Path, [string]$Line) {
    if (-not (IsFile $Path)) { return $false }
    $lines = @(([IO.File]::ReadAllText($Path) -split "`n") | ForEach-Object { $_ -replace "`r$", "" })
    return [bool]($lines -ccontains $Line)
}
function SameBytes([string]$A, [string]$B2) {
    if (-not (IsFile $A) -or -not (IsFile $B2)) { return $false }
    $x = [IO.File]::ReadAllBytes($A); $y = [IO.File]::ReadAllBytes($B2)
    return [Linq.Enumerable]::SequenceEqual([byte[]]$x, [byte[]]$y)
}
# IsExecLike FILE: what test -x / perl -x said for FILE in the former Git Bash
# run. NTFS under Git Bash (mount noacl) has no executable bit; Cygwin derives it:
# a name ending in .exe, or content starting with "#!", "MZ" or ":" (probe
# 2026-11-14, Git for Windows perl and test: run.sh with "#!/bin/sh" -> x after
# chmod 644; plain.sh, t.bat, t.cmd, t.com -> not x; t.exe, mz.txt, colon.txt
# -> x). setup-user-*.ps1 sets no mode on Windows (aitools-lib.ps1: "Windows has
# no executable bit"), so this mirrors the old run and the golden " x" marks.
function IsExecLike([string]$Path) {
    if (-not (IsFile $Path)) { return $false }
    if ($Path.EndsWith(".exe", [StringComparison]::OrdinalIgnoreCase)) { return $true }
    $fs = [IO.File]::OpenRead($Path)
    try {
        $buf = [byte[]]::new(2); $n = $fs.Read($buf, 0, 2)
    } finally { $fs.Dispose() }
    if ($n -ge 1 -and $buf[0] -eq 0x3A) { return $true }
    if ($n -eq 2 -and (($buf[0] -eq 0x23 -and $buf[1] -eq 0x21) -or ($buf[0] -eq 0x4D -and $buf[1] -eq 0x5A))) { return $true }
    return $false
}
# LsNames DIR: ls DIR (names not starting with ".", ordinal order), one per
# output object; nothing if DIR is absent
function LsNames([string]$Dir) {
    if (-not (IsDir $Dir)) { return }
    $n = [string[]]@([IO.Directory]::GetFileSystemEntries($Dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { -not $_.StartsWith(".") })
    [Array]::Sort($n, [StringComparer]::Ordinal)
    $n
}
function LsIs([string]$Dir, [string]$Text) { (@(LsNames $Dir) -join "`n") -ceq $Text }
# FindBak DIR: find DIR -name '*.bak.*' printed something
function FindBak([string]$Dir) {
    if (-not (IsDir $Dir)) { return $false }
    foreach ($e in [IO.Directory]::EnumerateFileSystemEntries($Dir, "*", [IO.SearchOption]::AllDirectories)) {
        if ([IO.Path]::GetFileName($e).Contains(".bak.")) { return $true }
    }
    return $false
}

# --- Fixture: temp aitools checkout (adopt targets of shared and aitools skills
# land there, never in this repo), a payload copy without .git, and a git
# dotprofile with no remote (an adopt commits, the push fails) ---
$A = Join-Path $tmpRoot "aitools"
$PAYLOAD = Join-Path $tmpRoot "payload"
$REPO = $A
$DP = Join-Path $tmpRoot "aitools-tess"
$CSTUB = Join-Path $tmpRoot "cursor-stubs"
function Git-Fixture {
    $o = & git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false @args 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed: $o" }
}

try {
    try {
        foreach ($d in @("scripts", "shared/skills/s1", "shared/skills/dup", ".claude/skills/p1", ".claude/skills/dup")) {
            New-Item -ItemType Directory -Path (Join-Path $A $d) -Force | Out-Null
        }
        # Plain copies (no script is patched; each runs with its OS guard on)
        foreach ($f in @("setup-user-claude.sh", "setup-user-claude.ps1", "aitools-lib.sh", "aitools-lib.ps1", "aitools-profile.sh", "aitools-profile.ps1", "aitools-json.pl", "aitools-json.ps1")) {
            Copy-Item -LiteralPath (Join-Path $root "scripts/$f") -Destination (Join-Path $A "scripts/$f")
        }
        Copy-Item -LiteralPath (Join-Path $root "shared/claude-shared.md") -Destination (Join-Path $A "shared/claude-shared.md")
        WriteText (Join-Path $A "shared/skills/s1/SKILL.md") "## shared s1`n"
        WriteText (Join-Path $A ".claude/skills/p1/SKILL.md") "## project p1`n"
        WriteText (Join-Path $A "shared/skills/dup/SKILL.md") "## dup shared`n"
        WriteText (Join-Path $A ".claude/skills/dup/SKILL.md") "## dup project`n"
        New-Item -ItemType Directory -Path $PAYLOAD | Out-Null
        foreach ($d in @("scripts", "shared", ".claude")) { Copy-Item -LiteralPath (Join-Path $A $d) -Destination (Join-Path $PAYLOAD $d) -Recurse }
        Git-Fixture -C $A init -q
        WriteText (Join-Path $DP "claude/CLAUDE.md") "# Prefs for {{PROFILE_NAME}}`n`n## Code Style`n`n- keep it simple`n"
        WriteText (Join-Path $DP "profile.json") "{`"version`":2,`"identity`":{`"git`":{`"name`":`"Tess`",`"email`":`"t@example.com`"}},`"profiles`":{`"m1`":{`"name`":`"Tess`",`"company`":`"`"}}}`n"
        WriteText (Join-Path $DP "claude/skills/d1/SKILL.md") "## dot d1`n"
        Git-Fixture -C $DP init -q
        Git-Fixture -C $DP add -A
        Git-Fixture -C $DP commit -q -m fixture
    } catch {
        # A broken fixture fails the suite (die in the .sh); finally removes the temp root
        Write-Output "FAIL fixture setup: the temp aitools checkout or fixture dotprofile could not be created ($($_.Exception.Message))"
        exit 1
    }

    $probe = Join-Path $tmpRoot "cs-probe"
    WriteText $probe ""
    $caseSensitiveFs = -not (Test-Path -LiteralPath (Join-Path $tmpRoot "CS-PROBE"))

    # --- Case helpers ---------------------------------------------------------------
    # $script:H: the HOME of the case being seeded; $script:C: the case directory
    function hskill([string]$Name, [string]$Rel, [string]$Text) {   # ~/.aitools/skills/NAME/REL
        WriteText (PJ $script:H ".aitools" "skills" (MsysName $Name) (MsysName $Rel)) "$Text`n"
    }
    function dskill([string]$Name, [string]$Rel, [string]$Text) {   # ~/.claude/skills/NAME/REL (already deployed)
        WriteText (PJ $script:H ".claude" "skills" (MsysName $Name) (MsysName $Rel)) "$Text`n"
    }
    function cskill([string]$Name, [string]$Rel, [string]$Text) {   # ~/.cursor/skills/NAME/REL (already there)
        WriteText (PJ $script:H ".cursor" "skills" $Name $Rel) "$Text`n"
    }
    # manifest LINE...: ~/.aitools/skills/.aitools-skills-manifest (v1); "|" stands for the TAB
    function manifest {
        $t = "# aitools skills manifest v1`n"
        foreach ($l in $args) { $t += ($l -replace '\|', "`t") + "`n" }
        WriteText (PJ $script:H ".aitools" "skills" ".aitools-skills-manifest") $t
    }

    # Run-Env HOME SUMMARY: the environment of a run under HOME (the .sh's run_env:
    # HOME and USERPROFILE in Windows form, as Windows sets USERPROFILE -- the lib
    # shows a path under it as ~/...; logs, summary and git config in the mixed
    # form the .sh passed; the aitools override variables removed)
    function Run-Env([string]$HomeDir, [string]$Summary) {
        @{
            AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null; AITOOLS_USER_REPO_PATH = $null
            AITOOLS_PROFILE_FILE = $null; AITOOLS_PROFILE_SH = $null; AITOOLS_PROFILE_PS1 = $null
            HOME = $HomeDir; USERPROFILE = $HomeDir
            AITOOLS_LOG_DIR = (Mixed (Join-Path $HomeDir "logs")); AITOOLS_SUMMARY_FILE = (Mixed $Summary)
            GIT_CONFIG_GLOBAL = (Mixed (Join-Path $HomeDir ".gitconfig")); GIT_CONFIG_NOSYSTEM = "1"
        }
    }
    function Run-Child([string]$Script, [string]$Flag, [hashtable]$Envs) {
        [IO.File]::WriteAllText((Join-Path $script:C "$L.summary"), "")
        $argv = @("-NoProfile", "-NonInteractive", "-File", $Script)
        if ($Flag) { $argv += $Flag }
        $rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $Envs -OutFile (Join-Path $script:C "$L.out")
        [IO.File]::WriteAllText((Join-Path $script:C "$L.rc"), "$rc`n")
    }
    # Run-One [FLAG]: setup-user-claude.ps1 non-interactive under $C\ps
    function Run-One([string]$Flag = "") {
        $envs = Run-Env $script:H (Join-Path $script:C "$L.summary")
        Run-Child (PJ $REPO "scripts" "setup-user-claude.ps1") $Flag $envs
    }
    # Run-Pty INPUT: the same on a pty (review menu), keystrokes INPUT; the
    # terminal text goes to $C\ps.out (pty-run.py --log), the runner's own
    # output to $C\ps.pty
    function Run-Pty([string]$Keys) {
        $envs = Run-Env $script:H (Join-Path $script:C "$L.summary")
        [IO.File]::WriteAllText((Join-Path $script:C "$L.summary"), "")
        $argv = @($ptyScript, "--input", $Keys, "--log", (Join-Path $script:C "$L.out"), "--",
            $pwshExe, "-NoProfile", "-File", (PJ $REPO "scripts" "setup-user-claude.ps1"))
        $rc = Invoke-TestScript -FilePath $python3 -ArgumentList $argv -Environment $envs -OutFile (Join-Path $script:C "$L.pty")
        [IO.File]::WriteAllText((Join-Path $script:C "$L.rc"), "$rc`n")
    }
    # Seed-Home H: config.json -> the fixture dotprofile (mixed path), a git identity
    function Seed-Home([string]$HomeDir) {
        WriteText (PJ $HomeDir ".aitools" "config.json") ("{`"userRepoPath`":`"" + (Mixed $DP) + "`",`"machineAlias`":`"m1`"}`n")
        WriteText (Join-Path $HomeDir ".gitconfig") "[user]`n`tname = Test`n`temail = test@example.invalid`n[commit]`n`tgpgsign = false`n"
    }
    # Case-Run NAME SEED [FLAG]: a fresh HOME $C\ps seeded by SEED, then one run
    function Case-Run([string]$Name, [scriptblock]$Seed, [string]$Flag = "") {
        $script:C = Join-Path $tmpRoot $Name
        New-Item -ItemType Directory -Path $script:C -Force | Out-Null
        $script:H = Join-Path $script:C $L
        Seed-Home $script:H
        & $Seed
        Run-One $Flag
    }

    function Rc { (ReadText (Join-Path $script:C "$L.rc")).Trim() }
    function OutText { Strip (ReadText (Join-Path $script:C "$L.out")) }
    function OutHas([string]$Text) { (OutText).Contains($Text) }                    # grep -qF (one line)
    function OutMatch([string]$Re) { [regex]::IsMatch((OutText), $Re, "Multiline") }  # grep -q, one line
    function SummaryLines { @((Strip (ReadText (Join-Path $script:C "$L.summary"))) -split "`n" | Where-Object { $_ -ne "" }) }
    function Row([string]$Row) { [bool](@(SummaryLines) -ccontains $Row) }           # exact summary row
    function SummaryHas([string]$Text) { [bool](@(SummaryLines) | Where-Object { $_.Contains($Text) }) }
    function NonDetail([string]$Tool = "claude skills") {
        $l = @(SummaryLines | Where-Object { $_.Contains("|$Tool|") -and -not $_.StartsWith("DETAIL") })
        if ($l.Count) { $l[-1] } else { "" }
    }
    function S { PJ $script:C $L ".claude" "skills" }      # the deployed skills dir
    function CS { PJ $script:C $L ".cursor" "skills" }     # the deployed cursor skills dir
    # LogNorm: the run's *.log files, CR removed, every backslash a slash, the temp
    # root (native or MSYS form, any case) as <TMP> (lognorm in the .sh)
    function LogNorm {
        $d = PJ $script:C $L "logs"
        if (-not (IsDir $d)) { return "" }
        $files = [string[]]@([IO.Directory]::GetFiles($d) | Where-Object { $n = [IO.Path]::GetFileName($_); $n.EndsWith(".log", [StringComparison]::Ordinal) -and -not $n.StartsWith(".") })
        [Array]::Sort($files, [StringComparer]::Ordinal)
        $all = [Text.StringBuilder]::new()
        foreach ($f in $files) {
            $t = ([IO.File]::ReadAllText($f) -replace "`r", "").Replace('\', '/')
            foreach ($form in $tmpForms) { $t = [regex]::Replace($t, [regex]::Escape($form), '<TMP>', "IgnoreCase") }
            [void]$all.Append($t)
        }
        $all.ToString()
    }
    function Logged([string]$Text) { (LogNorm).Contains($Text) }
    function LoggedRe([string]$Re) { [regex]::IsMatch((LogNorm), $Re, "Multiline") }
    # BakNames: the entries beside ~/.claude/skills (or ~/.cursor/skills) named skills.bak.*
    function BakNames([string]$Parent = ".claude") {
        # LsNames already gives ordinal order
        @(LsNames (PJ $script:C $L $Parent)) | Where-Object { $_ -cmatch '^skills\.bak\.' }
    }
    function BakDirs { @(BakNames).Count }
    function NewestBak([string]$Parent = ".claude") { $n = @(BakNames $Parent); if ($n.Count) { PJ $script:C $L $Parent $n[-1] } else { "" } }

    # TreeSig DIR: "<path> <md5> [x]" per file (x: IsExecLike); a backup file is
    # "<path>.bak.TS (backup)", listed once; reparse points neither listed nor
    # followed; names as Git Bash showed them (U+F0xx back to ASCII); ordinal order
    function TreeSig([string]$Dir) {
        if (-not (IsDir $Dir)) { return "" }
        $out = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $stack = [Collections.Generic.Stack[string]]::new(); $stack.Push($Dir)
        while ($stack.Count) {
            $cur = $stack.Pop()
            foreach ($e in [IO.Directory]::GetFileSystemEntries($cur)) {
                $attr = [IO.File]::GetAttributes($e)
                if ($attr -band [IO.FileAttributes]::ReparsePoint) { continue }
                if ($attr -band [IO.FileAttributes]::Directory) { $stack.Push($e); continue }
                $rel = $e.Substring($Dir.Length + 1).Replace('\', '/')
                $rel = [regex]::Replace($rel, '[\uF001-\uF07F]', { param($m) [string][char]([int][char]$m.Value - 0xF000) })
                if ($rel -cmatch '\.bak\.[0-9TZ-]+\z') {
                    [void]$out.Add(($rel -creplace '\.bak\.[0-9TZ-]+\z', '.bak.TS') + " (backup)"); continue
                }
                $md5 = [Convert]::ToHexString([Security.Cryptography.MD5]::HashData([IO.File]::ReadAllBytes($e))).ToLowerInvariant()
                [void]$out.Add("$rel $md5" + $(if (IsExecLike $e) { " x" } else { "" }))
            }
        }
        $lines = [string[]]@($out)
        [Array]::Sort($lines, [StringComparer]::Ordinal)
        ($lines | ForEach-Object { "$_`n" }) -join ""
    }
    # Rows TOOL: ACTION rows and TOOL rows of the summary, ordinal order (LC_ALL=C sort)
    function Rows([string]$Tool) {
        $re = '^(ACTION\||[A-Z]+\|' + [regex]::Escape($Tool) + '\|)'
        $r = [string[]]@(SummaryLines | Where-Object { $_ -cmatch $re })
        [Array]::Sort($r, [StringComparer]::Ordinal)
        ($r | ForEach-Object { "$_`n" }) -join ""
    }
    # Golden-Record NAME DIR TOOL: the exit code, the tree of DIR and the summary
    # rows, HOME as "HOME", must equal golden/NAME.txt
    function Golden-Record([string]$Name, [string]$Dir, [string]$Tool) {
        $f = Join-Path $script:C "golden-$Name.txt"
        $t = "# exit code`n" + (ReadText (Join-Path $script:C "$L.rc")) +
            "# skills tree (path md5 [x]; symlinks not listed)`n" + (TreeSig $Dir) +
            "# summary rows (ACTION and skills, sorted)`n" + (Rows $Tool)
        foreach ($h in @((Mixed $script:H), ($script:H -replace '/', '\'))) { $t = $t.Replace($h, "HOME") }
        [IO.File]::WriteAllText($f, $t)
        Check "golden ${L}: ${Name}: exit code, tree, summary rows" (Test-GoldenMatch "$Name.txt" $f)
    }
    function Parity([string]$Name) { Golden-Record $Name (S) "claude skills" }
    function CParity([string]$Name) { Golden-Record $Name (CS) "cursor skills" }
    $DPN = '<TMP>/aitools-tess'   # the fixture dotprofile as LogNorm prints it

    # -----------------------------------------------------------------------------
    # No harness skills: nothing deployed, ~/.claude/skills untouched, exit 0
    # -----------------------------------------------------------------------------
    $seedMissing = { dskill mine SKILL.md 'mine' }
    Case-Run missing $seedMissing
    # No row: setup-user-skills (the fallback) owns the claude skills rows then (PR #125 N2)
    Check "missing: exit 0, no claude skills row, logged" ((Rc) -eq "0" -and -not (SummaryHas '|claude skills|') -and (OutMatch 'No harness skills at .*setup-user-skills deploys skills'))
    Check "missing: ~/.claude/skills untouched, no backup" ((HasLine (PJ (S) mine SKILL.md) mine) -and (LsIs (S) "mine") -and (BakDirs) -eq 0)
    Check "missing: the dotprofile's claude/skills is not deployed" (-not (Exists (PJ (S) d1)))
    Parity missing

    $seedEmpty = { New-Item -ItemType Directory -Path (PJ $script:H ".aitools" "skills") -Force | Out-Null }
    Case-Run empty $seedEmpty
    Check "empty: row n/a (no harness skills)" ((Rc) -eq "0" -and (NonDetail) -ceq 'OK|claude skills|n/a (no harness skills)')
    Parity empty

    # -----------------------------------------------------------------------------
    # Fan-out: every source, nested files, filters, executable bit, preserved
    # (third-party directory), rerun, edit, -Force
    # -----------------------------------------------------------------------------
    $seedFanout = {
        manifest 'd1|dotprofile' 'dup|shared' 'p1|aitools' 's1|shared'
        hskill s1 SKILL.md '## shared s1'
        hskill s1 tests/expected-behaviors.md 'nested'
        hskill s1 scripts/run.sh '#!/bin/sh'   # chmod 755 in the .sh: no mode on Windows
        hskill s1 SKILL.md.bak.2026-10-22T010203Z 'old s1'
        hskill s1 tests/X.BAK.1 'upper-case backup'
        hskill p1 SKILL.md '## project p1'
        hskill d1 SKILL.md '## dot d1'
        hskill dup SKILL.md '## dup shared'
        hskill old.bak.2026-10-25T000000Z SKILL.md 'a deploy-harness backup'
        hskill .hidden SKILL.md 'hidden'
        WriteText (PJ $script:H ".aitools" "skills" "notes.txt") "not a skill`n"
        dskill mine SKILL.md 'mine'
        # the firecrawl symlink of the .sh needs symlinks ($canSymlink)
    }
    Case-Run fanout $seedFanout
    Check "fanout: exit 0, row 6 added" ((Rc) -eq "0" -and (NonDetail) -ceq 'OK|claude skills|6 added')
    Check "fanout: shared, aitools, dotprofile skills deployed" ((HasLine (PJ (S) s1 SKILL.md) '## shared s1') -and (HasLine (PJ (S) p1 SKILL.md) '## project p1') -and (HasLine (PJ (S) d1 SKILL.md) '## dot d1') -and (HasLine (PJ (S) dup SKILL.md) '## dup shared'))
    Check "fanout: nested files deployed" ((HasLine (PJ (S) s1 tests expected-behaviors.md) nested) -and (IsFile (PJ (S) s1 scripts run.sh)))
    Check "fanout: executable bit copied" ((IsExecLike (PJ (S) s1 scripts run.sh)) -and -not (IsExecLike (PJ (S) s1 SKILL.md)))
    Check "fanout: *.bak.* (any case), hidden, backup dirs and top-level files skipped" (-not (Exists (PJ (S) s1 SKILL.md.bak.2026-10-22T010203Z)) -and -not (Exists (PJ (S) s1 tests X.BAK.1)) -and -not (Exists (PJ (S) old.bak.2026-10-25T000000Z)) -and -not (Exists (PJ (S) .hidden)) -and -not (Exists (PJ (S) notes.txt)))
    Check "fanout: top-level file logged, manifest silent" ((OutMatch 'Ignoring non-skill file in harness skills: notes.txt') -and -not (OutHas 'aitools-skills-manifest'))
    Check "fanout: third-party skill preserved" ((HasLine (PJ (S) mine SKILL.md) mine) -and (OutHas 'Preserved unmanaged skill: mine'))
    if ($canSymlink) { throw "symlink cases are not built on Windows" } else { Skip "fanout: firecrawl symlink preserved (no symlinks on Windows)" }
    Check "fanout: one item per file in DETAIL rows" ((Row 'DETAIL|claude skills|added: s1/SKILL.md') -and (Row 'DETAIL|claude skills|added: s1/scripts/run.sh') -and (Row 'DETAIL|claude skills|added: s1/tests/expected-behaviors.md'))
    Check "adopt map ${L}: shared -> aitools shared/skills" ((Logged 'claude skills: s1/SKILL.md source=shared adopt=') -and (Logged '/shared/skills/s1/SKILL.md'))
    Check "adopt map ${L}: aitools -> aitools .claude/skills" ((Logged 'claude skills: p1/SKILL.md source=aitools adopt=') -and (Logged '/.claude/skills/p1/SKILL.md'))
    Check "adopt map ${L}: dotprofile -> dotprofile claude/skills" (Logged "claude skills: d1/SKILL.md source=dotprofile adopt=$DPN/claude/skills/d1/SKILL.md")
    Check "adopt map ${L}: same name in shared and .claude, manifest shared -> shared" (LoggedRe 'claude skills: dup/SKILL\.md source=shared adopt=.*/aitools/shared/skills/dup/SKILL\.md$')
    Check "adopt map ${L}: no repo file -> none" (Logged 'claude skills: s1/tests/expected-behaviors.md source=shared adopt=none')
    Parity fanout
    Run-One
    Check "fanout rerun: row 6 verified, nothing written" ((NonDetail) -ceq 'OK|claude skills|6 verified' -and -not (FindBak (S)) -and (BakDirs) -eq 0)
    Parity fanout-rerun
    WriteText (PJ (S) s1 SKILL.md) "## shared s1`nlocal edit`n"
    Run-One
    Check "fanout edited, non-interactive: overwritten, backup kept, WARN row" ((NonDetail) -ceq 'WARN|claude skills|1 updated, 5 verified' -and (HasLine (PJ (S) s1 SKILL.md) '## shared s1') -and [bool](@(LsNames (PJ (S) s1)) -cmatch '^SKILL\.md\.bak\.'))
    Parity fanout-edited
    WriteText (PJ (S) s1 SKILL.md) "## shared s1`nlocal edit 2`n"
    Run-One "-Force"
    Check "fanout --force: overwritten" ((Rc) -eq "0" -and (HasLine (PJ (S) s1 SKILL.md) '## shared s1') -and (NonDetail) -ceq 'WARN|claude skills|1 updated, 5 verified')
    Parity fanout-force
    # The .sh clears the bit (chmod 644) first; Windows has no mode to clear, and
    # under Git Bash the chmod did not change test -x either (IsExecLike)
    Run-One
    Check "fanout: executable bit restored on a verified file" ((IsExecLike (PJ (S) s1 scripts run.sh)) -and (NonDetail) -ceq 'OK|claude skills|6 verified')
    Parity fanout-xbit

    Case-Run fanout-dry $seedFanout "-DryRun"
    Check "fanout dry run: nothing written, row dry run" ((Rc) -eq "0" -and (NonDetail) -ceq 'OK|claude skills|dry run (no files written)' -and -not (Exists (PJ (S) s1)) -and (OutMatch 'DRY RUN\] Would create: s1/SKILL.md'))
    Parity fanout-dry

    # A skill name in DEST that is a symlink or a file: needs a symlink
    Skip "kept symlink (no symlinks)"

    # -----------------------------------------------------------------------------
    # Retired skills: pruned only when the copy holds the harness copy's files
    # -----------------------------------------------------------------------------
    $seedRetired = {
        manifest '[r]|retired' 'a|shared' 'gone|retired' 'mine2|retired' 'old|retired'
        hskill a SKILL.md 'skill a'
        hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'          # deploy-harness retired it (backup, removed)
        hskill gone.bak.2026-10-25T000000Z tests/x.md 'gx'
        hskill old SKILL.md 'old'                                   # retired, but still in ~/.aitools/skills
        hskill '[r].bak.2026-10-25T000000Z' SKILL.md 'r'
        dskill gone SKILL.md 'gone'; dskill gone tests/x.md 'gx'; dskill gone SKILL.md.bak.2026-01-01T000000Z 'an old backup'
        dskill gone .DS_Store 'finder junk'; dskill gone tests/Thumbs.db 'explorer junk'   # never block the prune
        foreach ($i in 1..6) { dskill "../skills.bak.2026-01-0${i}T000000Z/old$i" SKILL.md "old backup $i" }
        dskill old SKILL.md 'old'
        dskill mine2 SKILL.md 'my own'
        dskill '[r]' SKILL.md 'r'
    }
    Case-Run retired $seedRetired
    Check "retired: exit 0, row 1 added, 3 removed (WARN: a kept dir still loads)" ((Rc) -eq "0" -and (NonDetail) -ceq 'WARN|claude skills|1 added, 3 removed')
    Check "retired: copies removed from ~/.claude/skills" (-not (Exists (PJ (S) gone)) -and -not (Exists (PJ (S) old)) -and -not (Exists (PJ (S) '[r]')))
    $b = NewestBak
    Check "retired: OS junk files did not block the prune; the backup keeps them" ($b -and (IsFile (PJ $b gone .DS_Store)) -and (IsFile (PJ $b gone tests Thumbs.db)))
    Check "retired: the newest backup dir beside ~/.claude/skills holds them" ($b -and (HasLine (PJ $b gone SKILL.md) gone) -and (HasLine (PJ $b gone tests x.md) gx) -and (HasLine (PJ $b old SKILL.md) old) -and (HasLine (PJ $b '[r]' SKILL.md) r))
    Check "retired: backups beside ~/.claude/skills pruned to the newest 5" ((BakDirs) -eq 5 -and -not (Exists (PJ $script:C $L .claude skills.bak.2026-01-01T000000Z)) -and -not (Exists (PJ $script:C $L .claude skills.bak.2026-01-02T000000Z)) -and (IsDir (PJ $script:C $L .claude skills.bak.2026-01-03T000000Z)) -and (OutHas 'Pruned old backup'))
    Check "retired: removals in DETAIL rows" ((Row 'DETAIL|claude skills|removed: gone') -and (Row 'DETAIL|claude skills|removed: old') -and (Row 'DETAIL|claude skills|removed: [r]'))
    Check "retired: a retired skill still in ~/.aitools/skills is not fanned out" ((OutHas 'Not fanned out: old (retired in the skills manifest)') -and -not (Row 'DETAIL|claude skills|added: old/SKILL.md'))
    Check "retired: user dir with a retired name kept, ACTION row" ((HasLine (PJ (S) mine2 SKILL.md) 'my own') -and (Row 'ACTION||Claude Code still loads retired skills in ~/.claude/skills: mine2 -- delete them unless you wrote them'))
    Parity retired
    Case-Run retired-dry $seedRetired "-DryRun"
    Check "retired dry run: nothing removed, row dry run, removal previewed" ((Rc) -eq "0" -and (NonDetail) -ceq 'WARN|claude skills|dry run (no files written)' -and (IsDir (PJ (S) gone)) -and (IsDir (PJ (S) old)) -and -not (Exists (PJ (S) a)) -and (BakDirs) -eq 6 -and (OutHas 'DRY RUN] Would back up and remove gone'))
    Parity retired-dry

    # A retired name whose copy differs only in case (Gone for gone)
    $seedRetiredCase = {
        manifest 'a|shared' 'gone|retired'
        hskill a SKILL.md 'skill a'
        hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'
        dskill Gone SKILL.md 'gone'
    }
    Case-Run retired-case $seedRetiredCase
    Check "retired, case differs: found and removed under its own name" ((Rc) -eq "0" -and (NonDetail) -ceq 'OK|claude skills|1 added, 1 removed' -and -not (Exists (PJ (S) Gone)) -and (Row 'DETAIL|claude skills|removed: Gone'))
    Parity retired-case

    # A retired copy with one file changed by the user: kept
    $seedRetiredMod = {
        manifest 'a|shared' 'gone|retired'
        hskill a SKILL.md 'skill a'
        hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'
        dskill gone SKILL.md 'gone, edited by me'
    }
    Case-Run retired-mod $seedRetiredMod
    Check "retired, user-modified: kept, ACTION row" ((Rc) -eq "0" -and (NonDetail) -ceq 'WARN|claude skills|1 added' -and (HasLine (PJ (S) gone SKILL.md) 'gone, edited by me') -and (Row 'ACTION||Claude Code still loads retired skills in ~/.claude/skills: gone -- delete them unless you wrote them'))
    Check "retired, user-modified: not counted again as preserved" (-not (OutHas 'Preserved unmanaged skill: gone') -and (OutHas 'Skills (claude skills): 1 added, 0 preserved'))
    Parity retired-mod

    # A retired copy that cannot be removed (read-only subdirectory) and a DEST that
    # cannot be listed: built with chmod in the .sh
    if ($canChmodRead) { throw "chmod cases are not built on Windows" } else { Skip "retired removal failure and unlisted DEST (no chmod on Windows)" }

    # -----------------------------------------------------------------------------
    # Manifest absent, bad header, invalid lines, unreadable
    # -----------------------------------------------------------------------------
    $seedNoManifest = { hskill a SKILL.md 'skill a'; hskill b SKILL.md 'skill b' }
    Case-Run nomanifest $seedNoManifest
    Check "no manifest: everything fanned out, adopt not offered" ((Rc) -eq "0" -and (NonDetail) -ceq 'OK|claude skills|2 added' -and (OutHas 'No skills manifest') -and (Logged 'claude skills: a/SKILL.md source=unknown adopt=none'))
    Parity nomanifest

    $seedBadHeader = {
        WriteText (PJ $script:H ".aitools" "skills" ".aitools-skills-manifest") "# aitools skills manifest v2`nx`tretired`n"
        hskill a SKILL.md 'skill a'; hskill x.bak.2026-10-25T000000Z SKILL.md 'x'; dskill x SKILL.md 'x'
    }
    Case-Run badheader $seedBadHeader
    Check "bad header: fanned out, nothing retired, WARN + ACTION" ((Rc) -eq "0" -and (NonDetail) -ceq 'WARN|claude skills|1 added' -and (IsDir (PJ (S) x)) -and (Row 'ACTION||Run aitools to rebuild ~/.aitools/skills and its manifest'))
    Parity badheader

    $seedInvalid = { manifest '.dot|shared' 'a|unknown' 'b|shared'; hskill a SKILL.md 'skill a'; hskill b SKILL.md 'skill b' }
    Case-Run invalid $seedInvalid
    Check "invalid lines: warned, skills still fanned out" ((Rc) -eq "0" -and (NonDetail) -ceq 'WARN|claude skills|2 added' -and (OutHas 'line ignored: .dot<TAB>shared') -and (Logged 'claude skills: a/SKILL.md source=unknown adopt=none'))
    Parity invalid

    if ($canChmodRead) { throw "chmod cases are not built on Windows" } else { Skip "unreadable harness dir and manifest (no chmod on Windows)" }

    # -----------------------------------------------------------------------------
    # Adopt (pty) and abort (pty); package payload (no .git)
    # -----------------------------------------------------------------------------
    if ($havePty) {
        $script:C = Join-Path $tmpRoot "fanout"
        $script:H = Join-Path $script:C $L
        WriteText (PJ (S) d1 SKILL.md) "## dot d1`nmy edit $L`n"
        WriteText (PJ (S) p1 SKILL.md) "## project p1`nmy edit $L`n"
        Run-Pty 'a\na\n'
        $lastFiles = @((& git -C $DP log -1 --name-only --format= 2>&1 | Out-String) -split "`n" | ForEach-Object { $_ -replace "`r$", "" })
        & git -C $DP diff --quiet -- claude/skills/d1/SKILL.md 2>&1 | Out-Null
        $dpClean = ($LASTEXITCODE -eq 0)
        Check "adopt ${L}: dotprofile skill written to the dotprofile and committed" ((HasLine (PJ $DP claude skills d1 SKILL.md) "my edit $L") -and ($lastFiles -ccontains 'claude/skills/d1/SKILL.md') -and $dpClean)
        Check "adopt ${L}: aitools skill written to the aitools working tree" (HasLine (PJ $A .claude skills p1 SKILL.md) "my edit $L")
        Check "adopt ${L}: DETAIL rows" ((Row 'DETAIL|claude skills|accept & adopt: d1/SKILL.md') -and (Row 'DETAIL|claude skills|accept & adopt: p1/SKILL.md'))
        # abort: exit 2 from the library, no claude skills row, the local file kept
        WriteText (PJ (S) s1 SKILL.md) "## shared s1`nlocal $L`n"
        Run-Pty 'x\n'
        Check "abort ${L}: exit 2, no claude skills row, local file kept" ((Rc) -eq "2" -and -not (NonDetail) -and (HasLine (PJ (S) s1 SKILL.md) "local $L"))
    } elseif ($env:CI) {
        # In CI a missing pty backend is a broken runner, not a reason to pass
        Write-Output "FAIL adopt and abort on a pty ($noPtyWhy; required under CI)"; $script:fail++
    } else {
        Skip "adopt and abort on a pty ($noPtyWhy)"
    }
    WriteText (PJ $A .claude skills p1 SKILL.md) "## project p1`n"

    $seedPayload = {
        manifest 'd1|dotprofile' 'p1|aitools' 's1|shared'
        hskill s1 SKILL.md '## shared s1'; hskill p1 SKILL.md '## project p1'; hskill d1 SKILL.md '## dot d1'
    }
    $REPO = $PAYLOAD
    Case-Run payload $seedPayload
    $REPO = $A
    Check "payload ${L}: no adopt into a checkout without .git" ((Logged 'claude skills: s1/SKILL.md source=shared adopt=none') -and (Logged 'claude skills: p1/SKILL.md source=aitools adopt=none') -and (Logged "claude skills: d1/SKILL.md source=dotprofile adopt=$DPN/claude/skills/d1/SKILL.md"))
    Parity payload

    # -----------------------------------------------------------------------------
    # Names: [ ] in a name, case-only duplicates, dangling symlink; DEST not creatable
    # -----------------------------------------------------------------------------
    # 'a*b?.md': Git Bash stored * and ? as U+F02A and U+F03F (MsysName); so does this
    $seedBracket = { manifest '[x]|shared'; hskill '[x]' SKILL.md 'bracket'; hskill '[x]' 'a*b?.md' 'glob chars' }
    Case-Run bracket $seedBracket
    Check "bracket name: deployed" ((NonDetail) -ceq 'OK|claude skills|2 added' -and (HasLine (PJ (S) '[x]' SKILL.md) bracket) -and (HasLine (PJ (S) '[x]' (MsysName 'a*b?.md')) 'glob chars'))
    Run-One
    Check "bracket name: rerun verified" ((NonDetail) -ceq 'OK|claude skills|2 verified')
    Parity bracket

    # Non-text files (a NUL byte; invalid UTF-8): copied byte for byte, never corrupted
    $seedBinary = {
        manifest 'b|shared'
        hskill b SKILL.md 'skill b'
        WriteBytes (PJ $script:H .aitools skills b img.bin) (B 'PNG' 0 1 2 " bytes`n")
        WriteBytes (PJ $script:H .aitools skills b latin.txt) (B 0xFF 0xFE 'latin1 ' 0xE9 "`n")
    }
    Case-Run binary $seedBinary
    Check "binary: exit 0, row 3 added, bytes identical" ((Rc) -eq "0" -and (NonDetail) -ceq 'OK|claude skills|3 added' -and (SameBytes (PJ $script:C $L .aitools skills b img.bin) (PJ (S) b img.bin)) -and (SameBytes (PJ $script:C $L .aitools skills b latin.txt) (PJ (S) b latin.txt)))
    Parity binary
    Run-One
    Check "binary rerun: row 3 verified" ((NonDetail) -ceq 'OK|claude skills|3 verified')
    WriteBytes (PJ (S) b img.bin) (B 'changed' 0 "`n")
    Run-One
    Check "binary edited: overwritten byte for byte, backup kept" ((NonDetail) -ceq 'OK|claude skills|1 updated, 2 verified' -and (SameBytes (PJ $script:C $L .aitools skills b img.bin) (PJ (S) b img.bin)) -and [bool](@(LsNames (PJ (S) b)) -cmatch '^img\.bin\.bak\.') -and -not [bool](@(LsNames (PJ (S) b)) -cmatch 'aitools-tmp'))
    Parity binary-edited

    # Strict UTF-8 (review R1): each of these is binary in sh and ps; a valid
    # multi-byte file and a noncharacter stay text
    $seedUtf8Edge = {
        manifest 'u|shared'
        hskill u SKILL.md 'skill u'
        $u = PJ $script:H .aitools skills u
        WriteBytes (PJ $u surrogate.txt) (B 'a' 0xED 0xA0 0x80 "b`n")       # ED A0 80: U+D800
        WriteBytes (PJ $u above-max.txt) (B 'a' 0xF4 0x90 0x80 0x80 "b`n")  # F4 90 80 80: > U+10FFFF
        WriteBytes (PJ $u ff.txt) (B 'a' 0xFF "b`n")                        # FF
        WriteBytes (PJ $u overlong.txt) (B 'a' 0xC0 0xAF "b`n")             # C0 AF: overlong "/"
        WriteBytes (PJ $u truncated.txt) (B 'a' 0xE2 0x82 "`n")             # E2 82 then a newline
        WriteBytes (PJ $u valid.txt) (B 'caf' 0xC3 0xA9 ' ' 0xE2 0x82 0xAC "`n")  # valid: e-acute, euro
        WriteBytes (PJ $u nonchar.txt) (B 'a' 0xEF 0xBF 0xBE "b`n")         # EF BF BE: U+FFFE (valid UTF-8)
    }
    Case-Run utf8edge $seedUtf8Edge
    foreach ($f in @("surrogate", "above-max", "ff", "overlong", "truncated")) {
        Check "utf8 strict ${L}: $f.txt copied as binary, bytes identical" ((Logged "Created: u/$f.txt (binary)") -and (SameBytes (PJ $script:C $L .aitools skills u "$f.txt") (PJ $script:C $L .claude skills u "$f.txt")))
    }
    foreach ($f in @("valid", "nonchar")) {
        Check "utf8 strict ${L}: $f.txt is text (review path)" ((Logged "Created: u/$f.txt ->") -and -not (Logged "Created: u/$f.txt (binary)"))
    }
    Parity utf8edge

    # Large valid UTF-8 files stay text in sh as in ps (review NB1)
    $seedUtf8Large = {
        manifest 'w|shared'
        hskill w SKILL.md 'skill w'
        $w = PJ $script:H .aitools skills w
        $eacute = [byte[]]::new(200001); for ($i = 0; $i -lt 200000; $i += 2) { $eacute[$i] = 0xC3; $eacute[$i + 1] = 0xA9 }; $eacute[200000] = 0x0A
        WriteBytes (PJ $w eacute.txt) $eacute                                # 200 KB of e-acute
        $mixed = [byte[]]::new(120001); for ($i = 0; $i -lt 120000; $i += 3) { $mixed[$i] = 0x61; $mixed[$i + 1] = 0xC3; $mixed[$i + 2] = 0xA9 }; $mixed[120000] = 0x0A
        WriteBytes (PJ $w mixed.txt) $mixed                                  # 120 KB, ASCII between
        $badtail = [byte[]]::new(120002); [Array]::Copy($mixed, $badtail, 120000); $badtail[120000] = 0xFF; $badtail[120001] = 0x0A
        WriteBytes (PJ $w badtail.txt) $badtail                              # the same, FF at the end
    }
    Case-Run utf8large $seedUtf8Large
    foreach ($f in @("eacute", "mixed")) {
        Check "utf8 large ${L}: $f.txt is text (review path), bytes identical" ((Logged "Created: w/$f.txt ->") -and -not (Logged "Created: w/$f.txt (binary)") -and (SameBytes (PJ $script:C $L .aitools skills w "$f.txt") (PJ $script:C $L .claude skills w "$f.txt")))
    }
    Check "utf8 large ${L}: badtail.txt (invalid byte after 120 KB) is binary" ((Logged "Created: w/badtail.txt (binary)") -and (SameBytes (PJ $script:C $L .aitools skills w badtail.txt) (PJ $script:C $L .claude skills w badtail.txt)))
    Parity utf8large

    # Names Claude Code owns (synced, anthropic-skills*): never written, never removed
    $seedReserved = {
        manifest 'a|shared' 'anthropic-skills-old|retired'
        hskill a SKILL.md 'skill a'
        hskill synced SKILL.md 'not ours to write'
        hskill Anthropic-Skills-pack SKILL.md 'not ours either'
        hskill anthropic-skills-old.bak.2026-10-25T000000Z SKILL.md 'o'
        dskill synced keep.txt 'theirs'
        dskill anthropic-skills-old SKILL.md 'o'
    }
    Case-Run reserved $seedReserved
    Check "reserved: exit 1, row 2 failed, failed DETAIL rows" ((Rc) -eq "1" -and (NonDetail) -ceq 'ERROR|claude skills|2 failed' -and (Row 'DETAIL|claude skills|failed: synced') -and (Row 'DETAIL|claude skills|failed: Anthropic-Skills-pack'))
    Check "reserved: nothing written into or removed from them" (-not (Exists (PJ (S) synced SKILL.md)) -and (HasLine (PJ (S) synced keep.txt) theirs) -and -not (Exists (PJ (S) Anthropic-Skills-pack)) -and (HasLine (PJ (S) anthropic-skills-old SKILL.md) o) -and (IsFile (PJ (S) a SKILL.md)) -and -not (Row 'DETAIL|claude skills|removed: anthropic-skills-old'))
    Parity reserved

    if ($caseSensitiveFs) {
        $seedDupCase = { hskill a SKILL.md 'lower'; hskill A SKILL.md 'upper' }
        Case-Run dupcase $seedDupCase
        Check "case-only duplicate: the first wins, the second failed" ((Rc) -eq "1" -and (NonDetail) -ceq 'ERROR|claude skills|1 failed')
        # No golden record: only a case-sensitive file system builds this fixture
    } else {
        Skip "case-only duplicate (case-insensitive file system)"
    }

    Skip "dangling symlink (no symlinks)"

    # ~/.claude/skills cannot be created (a file is in the way): ERROR row, exit 1,
    # the script still reaches its exit footer
    $seedNoCreate = { hskill a SKILL.md 'skill a'; WriteText (PJ $script:H .claude skills) "not a dir`n" }
    Case-Run nocreate $seedNoCreate
    Check "cannot create skills dir: ERROR row, exit 1, file untouched" ((Rc) -eq "1" -and (NonDetail) -ceq 'ERROR|claude skills|cannot create skills dir' -and (HasLine (PJ $script:C $L .claude skills) 'not a dir') -and (OutHas 'FAILED with'))
    Parity nocreate
    Case-Run nocreate-dry $seedNoCreate "-DryRun"
    Check "cannot create skills dir, dry run: the same ERROR row as the real run" ((Rc) -eq "1" -and (NonDetail) -ceq 'ERROR|claude skills|cannot create skills dir' -and (HasLine (PJ $script:C $L .claude skills) 'not a dir'))
    Parity nocreate-dry

    # -----------------------------------------------------------------------------
    # The real deploy-harness.ps1 (FO-2) fills ~/.aitools/skills from this
    # checkout's shared/skills only (not .claude/skills, not the fixture
    # dotprofile's claude/skills; commander 2026-11-06); the fan-out deploys every
    # non-retired skill it lists
    # -----------------------------------------------------------------------------
    $seedReal = {
        $envs = Run-Env $script:H (Join-Path $script:C "dh.summary")
        $envs["AITOOLS_LOG_DIR"] = Mixed (Join-Path $script:H "logs-dh")
        $argv = @("-NoProfile", "-NonInteractive", "-File", (PJ $root scripts deploy-harness.ps1), "-SkipConfig", "-Force")
        $dhRc = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile (Join-Path $script:C "dh.out")
        [IO.File]::WriteAllText((Join-Path $script:C "dh.rc"), "$dhRc`n")
    }
    Case-Run real $seedReal
    $rmf = PJ $script:C $L .aitools skills .aitools-skills-manifest
    $mLines = @()
    if (IsFile $rmf) {
        $mLines = @([IO.File]::ReadAllText($rmf) -split "`n")
        if ($mLines.Count -and $mLines[-1] -eq "") { $mLines = @($mLines | Select-Object -SkipLast 1) }
    }
    $ok = ((ReadText (Join-Path $script:C "dh.rc")).Trim() -eq "0" -and $mLines.Count -ge 1 -and ($mLines[0] -replace "`r$", "") -ceq '# aitools skills manifest v1')
    if (-not $ok) { @((Strip (ReadText (Join-Path $script:C "dh.out"))) -split "`n") | Select-Object -Last 20 | ForEach-Object { Write-Output $_ } }
    Check "real harness: deploy-harness wrote the skills manifest" $ok
    # Names: every manifest line after the header whose source is not "retired"
    $names = @($mLines | Select-Object -Skip 1 | ForEach-Object { $p = ($_ -replace "`r$", "") -split "`t"; if ($p.Count -lt 2 -or $p[1] -cne "retired") { $p[0] } })
    $missingName = @($names | Where-Object { -not (IsFile (PJ (S) $_ SKILL.md)) })
    Check "real harness: every listed skill fanned out with its SKILL.md" ($names.Count -gt 0 -and $missingName.Count -eq 0)
    $badLines = @($mLines | Select-Object -Skip 1 | Where-Object { $_ -cnotmatch "`tshared`r?$" })
    Check "real harness: manifest lists shared skills only" ($badLines.Count -eq 0)
    Check "real harness: the dotprofile skill is neither listed nor deployed" (-not ($names -ccontains 'd1') -and -not (Exists (PJ (S) d1)) -and -not (Exists (PJ $script:C $L .aitools skills d1)))
    Check "real harness: exit 0, OK row" ((Rc) -eq "0" -and (NonDetail) -cmatch '^OK\|claude skills\|[0-9]+ added$')
    # No golden record: the tree is this checkout's own skills (it changes with
    # every skill edit); the checks above are the record
    Run-One
    Check "real harness rerun: verified" ((NonDetail) -cmatch '^OK\|claude skills\|[0-9]+ verified$')

    # -----------------------------------------------------------------------------
    # Cursor (FO-5): setup-user-cursor.ps1 step 5 runs the same fan-out into
    # ~/.cursor/skills with tool "cursor skills" and no adopt target. The whole
    # script runs, stub rg/agent on PATH (.cmd files: native pwsh runs no
    # extensionless bash stub) so steps 1-2 find them installed and no installer runs.
    # -----------------------------------------------------------------------------
    Copy-Item -LiteralPath (Join-Path $root "scripts/setup-user-cursor.sh") -Destination (Join-Path $A "scripts/setup-user-cursor.sh")
    Copy-Item -LiteralPath (Join-Path $root "scripts/setup-user-cursor.ps1") -Destination (Join-Path $A "scripts/setup-user-cursor.ps1")
    WriteText (Join-Path $CSTUB "rg.cmd") "@echo ripgrep 14.1.0`r`n"
    WriteText (Join-Path $CSTUB "agent.cmd") "@echo 2026.05.21-stub`r`n"

    # Run-Cursor [FLAG]: setup-user-cursor.ps1 under $C\ps, non-interactive
    function Run-Cursor([string]$Flag = "") {
        $envs = Run-Env $script:H (Join-Path $script:C "$L.summary")
        $envs["PATH"] = $CSTUB + [IO.Path]::PathSeparator + $env:PATH
        Run-Child (PJ $A "scripts" "setup-user-cursor.ps1") $Flag $envs
    }
    function Cursor-Case([string]$Name, [scriptblock]$Seed, [string]$Flag = "") {
        $script:C = Join-Path $tmpRoot $Name
        New-Item -ItemType Directory -Path $script:C -Force | Out-Null
        $script:H = Join-Path $script:C $L
        Seed-Home $script:H
        & $Seed
        Run-Cursor $Flag
    }

    $seedCursor = {
        manifest 'd1|dotprofile' 'gone|retired' 'mine2|retired' 'p1|aitools' 's1|shared'
        hskill s1 SKILL.md '## shared s1'
        hskill s1 scripts/run.sh '#!/bin/sh'   # chmod 755 in the .sh: no mode on Windows
        hskill p1 SKILL.md '## project p1'
        hskill d1 SKILL.md '## dot d1'
        hskill gone.bak.2026-10-25T000000Z SKILL.md 'gone'
        cskill gone SKILL.md 'gone'                      # the fan-out's copy of a retired skill
        cskill mine2 SKILL.md 'my own'                   # a user's skill at a retired name
        cskill mine SKILL.md 'mine'                      # a user's own skill
        # the firecrawl symlink of the .sh needs symlinks ($canSymlink)
    }
    Cursor-Case cursor $seedCursor
    Check "cursor: exit 0, row 4 added, 1 removed (WARN: a kept dir still loads)" ((Rc) -eq "0" -and (NonDetail "cursor skills") -ceq 'WARN|cursor skills|4 added, 1 removed')
    Check "cursor: shared, aitools, dotprofile skills in ~/.cursor/skills, x bit kept" ((HasLine (PJ (CS) s1 SKILL.md) '## shared s1') -and (HasLine (PJ (CS) p1 SKILL.md) '## project p1') -and (HasLine (PJ (CS) d1 SKILL.md) '## dot d1') -and (IsExecLike (PJ (CS) s1 scripts run.sh)))
    Check "cursor: nothing written to ~/.claude/skills" (-not (Exists (PJ $script:C $L .claude skills)))
    Check "cursor ${L}: adopt=none for every source" ((Logged 'cursor skills: s1/SKILL.md source=shared adopt=none') -and (Logged 'cursor skills: p1/SKILL.md source=aitools adopt=none') -and (Logged 'cursor skills: d1/SKILL.md source=dotprofile adopt=none'))
    $cb = @(BakNames ".cursor")
    Check "cursor: retired copy removed, backed up beside ~/.cursor/skills" (-not (Exists (PJ (CS) gone)) -and $cb.Count -ge 1 -and (HasLine (PJ $script:C $L .cursor $cb[0] gone SKILL.md) gone) -and (Row 'DETAIL|cursor skills|removed: gone'))
    Check "cursor: user skill at a retired name kept, ACTION row" ((HasLine (PJ (CS) mine2 SKILL.md) 'my own') -and (Row 'ACTION||Cursor still loads retired skills in ~/.cursor/skills: mine2 -- delete them unless you wrote them'))
    Check "cursor: a user's own skill kept" ((HasLine (PJ (CS) mine SKILL.md) mine) -and (OutHas 'Preserved unmanaged skill: mine'))
    if ($canSymlink) { throw "symlink cases are not built on Windows" } else { Skip "cursor: firecrawl symlink preserved (no symlinks on Windows)" }
    Check "cursor: step 5 logged after step 4" (OutHas 'Step 5: Cursor user skills')
    CParity cursor
    Run-Cursor
    Check "cursor rerun: 4 verified (WARN: the kept dir)" ((NonDetail "cursor skills") -ceq 'WARN|cursor skills|4 verified')
    CParity cursor-rerun

    $seedCursorNone = { cskill mine SKILL.md 'mine' }
    Cursor-Case cursor-none $seedCursorNone
    # No ~/.aitools/skills: the fan-out logs only and writes no row (FO-6's
    # setup-user-skills owns the row then; contract change in #124 5267e9e)
    Check "cursor, no harness skills: no cursor skills row, logged, ~/.cursor/skills untouched" ((Rc) -eq "0" -and -not (NonDetail "cursor skills") -and -not (SummaryHas '|cursor skills|') -and (OutMatch 'No harness skills at .*setup-user-skills deploys skills') -and (LsIs (CS) "mine"))
    CParity cursor-none

    # Only retired names in both manifests, nothing in ~/.cursor: steps 4 and 5
    # write the same row text (review 1 / audit B6)
    $seedCursorRetiredOnly = {
        manifest 'gone|retired'
        WriteText (PJ $script:H .aitools rules .aitools-rules-manifest) "# aitools rules manifest v1`nx.md`tretired`n"
    }
    Cursor-Case cursor-retired-only $seedCursorRetiredOnly
    Check "cursor, only retired names: both steps write n/a (nothing to deploy)" ((Rc) -eq "0" -and (NonDetail "cursor skills") -ceq 'OK|cursor skills|n/a (nothing to deploy)' -and (NonDetail "cursor rules") -ceq 'OK|cursor rules|n/a (nothing to deploy)')
    CParity cursor-retired-only
} catch {
    # An unexpected error is a failed suite, never a silent pass
    Write-Output "FAIL suite error: $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    $script:fail++
} finally {
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: ps1 scripts)" -f $script:pass, $script:fail, $script:skip)
if ($script:fail -ne 0) { exit 1 }
exit 0
