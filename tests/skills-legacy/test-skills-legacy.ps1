# test-skills-legacy.ps1 -- tests for setup-user-skills.ps1 as the fallback
# skills deployer (FD-9, plans/skills-and-rules-fanout.md FO-6), dev path and the
# generated MDM copy that scripts/build-deploy.sh writes into <dotprofile>/deploy/.
# The Windows harness of this suite; tests/skills-legacy/test-skills-legacy.sh is
# the macOS/Linux harness of the same cases for the .sh scripts.
#
# Cases: fallback (no ~/.aitools/skills), fanned out (and dry run, header-bad
# manifest, no dotprofile, resolver error, empty ~/.aitools/skills), pty adopt,
# one writer per row (setup-user-claude, -skills, -cursor in dev order), MDM
# (build-deploy.sh build, the generated setup-user-skills.ps1 run). The case list
# and check names are those of the .sh harness (see its header).
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs the .ps1 scripts with native pwsh on Windows only. Parity
# with the .sh scripts is checked against the committed golden summary rows in
# tests/skills-legacy/golden/, which the .sh harness checks on macOS/Linux
# (Test-GoldenMatch in tests/lib/platform-lib.ps1). build-deploy.sh is an
# all-platform bash script: the MDM build runs it with Git for Windows bash
# (Resolve-TestGitBash), as on every platform. The unreadable (.sh: chmod 000)
# and adopt-failure (.sh: chmod 555) cases run with an ACL deny entry for the
# current user instead (Deny-Access): chmod changes nothing on NTFS, so the old
# Git Bash harness skipped them; each group SKIPs here (one line) only if a
# probe shows a deny right it uses does not block (Test-DenyBlocks). A missing
# git, node, Git Bash or python3 (with pywinpty) skips its cases locally; under
# CI=true it is a failure.
#
# Safe to re-run: every case runs in a child pwsh under its own temp HOME (never
# the real HOME or a real dotprofile), removed on exit. The scripts run from a
# fixture copy of the repo (scripts/ copied unchanged from this checkout,
# shared/skills a fixture); the build runs under an isolated HOME whose
# config.json points at a fixture dotprofile (a git repo in the temp dir). The
# resolver error is a stub (AITOOLS_PROFILE_PS1, the lib's lookup override).
# Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/skills-legacy/test-skills-legacy.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath | Select-Object -Skip 1 | ForEach-Object -Begin { $script:inHeader = $true } -Process { if ($script:inHeader -and $_ -match '^#') { $_ -replace '^# ?', '' } else { $script:inHeader = $false } }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/skills-legacy/test-skills-legacy.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$L = "ps"   # tag of the language under test in case and check names (as on the .sh's Windows run)

$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:OUT = ""

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
# Native { CMD 2>&1 }: runs a native command with stderr merged into the output
# under ErrorActionPreference Continue (under Stop a stderr line, e.g. git init's
# hint, would end the script); the caller checks $LASTEXITCODE
function Native([scriptblock]$Block) { $ErrorActionPreference = "Continue"; & $Block }

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if ($script:OUT -and (Test-Path -LiteralPath $script:OUT -PathType Leaf)) {
        @((Strip (ReadText $script:OUT)) -split "`n") | Select-Object -Last 25 | ForEach-Object { Write-Output "      | $_" }
    }
}
function Skip([string]$Name) { Write-Output "SKIP $Name"; $script:skip++ }
# Need-Skip MSG: cases skipped because a tool is missing. Under CI (CI=true) that
# is a failure: a green CI run must not hide the parity, pty or MDM cases.
function Need-Skip([string]$Name) {
    if ($env:CI -eq "true") { Write-Output "FAIL $Name (a required tool is missing under CI=true)"; $script:fail++ }
    else { Skip $Name }
}

# git builds the fixtures (the .sh also requires perl for itself; this harness
# does not use perl)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    # Get-Command exempt: command-existence check; this branch is the fallback
    if ($env:CI -eq "true") { Write-Output "FAIL all cases (git not found; required under CI=true)"; exit 1 }
    Write-Output "SKIP all cases (git not found)"
    exit 0
}
$haveNode = [bool](Get-Command node -ErrorAction SilentlyContinue)   # existence check
$PTY = Join-Path $root "tests/managed-files/pty-run.py"
$python = Get-Command python3 -ErrorAction SilentlyContinue   # existence check; $null = no pty
$havePty = [bool]$python -and (Test-Path -LiteralPath $PTY -PathType Leaf)
$noPtyWhy = "python3 pty not available"
# Windows pty = pywinpty (ConPTY); the import failing means it is not installed
if ($havePty) {
    $null = Native { & $python.Source -c "import winpty" 2>&1 }
    if ($LASTEXITCODE -ne 0) { $havePty = $false; $noPtyWhy = "pywinpty not installed (scripts/setup-pywinpty.ps1)" }
}
$tmpRoot = New-TestTempRoot "skills-legacy"
$GoldenDir = Join-Path $root "tests/skills-legacy/golden"
$GoldenTmp = $tmpRoot
$W = Join-Path $tmpRoot "work"
New-Item -ItemType Directory -Path $W | Out-Null

# Deny-Access PATH RIGHTS: an ACL deny entry for the current user, the Windows
# equivalent of the .sh's chmod 000 / 555 (chmod changes nothing on NTFS: the old
# Git Bash run skipped these cases). Undo-Deny PATH removes it (the owner may
# always change the ACL). $script:Denied lists the paths still denied, so the
# finally block can undo an interrupted case before the temp root is removed.
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
# Test-DenyBlocks KIND: every deny right a group of ACL cases uses is probed first
# on a throwaway item in the work dir (the .sh's CAN_CHMOD_READ; a deny may not
# block e.g. for a process that reads with backup privilege). $true when the deny
# really blocks here and, once removed, the item works again:
#   read    ReadData on a file: reading it fails (the .sh's chmod 000 on a file)
#   list    ListDirectory on a folder: listing it fails (chmod 000 on a folder)
#   create  CreateFiles, CreateDirectories, DeleteSubdirectoriesAndFiles on a
#           folder: creating a file and a folder in it fails, an existing file
#           in it stays writable (chmod 555 on a folder). Not probed: deleting
#           an existing entry, which this deny does not stop (the entry's own
#           ACL grants DELETE); the case needs only the creates to fail
# A group whose rights do not all block prints one SKIP line instead of FAIL
# lines. The probe items are removed again.
function Test-Succeeds([scriptblock]$Action) {
    # the caught error is the answer: the action was blocked
    try { & $Action; return $true } catch { return $false }
}
function Test-DenyBlocks([ValidateSet("read", "list", "create")][string]$Kind) {
    $dir = Join-Path $W "acl-probe-$Kind"
    $file = Join-Path $dir "item"
    WriteLf $file "x`n"
    $target = $dir
    switch ($Kind) {
        "read" {
            $target = $file; $rights = [Security.AccessControl.FileSystemRights]::ReadData
            $act = { $null = [IO.File]::ReadAllText($file) }
        }
        "list" {
            $rights = [Security.AccessControl.FileSystemRights]::ListDirectory
            $act = { $null = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop) }   # as setup-user-skills.ps1 lists
        }
        "create" {
            # the rights the adopt-failure case denies
            $rights = [Security.AccessControl.FileSystemRights]'CreateFiles, CreateDirectories, DeleteSubdirectoriesAndFiles'
            $act = { [IO.File]::WriteAllText((Join-Path $dir "new"), "x"); $null = [IO.Directory]::CreateDirectory((Join-Path $dir "sub")) }
        }
    }
    $blocks = $false
    try {
        Deny-Access $target $rights
        if ($Kind -eq "create") {
            # each of the two creates fails on its own; the existing file stays writable
            $blocks = -not (Test-Succeeds { [IO.File]::WriteAllText((Join-Path $dir "new"), "x") }) -and
                -not (Test-Succeeds { $null = [IO.Directory]::CreateDirectory((Join-Path $dir "sub")) }) -and
                (Test-Succeeds { [IO.File]::WriteAllText($file, "y`n") })
        } else {
            $blocks = -not (Test-Succeeds $act)
        }
    } catch {
        Write-Host "      | ACL deny not available ($Kind): $($_.Exception.Message)"
    } finally {
        if ($script:Denied.Contains($target)) { Undo-Deny $target }
    }
    if ($blocks -and -not (Test-Succeeds $act)) {
        Write-Host "      | deny probe ($Kind): still blocked after the deny entry was removed"
        $blocks = $false
    }
    try { Remove-Item -LiteralPath $dir -Recurse -Force } catch { Write-Host "      | could not remove the deny probe ${dir}: $($_.Exception.Message)" }
    return $blocks
}

function GitC { & git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false @args }

function Skill([string]$Dir, [string]$Name, [string]$Text) {   # DIR/NAME/SKILL.md holding TEXT
    WriteLf (Join-Path (Join-Path $Dir $Name) "SKILL.md") "---`nname: $Name`n---`n$Text`n"
}

try {
    # The deny probes, inside the try so the finally undoes an interrupted probe
    $denyBlocksRead = Test-DenyBlocks read
    $denyBlocksList = Test-DenyBlocks list
    $denyBlocksCreate = Test-DenyBlocks create

    # --- Fixture dotprofile (a git repo in the temp dir) ---
    $DP = Join-Path $tmpRoot "aitools-tess"
    WriteLf (Join-Path $DP "claude/CLAUDE.md") "# Prefs for {{PROFILE_NAME}}`n`n## Code Style`n`n- keep it simple`n"
    WriteLf (Join-Path $DP "claude/rules/r1.md") "rule one`n"
    WriteLf (Join-Path $DP "profile.json") ('{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}' + "`n")
    Skill (Join-Path $DP "claude/skills") dpskill "dotprofile skill"
    $o = Native { & git -C $DP init -q 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "fixture: git init $DP failed: $o" }
    $o = Native { GitC -C $DP add -A 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "fixture: git add in $DP failed: $o" }
    $o = Native { GitC -C $DP commit -q -m fixture 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "fixture: git commit in $DP failed: $o" }

    # --- Fixture repo: this checkout's scripts/, a known shared/skills ---
    $FR = Join-Path $tmpRoot "repo"
    New-Item -ItemType Directory -Path (Join-Path $FR "shared/skills") -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root "scripts") -Destination (Join-Path $FR "scripts") -Recurse -Force
    Skill (Join-Path $FR "shared/skills") alpha "shared alpha"
    Skill (Join-Path $FR "shared/skills") beta "shared beta"

    # Resolver error stubs: resolve_user_repo_path / Resolve-UserRepoPath return 3
    # (the .ps1 lib reads AITOOLS_PROFILE_PS1; the .sh stub is set too, as before)
    WriteLf (Join-Path $W "fail.sh") "#!/usr/bin/env bash`nprintf `"via\tnone\nerror\tstub resolver failure\n`"`nexit 2`n"
    WriteLf (Join-Path $W "fail.ps1") "`"via``tnone`"`n`"error``tstub resolver failure`"`nexit 2`n"

    # Write-Config HOME_DIR [nodp | DOTPROFILE_DIR]: ~/.aitools/config.json
    # (userRepoPath in C:/... form, as the .sh wrote it with cygpath -m)
    function Write-Config([string]$H, [string]$Mode = "") {
        $f = Join-Path $H ".aitools/config.json"
        if ($Mode -eq "nodp") { WriteLf $f "{`"machineAlias`":`"m1`"}`n"; return }
        $target = if ($Mode) { $Mode } else { $DP }
        WriteLf $f ("{`"userRepoPath`":`"" + (Mixed $target) + "`",`"machineAlias`":`"m1`"}`n")
    }
    # Own-Dotprofile CASE: a copy of the fixture dotprofile for CASE (adopt writes it)
    function Own-Dotprofile([string]$Case) {
        $dst = Join-Path $tmpRoot "dp-$Case"
        # -Force: .git is a hidden directory, which Copy-Item skips without it
        Copy-Item -LiteralPath $DP -Destination $dst -Recurse -Force
        Write-Config (Join-Path $tmpRoot $Case) $dst
    }
    # Seed-Harness HOME_DIR: ~/.aitools/skills as deploy-harness leaves it, plus a
    # ~/.claude/skills holding harness skills, a backup, a retired name and one
    # user-created skill ("mine")
    function Seed-Harness([string]$H) {
        $hs = Join-Path $H ".aitools/skills"; $cs = Join-Path $H ".claude/skills"
        Skill $hs alpha "harness alpha"
        Skill $hs aitskill "aitools project skill"
        Skill $hs CaseSkill "case"
        Skill $hs "old.bak.20261001T000000Z" "harness backup"
        WriteLf (Join-Path $hs ".aitools-skills-manifest") "# aitools skills manifest v1`naitskill`taitools`nalpha`tshared`nCaseSkill`tshared`ngone`tretired`n"
        Skill $cs alpha "user alpha"
        Skill $cs aitskill "fanned out"
        Skill $cs caseskill "fanned out, other case"
        Skill $cs gone "retired, kept by the fan-out"
        Skill $cs "gone.bak.20261020T000000Z" "fan-out backup"
        Skill $cs mine "user-created"
        Retired-Copies $cs
    }
    # Retired-Copies DIR: old aitools copies of skills PR 129 retired before the
    # skills manifest existed (one in another case): never offered for adoption
    function Retired-Copies([string]$Dir) {
        Skill $Dir aitool-ops "old aitools copy"
        Skill $Dir Aitool-Eval "old aitools copy, other case"
    }

    function OutOf([string]$Case) { Join-Path $tmpRoot "$Case.out" }
    function SumOf([string]$Case) { Join-Path $tmpRoot "$Case.summary" }
    $script:RC = @{}
    function RcOf([string]$Case) { $script:RC[$Case] }
    function Row([string]$Case, [string]$Line) { @(Get-Lines (SumOf $Case)) -ccontains $Line }
    function NoRowsFor([string]$Case, [string]$Tool) {
        $re = '^[A-Z]*\|' + [regex]::Escape($Tool) + '\|'
        -not [bool](@(Get-Lines (SumOf $Case)) | Where-Object { $_ -cmatch $re })
    }
    # skill rows: every row except the resolver's own (dotprofile, ACTION), ordinal sort
    function RowsOf([string]$Case) {
        $rows = [string[]]@(Get-Lines (SumOf $Case) | Where-Object { -not $_.StartsWith("ACTION|", [StringComparison]::Ordinal) -and -not $_.Contains("|dotprofile|") })
        [Array]::Sort($rows, [StringComparer]::Ordinal)
        $rows
    }
    function RowsText([string]$Case) { @(RowsOf $Case) -join "`n" }
    # Golden-Rows CASE: the skill rows of CASE ("<lang>-<name>") equal golden/<name>.rows,
    # the same file for the .sh run (macOS/Linux) and the .ps1 run (Windows)
    function Golden-Rows([string]$Case) {
        $name = $Case.Substring($Case.IndexOf('-') + 1)
        $f = Join-Path $tmpRoot "$Case.rows"
        $rows = @(RowsOf $Case)
        WriteLf $f $(if ($rows.Count) { ($rows -join "`n") + "`n" } else { "" })
        Check "golden ${L}: ${name}: summary rows" (Test-GoldenMatch "$name.rows" $f)
    }
    function OutLines([string]$Case) { @((Strip (ReadText (OutOf $Case))) -split "`n") }
    function OutHas([string]$Case, [string]$Pattern) { [bool](@(OutLines $Case) | Where-Object { $_ -cmatch $Pattern }) }
    function Found([string]$Case, [string]$Name) { OutHas $Case ("Found user-created skill: " + [regex]::Escape($Name) + '$') }
    function FoundAnyOf([string]$Case, [string[]]$Names) {   # true when any NAME was offered
        foreach ($n in $Names) { if (Found $Case $n) { return $true } }
        return $false
    }
    # FoundLog CASE TEXT: deploy.log of CASE holds TEXT (a fixed string)
    function FoundLog([string]$Case, [string]$Text) { (ReadText (Join-Path $tmpRoot "$Case/logs/deploy.log")).Contains($Text) }
    # RetiredNotOffered CASE: neither copy offered, the log says why (same text in .sh and .ps1)
    function RetiredNotOffered([string]$Case) {
        (-not (FoundAnyOf $Case @("aitool-ops", "Aitool-Eval"))) -and
            (-not (OutHas $Case 'Would offer to adopt [Aa]itool-')) -and
            (FoundLog $Case 'Not offered for adoption: aitool-ops (an aitools skill retired before the skills manifest existed; delete ~/.claude/skills/aitool-ops if you no longer use it)') -and
            (FoundLog $Case 'Not offered for adoption: Aitool-Eval (an aitools skill retired before the skills manifest existed; delete ~/.claude/skills/Aitool-Eval if you no longer use it)')
    }
    function FileHas([string]$Path, [string]$Text) { (ReadText $Path).Contains($Text) }
    function Exists([string]$Path) { Test-Path -LiteralPath $Path }
    $FANOUT_ROW = 'OK|skills|n/a (fanned out)'

    # Run-Env H SUMMARY: the environment of a run under HOME H. HOME and USERPROFILE
    # get the form Windows itself gives USERPROFILE (C:\..., backslashes: with
    # C:/... the lib's "~/" display of a home path does not match; windows CI run
    # 41265193554, tests/skills-fanout); the log dir and summary file the C:/...
    # form the .sh passed. The variables the .sh unset with env -u are removed.
    function Run-Env([string]$H, [string]$Summary) {
        @{
            AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null; AITOOLS_USER_REPO_PATH = $null; AITOOLS_PROFILE_FILE = $null
            AITOOLS_PROFILE_SH = $null; AITOOLS_PROFILE_PS1 = $null
            HOME = $H; USERPROFILE = $H; AITOOLS_LOG_DIR = (Mixed (Join-Path $H "logs")); AITOOLS_SUMMARY_FILE = (Mixed $Summary)
        }
    }
    # Run-Skills CASE STUB [ARGS...]: setup-user-skills.ps1 (fixture repo) non-interactive;
    # HOME = $tmpRoot/CASE; STUB = live | fail
    function Run-Skills([string]$Case, [string]$Stub, [string[]]$ScriptArgs = @()) {
        $h = Join-Path $tmpRoot $Case
        if (-not (Test-Path -LiteralPath (Join-Path $h ".aitools/config.json"))) { Write-Config $h }
        $script:OUT = OutOf $Case
        WriteLf (SumOf $Case) ""
        $envs = Run-Env $h (SumOf $Case)
        if ($Stub -eq "fail") {
            $envs.AITOOLS_PROFILE_SH = Mixed (Join-Path $W "fail.sh"); $envs.AITOOLS_PROFILE_PS1 = Mixed (Join-Path $W "fail.ps1")
        }
        $argv = @("-NoProfile", "-NonInteractive", "-File", (Join-Path $FR "scripts/setup-user-skills.ps1")) + $ScriptArgs
        $script:RC[$Case] = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile $script:OUT
    }
    # Run-SkillsPty CASE INPUT: as Run-Skills (live resolver), on a pty
    # (tests/managed-files/pty-run.py) with INPUT typed at the prompts
    function Run-SkillsPty([string]$Case, [string]$InputKeys) {
        $h = Join-Path $tmpRoot $Case
        if (-not (Test-Path -LiteralPath (Join-Path $h ".aitools/config.json"))) { Write-Config $h }
        $script:OUT = OutOf $Case
        WriteLf (SumOf $Case) ""
        $argv = @($PTY, "--input", $InputKeys, "--log", $script:OUT, "--", $pwshExe, "-NoProfile", "-File", (Join-Path $FR "scripts/setup-user-skills.ps1"))
        $script:RC[$Case] = Invoke-TestScript -FilePath $python.Source -ArgumentList $argv -Environment (Run-Env $h (SumOf $Case)) -OutFile (Join-Path $tmpRoot "$Case.pty-runner")
    }

    # ---------------------------------------------------------------------------
    # Dev path
    # ---------------------------------------------------------------------------
    foreach ($lang in @($L)) {
        $DRY = "-DryRun"

        # fallback: no ~/.aitools/skills
        $c = "$lang-fallback"
        Skill (Join-Path $tmpRoot "$c/.claude/skills") mine "user-created"
        Retired-Copies (Join-Path $tmpRoot "$c/.claude/skills")
        Run-Skills $c live
        $H = Join-Path $tmpRoot $c
        Check "$lang fallback: exit 0, claude skills and cursor skills rows, no skills row" `
            ((RcOf $c) -eq 0 -and (Row $c 'OK|claude skills|3 added') -and (Row $c 'OK|cursor skills|3 added') -and (NoRowsFor $c skills))
        Check "$lang fallback: shared and dotprofile skills deployed to both tools" `
            ((FileHas (Join-Path $H ".claude/skills/alpha/SKILL.md") 'shared alpha') -and (FileHas (Join-Path $H ".cursor/skills/dpskill/SKILL.md") 'dotprofile skill') -and (Test-Path -LiteralPath (Join-Path $H ".cursor/skills/beta/SKILL.md") -PathType Leaf))
        Check "$lang fallback: reverse discovery finds the user-created skill" (Found $c mine)
        Check "$lang fallback: retired aitool-ops / aitool-eval copies not offered, kept, logged" `
            ((RetiredNotOffered $c) -and (Test-Path -LiteralPath (Join-Path $H ".claude/skills/aitool-ops/SKILL.md") -PathType Leaf))
        Golden-Rows $c

        # fanned out: ~/.aitools/skills exists
        $c = "$lang-fan"
        $H = Join-Path $tmpRoot $c
        Seed-Harness $H
        Run-Skills $c live
        Check "$lang fanned out: exit 0, only the skills n/a row (no claude skills / cursor skills rows)" `
            ((RcOf $c) -eq 0 -and (RowsText $c) -ceq $FANOUT_ROW)
        Check "$lang fanned out: nothing deployed (no ~/.cursor/skills, beta absent, alpha kept)" `
            (-not (Exists (Join-Path $H ".cursor/skills")) -and -not (Exists (Join-Path $H ".claude/skills/beta")) -and -not (Exists (Join-Path $H ".claude/skills/dpskill")) -and (FileHas (Join-Path $H ".claude/skills/alpha/SKILL.md") 'user alpha'))
        Check "$lang fanned out: log names the fan-out owners (same text in .sh and .ps1)" `
            (FoundLog $c 'Skills are fanned out from ~/.aitools/skills by setup-user-claude (claude skills) and setup-user-cursor (cursor skills): not deploying them here')
        Check "$lang fanned out: harness names (entry, manifest, other case) and backups not offered" `
            (-not (FoundAnyOf $c @("alpha", "aitskill", "caseskill", "gone", "gone.bak.20261020T000000Z")))
        Check "$lang fanned out: reverse discovery still finds the user-created skill" (Found $c mine)
        Check "$lang fanned out: retired aitool-ops / aitool-eval copies not offered, kept, logged" `
            ((RetiredNotOffered $c) -and (Test-Path -LiteralPath (Join-Path $H ".claude/skills/Aitool-Eval/SKILL.md") -PathType Leaf))
        Golden-Rows $c

        $c = "$lang-fandry"
        $H = Join-Path $tmpRoot $c
        Seed-Harness $H
        Run-Skills $c live @($DRY)
        Check "$lang fanned out, dry run: n/a row only, nothing written, adoption only previewed" `
            ((RcOf $c) -eq 0 -and (RowsText $c) -ceq $FANOUT_ROW -and -not (Exists (Join-Path $H ".cursor/skills")) -and (OutHas $c 'Would offer to adopt mine') -and -not (OutHas $c 'Would offer to adopt alpha') -and -not (OutHas $c 'Would offer to adopt [Aa]itool-'))

        # header-bad manifest: directory names still count, manifest-only names do not
        $c = "$lang-hbad"
        $H = Join-Path $tmpRoot $c
        Seed-Harness $H
        WriteLf (Join-Path $H ".aitools/skills/.aitools-skills-manifest") "# not a manifest`naitskill`taitools`ngone`tretired`n"
        Run-Skills $c live
        Check "$lang header-bad manifest: exit 0, directory names ignored, manifest-only 'gone' offered" `
            ((RcOf $c) -eq 0 -and (RowsText $c) -ceq $FANOUT_ROW -and -not (FoundAnyOf $c @("alpha", "aitskill")) -and (Found $c gone) -and (OutHas $c 'Skills manifest header not recognised'))
        Golden-Rows $c

        # no dotprofile: nothing can be adopted
        $c = "$lang-nodp"
        $H = Join-Path $tmpRoot $c
        Write-Config $H nodp
        Seed-Harness $H
        Run-Skills $c live
        Check "$lang fanned out, no dotprofile: exit 0, n/a row only, no adoption offered" `
            ((RcOf $c) -eq 0 -and (RowsText $c) -ceq $FANOUT_ROW -and -not (Found $c mine))
        Golden-Rows $c

        # resolver error
        $c = "$lang-rerr"
        Seed-Harness (Join-Path $tmpRoot $c)
        Run-Skills $c fail
        Check "$lang fanned out, resolver error: exit 1, n/a + ERROR skills rows, no fan-out rows, nothing offered" `
            ((RcOf $c) -eq 1 -and (Row $c $FANOUT_ROW) -and (Row $c 'ERROR|skills|no adopt: dotprofile error') -and (NoRowsFor $c 'claude skills') -and (NoRowsFor $c 'cursor skills') -and -not (Found $c mine) -and (FoundLog $c 'Dotprofile unresolved (resolver error above) -- reverse discovery not run, so no skill can be adopted to the dotprofile'))
        Golden-Rows $c
        $c = "$lang-rerrfb"
        Run-Skills $c fail
        Check "$lang fallback, resolver error: today's ERROR claude skills / cursor skills rows, nothing deployed" `
            ((RcOf $c) -eq 1 -and (Row $c 'ERROR|claude skills|not deployed: dotprofile error') -and (Row $c 'ERROR|cursor skills|not deployed: dotprofile error') -and (NoRowsFor $c skills) -and -not (Exists (Join-Path $tmpRoot "$c/.claude/skills")))
        Golden-Rows $c

        # unreadable manifest / harness directory (the .sh: chmod 000; here a
        # deny of ReadData / ListDirectory, see Deny-Access; both probed)
        if ($denyBlocksRead -and $denyBlocksList) {
            $c = "$lang-mfu"
            $H = Join-Path $tmpRoot $c
            Seed-Harness $H
            $p = Join-Path $H ".aitools/skills/.aitools-skills-manifest"
            Deny-Access $p ([Security.AccessControl.FileSystemRights]::ReadData)
            try { Run-Skills $c live } finally { Undo-Deny $p }
            Check "$lang unreadable manifest: exit 1, ERROR skills row, reverse discovery not run" `
                ((RcOf $c) -eq 1 -and (Row $c $FANOUT_ROW) -and (Row $c 'ERROR|skills|no adopt: manifest unreadable') -and -not (Found $c mine) -and (FoundLog $c 'Cannot read the skills manifest ~/.aitools/skills/.aitools-skills-manifest -- reverse discovery not run, so no harness skill is offered for adoption: '))
            Golden-Rows $c
            $c = "$lang-hdu"
            $H = Join-Path $tmpRoot $c
            Seed-Harness $H
            $p = Join-Path $H ".aitools/skills"
            Deny-Access $p ([Security.AccessControl.FileSystemRights]::ListDirectory)
            try { Run-Skills $c live } finally { Undo-Deny $p }
            Check "$lang unreadable ~/.aitools/skills: exit 1, ERROR skills row, reverse discovery not run" `
                ((RcOf $c) -eq 1 -and (Row $c $FANOUT_ROW) -and (Row $c 'ERROR|skills|no adopt: harness unreadable') -and -not (Found $c mine) -and (FoundLog $c 'Cannot read ~/.aitools/skills -- reverse discovery not run, so no harness skill is offered for adoption: '))
            Golden-Rows $c
            # Audit B N1: an unreadable ~/.claude/skills is an error, not an empty scan
            $c = "$lang-dstu"
            $H = Join-Path $tmpRoot $c
            Seed-Harness $H
            $p = Join-Path $H ".claude/skills"
            Deny-Access $p ([Security.AccessControl.FileSystemRights]::ListDirectory)
            try { Run-Skills $c live } finally { Undo-Deny $p }
            Check "$lang unreadable ~/.claude/skills: exit 1, ERROR skills 'no adopt: target unreadable', logged" `
                ((RcOf $c) -eq 1 -and (Row $c $FANOUT_ROW) -and (Row $c 'ERROR|skills|no adopt: target unreadable') -and (NoRowsFor $c 'claude skills') -and -not (Found $c mine) -and (FoundLog $c 'Cannot read ~/.claude/skills -- reverse discovery not run, so no user-created skill is offered for adoption: '))
            Golden-Rows $c
        } else {
            Skip "$lang unreadable cases (a deny ACE does not block reads or listing here)"
        }

        # empty harness: still fanned out (the fan-out gates on the directory too)
        $c = "$lang-empty"
        $H = Join-Path $tmpRoot $c
        New-Item -ItemType Directory -Path (Join-Path $H ".aitools/skills") -Force | Out-Null
        Skill (Join-Path $H ".claude/skills") mine "user-created"
        Run-Skills $c live
        Check "$lang empty ~/.aitools/skills: n/a row only, nothing deployed, user skill still found" `
            ((RcOf $c) -eq 0 -and (RowsText $c) -ceq $FANOUT_ROW -and -not (Exists (Join-Path $H ".cursor/skills")) -and -not (Exists (Join-Path $H ".claude/skills/alpha")) -and (Found $c mine))
        Golden-Rows $c

        # pty: adopt in fan-out mode writes the dotprofile; a failed adopt is a
        # "skills" row (review N1), never "claude skills"
        if ($havePty) {
            $c = "$lang-adopt"
            Own-Dotprofile $c
            Seed-Harness (Join-Path $tmpRoot $c)
            Run-SkillsPty $c 'a\n'
            Check "$lang pty adopt (fanned out): exit 0, mine adopted to the dotprofile, n/a row only" `
                ((RcOf $c) -eq 0 -and (FileHas (Join-Path $tmpRoot "dp-$c/claude/skills/mine/SKILL.md") 'user-created') -and (RowsText $c) -ceq $FANOUT_ROW)
            Golden-Rows $c
            if ($denyBlocksCreate) {
                # the .sh: chmod 555 on the dotprofile's claude/skills; here a deny
                # of creating entries in it (probed: Test-DenyBlocks create)
                $c = "$lang-adoptfail"
                Own-Dotprofile $c
                Seed-Harness (Join-Path $tmpRoot $c)
                $p = Join-Path $tmpRoot "dp-$c/claude/skills"
                Deny-Access $p ([Security.AccessControl.FileSystemRights]'CreateFiles, CreateDirectories, DeleteSubdirectoriesAndFiles')
                try { Run-SkillsPty $c 'a\n' } finally { Undo-Deny $p }
                Check "$lang pty adopt failure (fanned out): exit 1, ERROR skills 'adopt failed: mine', no claude skills row" `
                    ((RcOf $c) -eq 1 -and (Row $c 'ERROR|skills|adopt failed: mine') -and (NoRowsFor $c 'claude skills') -and -not (Exists (Join-Path $tmpRoot "dp-$c/claude/skills/mine")))
                Golden-Rows $c
            } else {
                Skip "$lang pty adopt failure (a deny ACE does not block writes here)"
            }
        } else {
            Need-Skip "$lang pty adopt cases ($noPtyWhy)"
        }
    }

    # ---------------------------------------------------------------------------
    # One writer per row (review N2): a dev-order run (setup-user-claude, then
    # setup-user-skills, then setup-user-cursor) into one summary file writes each
    # skills tool row exactly once -- fallback: "claude skills" and "cursor skills"
    # from setup-user-skills; fanned out: both from the fan-out plus "skills" n/a
    # ---------------------------------------------------------------------------
    # Stub rg and agent first on PATH: setup-user-cursor finds them installed, so no
    # installer runs (as tests/rules-fanout-cursor does); .cmd files, which native
    # pwsh can run.
    $SB = Join-Path $W "stub-bin"
    WriteLf (Join-Path $SB "rg.cmd") "@echo ripgrep 14.1.0`r`n"
    WriteLf (Join-Path $SB "agent.cmd") "@echo 2026.05.21-stub`r`n"
    # Run-DevOrder CASE: the three scripts (the real ones, guards on), one HOME,
    # one summary file
    function Run-DevOrder([string]$Case) {
        $h = Join-Path $tmpRoot $Case
        if (-not (Test-Path -LiteralPath (Join-Path $h ".aitools/config.json"))) { Write-Config $h }
        $out = OutOf $Case
        WriteLf (SumOf $Case) ""; WriteLf $out ""
        $envs = Run-Env $h (SumOf $Case)
        $envs.PATH = $SB + [IO.Path]::PathSeparator + $env:PATH
        $rc = 0
        foreach ($s in @("setup-user-claude", "setup-user-skills", "setup-user-cursor")) {
            $one = Join-Path $tmpRoot "$Case.$s.out"
            $r = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", (Join-Path $FR "scripts/$s.ps1")) -Environment $envs -OutFile $one
            if ($r -ne 0) { $rc = 1 }
            [IO.File]::AppendAllText($out, (ReadText $one))
        }
        $script:RC[$Case] = $rc
        $script:OUT = SumOf $Case   # a failed check shows the rows
    }
    # CountRows CASE TOOL: the status rows (OK / WARN / ERROR, not DETAIL) for TOOL
    function CountRows([string]$Case, [string]$Tool) {
        $re = '^(OK|WARN|ERROR)\|' + [regex]::Escape($Tool) + '\|'
        @(Get-Lines (SumOf $Case) | Where-Object { $_ -cmatch $re }).Count
    }
    foreach ($lang in @($L)) {
        $c = "$lang-order-fb"
        Run-DevOrder $c
        Check "$lang dev order, fallback: claude skills and cursor skills rows once each (from setup-user-skills), no skills row" `
            ((RcOf $c) -eq 0 -and (CountRows $c 'claude skills') -eq 1 -and (CountRows $c 'cursor skills') -eq 1 -and (CountRows $c skills) -eq 0 -and (Row $c 'OK|claude skills|3 added') -and (Row $c 'OK|cursor skills|3 added'))
        $c = "$lang-order-fan"
        $H = Join-Path $tmpRoot $c
        Skill (Join-Path $H ".aitools/skills") alpha "harness alpha"
        WriteLf (Join-Path $H ".aitools/skills/.aitools-skills-manifest") "# aitools skills manifest v1`nalpha`tshared`n"
        Run-DevOrder $c
        Check "$lang dev order, fanned out: claude skills, cursor skills and skills rows once each" `
            ((RcOf $c) -eq 0 -and (CountRows $c 'claude skills') -eq 1 -and (CountRows $c 'cursor skills') -eq 1 -and (CountRows $c skills) -eq 1 -and (Row $c $FANOUT_ROW) -and (FileHas (Join-Path $H ".claude/skills/alpha/SKILL.md") 'harness alpha') -and (FileHas (Join-Path $H ".cursor/skills/alpha/SKILL.md") 'harness alpha'))
    }

    # ---------------------------------------------------------------------------
    # MDM: the generated setup-user-skills.ps1 (build-deploy.sh writes the .sh and
    # the .ps1; the .sh is syntax-checked with Git Bash, the .ps1 parsed and run)
    # ---------------------------------------------------------------------------
    $gitBash = Resolve-TestGitBash
    if (-not $haveNode) {
        Need-Skip "MDM cases (node not found; build-deploy needs it)"
    } elseif (-not $gitBash) {
        Need-Skip "MDM cases (Git for Windows bash not found; build-deploy.sh runs in it)"
    } else {
        $HB = Join-Path $tmpRoot "home-build"
        Write-Config $HB
        $script:OUT = Join-Path $tmpRoot "build.out"
        # build-deploy.sh runs in Git Bash with HOME in MSYS form (the path the bash
        # build itself uses) and USERPROFILE in Windows form: the build's resolver
        # runs aitools-profile.ps1 through pwsh, whose $HOME follows USERPROFILE;
        # without it the resolver read the runner's own home and found no
        # dotprofile (windows CI run 41265193554). AITOOLS_LOG_DIR in MSYS form, as
        # the .sh passed it.
        $benv = @{
            AITOOLS_USER_REPO_PATH = $null; AITOOLS_SUMMARY_FILE = $null; AITOOLS_PROFILE_SH = $null; AITOOLS_PROFILE_PS1 = $null
            HOME = (ConvertTo-MsysPath $HB); USERPROFILE = $HB; AITOOLS_LOG_DIR = (ConvertTo-MsysPath (Join-Path $HB "logs"))
        }
        $buildRc = Invoke-TestScript -FilePath $gitBash -ArgumentList @((ConvertTo-MsysPath (Join-Path $root "scripts/build-deploy.sh"))) -Environment $benv -OutFile $script:OUT
        $G = Join-Path $DP "deploy"
        $gsh = Join-Path $G "setup-user-skills.sh"; $gps = Join-Path $G "setup-user-skills.ps1"
        $shOk = $false
        if ($buildRc -eq 0 -and (Test-Path -LiteralPath $gsh -PathType Leaf) -and (Test-Path -LiteralPath $gps -PathType Leaf)) {
            # -x as Git Bash sees it (the .sh's [ -x ]), then bash -n with the same bash
            $null = Native { & $gitBash -c 'test -x "$1"' _ (ConvertTo-MsysPath $gsh) 2>&1 }
            if ($LASTEXITCODE -eq 0) {
                $synOut = Native { & $gitBash -n (ConvertTo-MsysPath $gsh) 2>&1 }
                if ($LASTEXITCODE -eq 0) { $shOk = $true } else { Write-Host "      | bash -n: $synOut" }
            } else { Write-Host "      | $gsh is not executable for Git Bash" }
        }
        Check "build: exit 0, setup-user-skills.sh/.ps1 generated, bash -n (bash)" $shOk
        Check "build: the generated scripts carry the harness check and gate the embedded deploy" `
            ((FileHas $gsh 'SKILLS_HARNESS_DIR="$HOME/.aitools/skills"') -and (FileHas $gsh 'if [ "$SKILLS_FANNED_OUT" != "true" ]; then') -and (FileHas $gps '$skillsHarnessDir = ') -and (FileHas $gps 'if (-not $skillsFannedOut) {'))

        # One shared skill the build embedded (the real shared/skills of this checkout)
        $SHARED_ONE = ""
        $names = [string[]]@(Get-ChildItem -LiteralPath (Join-Path $root "shared/skills") -Directory | ForEach-Object { $_.Name })
        [Array]::Sort($names, [StringComparer]::Ordinal)
        foreach ($n in $names) {
            if (Test-Path -LiteralPath (Join-Path $root "shared/skills/$n/SKILL.md") -PathType Leaf) { $SHARED_ONE = $n; break }
        }

        # Run-Mdm CASE: the generated script (as built, guard on); HOME = $tmpRoot/CASE
        function Run-Mdm([string]$Case) {
            $h = Join-Path $tmpRoot $Case
            New-Item -ItemType Directory -Path $h -Force | Out-Null
            $script:OUT = OutOf $Case
            WriteLf (SumOf $Case) ""
            $script:RC[$Case] = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $gps) -Environment (Run-Env $h (SumOf $Case)) -OutFile $script:OUT
        }

        # The generated .ps1 is parsed where it runs (Windows)
        $parseErrors = $null
        $parsed = $false
        if (Test-Path -LiteralPath $gps -PathType Leaf) {
            $null = [System.Management.Automation.Language.Parser]::ParseFile($gps, [ref]$null, [ref]$parseErrors)
            $parsed = (@($parseErrors).Count -eq 0)
            if (-not $parsed) { @($parseErrors) | ForEach-Object { Write-Host "      | $($_.Message)" } }
        }
        Check "build: pwsh parser accepts the generated setup-user-skills.ps1" $parsed

        foreach ($lang in @($L)) {
            $c = "mdm-$lang-fb"
            Run-Mdm $c
            $H = Join-Path $tmpRoot $c
            Check "MDM $lang without ~/.aitools/skills: exit 0, embedded skills deployed to both tools ($SHARED_ONE)" `
                ((RcOf $c) -eq 0 -and [bool](@(Get-Lines (SumOf $c)) -cmatch '^OK\|claude skills\|') -and [bool](@(Get-Lines (SumOf $c)) -cmatch '^OK\|cursor skills\|') -and (NoRowsFor $c skills) -and (Test-Path -LiteralPath (Join-Path $H ".claude/skills/$SHARED_ONE/SKILL.md") -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $H ".cursor/skills/$SHARED_ONE/SKILL.md") -PathType Leaf))
            $c = "mdm-$lang-fan"
            $H = Join-Path $tmpRoot $c
            New-Item -ItemType Directory -Path (Join-Path $H ".aitools/skills") -Force | Out-Null
            Run-Mdm $c
            Check "MDM $lang with ~/.aitools/skills: exit 0, only the skills n/a row, nothing deployed" `
                ((RcOf $c) -eq 0 -and (RowsText $c) -ceq $FANOUT_ROW -and -not (Exists (Join-Path $H ".claude/skills")) -and -not (Exists (Join-Path $H ".cursor/skills")))
        }
    }
} finally {
    foreach ($p in @($script:Denied)) {
        try { Undo-Deny $p } catch { Write-Host "      | could not remove the deny entry on ${p}: $($_.Exception.Message)" }
    }
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: ps1 scripts)" -f $script:pass, $script:fail, $script:skip)
if ($script:fail -ne 0) { exit 1 }
exit 0
