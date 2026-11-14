# test-rules-fanout.ps1 -- tests for the rules fan-out of scripts/setup-user-claude.ps1:
# ~/.aitools/rules -> ~/.claude/rules. Everything is fanned out except the rules
# the manifest retires; *.md only, names compared case-insensitively; *.bak.* and
# hidden files skipped; unmanaged files preserved; the copy of a retired rule
# removed only when it matches a harness copy; adopt target from the manifest
# source; the dotprofile's claude/rules is not read directly. Also the lib
# helpers (tracker "removed", unknown outcomes, Get-RuleNameKind).
# The Windows harness of this suite; tests/rules-fanout/test-rules-fanout.sh is
# the macOS/Linux harness of the same cases for setup-user-claude.sh.
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs setup-user-claude.ps1 with native pwsh on Windows only.
# Parity with the .sh is checked against the committed golden results in
# tests/rules-fanout/golden/ (exit code, ~/.claude/rules tree, summary rows per
# case), which the .sh harness checks on macOS/Linux (Test-GoldenMatch in
# tests/lib/platform-lib.ps1). The unreadable cases (.sh: chmod 000) run with an
# ACL deny entry for the current user instead (Deny-Access; chmod changes
# nothing on NTFS, so the old Git Bash harness skipped them). The case-only
# duplicate (case-sensitive file system) and dangling symlink (creating a
# symlink needs a privilege on Windows) cases stay SKIP, with the .sh harness's
# Windows-run text.
#
# Safe to re-run: every case runs a copy of scripts/ in a temp aitools checkout,
# in a child pwsh under its own temp HOME, with a temp git dotprofile (all
# removed on exit); the real HOME, ~/.aitools and dotprofile are never touched.
# Needs git; python3 with pywinpty for the pty cases (else SKIP). Exit 1 if any
# case fails. Spec: plans/rules-fanout-claude.md.
#
# Usage: pwsh -NoProfile -File tests/rules-fanout/test-rules-fanout.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath | Select-Object -Skip 1 | ForEach-Object -Begin { $script:inHeader = $true } -Process { if ($script:inHeader -and $_ -match '^#') { $_ -replace '^# ?', '' } else { $script:inHeader = $false } }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/rules-fanout/test-rules-fanout.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
# L: the language this platform runs (ps, as on the .sh's Windows run); also the
# name of the case's HOME, output and summary files. PowerShell names are
# case-insensitive: no other variable here may be named $l (a loop over $l once
# replaced it and sent the parity rows to the wrong summary file)
$L = "ps"
$PTY = Join-Path $root "tests/managed-files/pty-run.py"

$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:C = ""
$script:rc = $null

function Strip([string]$Text) { ($Text -replace "`e\[[0-9;]*m", "") -replace "`r", "" }
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
# Get-Lines PATH: the lines of PATH (CR removed), as grep and sort read them
function Get-Lines([string]$Path) {
    $t = (ReadText $Path) -replace "`r", ""
    if ($t -eq "") { return }
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    $t -split "`n"
}
function WriteLf([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text)
}
function Mixed([string]$Path) { $Path -replace '\\', '/' }   # C:/... (native_path in the .sh)
# Native { CMD 2>&1 }: a native command with stderr merged into the output under
# ErrorActionPreference Continue (under Stop a stderr line, e.g. git init's hint,
# would end the script); the caller checks $LASTEXITCODE
function Native([scriptblock]$Block) { $ErrorActionPreference = "Continue"; & $Block }

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    $out = if ($script:C) { Join-Path $script:C "$L.out" } else { "" }
    if ($out -and (Test-Path -LiteralPath $out -PathType Leaf)) {
        @((Strip (ReadText $out)) -split "`n") | Select-Object -Last 25 | ForEach-Object { Write-Output "      | $_" }
    }
}
function Skip([string]$Name) { Write-Output "SKIP $Name"; $script:skip++ }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    # Get-Command exempt: command-existence check; this branch is the fallback
    # (the .sh also required perl for itself; this harness does not use perl)
    Write-Output "SKIP all cases (git not found)"
    exit 0
}
$python = Get-Command python3 -ErrorAction SilentlyContinue   # existence check; $null = no pty
$havePty = [bool]$python -and (Test-Path -LiteralPath $PTY -PathType Leaf)
# Windows pty = pywinpty (ConPTY); the import failing means "not installed"
if ($havePty) {
    $null = Native { & $python.Source -c "import winpty" 2>&1 }
    if ($LASTEXITCODE -ne 0) { $havePty = $false }
}
$tmpRoot = New-TestTempRoot "rules-fanout"
$GoldenDir = Join-Path $root "tests/rules-fanout/golden"
$GoldenTmp = $tmpRoot

# Deny-Access PATH RIGHTS: an ACL deny entry for the current user, the Windows
# equivalent of the .sh's chmod 000 (chmod changes nothing on NTFS: the old Git
# Bash run skipped these cases). Undo-Deny PATH removes it (the owner may always
# change the ACL). $script:Denied lists the paths still denied, so the finally
# block can undo an interrupted case before the temp root is removed.
$script:Me = [Security.Principal.WindowsIdentity]::GetCurrent().User
$script:Denied = [Collections.Generic.List[string]]::new()
function Deny-Access([string]$Path, [Security.AccessControl.FileSystemRights]$Rights) {
    $acl = Get-Acl -LiteralPath $Path
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($script:Me, $Rights, [Security.AccessControl.AccessControlType]::Deny))
    Set-Acl -LiteralPath $Path -AclObject $acl
    $script:Denied.Add($Path)
}
function Undo-Deny([string]$Path) {
    $acl = Get-Acl -LiteralPath $Path
    foreach ($r in @($acl.Access | Where-Object { $_.AccessControlType -eq 'Deny' -and $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -eq $script:Me.Value })) {
        $null = $acl.RemoveAccessRule($r)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
    $null = $script:Denied.Remove($Path)
}
# $canDenyRead: a denied read really fails here (the .sh's CAN_CHMOD_READ; false
# e.g. for a process that reads with backup privilege). The SKIP line keeps the
# .sh's text when it is false.
function Test-DenyBlocksRead {
    $f = Join-Path $tmpRoot "deny-probe"
    [IO.File]::WriteAllText($f, "x`n")
    try {
        Deny-Access $f ([Security.AccessControl.FileSystemRights]::ReadData)
        try { $null = [IO.File]::ReadAllText($f); return $false } catch { return $true }
    } catch {
        Write-Host "      | ACL deny not available: $($_.Exception.Message)"
        return $false
    } finally {
        if ($script:Denied.Contains($f)) { Undo-Deny $f }
    }
}
$canDenyRead = Test-DenyBlocksRead

function GitC { & git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false @args }
# Fixture-Fail WHAT: a fixture step that fails ends the run (exit 1) instead of
# showing up later as failed or vacuous checks (audit A N8)
function Fixture-Fail([string]$What) { Write-Output "FATAL fixture setup failed: $What"; exit 1 }

try {
    WriteLf (Join-Path $tmpRoot "cs-probe") ""
    $caseSensitiveFs = -not (Test-Path -LiteralPath (Join-Path $tmpRoot "CS-PROBE"))

    # --- Temp aitools checkout: a copy of scripts/ (adopt targets of shared and
    # aitools rules land here, never in this repo) ---
    $A = Join-Path $tmpRoot "aitools"
    try {
        foreach ($d in @("scripts", "shared/rules", ".claude/rules")) { New-Item -ItemType Directory -Path (Join-Path $A $d) -Force | Out-Null }
    } catch { Fixture-Fail "mkdir $A" }
    # Unchanged copies, OS guards included: the .ps1 runs only on Windows
    foreach ($f in @("setup-user-claude.sh", "setup-user-claude.ps1", "aitools-lib.sh", "aitools-lib.ps1", "aitools-profile.sh", "aitools-profile.ps1", "aitools-json.pl", "aitools-json.ps1")) {
        try { Copy-Item -LiteralPath (Join-Path $root "scripts/$f") -Destination (Join-Path $A "scripts/$f") } catch { Fixture-Fail "cp scripts/$f" }
    }
    try { Copy-Item -LiteralPath (Join-Path $root "shared/claude-shared.md") -Destination (Join-Path $A "shared/claude-shared.md") } catch { Fixture-Fail "cp shared/claude-shared.md" }
    # A package payload (git archive) has the same files but no .git: adopt into it
    # is never offered (BUILD-PKG BP-6). The fan-out counts only a git checkout.
    $PAYLOAD = Join-Path $tmpRoot "payload"
    try {
        New-Item -ItemType Directory -Path $PAYLOAD | Out-Null
        foreach ($d in @("scripts", "shared", ".claude")) { Copy-Item -LiteralPath (Join-Path $A $d) -Destination (Join-Path $PAYLOAD $d) -Recurse -Force }
    } catch { Fixture-Fail "payload copy" }
    $o = Native { & git -C $A init -q 2>&1 }
    if ($LASTEXITCODE -ne 0) { Fixture-Fail "git init $A ($o)" }
    $script:REPO = $A   # the checkout Run-One / Run-Pty run setup-user-claude from

    # --- Fixture dotprofile (a git repo, no remote: an adopt commits, the push fails) ---
    $DP = Join-Path $tmpRoot "aitools-tess"
    try {
        WriteLf (Join-Path $DP "claude/CLAUDE.md") "# Prefs for {{PROFILE_NAME}}`n`n## Code Style`n`n- keep it simple`n"
        WriteLf (Join-Path $DP "profile.json") ('{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}' + "`n")
        WriteLf (Join-Path $DP "claude/rules/d.md") "## dot d`n"
        WriteLf (Join-Path $DP "claude/rules/only-dp.md") "## only in the dotprofile`n"
    } catch { Fixture-Fail "dotprofile files ($($_.Exception.Message))" }
    $o = Native { & git -C $DP init -q 2>&1 }
    if ($LASTEXITCODE -ne 0) { Fixture-Fail "git init $DP ($o)" }
    $o = Native { GitC -C $DP add -A 2>&1 }
    if ($LASTEXITCODE -ne 0) { Fixture-Fail "git add (dotprofile) ($o)" }
    $o = Native { GitC -C $DP commit -q -m fixture 2>&1 }
    if ($LASTEXITCODE -ne 0) { Fixture-Fail "git commit (dotprofile) ($o)" }

    # --- Case helpers ---
    # $H: the HOME of the run being seeded (set by Case-Run)
    function Harness([string]$Name, [string]$Text) { WriteLf (Join-Path $script:H ".aitools/rules/$Name") "$Text`n" }
    function Deployed([string]$Name, [string]$Text) { WriteLf (Join-Path $script:H ".claude/rules/$Name") "$Text`n" }
    # Manifest LINE...: ~/.aitools/rules/.aitools-rules-manifest (PR #100 v1); "|" stands for the TAB
    function Manifest([string[]]$Lines) {
        $text = "# aitools rules manifest v1`n"
        foreach ($ml in $Lines) { $text += ($ml -replace '\|', "`t") + "`n" }
        WriteLf (Join-Path $script:H ".aitools/rules/.aitools-rules-manifest") $text
    }
    # Run-Env H: the environment of a run under HOME H. The paths are in C:/...
    # form, as the .sh passed them (cygpath -m); the variables the .sh unset with
    # env -u are removed.
    function Run-Env([string]$H) {
        @{
            AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null; AITOOLS_USER_REPO_PATH = $null; AITOOLS_PROFILE_FILE = $null
            AITOOLS_PROFILE_SH = $null; AITOOLS_PROFILE_PS1 = $null
            HOME = (Mixed $H); USERPROFILE = (Mixed $H); AITOOLS_LOG_DIR = (Mixed (Join-Path $H "logs"))
            AITOOLS_SUMMARY_FILE = (Mixed (Join-Path $script:C "$L.summary"))
            GIT_CONFIG_GLOBAL = (Mixed (Join-Path $H ".gitconfig")); GIT_CONFIG_NOSYSTEM = "1"
        }
    }
    # Run-One [FLAG]: setup-user-claude.ps1 non-interactively under $C/<L>
    function Run-One([string]$Flag = "") {
        $h = Join-Path $script:C $L
        WriteLf (Join-Path $script:C "$L.summary") ""
        $argv = @("-NoProfile", "-NonInteractive", "-File", (Join-Path $script:REPO "scripts/setup-user-claude.ps1"))
        if ($Flag) { $argv += $Flag }
        $script:rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment (Run-Env $h) -OutFile (Join-Path $script:C "$L.out")
    }
    # Run-Pty INPUT: the same on a pty (review menu), keystrokes INPUT
    function Run-Pty([string]$InputKeys) {
        $h = Join-Path $script:C $L
        WriteLf (Join-Path $script:C "$L.summary") ""
        $argv = @($PTY, "--input", $InputKeys, "--log", (Join-Path $script:C "$L.out"), "--",
            $pwshExe, "-NoProfile", "-File", (Join-Path $script:REPO "scripts/setup-user-claude.ps1"))
        $script:rc = Invoke-TestScript -FilePath $python.Source -ArgumentList $argv -Environment (Run-Env $h) -OutFile (Join-Path $script:C "$L.pty-runner")
    }
    # Case-Run NAME SEED [FLAG]: a fresh HOME $C/<L> with config.json -> the
    # fixture dotprofile, seeded by SEED, then one run (FLAG: the .ps1 spelling)
    function Case-Run([string]$Name, [scriptblock]$Seed, [string]$Flag = "") {
        $script:C = Join-Path $tmpRoot $Name
        $script:H = Join-Path $script:C $L
        WriteLf (Join-Path $script:H ".aitools/config.json") ("{`"userRepoPath`":`"" + (Mixed $DP) + "`",`"machineAlias`":`"m1`"}`n")
        WriteLf (Join-Path $script:H ".gitconfig") "[user]`n`tname = Test`n`temail = test@example.invalid`n[commit]`n`tgpgsign = false`n"
        & $Seed
        Run-One $Flag
    }
    function Rerun([string]$Flag = "") { Run-One $Flag }   # run again in the same HOME

    function SumLines { @(Get-Lines (Join-Path $script:C "$L.summary")) }
    function Row([string]$Line) { (SumLines) -ccontains $Line }   # exact summary row
    # Nondetail: the last claude rules row that is not DETAIL ("" when none)
    function Nondetail {
        $r = @(SumLines | Where-Object { $_.Contains("|claude rules|") -and -not $_.StartsWith("DETAIL") })
        if ($r.Count) { $r[-1] } else { "" }
    }
    function RulesDir { Join-Path $script:C "$L/.claude/rules" }   # the deployed rules dir
    function OutLines { @((Strip (ReadText (Join-Path $script:C "$L.out"))) -split "`n") }
    function OutHas([string]$Pattern) { [bool](OutLines | Where-Object { $_ -cmatch $Pattern }) }
    # FileHasLine PATH LINE: a line of PATH (CR removed) is exactly LINE (grep -qx)
    function FileHasLine([string]$Path, [string]$Line) { @(Get-Lines $Path) -ccontains $Line }
    function Exists([string]$Path) { Test-Path -LiteralPath $Path }
    function IsFile([string]$Path) { Test-Path -LiteralPath $Path -PathType Leaf }
    # LsNames DIR: the names ls lists (no dot-names), ordinal order
    function LsNames([string]$Dir) {
        if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return }
        $n = [string[]]@(Get-ChildItem -LiteralPath $Dir -Force | ForEach-Object { $_.Name } | Where-Object { -not $_.StartsWith(".") })
        [Array]::Sort($n, [StringComparer]::Ordinal)
        $n
    }
    function LsHas([string]$Dir, [string]$Pattern) { [bool](@(LsNames $Dir) | Where-Object { $_ -cmatch $Pattern }) }
    # LogText: the run's log files, concatenated (as cat logs/*.log), CR removed
    function LogText {
        $d = Join-Path $script:C "$L/logs"
        if (-not (Test-Path -LiteralPath $d -PathType Container)) { return "" }
        $t = ""
        $files = [string[]]@(Get-ChildItem -LiteralPath $d -File | Where-Object { $_.Name.EndsWith(".log", [StringComparison]::Ordinal) } | ForEach-Object { $_.FullName })
        [Array]::Sort($files, [StringComparer]::Ordinal)
        foreach ($f in $files) { $t += [IO.File]::ReadAllText($f) }
        $t -replace "`r", ""
    }
    # Logged TEXT: TEXT in the run's log files. TEXT holds no path: paths are
    # checked with AdoptIs.
    function Logged([string]$Text) { (LogText).Contains($Text) }
    # Loc PATH: PATH as a location: full path, 8.3 short components expanded
    # (pwsh can name a directory C:\Users\RUNNER~1\... where the harness has the
    # long form; first native CI run 41265193554), / separators. $null on failure.
    function Loc([string]$Path) {
        try {
            $p = [IO.Path]::GetFullPath($Path)
            if ($p -match '~') { $p = Get-TestLongPath $p }
            return ($p -replace '\\', '/')
        } catch {
            Write-Host "      | cannot resolve ${Path}: $($_.Exception.Message)"
            return $null
        }
    }
    # AdoptIs RULE SOURCE WANT: the run logged "claude rules: RULE source=SOURCE
    # adopt=<path>" and <path> is WANT (a path, or "none"). Paths are compared as
    # locations (Loc, case-insensitive: a Windows path names one location in any
    # case), not as text. Prints what was logged on a mismatch (Write-Host: the
    # result is the only output).
    function AdoptIs([string]$Rule, [string]$Src, [string]$Want) {
        $re = '\[detail\] claude rules: ' + [regex]::Escape($Rule) + ' source=' + [regex]::Escape($Src) + ' adopt=(.*)\z'
        $got = $null
        foreach ($line in ((LogText) -split "`n")) {
            $m = [regex]::Match($line, $re)
            if ($m.Success) { $got = $m.Groups[1].Value }
        }
        if (-not $got) {
            Write-Host "      | no `"claude rules: $Rule source=$Src adopt=`" line in the log"
            return $false
        }
        $g = $got; $w = $Want
        if ($w -ne "none" -and $g -ne "none") {
            $g = Loc $got; $w = Loc $Want
            if ($null -eq $g -or $null -eq $w) { return $false }
            if ([string]::Equals($g, $w, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        } elseif ($g -ceq $w) {
            return $true
        }
        Write-Host "      | adopt=$got (want $Want)"
        return $false
    }

    # TreeSig DIR: "<path> <md5>" per file, backup time stamps normalized, ordinal
    # sort (the .sh's perl tree_sig); nothing when DIR is not a directory
    function TreeSig([string]$Dir) {
        if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return }
        $lines = [string[]]@(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force | ForEach-Object {
            $rel = ([IO.Path]::GetRelativePath($Dir, $_.FullName) -replace '\\', '/') -creplace '\.bak\.[0-9TZ-]+\z', '.bak.TS'
            $md5 = ([Convert]::ToHexString([Security.Cryptography.MD5]::HashData([IO.File]::ReadAllBytes($_.FullName)))).ToLowerInvariant()
            "$rel $md5"
        })
        [Array]::Sort($lines, [StringComparer]::Ordinal)
        $lines
    }
    # Rows FILE: the ACTION and claude rules rows, ordinal sort
    function Rows([string]$File) {
        $r = [string[]]@(Get-Lines $File | Where-Object { $_ -cmatch '^(ACTION\||[A-Z]+\|claude rules\|)' })
        [Array]::Sort($r, [StringComparer]::Ordinal)
        $r
    }
    # Parity CASE: this run's exit code, ~/.claude/rules tree and summary rows equal
    # the golden result tests/rules-fanout/golden/CASE.result, which the .sh run
    # (macOS/Linux) and the .ps1 run (Windows) must both give
    function Parity([string]$Case) {
        $text = "exit code: $($script:rc)`n# ~/.claude/rules (path md5)`n"
        foreach ($line in @(TreeSig (RulesDir))) { $text += "$line`n" }
        $text += "# summary rows`n"
        foreach ($line in @(Rows (Join-Path $script:C "$L.summary"))) { $text += "$line`n" }
        $f = Join-Path $script:C "$Case.result"
        WriteLf $f $text
        Check "parity: ${Case}: exit code, ~/.claude/rules and summary rows match golden (sh and ps share it)" (Test-GoldenMatch "$Case.result" $f)
    }

    # ---------------------------------------------------------------------------
    # Lib helpers: tracker "removed" and unknown outcomes, Get-RuleNameKind
    # ---------------------------------------------------------------------------
    $script:C = Join-Path $tmpRoot "lib"
    $libPs1 = Join-Path $script:C "lib.ps1"
    WriteLf $libPs1 @'
param([string]$Repo)
. (Join-Path (Join-Path $Repo "scripts") "aitools-lib.ps1")
Initialize-Logging "test-rules-fanout"
Initialize-DeployTracker
Record-DeployOutcome -Outcome "removed" -ToolName "t" -ItemName "x.md"
Record-DeployOutcome -Outcome "bogus" -ToolName "t" -ItemName "y.md"
Write-DeployTrackerSummary -ToolName "t"
[Console]::WriteLine("TEXT=$($script:deployTrackerText)")
foreach ($n in @("a.md", "A.MD", "b.Md", "x.md.bak.1", "X.MD.BAK.2026", "odd.bak.2026.md", ".hidden.md", "notes.txt")) { [Console]::WriteLine("$n=$(Get-RuleNameKind $n)") }

'@
    WriteLf (Join-Path $script:C "$L.summary") ""
    $libEnv = @{
        HOME = (Mixed $script:C); USERPROFILE = (Mixed $script:C); AITOOLS_LOG_DIR = (Mixed (Join-Path $script:C "logs-ps"))
        AITOOLS_SUMMARY_FILE = (Mixed (Join-Path $script:C "$L.summary"))
    }
    $null = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $libPs1, (Mixed $A)) -Environment $libEnv -OutFile (Join-Path $script:C "$L.out")
    $libOut = @(OutLines)
    Check "lib ${L}: removed outcome: DETAIL row and count" ((Row 'DETAIL|t|removed: x.md') -and ($libOut -ccontains 'TEXT=1 removed, 1 failed'))
    Check "lib ${L}: unknown outcome: logged, counted as failed, ERROR row" ((Row 'DETAIL|t|failed: y.md') -and (Row 'ERROR|t|1 failed') -and (OutHas 'unknown outcome "bogus"'))
    Check "lib ${L}: rule_name_kind is case-insensitive" (($libOut -ccontains 'A.MD=rule') -and ($libOut -ccontains 'b.Md=rule') -and ($libOut -ccontains 'X.MD.BAK.2026=backup') -and ($libOut -ccontains 'odd.bak.2026.md=backup') -and ($libOut -ccontains '.hidden.md=hidden') -and ($libOut -ccontains 'notes.txt=other'))
    # Parity (was: sh and ps output compared on one machine): both match the golden files
    $kinds = @($libOut | Where-Object { $_ -cmatch '^(TEXT=|[^ ]+=(rule|backup|hidden|other)$)' })
    WriteLf (Join-Path $script:C "lib.kinds") $(if ($kinds.Count) { ($kinds -join "`n") + "`n" } else { "" })
    Check "lib parity: tracker rows match golden" (Test-GoldenMatch "lib.summary" (Join-Path $script:C "$L.summary"))
    Check "lib parity: summary text and kinds match golden" (Test-GoldenMatch "lib.kinds" (Join-Path $script:C "lib.kinds"))

    # ---------------------------------------------------------------------------
    # No harness rules: nothing deployed, ~/.claude/rules untouched, exit 0
    # ---------------------------------------------------------------------------
    Case-Run missing { Deployed mine.md 'mine' }
    Check "missing: exit 0, row n/a (no harness rules)" ($script:rc -eq 0 -and (Nondetail) -ceq 'OK|claude rules|n/a (no harness rules)')
    Check "missing: ~/.claude/rules untouched, no directory backup" ((FileHasLine (Join-Path (RulesDir) "mine.md") 'mine') -and (@(LsNames (RulesDir)) -join "`n") -ceq 'mine.md' -and -not (LsHas (Join-Path $script:C "$L/.claude") 'rules.bak'))
    Check "missing: the dotprofile's claude/rules is not deployed" (-not (Exists (Join-Path (RulesDir) "d.md")) -and -not (Exists (Join-Path (RulesDir) "only-dp.md")))
    Parity missing

    Case-Run empty { New-Item -ItemType Directory -Path (Join-Path $script:H ".aitools/rules") -Force | Out-Null }
    Check "empty: row n/a (no harness rules)" ($script:rc -eq 0 -and (Nondetail) -ceq 'OK|claude rules|n/a (no harness rules)')
    Parity empty

    # ---------------------------------------------------------------------------
    # Fan-out: every source, filter, preserved, rerun, edit, -Force
    # ---------------------------------------------------------------------------
    Case-Run fanout {
        Manifest @('d.md|dotprofile', 'p.md|aitools', 's.md|shared')
        Harness s.md '## shared s'; Harness p.md '## project p'; Harness d.md '## dot d'
        Harness UP.MD '## upper-case extension'
        Harness s.md.bak.2026-10-22T010203Z 'old s'
        Harness odd.bak.2026.md 'odd'; Harness Up.MD.BAK.1 'upper backup'
        Harness notes.txt 'not a rule'; Harness '.hidden.md' 'hidden'
        WriteLf (Join-Path $script:H ".aitools/rules/subdir/nested.md") "nested`n"
        Deployed mine.md 'mine'
    }
    Check "fanout: exit 0, row 4 added" ($script:rc -eq 0 -and (Nondetail) -ceq 'OK|claude rules|4 added')
    Check "fanout: shared, aitools, dotprofile and upper-case .MD rules deployed" ((FileHasLine (Join-Path (RulesDir) "s.md") '## shared s') -and (FileHasLine (Join-Path (RulesDir) "p.md") '## project p') -and (FileHasLine (Join-Path (RulesDir) "d.md") '## dot d') -and (IsFile (Join-Path (RulesDir) "UP.MD")))
    Check "fanout: *.bak.* (any case), hidden, non-.md and nested files skipped" (-not (Exists (Join-Path (RulesDir) "s.md.bak.2026-10-22T010203Z")) -and -not (Exists (Join-Path (RulesDir) "odd.bak.2026.md")) -and -not (Exists (Join-Path (RulesDir) "Up.MD.BAK.1")) -and -not (Exists (Join-Path (RulesDir) ".hidden.md")) -and -not (Exists (Join-Path (RulesDir) "notes.txt")) -and -not (Exists (Join-Path (RulesDir) "nested.md")) -and -not (Exists (Join-Path (RulesDir) "subdir")))
    Check "fanout: non-rule file logged, manifest and backups silent" ((OutHas 'Ignoring non-rule file in harness rules: notes.txt') -and -not (OutHas 'aitools-rules-manifest') -and -not (OutHas 's.md.bak'))
    Check "fanout: unmanaged rule preserved" ((FileHasLine (Join-Path (RulesDir) "mine.md") 'mine') -and (OutHas 'Preserved unmanaged rule: mine.md'))
    Check "fanout: dotprofile-only rule not deployed (not in ~/.aitools/rules)" (-not (Exists (Join-Path (RulesDir) "only-dp.md")))
    Parity fanout
    Rerun
    Check "fanout rerun: row 4 verified, nothing written" ((Nondetail) -ceq 'OK|claude rules|4 verified' -and -not (LsHas (RulesDir) '\.bak\.'))
    Parity fanout-rerun
    WriteLf (Join-Path (RulesDir) "s.md") "## shared s`nlocal edit`n"
    Rerun
    Check "fanout edited, non-interactive: overwritten, backup kept, WARN row" ((Nondetail) -ceq 'WARN|claude rules|1 updated, 3 verified' -and (FileHasLine (Join-Path (RulesDir) "s.md") '## shared s') -and (LsHas (RulesDir) '^s\.md\.bak\.'))
    Parity fanout-edited
    WriteLf (Join-Path (RulesDir) "s.md") "## shared s`nlocal edit 2`n"
    # The edited run's backup is checked above; removed so the tree holds one backup
    # whether or not the next run's stamp falls in the same second (golden file)
    Get-ChildItem -LiteralPath (RulesDir) -File | Where-Object { $_.Name.StartsWith("s.md.bak.", [StringComparison]::Ordinal) } | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    Rerun "-Force"
    Check "fanout --force: overwritten" ($script:rc -eq 0 -and (FileHasLine (Join-Path (RulesDir) "s.md") '## shared s') -and (Nondetail) -ceq 'WARN|claude rules|1 updated, 3 verified')
    Parity fanout-force

    # ---------------------------------------------------------------------------
    # Retired rules: pruned only when the copy matches a harness copy
    # ---------------------------------------------------------------------------
    $seedRetired = {
        Manifest @('a.md|shared', 'gone.md|retired', 'mine2.md|retired', 'old.md|retired')
        Harness a.md 'rule a'
        Harness gone.md.bak.2026-10-25T000000Z 'gone rule'   # deploy-harness retired it (backup, removed)
        Harness old.md 'old rule'                            # retired, but still in ~/.aitools/rules
        Deployed gone.md 'gone rule'; Deployed old.md 'old rule'; Deployed mine2.md 'my own'
    }
    Case-Run retired $seedRetired
    Check "retired: exit 0, row 1 added, 2 removed (WARN: a kept file still loads)" ($script:rc -eq 0 -and (Nondetail) -ceq 'WARN|claude rules|1 added, 2 removed')
    Check "retired: copies removed, backups kept" (-not (Exists (Join-Path (RulesDir) "gone.md")) -and -not (Exists (Join-Path (RulesDir) "old.md")) -and (LsHas (RulesDir) '^gone\.md\.bak\.') -and (LsHas (RulesDir) '^old\.md\.bak\.'))
    Check "retired: removals in DETAIL rows" ((Row 'DETAIL|claude rules|removed: gone.md') -and (Row 'DETAIL|claude rules|removed: old.md'))
    Check "retired: a retired rule still in ~/.aitools/rules is not fanned out" ((OutHas 'Not fanned out: old.md \(retired in the rules manifest\)') -and -not (Row 'DETAIL|claude rules|added: old.md'))
    Check "retired: user file with a retired name kept, ACTION row" ((FileHasLine (Join-Path (RulesDir) "mine2.md") 'my own') -and (Row 'ACTION||Claude Code still loads retired rules in ~/.claude/rules: mine2.md -- delete them unless you wrote them'))
    Parity retired
    Case-Run retired-dry $seedRetired "-DryRun"
    Check "retired dry run: nothing written, row dry run, removal previewed" ($script:rc -eq 0 -and (Nondetail) -ceq 'WARN|claude rules|dry run (no files written)' -and (IsFile (Join-Path (RulesDir) "gone.md")) -and (IsFile (Join-Path (RulesDir) "old.md")) -and -not (Exists (Join-Path (RulesDir) "a.md")) -and (OutHas 'DRY RUN\] Would back up and remove gone.md'))
    Parity retired-dry

    # A retired name holding [ ]: removed only with its backup (review RC-1: a
    # wildcard-based backup step could report success without a copy)
    Case-Run retired-bracket {
        Manifest @('a.md|shared', '[r].md|retired')
        Harness a.md 'rule a'
        Harness '[r].md.bak.2026-10-25T000000Z' 'r rule'
        Deployed '[r].md' 'r rule'
    }
    Check "retired [r].md: removed, backup kept" ($script:rc -eq 0 -and (Nondetail) -ceq 'OK|claude rules|1 added, 1 removed' -and -not (Exists (Join-Path (RulesDir) "[r].md")) -and (LsHas (RulesDir) '^\[r\]\.md\.bak\.'))
    Parity retired-bracket

    # A retired name whose copy differs only in case (Gone.md for gone.md)
    Case-Run retired-case {
        Manifest @('a.md|shared', 'gone.md|retired')
        Harness a.md 'rule a'
        Harness gone.md.bak.2026-10-25T000000Z 'gone rule'
        Deployed Gone.md 'gone rule'
    }
    Check "retired, case differs: the copy found and removed under its own name" ($script:rc -eq 0 -and (Nondetail) -ceq 'OK|claude rules|1 added, 1 removed' -and -not (Exists (Join-Path (RulesDir) "Gone.md")) -and (Row 'DETAIL|claude rules|removed: Gone.md') -and (LsHas (RulesDir) '^Gone\.md\.bak\.'))
    Parity retired-case

    # ---------------------------------------------------------------------------
    # Manifest absent, bad header, invalid lines
    # ---------------------------------------------------------------------------
    Case-Run nomanifest { Harness a.md 'rule a'; Harness b.md 'rule b' }
    Check "no manifest: everything fanned out, adopt not offered" ($script:rc -eq 0 -and (Nondetail) -ceq 'OK|claude rules|2 added' -and (OutHas 'No rules manifest') -and (Logged 'claude rules: a.md source=unknown adopt=none'))
    Parity nomanifest

    Case-Run badheader {
        WriteLf (Join-Path $script:H ".aitools/rules/.aitools-rules-manifest") "# aitools rules manifest v2`nx.md`tretired`n"
        Harness a.md 'rule a'; Harness x.md.bak.2026-10-25T000000Z 'x rule'; Deployed x.md 'x rule'
    }
    Check "bad header: fanned out, nothing retired, WARN + ACTION" ($script:rc -eq 0 -and (Nondetail) -ceq 'WARN|claude rules|1 added' -and (IsFile (Join-Path (RulesDir) "x.md")) -and (Row 'ACTION||Run aitools to rebuild ~/.aitools/rules and its manifest'))
    Parity badheader

    Case-Run invalid { Manifest @('bad.txt|shared', 'a.md|unknown', 'b.md|shared'); Harness a.md 'rule a'; Harness b.md 'rule b' }
    Check "invalid lines: warned, rules still fanned out" ($script:rc -eq 0 -and (Nondetail) -ceq 'WARN|claude rules|2 added' -and (OutHas 'line ignored: bad.txt<TAB>shared') -and (Logged 'claude rules: a.md source=unknown adopt=none'))
    Parity invalid

    # ---------------------------------------------------------------------------
    # Adopt target from the manifest source
    # ---------------------------------------------------------------------------
    Case-Run adoptmap {
        Manifest @('d.md|dotprofile', 'p.md|aitools', 's.md|shared', 'z.md|dotprofile')
        Harness s.md '## shared s'; Harness p.md '## project p'; Harness d.md '## dot d'; Harness z.md '## z'
        WriteLf (Join-Path $A "shared/rules/s.md") "## shared s`n"; WriteLf (Join-Path $A ".claude/rules/p.md") "## project p`n"
    }
    # The full adopt path, from one log line (a split match could pass on
    # "adopt=none" plus the deploy destination's ".../.claude/rules/p.md")
    Check "adopt map ${L}: shared -> aitools shared/rules" (AdoptIs s.md shared (Join-Path $A "shared/rules/s.md"))
    Check "adopt map ${L}: aitools -> aitools .claude/rules" (AdoptIs p.md aitools (Join-Path $A ".claude/rules/p.md"))
    Check "adopt map ${L}: dotprofile -> dotprofile claude/rules" (AdoptIs d.md dotprofile (Join-Path $DP "claude/rules/d.md"))
    Check "adopt map ${L}: no repo file -> none" (AdoptIs z.md dotprofile none)

    if ($havePty) {
        WriteLf (Join-Path $script:C "$L/.claude/rules/d.md") "## dot d`nmy edit $L`n"
        WriteLf (Join-Path $script:C "$L/.claude/rules/p.md") "## project p`nmy edit $L`n"
        Run-Pty 'a\na\n'
        $subj = (Native { & git -C $DP log -1 --format=%s 2>&1 }) -join "`n"
        Check "adopt ${L}: dotprofile rule written to the dotprofile and committed" ((FileHasLine (Join-Path $DP "claude/rules/d.md") "my edit $L") -and ($subj -cmatch 'd.md'))
        Check "adopt ${L}: aitools rule written to the aitools working tree" (FileHasLine (Join-Path $A ".claude/rules/p.md") "my edit $L")
        Check "adopt ${L}: DETAIL rows" ((Row 'DETAIL|claude rules|accept & adopt: d.md') -and (Row 'DETAIL|claude rules|accept & adopt: p.md'))
        # abort: exit 2 from the library, no claude rules row, the local file kept
        WriteLf (Join-Path $script:C "$L/.claude/rules/s.md") "## shared s`nlocal $L`n"
        Run-Pty 'x\n'
        Check "abort ${L}: exit 2, no claude rules row, local file kept" ($script:rc -eq 2 -and (Nondetail) -ceq "" -and (FileHasLine (Join-Path $script:C "$L/.claude/rules/s.md") "local $L"))
    } else {
        Skip "adopt and abort on a pty (python3 not found; on Windows also pywinpty)"
    }
    WriteLf (Join-Path $A ".claude/rules/p.md") "## project p`n"

    # Run from a package payload (no .git): no adopt into it, dotprofile adopt kept
    $script:REPO = $PAYLOAD
    Case-Run payload {
        Manifest @('d.md|dotprofile', 'p.md|aitools', 's.md|shared')
        Harness s.md '## shared s'; Harness p.md '## project p'; Harness d.md '## dot d'
        WriteLf (Join-Path $PAYLOAD "shared/rules/s.md") "## shared s`n"; WriteLf (Join-Path $PAYLOAD ".claude/rules/p.md") "## project p`n"
    }
    $script:REPO = $A
    Check "payload ${L}: no adopt into a checkout without .git" ((AdoptIs s.md shared none) -and (AdoptIs p.md aitools none) -and (AdoptIs d.md dotprofile (Join-Path $DP "claude/rules/d.md")))
    Parity payload

    # ---------------------------------------------------------------------------
    # Names: [ ] in a name, case-only duplicates, dangling symlink, unreadable dir
    # ---------------------------------------------------------------------------
    Case-Run bracket { Manifest @('[x].md|shared'); Harness '[x].md' 'bracket' }
    Check "bracket name: deployed" ((Nondetail) -ceq 'OK|claude rules|1 added' -and (FileHasLine (Join-Path (RulesDir) "[x].md") 'bracket'))
    Rerun
    Check "bracket name: rerun verified" ((Nondetail) -ceq 'OK|claude rules|1 verified')
    Parity bracket

    if ($caseSensitiveFs) {
        Case-Run dupcase { Harness a.md 'lower'; Harness A.md 'upper' }
        # The first in ordinal (byte) order wins on every locale: A.md (0x41) before
        # a.md (0x61). No golden parity file: only a case-sensitive file system runs
        # this case; the checks pin the result.
        Check "case-only duplicate: the first wins, the second failed" ($script:rc -eq 1 -and (Nondetail) -ceq 'ERROR|claude rules|1 failed')
        Check "case-only duplicate: ordinal order, A.md deployed and a.md failed" ((IsFile (Join-Path (RulesDir) "A.md")) -and -not (Exists (Join-Path (RulesDir) "a.md")) -and (Row 'DETAIL|claude rules|failed: a.md'))
    } else {
        Skip "case-only duplicate (case-insensitive file system)"
    }

    # Dangling symlink: not run on Windows (the .sh harness skipped it under Git
    # Bash with this text; creating a symlink needs a privilege on Windows), so
    # the SKIP line is the one the .sh's Windows run printed
    Skip "dangling symlink (Git Bash)"

    # The .sh: chmod 000 on ~/.aitools/rules, then on the manifest; here a deny of
    # ListDirectory, then of ReadData (see Deny-Access)
    if ($canDenyRead) {
        Case-Run unreadable { Harness a.md 'rule a'; Deny-Access (Join-Path $script:H ".aitools/rules") ([Security.AccessControl.FileSystemRights]::ListDirectory) }
        Undo-Deny (Join-Path $script:C "$L/.aitools/rules")
        Check "unreadable harness dir: ERROR row, exit 1" ($script:rc -eq 1 -and (Nondetail) -ceq 'ERROR|claude rules|cannot read harness rules')
        Parity unreadable

        # Unreadable manifest (review RC-2): the fan-out still runs, the final row is ERROR
        Case-Run manifest-unreadable { Manifest @('a.md|shared'); Harness a.md 'rule a'; Deny-Access (Join-Path $script:H ".aitools/rules/.aitools-rules-manifest") ([Security.AccessControl.FileSystemRights]::ReadData) }
        Undo-Deny (Join-Path $script:C "$L/.aitools/rules/.aitools-rules-manifest")
        Check "unreadable manifest: rules fanned out, ERROR rows, final row ERROR, exit 1" ($script:rc -eq 1 -and (IsFile (Join-Path (RulesDir) "a.md")) -and (Row 'ERROR|claude rules|cannot read rules manifest') -and (Row 'DETAIL|claude rules|failed: .aitools-rules-manifest') -and (Nondetail) -ceq 'ERROR|claude rules|1 failed')
        Parity manifest-unreadable
    } else {
        Skip "unreadable harness dir and manifest (root or Git Bash)"
    }

    # ~/.claude/rules cannot be created (a file is in the way): ERROR row, exit 1,
    # the script still reaches its exit footer
    $seedNocreate = { Harness a.md 'rule a'; WriteLf (Join-Path $script:H ".claude/rules") "not a dir`n" }
    Case-Run nocreate $seedNocreate
    Check "cannot create rules dir: ERROR row, exit 1, file untouched" ($script:rc -eq 1 -and (Nondetail) -ceq 'ERROR|claude rules|cannot create rules dir' -and (FileHasLine (Join-Path $script:C "$L/.claude/rules") 'not a dir') -and (OutHas 'FAILED with'))
    Parity nocreate
    # The dry run previews that error (audit B N3): same row, exit 1, nothing written
    Case-Run nocreate-dry $seedNocreate "-DryRun"
    Check "cannot create rules dir, dry run: same ERROR row, exit 1, file untouched" ($script:rc -eq 1 -and (Nondetail) -ceq 'ERROR|claude rules|cannot create rules dir' -and (FileHasLine (Join-Path $script:C "$L/.claude/rules") 'not a dir') -and (OutHas 'not a directory \(dry run\)'))
    Parity nocreate-dry

    # A directory at the manifest path is unreadable, not absent (audit B N5): the
    # fan-out runs, the manifest is a failed item, the final row is ERROR
    Case-Run manifest-dir { Harness a.md 'rule a'; New-Item -ItemType Directory -Path (Join-Path $script:H ".aitools/rules/.aitools-rules-manifest") -Force | Out-Null }
    Check "manifest is a directory: unreadable, rules fanned out, final row ERROR, exit 1" ($script:rc -eq 1 -and (IsFile (Join-Path (RulesDir) "a.md")) -and (Row 'ERROR|claude rules|cannot read rules manifest') -and (Row 'DETAIL|claude rules|failed: .aitools-rules-manifest') -and (Nondetail) -ceq 'ERROR|claude rules|1 failed' -and -not (OutHas 'No rules manifest'))
    Parity manifest-dir
} finally {
    foreach ($p in @($script:Denied)) {
        try { Undo-Deny $p } catch { Write-Host "      | could not remove the deny entry on ${p}: $($_.Exception.Message)" }
    }
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped" -f $script:pass, $script:fail, $script:skip)
if ($script:fail -ne 0) { exit 1 }
exit 0
