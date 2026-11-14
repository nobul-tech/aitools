# test-deploy-harness.ps1 -- tests for scripts/deploy-harness.ps1 (populate
# %USERPROFILE%\.aitools). The Windows harness of this suite;
# tests/deploy-harness/test-deploy-harness.sh is the macOS/Linux harness of the
# same cases for deploy-harness.sh.
#
# Each case builds fixture repos (a git aitools repo holding a copy of
# deploy-harness.ps1 + aitools-lib.ps1, and a git dotprofile) and runs the
# script under an isolated HOME and USERPROFILE in a temp directory, removed on
# exit. Cases: first run, rerun, edit then rerun (non-interactive -> overwrite),
# accept & adopt into the aitools repo (pty), skip (pty), abort (pty, exit 2),
# -Force on a terminal, conflicts (first source wins, ERROR rows, exit 1), dry
# run (no writes), config writer failure (stub and real writer), rules and
# skills from aitools shared/ only (commander 2026-11-06), preserved files, bad
# arguments, -Help, the rules and skills manifests and retired rules and skills,
# rule names with an upper- or mixed-case .md extension, and the lib's manifest
# reader (Read-HarnessManifest).
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs deploy-harness.ps1 with native pwsh on Windows only. Parity
# with deploy-harness.sh: the skills sequence's traces (exit codes, summary
# rows, manifest, tree) must equal the committed golden files
# tests/deploy-harness/golden/skills.trace and skills-readonly.trace, which the
# .sh harness checks on macOS/Linux (Test-GoldenMatch in
# tests/lib/platform-lib.ps1). The other cases check exact rows and files, the
# same expectations as the .sh harness. The read-only and unreadable-file cases
# (chmod 555/000 in the .sh) use NTFS deny ACEs for the current user, and a
# ReadOnly file attribute for the read-only item in a partial backup; a probe
# turns them into SKIP lines where a deny ACE does not block. Not here: the
# executable-bit check (only the .sh sets the bit). Interactive cases use
# tests/managed-files/pty-run.py with pywinpty (python3, else python, that can
# import winpty); skipped without it. The config writer is a stub except in
# the "real writer" case. No case runs bash code.
#
# Safe to re-run: the real HOME, the real repos and the real dotprofile are
# never read or written; every deny ACE is removed again. Exit 1 if any check
# fails.
#
# Usage: pwsh -NoProfile -File tests/deploy-harness/test-deploy-harness.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 39 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/deploy-harness/test-deploy-harness.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$Pty = Join-Path $root "tests/managed-files/pty-run.py"
$tmpRoot = New-TestTempRoot "deploy-harness"
$GoldenDir = Join-Path $root "tests/deploy-harness/golden"
$GoldenTmp = $tmpRoot
$lang = "ps1"
$T = "`t"

$script:pass = 0; $script:fail = 0; $script:skip = 0

# The pty runner's Python: python3, else python, that can import winpty (pywinpty,
# the ConPTY backend of pty-run.py). The Git Bash harness used python3 only; a
# Windows Store alias stub fails the import and is passed over.
$script:Py = $null
foreach ($name in @("python3", "python")) {
    $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { continue }   # not installed: try the next name
    # 2>$null: an ImportError traceback is the "not installed" answer, read from the exit code
    & $cmd.Source -c "import winpty" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $script:Py = $cmd.Source; break }
}
$havePty = [bool]$script:Py -and (Test-Path -LiteralPath $Pty -PathType Leaf)
# Read-only cases: the .sh blocks writes with chmod 555 on a directory and reads
# with chmod 000 on a file (Git Bash's chmod blocks neither on NTFS, so the Git
# Bash harness skipped them). Here an NTFS deny ACE for the current user does the
# same: Deny-Write DIR denies creating files and subdirectories in DIR (this
# directory only; existing files stay writable, as under chmod 555), Deny-Read
# FILE denies reading FILE's data. Every ACE is removed again (Undeny, and in the
# final cleanup). $haveReadonly is set by a probe on a scratch directory, after
# the helpers below: a deny ACE that does not block (the .sh's "root" case)
# leaves the cases as SKIP lines.
$script:Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$script:Denied = [Collections.Generic.List[object]]::new()
$DenyWriteRights = [Security.AccessControl.FileSystemRights]::CreateFiles -bor [Security.AccessControl.FileSystemRights]::CreateDirectories
$DenyReadRights = [Security.AccessControl.FileSystemRights]::ReadData
function Add-Deny([string]$Path, [Security.AccessControl.FileSystemRights]$Rights) {
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($script:Sid, $Rights,
        [Security.AccessControl.InheritanceFlags]::None, [Security.AccessControl.PropagationFlags]::None,
        [Security.AccessControl.AccessControlType]::Deny)
    $acl = Get-Acl -LiteralPath $Path
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $Path -AclObject $acl
    $script:Denied.Add([pscustomobject]@{ Path = $Path; Rule = $rule })
}
function Deny-Write([string]$Dir) { Add-Deny $Dir $DenyWriteRights }    # chmod 555 DIR
function Deny-Read([string]$File) { Add-Deny $File $DenyReadRights }    # chmod 000 FILE
# Undeny PATH: remove the deny ACEs this harness added to PATH (chmod 755 / 644)
function Undeny([string]$Path) {
    foreach ($d in @($script:Denied | Where-Object { $_.Path -eq $Path })) {
        $acl = Get-Acl -LiteralPath $d.Path
        if (-not $acl.RemoveAccessRule($d.Rule)) { throw "Undeny: the deny ACE on $($d.Path) was not found" }
        Set-Acl -LiteralPath $d.Path -AclObject $acl
        [void]$script:Denied.Remove($d)
    }
}
$haveReadonly = $false

function StripAnsi([string]$Text) { ($Text -replace "`e\[[0-9;?]*[A-Za-z]", "") -replace "`r", "" }
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
function W([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text) }   # UTF-8, no BOM, LF as given
function New-Dirs([string[]]$Paths) { foreach ($p in $Paths) { [void][IO.Directory]::CreateDirectory($p) } }   # .NET: [ ] in names are literal

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if ($script:C) {
        $out = Join-Path $script:C "out"
        if (Test-Path -LiteralPath $out -PathType Leaf) {
            @((StripAnsi (ReadText $out)) -split "`n") | Select-Object -Last 30 | ForEach-Object { Write-Output "      | $_" }
        }
    }
}
function Skip([string]$Text) { Write-Output "SKIP $Text"; $script:skip++ }

# FileLines PATH: the lines of PATH (CR removed), as grep sees them; none when absent
function FileLines([string]$Path) {
    $t = (ReadText $Path) -replace "`r", ""
    if ($t -eq "") { return }
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    return @($t -split "`n")
}
# Grep helpers (the .sh's grep calls; patterns are .NET regexes, one line at a time)
function GrepQ([string]$Path, [string]$Pattern, [switch]$I) {
    $opt = if ($I) { [Text.RegularExpressions.RegexOptions]::IgnoreCase } else { [Text.RegularExpressions.RegexOptions]::None }
    foreach ($l in @(FileLines $Path)) { if ([regex]::IsMatch($l, $Pattern, $opt)) { return $true } }
    return $false
}
function GrepC([string]$Path, [string]$Pattern) { @(@(FileLines $Path) | Where-Object { $_ -cmatch $Pattern }).Count }
function GrepX([string]$Path, [string]$Line) { @(FileLines $Path) -ccontains $Line }   # grep -qxF
function GrepF([string]$Path, [string]$Text) { [bool](@(FileLines $Path) | Where-Object { $_.Contains($Text) }) }   # grep -qF
# Same A B: both files exist with the same bytes (cmp -s)
function Same([string]$A, [string]$B) {
    if (-not (Test-Path -LiteralPath $A -PathType Leaf) -or -not (Test-Path -LiteralPath $B -PathType Leaf)) { return $false }
    $x = [IO.File]::ReadAllBytes($A); $y = [IO.File]::ReadAllBytes($B)
    return ($x.Length -eq $y.Length) -and [Linq.Enumerable]::SequenceEqual($x, $y)
}
function Exists([string]$Path) { Test-Path -LiteralPath $Path }
function IsFile([string]$Path) { Test-Path -LiteralPath $Path -PathType Leaf }
function IsDir([string]$Path) { Test-Path -LiteralPath $Path -PathType Container }
# LsNames DIR: entry names as ls lists them (no dot names); LsA DIR: all names (ls -A)
function LsA([string]$Dir) {
    if (-not (IsDir $Dir)) { return }
    foreach ($e in [IO.Directory]::GetFileSystemEntries($Dir)) { [IO.Path]::GetFileName($e) }
}
function LsNames ([string]$Dir) { LsA $Dir | Where-Object { -not $_.StartsWith(".") } }   # not "Ls": ls is an alias
function Lsx([string]$Name) { @(LsNames (Join-Path $script:H ".aitools/rules")) -ccontains $Name }   # exact case
# HasPrefix DIR PREFIX: an entry of DIR starts with PREFIX (ls DIR/PREFIX*)
function HasPrefix([string]$Dir, [string]$Prefix) { [bool](@(LsA $Dir) | Where-Object { $_.StartsWith($Prefix, [StringComparison]::Ordinal) }) }
# FindBak DIR: an entry under DIR (recursive) whose name contains ".bak." (find -name '*.bak.*')
function FindBak([string]$Dir) {
    if (-not (IsDir $Dir)) { return $false }
    [bool]([IO.Directory]::GetFileSystemEntries($Dir, "*", [IO.SearchOption]::AllDirectories) |
        Where-Object { [IO.Path]::GetFileName($_) -cmatch '\.bak\.' })
}

# Gitc ARGS: git with a test identity, in the harness environment (as the .sh's
# gitc). A failure is a FAIL line, not silent (the .sh ignored it).
function Git-Run([string[]]$GitArgs) {
    $ErrorActionPreference = "Continue"
    $o = & git @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Output "FAIL fixture: git $($GitArgs -join ' ') (exit $LASTEXITCODE)"; $script:fail++
        @($o) | ForEach-Object { Write-Output "      | $_" }
    }
}
function Gitc([string[]]$GitArgs) { Git-Run (@("-c", "user.name=test", "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false") + $GitArgs) }

# Lang-Scripts: deploy-harness.ps1, its library and a stub config writer in $R\scripts.
# The stub records its arguments in $USERPROFILE\writer-calls ("called " or
# "called --dry-run", LF) and exits with STUB_WRITER_RC.
function Lang-Scripts {
    Copy-Item -LiteralPath (Join-Path $root "scripts/deploy-harness.ps1"), (Join-Path $root "scripts/aitools-lib.ps1") -Destination (Join-Path $script:R "scripts")
    # Here-strings take this file's line endings (CRLF in a Windows checkout): CRs removed.
    W (Join-Path $script:R "scripts/setup-user-config.ps1") (@'
param([switch]$DryRun, [switch]$Force)
$a = if ($DryRun) { "--dry-run" } else { "" }
[IO.File]::AppendAllText((Join-Path $env:USERPROFILE "writer-calls"), "called $a`n")
$rc = 0; if ($env:STUB_WRITER_RC) { $rc = [int]$env:STUB_WRITER_RC }
exit $rc

'@.Replace("`r", ""))
}

# Setup-Case NAME: fixture aitools repo ($R), dotprofile ($D), HOME ($H) with config.json.
# Deployed: reference 3, registries 1, hooks 2, skills 3 (s1: 2 files, s2), rules 2
# (scratch, hook-lifecycle), bin 3 = 14 files. Never deployed (not harness
# sources): .claude/skills/s3, .claude/rules/{p1,p2}.md, the dotprofile
# claude/rules/user1.md. The .sh's chmod +x has no Windows counterpart (git
# keeps 100644 with core.filemode false either way).
function Setup-Case([string]$Name) {
    $script:C = Join-Path $tmpRoot $Name
    $script:R = Join-Path $script:C "repo"; $script:D = Join-Path $script:C "dot"; $script:H = Join-Path $script:C "home"
    $R = $script:R; $D = $script:D
    New-Dirs @("$R\scripts", "$R\reference\evaluations", "$R\registries", "$R\shared\hooks",
        "$R\shared\skills\s1\tests", "$R\shared\skills\s2", "$R\.claude\skills\s3",
        "$R\shared\rules", "$R\.claude\rules", "$D\claude\rules", "$($script:H)\.aitools", "$($script:C)\logs")
    Lang-Scripts
    foreach ($f in @("harness-db.py", "read-session.py", "read-session-full.py")) {
        W "$R\scripts\$f" "#!/usr/bin/env python3`nprint(`"$f`")`n"
    }
    W "$R\reference\harness.md" "# Harness`n`nsource text`n"
    W "$R\reference\notes.md" "notes`n"
    W "$R\reference\evaluations\e.md" "eval`n"
    W "$R\registries\r.json" "{`n  `"a`": 1,`n  `"b`": [1, 2]`n}`n"
    W "$R\shared\hooks\h1.sh" "#!/usr/bin/env bash`necho hook`n"
    W "$R\shared\hooks\h1.sh.bak.2026-01-01T000000Z" "old copy`n"
    W "$R\shared\hooks\hooks-manifest.json" "{`"hooks`": []}`n"
    W "$R\shared\skills\s1\SKILL.md" "skill one`n"
    W "$R\shared\skills\s1\tests\t.md" "skill one test`n"
    W "$R\shared\skills\s2\SKILL.md" "skill two`n"
    W "$R\.claude\skills\s3\SKILL.md" "skill three`n"
    W "$R\shared\rules\scratch.md" "shared scratch rule`n"
    W "$R\shared\rules\hook-lifecycle.md" "shared hook lifecycle`n"
    W "$R\.claude\rules\p1.md" "project rule`n"
    W "$R\.claude\rules\p2.md" "project rule two`n"
    Git-Run @("-C", $R, "init", "-q")
    Gitc @("-C", $R, "add", "-A")
    Gitc @("-C", $R, "commit", "-q", "-m", "fixture")
    W "$R\reference\untracked.md" "untracked`n"
    W "$D\claude\rules\user1.md" "user rule`n"
    Git-Run @("-C", $D, "init", "-q")
    Gitc @("-C", $D, "add", "-A")
    Gitc @("-C", $D, "commit", "-q", "-m", "fixture")
    Write-Config $D
}

# Write-Config USER_REPO_PATH: config.json with forward-slash native paths
# (C:/...), as the Git Bash harness wrote them (cygpath -m); no JSON escaping needed.
function Write-Config([string]$UserRepo) {
    $m = { param($p) $p -replace '\\', '/' }
    W (Join-Path $script:H ".aitools/config.json") ("{`n  `"version`": 3,`n  `"reposPath`": `"$(& $m $script:C)`",`n  `"repoPath`": `"$(& $m $script:R)`",`n  `"userRepoPath`": `"$(& $m $UserRepo)`"`n}`n")
}

# Post-Run: CRs removed from the summary and the console output; $LOG is the
# deploy log with CRs removed and \ turned into / (log lines name native paths).
function Post-Run {
    foreach ($f in @("summary", "out")) {
        $p = Join-Path $script:C $f
        if (IsFile $p) { W $p ((ReadText $p) -replace "`r", "") }
    }
    $script:LOG = Join-Path $script:C "deploy.log.txt"
    $dl = Join-Path $script:C "logs/deploy.log"
    if (IsFile $dl) { W $script:LOG (((ReadText $dl) -replace "`r", "") -replace '\\', '/') } else { W $script:LOG "" }
}

# Run-DH INPUT [ARGS] [EXTRA]: run deploy-harness.ps1 under the case HOME and
# USERPROFILE. INPUT "": non-interactive (stdin at EOF). Otherwise on a
# pseudo-terminal (pty-run.py) with these keystrokes (\n escapes, decoded by
# pty-run.py). EXTRA: more environment variables for this run.
# AITOOLS_FORCE and AITOOLS_DRY_RUN are removed unless EXTRA sets them.
function Run-DH([string]$Keys = "", [string[]]$DhArgs = @(), [hashtable]$Extra = @{}) {
    $C = $script:C
    W (Join-Path $C "summary") ""
    $envs = @{
        HOME = $script:H; USERPROFILE = $script:H
        AITOOLS_LOG_DIR = (Join-Path $C "logs"); AITOOLS_SUMMARY_FILE = (Join-Path $C "summary")
        AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null
    }
    foreach ($k in $Extra.Keys) { $envs[$k] = $Extra[$k] }
    $dh = Join-Path $script:R "scripts\deploy-harness.ps1"
    if (-not $Keys) {
        $argv = @("-NoProfile", "-NonInteractive", "-File", $dh) + $DhArgs
        $script:rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile (Join-Path $C "out")
    } else {
        # No -NonInteractive: the review menu reads the terminal (as the .sh harness ran it).
        # pty-run.py writes the terminal output to out; its own messages go to pty-run.txt.
        $argv = @($Pty, "--input", $Keys, "--log", (Join-Path $C "out"), "--", $pwshExe, "-NoProfile", "-File", $dh) + $DhArgs
        $script:rc = Invoke-TestScript -FilePath $script:Py -ArgumentList $argv -Environment $envs -OutFile (Join-Path $C "pty-run.txt")
    }
    Post-Run
}

function Row([string]$Line) { GrepX (Join-Path $script:C "summary") $Line }      # exact summary row
function HasRow([string]$Text) { GrepF (Join-Path $script:C "summary") $Text }   # summary substring
function A { Join-Path $script:H ".aitools" }
function Fresh-Log { New-Dirs @((Join-Path $script:C "logs")); W (Join-Path $script:C "logs/deploy.log") "" }   # the log accumulates across the runs of a case

try {
    # The read-only probe: Deny-Write must stop a new file and a new directory,
    # Deny-Read must stop File.Copy (what deploy-harness.ps1 does), and Undeny
    # must give both back.
    $probe = Join-Path $tmpRoot "acl-probe"
    New-Dirs @($probe)
    W "$probe\secret.md" "secret`n"
    $blocked = 0
    Deny-Write $probe
    try { W "$probe\new.txt" "x" } catch { $blocked++ }
    try { [void][IO.Directory]::CreateDirectory("$probe\sub") } catch { $blocked++ }
    Undeny $probe
    Deny-Read "$probe\secret.md"
    try { [IO.File]::Copy("$probe\secret.md", "$probe\copy.md") } catch { $blocked++ }
    Undeny "$probe\secret.md"
    W "$probe\new2.txt" "x"
    [IO.File]::Copy("$probe\secret.md", "$probe\copy2.md")
    $haveReadonly = ($blocked -eq 3)

    # ---------------------------------------------------------------------------
    # First run, rerun, edit then rerun
    # ---------------------------------------------------------------------------
    Setup-Case first
    Run-DH
    Check "first run: exit 0" ($rc -eq 0)
    Check "first run: six directories exist" ((IsDir "$(A)\reference") -and (IsDir "$(A)\registries") -and (IsDir "$(A)\hooks") -and (IsDir "$(A)\rules") -and (IsDir "$(A)\skills") -and (IsDir "$(A)\bin"))
    Check "first run: one OK row, 14 added" (Row 'OK|harness files|14 added')
    Check "first run: no ERROR row" (-not (GrepQ "$C\summary" '^ERROR\|'))
    Check "first run: config writer called without flags" (GrepX "$H\writer-calls" 'called ')
    Check "first run: reference tree kept (nested path)" (Same "$R\reference\evaluations\e.md" "$(A)\reference\evaluations\e.md")
    Check "first run: registries deployed (JSON)" (Same "$R\registries\r.json" "$(A)\registries\r.json")
    Check "first run: untracked file not deployed" (-not (Exists "$(A)\reference\untracked.md"))
    Check "first run: tracked *.bak.* not deployed" (-not (Exists "$(A)\hooks\h1.sh.bak.2026-01-01T000000Z"))
    Check "first run: hooks flat" ((IsFile "$(A)\hooks\h1.sh") -and (IsFile "$(A)\hooks\hooks-manifest.json"))
    Check "first run: skills are directories (all files)" ((IsFile "$(A)\skills\s1\SKILL.md") -and (IsFile "$(A)\skills\s1\tests\t.md") -and (IsFile "$(A)\skills\s2\SKILL.md"))
    Check "first run: rules flat from shared/rules" ((IsFile "$(A)\rules\scratch.md") -and (IsFile "$(A)\rules\hook-lifecycle.md"))
    Check "first run: .claude/skills, .claude/rules and dotprofile rules not deployed" (-not (Exists "$(A)\skills\s3") -and -not (Exists "$(A)\rules\p1.md") -and -not (Exists "$(A)\rules\p2.md") -and -not (Exists "$(A)\rules\user1.md"))
    Check "first run: no .claude/rules, .claude/skills or dotprofile source looked at" (-not (GrepQ $LOG 'Source (\.claude/(rules|skills)|dotprofile)') -and -not (GrepQ $LOG 'dotprofile' -I))
    Check "first run: bin CLIs deployed" ((IsFile "$(A)\bin\harness-db.py") -and (IsFile "$(A)\bin\read-session-full.py"))
    # (The .sh's "first run sh: hooks and bin CLIs executable": only the .sh sets the bit.)
    Check "first run: missing .claude/hooks is info, not error" (GrepQ $LOG '\[info\] Source .claude/hooks not found')

    Run-DH
    Check "rerun: exit 0, everything verified" ($rc -eq 0 -and (Row 'OK|harness files|14 verified'))
    Check "rerun: no backups made" (-not (FindBak (A)))

    W "$(A)\rules\scratch.md" "local edit`n"
    Run-DH
    Check "edit then rerun (non-interactive): source overwrites, backup kept" ($rc -eq 0 -and (Same "$R\shared\rules\scratch.md" "$(A)\rules\scratch.md") -and (HasPrefix "$(A)\rules" "scratch.md.bak."))
    Check "edit then rerun: counted as updated" (HasRow 'harness files|1 updated')
    Check "edit then rerun: backup is not reported as preserved" (-not (GrepQ $LOG 'Preserved: .*scratch.md.bak'))

    W "$(A)\rules\mine.md" "mine`n"
    Run-DH
    Check "preserved: file with no source kept and logged" ((IsFile "$(A)\rules\mine.md") -and (GrepQ $LOG 'Preserved: .*rules/mine.md'))

    # reference/ and registries/ are read-only copies: source wins, backup kept, no warning
    Setup-Case readonly
    Run-DH
    W "$(A)\reference\harness.md" "# Harness`n`nlocal edit`n"
    W "$(A)\registries\r.json" "{`"a`": 9}`n"
    Run-DH
    Check "read-only copies: reference and registries overwritten from source" ($rc -eq 0 -and (Same "$R\reference\harness.md" "$(A)\reference\harness.md") -and (Same "$R\registries\r.json" "$(A)\registries\r.json"))
    Check "read-only copies: backups kept" ((HasPrefix "$(A)\reference" "harness.md.bak.") -and (HasPrefix "$(A)\registries" "r.json.bak."))
    Check "read-only copies: OK row (no warning), logged as read-only" ((Row 'OK|harness files|2 updated, 12 verified') -and (GrepC $LOG 'read-only copy: source wins, backup kept') -eq 2 -and -not (GrepQ $LOG '\[warn\]'))

    # ---------------------------------------------------------------------------
    # Interactive (pty): adopt, skip, abort, -Force
    # ---------------------------------------------------------------------------
    # No-Menu: the console output shows no review menu (ANSI sequences removed)
    function No-Menu { -not (StripAnsi (ReadText (Join-Path $script:C "out"))).Contains('choice [') }
    if ($havePty) {
        Setup-Case adopt
        Run-DH
        W "$(A)\rules\scratch.md" "local edit`n"
        Run-DH 'a\n'
        Check "adopt: exit 0" ($rc -eq 0)
        Check "adopt: LOCAL kept and copied to the repo source" ((GrepX "$(A)\rules\scratch.md" 'local edit') -and (GrepX "$R\shared\rules\scratch.md" 'local edit'))
        Check "adopt: aitools repo target left uncommitted and logged, no protected-file WARN" ((GrepQ $LOG 'Uncommitted change in .*: scratch.md') -and -not (GrepQ $LOG 'Adopted into protected file'))
        Check "adopt: DETAIL row" (GrepQ "$C\summary" '^DETAIL\|harness files\|accept & adopt: ')
        Run-DH
        Check "adopt: next run verifies; repo backup not deployed" ((Row 'OK|harness files|14 verified') -and -not (FindBak "$(A)\rules"))

        Setup-Case readonly-pty
        Run-DH
        W "$(A)\reference\harness.md" "# Harness`n`nlocal edit`n"
        W "$(A)\registries\r.json" "{`"a`": 9}`n"
        Run-DH 'a\na\n'
        Check "read-only copies on a terminal: no menu, source wins, nothing adopted" ($rc -eq 0 -and (No-Menu) -and (Same "$R\reference\harness.md" "$(A)\reference\harness.md") -and (Same "$R\registries\r.json" "$(A)\registries\r.json") -and -not (GrepQ "$R\reference\harness.md" 'local edit'))

        Setup-Case skip
        Run-DH
        W "$(A)\skills\s2\SKILL.md" "local edit`n"
        Run-DH 's\n'
        Check "skip: nothing written, WARN row" ($rc -eq 0 -and (GrepX "$(A)\skills\s2\SKILL.md" 'local edit') -and (Row 'WARN|harness files|1 skipped (user review)'))

        Setup-Case abort
        Run-DH
        W "$(A)\hooks\h1.sh" "local edit`n"
        Run-DH 'x\n'
        Check "abort: exit 2, file unchanged" ($rc -eq 2 -and (GrepX "$(A)\hooks\h1.sh" 'local edit'))

        Setup-Case force
        Run-DH
        W "$(A)\rules\hook-lifecycle.md" "local edit`n"
        Run-DH 'a\n' @('-Force')
        Check "--force on a terminal: overwrite, no menu" ($rc -eq 0 -and (Same "$R\shared\rules\hook-lifecycle.md" "$(A)\rules\hook-lifecycle.md") -and (No-Menu))
        W "$(A)\rules\hook-lifecycle.md" "local edit`n"
        Run-DH 'a\n' @() @{ AITOOLS_FORCE = "1" }
        Check "AITOOLS_FORCE=1 on a terminal: overwrite, no menu" ($rc -eq 0 -and (Same "$R\shared\rules\hook-lifecycle.md" "$(A)\rules\hook-lifecycle.md") -and (No-Menu))
    } else {
        Skip "interactive cases (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)"
    }

    # ---------------------------------------------------------------------------
    # Conflicts: first source wins, one ERROR row per skipped duplicate, exit 1
    # ---------------------------------------------------------------------------
    # Hooks still have two sources (shared/hooks, then .claude/hooks). Rules and
    # skills of the same name in .claude/ or the dotprofile are not sources: no
    # duplicate, nothing deployed from them.
    Setup-Case conflict
    New-Dirs @("$R\.claude\hooks", "$R\.claude\skills\s1")
    W "$R\.claude\hooks\h1.sh" "#!/usr/bin/env bash`necho project hook`n"
    W "$R\.claude\hooks\Hooks-Manifest.json" "{`"Hooks`": []}`n"
    W "$R\.claude\skills\s1\SKILL.md" "project skill one`n"
    W "$R\.claude\rules\scratch.md" "project scratch rule`n"
    Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "dups")
    W "$D\claude\rules\scratch.md" "dotprofile scratch rule`n"
    W "$D\claude\rules\Hook-Lifecycle.md" "dotprofile lifecycle`n"
    Gitc @("-C", $D, "add", "-A"); Gitc @("-C", $D, "commit", "-q", "-m", "dups")
    Run-DH
    Check "conflict: exit 1" ($rc -eq 1)
    Check "conflict: ERROR row per duplicate (hooks), none for .claude/ or dotprofile rules and skills" ((Row 'ERROR|harness files|h1.sh: dup in .claude/hooks') -and (Row 'ERROR|harness files|Hooks-Manifest.json: dup in...') -and (GrepC "$C\summary" '^ERROR\|') -eq 2)
    Check "conflict: log_error names both sources" (GrepQ $LOG '\[error\] Duplicate hooks name: h1.sh in .claude/hooks .* kept h1.sh from shared/hooks')
    Check "conflict: first source wins (hooks); shared rules and skills deployed" ((Same "$R\shared\hooks\h1.sh" "$(A)\hooks\h1.sh") -and (Same "$R\shared\rules\scratch.md" "$(A)\rules\scratch.md") -and (Same "$R\shared\rules\hook-lifecycle.md" "$(A)\rules\hook-lifecycle.md") -and (Same "$R\shared\skills\s1\SKILL.md" "$(A)\skills\s1\SKILL.md"))
    Check "conflict: case-insensitive duplicate not deployed" ((GrepQ "$(A)\hooks\hooks-manifest.json" '"hooks"') -and -not (@(LsNames "$(A)\hooks") -ccontains 'Hooks-Manifest.json') -and -not (@(LsNames "$(A)\rules") -ccontains 'Hook-Lifecycle.md'))
    Check "conflict: other files still deployed" ((IsFile "$(A)\skills\s2\SKILL.md") -and (IsFile "$(A)\skills\s1\tests\t.md"))

    # ---------------------------------------------------------------------------
    # Dry run: report, write nothing
    # ---------------------------------------------------------------------------
    Setup-Case dryrun
    Run-DH "" @('-DryRun')
    Check "dry run: exit 0, counts" ($rc -eq 0 -and (Row 'OK|harness files|dry-run: 14 create, 0 update'))
    Check "dry run: no harness directory created" (-not (Exists "$(A)\reference") -and -not (Exists "$(A)\rules") -and -not (Exists "$(A)\bin"))
    Check "dry run: config writer called with --dry-run" (GrepX "$H\writer-calls" 'called --dry-run')
    Run-DH
    W "$(A)\rules\hook-lifecycle.md" "local edit`n"
    Run-DH "" @() @{ AITOOLS_DRY_RUN = "1" }
    Check "AITOOLS_DRY_RUN=1: would update 1, file untouched" ((Row 'OK|harness files|dry-run: 0 create, 1 update') -and (GrepX "$(A)\rules\hook-lifecycle.md" 'local edit'))

    # ---------------------------------------------------------------------------
    # config.json writer failures
    # ---------------------------------------------------------------------------
    Setup-Case writerfail
    Run-DH "" @() @{ STUB_WRITER_RC = "1" }
    Check "writer failure: exit 1, ERROR row, files still deployed" ($rc -eq 1 -and (Row 'ERROR|harness files|config.json not generated') -and (IsFile "$(A)\rules\scratch.md"))

    Setup-Case realwriter
    Copy-Item -LiteralPath (Join-Path $root "scripts/setup-user-config.ps1"), (Join-Path $root "scripts/aitools-profile.ps1"), (Join-Path $root "scripts/aitools-json.ps1") -Destination "$R\scripts" -Force
    Remove-Item -LiteralPath "$H\.aitools\config.json" -Force
    Run-DH
    Check "real writer, no bootstrap config: exit 1, ERROR row propagated" ($rc -eq 1 -and (Row 'ERROR|harness files|config.json not generated') -and (GrepQ $LOG '\[setup-user-config\] \[error\]'))

    # ---------------------------------------------------------------------------
    # The dotprofile is not a harness source: missing or not a git checkout changes nothing
    # ---------------------------------------------------------------------------
    Setup-Case nodot
    Write-Config "$C\no-such-dotprofile"
    Run-DH
    Check "missing dotprofile: exit 0, 14 added, not mentioned" ($rc -eq 0 -and (Row 'OK|harness files|14 added') -and -not (GrepQ $LOG 'dotprofile' -I))

    Setup-Case nogitdot
    Remove-Item -LiteralPath "$D\.git" -Recurse -Force
    Run-DH
    Check "dotprofile not in git: exit 0, no ERROR row, its rules not deployed" ($rc -eq 0 -and -not (GrepQ "$C\summary" '^ERROR\|') -and (Row 'OK|harness files|14 added') -and -not (Exists "$(A)\rules\user1.md"))

    # ---------------------------------------------------------------------------
    # Rules manifest (~/.aitools/rules/.aitools-rules-manifest) and retired rules
    # ---------------------------------------------------------------------------
    function M { Join-Path $script:H ".aitools/rules/.aitools-rules-manifest" }
    # MfIs HEADER LINE... -- the manifest file is exactly the header + these lines (LF, in order)
    function ManifestIs([string]$Path, [string]$Header, [string[]]$Lines) {
        $want = [Text.Encoding]::UTF8.GetBytes((@($Header) + $Lines | ForEach-Object { "$_`n" }) -join "")
        if (-not (IsFile $Path)) { return $false }
        $got = [IO.File]::ReadAllBytes($Path)
        return ($got.Length -eq $want.Length) -and [Linq.Enumerable]::SequenceEqual($got, $want)
    }
    function MfIs([string[]]$Lines) { ManifestIs (M) '# aitools rules manifest v1' $Lines }
    $firstMf = @("hook-lifecycle.md${T}shared", "scratch.md${T}shared")

    Setup-Case manifest
    New-Dirs @("$(A)\rules")
    W "$(A)\rules\old.md" "left over`n"
    W "$R\shared\rules\x.bak.1.md" "backup copy`n"
    Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "bak")
    Run-DH
    Check "manifest: first run writes it (header, sorted, winning sources)" ($rc -eq 0 -and (MfIs $firstMf))
    $mb = if (IsFile (M)) { [IO.File]::ReadAllBytes((M)) } else { [byte[]]@() }
    Check "manifest: LF, no BOM" (($mb -notcontains [byte]13) -and $mb.Length -ge 3 -and [Text.Encoding]::ASCII.GetString($mb, 0, 3) -ceq '# a')
    Check "manifest: first run (no previous manifest) retires nothing" ((IsFile "$(A)\rules\old.md") -and (GrepQ $LOG 'Preserved: .*rules/old.md') -and -not (GrepQ $LOG 'Retired rule'))
    Check "manifest: *.bak.* never listed, manifest itself not preserved" (-not (GrepQ (M) 'bak') -and -not (GrepQ $LOG 'Preserved: .*aitools-rules-manifest') -and -not (Exists "$(M).tmp"))
    Check "manifest: no .md extension (consumers copying *.md skip it)" ((IsFile (M)) -and -not (@(LsNames "$(A)\rules") | Where-Object { $_ -cmatch 'manifest.*\.md' }))

    Gitc @("-C", $R, "rm", "-q", "shared/rules/scratch.md"); Gitc @("-C", $R, "commit", "-q", "-m", "retire")
    Fresh-Log
    Run-DH
    Check "retire: exit 0, line becomes retired" ($rc -eq 0 -and (MfIs @("hook-lifecycle.md${T}shared", "scratch.md${T}retired")))
    Check "retire: file backed up and removed, logged, DETAIL row" (-not (Exists "$(A)\rules\scratch.md") -and (HasPrefix "$(A)\rules" "scratch.md.bak.") -and (GrepQ $LOG 'Retired rule: scratch.md \(was shared') -and (Row 'DETAIL|harness files|retired: rules/scratch.md'))
    Check "retire: a file never in a manifest is still preserved" (IsFile "$(A)\rules\old.md")
    Fresh-Log
    Run-DH
    Check "retired line persists; no new backup, no row" ($rc -eq 0 -and (GrepX (M) "scratch.md${T}retired") -and @(@(LsNames "$(A)\rules") | Where-Object { $_ -cmatch '^scratch.md.bak' }).Count -eq 1 -and -not (HasRow 'retired:'))
    W "$(A)\rules\scratch.md" "scratch again`n"
    Run-DH
    $againBak = [bool](@(LsA "$(A)\rules") | Where-Object { $_.StartsWith("scratch.md.bak.", [StringComparison]::Ordinal) -and (GrepQ "$(A)\rules\$_" 'scratch again') })
    Check "retired name's file found again: backed up and removed" (-not (Exists "$(A)\rules\scratch.md") -and $againBak -and (GrepX (M) "scratch.md${T}retired"))
    W "$R\shared\rules\scratch.md" "shared scratch again`n"
    Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "back")
    Run-DH
    Check "reappearing name returns to its source and is deployed" ($rc -eq 0 -and (GrepX (M) "scratch.md${T}shared") -and (GrepX "$(A)\rules\scratch.md" 'shared scratch again'))

    # Migration from the three-source harness: a previous manifest (and
    # ~/.aitools/rules) still holds rules deployed from aitools .claude/rules
    # ("aitools") and the dotprofile ("dotprofile"). Both sources are withdrawn:
    # their names are retired on the next run, although neither is listed, and
    # whether or not the dotprofile exists.
    function Seed-WithdrawnRules {
        W (M) "# aitools rules manifest v1`nhook-lifecycle.md`tshared`np1.md`taitools`np2.md`taitools`nscratch.md`tshared`nuser1.md`tdotprofile`n"
        W "$(A)\rules\p1.md" "project rule`n"
        W "$(A)\rules\p2.md" "project rule two`n"
        W "$(A)\rules\user1.md" "user rule`n"
    }
    Seed-WithdrawnRules
    Fresh-Log
    Run-DH "" @('-DryRun')
    Check "withdrawn sources, dry run: retirement reported, nothing removed or written" ($rc -eq 0 -and (IsFile "$(A)\rules\p1.md") -and (IsFile "$(A)\rules\user1.md") -and (GrepX (M) "p1.md${T}aitools") -and (GrepX (M) "user1.md${T}dotprofile") -and (GrepQ $LOG 'DRY RUN\] Would back up and remove .*rules/user1.md') -and (GrepQ $LOG 'DRY RUN\] Would back up and remove .*rules/p1.md'))
    Fresh-Log
    Run-DH
    Check "withdrawn sources: aitools and dotprofile names retired (backed up, removed), DETAIL rows" ($rc -eq 0 -and (MfIs @("hook-lifecycle.md${T}shared", "p1.md${T}retired", "p2.md${T}retired", "scratch.md${T}shared", "user1.md${T}retired")) -and -not (Exists "$(A)\rules\p1.md") -and -not (Exists "$(A)\rules\p2.md") -and -not (Exists "$(A)\rules\user1.md") -and (HasPrefix "$(A)\rules" "user1.md.bak.") -and (HasPrefix "$(A)\rules" "p1.md.bak.") -and (Row 'DETAIL|harness files|retired: rules/p1.md') -and (Row 'DETAIL|harness files|retired: rules/user1.md') -and (GrepQ $LOG 'Retired rule: user1.md \(was dotprofile') -and (GrepQ $LOG 'Retired rule: p1.md \(was aitools'))
    Check "withdrawn sources: shared rules untouched" ((IsFile "$(A)\rules\scratch.md") -and (IsFile "$(A)\rules\hook-lifecycle.md") -and -not (@(LsNames "$(A)\rules") | Where-Object { $_ -cmatch '^hook-lifecycle.md.bak' }))
    Seed-WithdrawnRules
    Write-Config "$C\no-such-dotprofile"
    Fresh-Log
    Run-DH
    Check "withdrawn sources, no dotprofile configured: retired all the same" ($rc -eq 0 -and (GrepX (M) "user1.md${T}retired") -and (GrepX (M) "p1.md${T}retired") -and -not (Exists "$(A)\rules\user1.md") -and -not (GrepQ $LOG 'kept as'))
    Write-Config $D

    # A source that is not listed this run keeps its names (shared/rules missing)
    Gitc @("-C", $R, "rm", "-q", "-r", "shared/rules"); Gitc @("-C", $R, "commit", "-q", "-m", "no-shared-rules")
    Fresh-Log
    Run-DH
    Check "source not listed (shared/rules missing): its names keep their lines, files kept" ($rc -eq 0 -and (GrepX (M) "scratch.md${T}shared") -and (IsFile "$(A)\rules\scratch.md") -and (GrepQ $LOG 'scratch.md kept as shared') -and (GrepQ $LOG 'Source shared/rules not found'))
    Gitc @("-C", $R, "checkout", "-q", "HEAD~1", "--", "shared/rules"); Gitc @("-C", $R, "commit", "-q", "-m", "shared-rules-back")

    W (M) "# aitools rules manifest v1`nScratch.md`tshared`nHOOK-LIFECYCLE.md`taitools`n"
    Fresh-Log
    Run-DH
    Check "names compared case-insensitively: a case variant is not retired (withdrawn source too)" ($rc -eq 0 -and (IsFile "$(A)\rules\scratch.md") -and (IsFile "$(A)\rules\hook-lifecycle.md") -and -not (GrepQ $LOG 'Retired rule') -and -not (GrepQ (M) 'Scratch.md') -and -not (GrepQ (M) 'HOOK-LIFECYCLE'))
    W (M) "not a manifest`nold.md`tshared`n"
    Fresh-Log
    Run-DH
    Check "unknown header: warning, nothing retired, rewritten" ((IsFile "$(A)\rules\old.md") -and (GrepQ $LOG '\[warn\] Rules manifest .*the first line is not') -and @(FileLines (M))[0] -ceq '# aitools rules manifest v1' -and -not (GrepQ (M) '^old.md'))
    W (M) "# aitools rules manifest v1`n../evil.md`tshared`nnotes.txt`tshared`nz.md`tbogus`n"
    W "$(A)\evil.md" "keep me`n"    # where rules/../evil.md resolves
    Fresh-Log
    Run-DH
    Check "invalid lines ignored with a warning (no path outside rules/)" ((IsFile "$(A)\evil.md") -and (GrepC $LOG 'line ignored') -eq 3 -and -not (GrepQ (M) 'evil'))
    New-Dirs @("$(A)\rules\d.md")
    W "$(A)\rules\d.md\f" "inside`n"
    W (M) "# aitools rules manifest v1`nd.md`tretired`n"
    Fresh-Log
    Run-DH
    Check "a directory named like a retired rule is left alone" ($rc -eq 0 -and (IsFile "$(A)\rules\d.md\f") -and (GrepX (M) "d.md${T}retired"))

    # Retirement edge cases on a fresh case: a name with [ ], then (POSIX only) a
    # failed backup and the retry
    Setup-Case retire
    W "$R\shared\rules\a[1].md" "bracket`n"
    Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "bracket")
    Run-DH
    Gitc @("-C", $R, "rm", "-q", "shared/rules/a[1].md"); Gitc @("-C", $R, "commit", "-q", "-m", "bracket-gone")
    Fresh-Log; Run-DH
    Check "${lang}: retired name with [ ] is backed up before removal" (-not (Exists "$(A)\rules\a[1].md") -and [bool](@(LsNames "$(A)\rules") | Where-Object { $_.Contains('a[1].md.bak.') }) -and (GrepX (M) "a[1].md${T}retired"))
    if ($haveReadonly) {
        Gitc @("-C", $R, "rm", "-q", "shared/rules/hook-lifecycle.md"); Gitc @("-C", $R, "commit", "-q", "-m", "hl-gone")
        Deny-Write "$(A)\rules"
        Fresh-Log; Run-DH
        Undeny "$(A)\rules"
        Check "${lang}: failed backup keeps the file (ERROR row, exit 1)" ($rc -eq 1 -and (IsFile "$(A)\rules\hook-lifecycle.md") -and (Row 'ERROR|harness files|retire failed: hook-lifecyc...') -and (GrepQ $LOG 'backup failed'))
        Fresh-Log; Run-DH
        Check "${lang}: next run retries and removes it" ($rc -eq 0 -and -not (Exists "$(A)\rules\hook-lifecycle.md") -and (GrepX (M) "hook-lifecycle.md${T}retired"))
        Deny-Write "$(A)\rules"
        Run-DH
        Undeny "$(A)\rules"
        Check "manifest write failure: ERROR row, exit 1, run completes" ($rc -eq 1 -and (Row 'ERROR|harness files|rules manifest not written') -and (GrepQ $LOG 'harness files: .* retired'))
    } else {
        Skip "failed rule backup and manifest write failure (a deny ACE does not block writes here)"
    }

    # ---------------------------------------------------------------------------
    # Skills manifest (~/.aitools/skills/.aitools-skills-manifest) and retired skills
    # (plan skills-and-rules-fanout.md section 3.2, FO-2). One case sequence; each
    # step's exit code, summary rows, manifest and skills tree go to a trace that
    # must equal the golden file (the .sh on macOS/Linux and the .ps1 on Windows
    # share it). The read-only steps (POSIX only) come last, with their own trace.
    # ---------------------------------------------------------------------------
    function SM { Join-Path $script:H ".aitools/skills/.aitools-skills-manifest" }
    function SmfIs([string[]]$Lines) { ManifestIs (SM) '# aitools skills manifest v1' $Lines }
    # N-Bak NAME -- number of NAME.bak.* directories in ~/.aitools/skills (literal name)
    function N-Bak([string]$Name) {
        $d = Join-Path (A) "skills"
        @(@(LsA $d) | Where-Object { $_.StartsWith("$Name.bak.", [StringComparison]::Ordinal) -and (IsDir (Join-Path $d $_)) }).Count
    }
    # BakLine NAME REL LINE -- a NAME.bak.* directory holds file REL with the line LINE
    function BakLine([string]$Name, [string]$Rel, [string]$Line) {
        $d = Join-Path (A) "skills"
        [bool](@(LsA $d) | Where-Object { $_.StartsWith("$Name.bak.", [StringComparison]::Ordinal) -and (GrepX (Join-Path (Join-Path $d $_) $Rel) $Line) })
    }
    # The skill named with glob characters: '*' and '?' cannot be in a Windows file
    # name, so Windows uses the brackets only (as the Git Bash harness did). The
    # trace writes the name as <BN>.
    $BN = 'b[1]'
    # Trace STEP -- append the observable state to $TRACE, as the .sh's trace():
    # "== STEP rc=N", the summary file, "-- manifest", the manifest (when it is a
    # file), "-- tree", then ". " and "./<path>" for every entry under
    # ~/.aitools/skills (forward slashes, ordinal sort = LC_ALL=C sort); CRs
    # removed, backup timestamps -> .bak.TS, the glob skill name -> <BN>.
    function Trace([string]$Step) {
        $sb = [Text.StringBuilder]::new()
        [void]$sb.Append("== $Step rc=$($script:rc)`n")
        [void]$sb.Append((ReadText (Join-Path $script:C "summary")))
        [void]$sb.Append("-- manifest`n")
        if (IsFile (SM)) { [void]$sb.Append((ReadText (SM))) }
        [void]$sb.Append("-- tree`n")
        $sk = [IO.Path]::GetFullPath((Join-Path (A) "skills")).TrimEnd('\')
        $entries = [Collections.Generic.List[string]]::new()
        $entries.Add(".")
        foreach ($e in [IO.Directory]::GetFileSystemEntries($sk, "*", [IO.SearchOption]::AllDirectories)) {
            $entries.Add("./" + ($e.Substring($sk.Length + 1) -replace '\\', '/'))
        }
        $arr = $entries.ToArray()
        [Array]::Sort($arr, [StringComparer]::Ordinal)
        foreach ($e in $arr) { [void]$sb.Append("$e`n") }
        $t = $sb.ToString() -replace "`r", ""
        $t = $t -replace '\.bak\.\d{4}-\d\d-\d\dT\d{6}Z', '.bak.TS'
        $t = $t.Replace($BN, '<BN>')
        [IO.File]::AppendAllText($script:TRACE, $t)
    }
    function Run-Sk([string[]]$SkArgs = @()) { Fresh-Log; Run-DH "" $SkArgs }

    Setup-Case skills
    $script:TRACE = "$C\trace"
    New-Dirs @("$D\claude\skills\d1\ref", "$R\shared\skills\.hidden", "$R\shared\skills\old.bak.1")
    W "$D\claude\skills\d1\SKILL.md" "dotprofile skill`n"
    W "$D\claude\skills\d1\ref\x.md" "dotprofile ref`n"
    Gitc @("-C", $D, "add", "-A"); Gitc @("-C", $D, "commit", "-q", "-m", "skills")
    W "$R\shared\skills\.hidden\SKILL.md" "hidden`n"
    W "$R\shared\skills\old.bak.1\SKILL.md" "backup`n"
    Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "hidden")

    Run-Sk; Trace first
    Check "$lang skills: first run writes the manifest (sorted, shared only)" ($rc -eq 0 -and (SmfIs @("s1${T}shared", "s2${T}shared")))
    Check "$lang skills: .claude/skills and dotprofile skills not deployed" (-not (Exists "$(A)\skills\s3") -and -not (Exists "$(A)\skills\d1"))
    Check "$lang skills: hidden and *.bak.* skill directories neither deployed nor listed" (-not (Exists "$(A)\skills\.hidden") -and -not (Exists "$(A)\skills\old.bak.1") -and -not (GrepQ (SM) 'hidden|old'))
    Check "$lang skills: manifest not reported as preserved, no .tmp left" (-not (GrepQ $LOG 'Preserved: .*aitools-skills-manifest') -and -not (Exists "$(SM).tmp"))

    # Migration from the three-source harness: the previous manifest and
    # ~/.aitools/skills still hold s3 (from .claude/skills, "aitools") and d1 (from
    # the dotprofile). Both sources are withdrawn: both skills are retired.
    W (SM) "# aitools skills manifest v1`nd1`tdotprofile`ns1`tshared`ns2`tshared`ns3`taitools`n"
    New-Dirs @("$(A)\skills\d1\ref", "$(A)\skills\s3")
    W "$(A)\skills\d1\SKILL.md" "dotprofile skill`n"
    W "$(A)\skills\d1\ref\x.md" "dotprofile ref`n"
    W "$(A)\skills\s3\SKILL.md" "skill three`n"
    Run-Sk @('-DryRun'); Trace dryrun
    Check "$lang skills: withdrawn sources, dry run -- retirement reported, nothing removed or written" ($rc -eq 0 -and (IsFile "$(A)\skills\d1\SKILL.md") -and (IsFile "$(A)\skills\s3\SKILL.md") -and (GrepX (SM) "d1${T}dotprofile") -and (GrepQ $LOG '\[DRY RUN\] Retired skill: d1 \(was dotprofile') -and (GrepQ $LOG '\[DRY RUN\] Retired skill: s3 \(was aitools') -and (N-Bak d1) -eq 0)
    Run-Sk; Trace withdrawn
    Check "$lang skills: withdrawn sources -- d1 and s3 retired (verified backups), DETAIL rows" ($rc -eq 0 -and (SmfIs @("d1${T}retired", "s1${T}shared", "s2${T}shared", "s3${T}retired")) -and -not (Exists "$(A)\skills\d1") -and -not (Exists "$(A)\skills\s3") -and (N-Bak d1) -eq 1 -and (N-Bak s3) -eq 1 -and (BakLine d1 'ref\x.md' 'dotprofile ref') -and (Row 'DETAIL|harness files|retired: skills/d1') -and (Row 'DETAIL|harness files|retired: skills/s3'))

    # The #74/#75 layout move: a skill moves from .claude/skills to shared/skills
    # and is deployed again, from shared
    Gitc @("-C", $R, "mv", ".claude/skills/s3", "shared/skills/s3"); Gitc @("-C", $R, "commit", "-q", "-m", "move")
    Run-Sk; Trace move
    Check "$lang skills: moved .claude -> shared: deployed again, source shared, nothing retired" ($rc -eq 0 -and (GrepX (SM) "s3${T}shared") -and (IsFile "$(A)\skills\s3\SKILL.md") -and -not (GrepQ $LOG 'Retired skill') -and (N-Bak s3) -eq 1)

    Gitc @("-C", $R, "rm", "-q", "-r", "shared/skills/s2"); Gitc @("-C", $R, "commit", "-q", "-m", "retire")
    Run-Sk; Trace retire
    Check "$lang skills: removed from its source -- retired line, DETAIL row" ($rc -eq 0 -and (GrepX (SM) "s2${T}retired") -and (Row 'DETAIL|harness files|retired: skills/s2') -and (GrepQ $LOG 'Retired skill: s2 \(was shared'))
    Check "$lang skills: harness directory backed up (backup_dir) and removed" (-not (Exists "$(A)\skills\s2") -and (N-Bak s2) -eq 1 -and (BakLine s2 'SKILL.md' 'skill two'))
    Check "$lang skills: backup directory not reported as preserved" (-not (GrepQ $LOG 'Preserved: .*s2.bak'))

    Run-Sk; Trace rerun
    Check "$lang skills: retired line persists; no new backup, no row" ($rc -eq 0 -and (GrepX (SM) "s2${T}retired") -and (N-Bak s2) -eq 1 -and -not (HasRow 'retired:'))

    # A skill with no top-level *.md, one named with glob characters ($BN; old
    # backups pruned to 5 by literal name; a decoy that the glob would match is
    # kept), and an upper-case .BAK. directory (not a skill name, never deployed)
    New-Dirs @("$R\shared\skills\nomd\a", "$R\shared\skills\$BN", "$R\shared\skills\x.BAK.y")
    W "$R\shared\skills\nomd\a\x.md" "nested only`n"
    W "$R\shared\skills\$BN\SKILL.md" "bracket skill`n"
    W "$R\shared\skills\x.BAK.y\SKILL.md" "upper bak`n"
    Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "copy-cases")
    Run-Sk; Trace copydeploy
    Check "$lang skills: nested-only and glob-named skills deployed; .BAK. directory not (case-insensitive)" ($rc -eq 0 -and (IsFile "$(A)\skills\nomd\a\x.md") -and (IsFile "$(A)\skills\$BN\SKILL.md") -and -not (Exists "$(A)\skills\x.BAK.y") -and -not (GrepQ (SM) 'x.bak.y' -I))
    foreach ($i in 1..6) {
        New-Dirs @("$(A)\skills\$BN.bak.2026-01-0${i}T000000Z")
        W "$(A)\skills\$BN.bak.2026-01-0${i}T000000Z\SKILL.md" "old $i`n"
    }
    New-Dirs @("$(A)\skills\b1.bak.2026-01-01T000000Z")
    W "$(A)\skills\b1.bak.2026-01-01T000000Z\SKILL.md" "decoy`n"
    Gitc @("-C", $R, "rm", "-q", "-r", "shared/skills/nomd", "shared/skills/$BN"); Gitc @("-C", $R, "commit", "-q", "-m", "copy-retire")
    Run-Sk; Trace copyretire
    Check "$lang skills: retired skill with no top-level *.md -- copied, verified, removed" ($rc -eq 0 -and -not (Exists "$(A)\skills\nomd") -and (N-Bak nomd) -eq 1 -and (BakLine nomd 'a\x.md' 'nested only') -and (Row 'DETAIL|harness files|retired: skills/nomd'))
    Check "$lang skills: glob-named skill retired; its backups pruned to 5 (oldest two); decoy kept" (-not (Exists "$(A)\skills\$BN") -and (N-Bak $BN) -eq 5 -and -not (Exists "$(A)\skills\$BN.bak.2026-01-01T000000Z") -and -not (Exists "$(A)\skills\$BN.bak.2026-01-02T000000Z") -and (IsDir "$(A)\skills\$BN.bak.2026-01-03T000000Z") -and (IsFile "$(A)\skills\b1.bak.2026-01-01T000000Z\SKILL.md"))

    W "$(A)\skills\zz" "a file`n"
    W (SM) "# aitools skills manifest v1`nzz`tretired`n../evil`tshared`n.hidden`tshared`nx.bak.1`tshared`na/b`tshared`nok`tbogus`n"
    Run-Sk; Trace invalid
    Check "$lang skills: invalid lines ignored (5 warnings); a file named like a retired skill left alone" ($rc -eq 0 -and (GrepC $LOG 'line ignored') -eq 5 -and (IsFile "$(A)\skills\zz") -and (GrepQ $LOG 'Retired skill zz: .* is not a directory') -and (Row 'WARN|harness files|not a dir: zz') -and (GrepX (SM) "zz${T}retired") -and -not (GrepQ (SM) 'evil|hidden|bogus'))
    W (SM) "not a manifest`nd2`tdotprofile`n"
    Run-Sk; Trace header
    Check "$lang skills: unknown header -- warning, nothing retired, rewritten" ($rc -eq 0 -and (GrepQ $LOG '\[warn\] Skills manifest .*the first line is not') -and @(FileLines (SM))[0] -ceq '# aitools skills manifest v1' -and -not (GrepQ (SM) 'retired'))

    # A directory at the manifest paths (skills and rules): ERROR, exit 1, nothing moved into it
    foreach ($p in @((SM), (M))) { if (Exists $p) { Remove-Item -LiteralPath $p -Force } }
    New-Dirs @((SM), (M))
    W "$(SM)\inside" "inside`n"
    Run-Sk; Trace mfdir
    Check "$lang skills: manifest path is a directory -- ERROR rows (skills, rules), exit 1, nothing written into it, contents not reported preserved" ($rc -eq 1 -and (Row 'ERROR|harness files|skills manifest not written') -and (Row 'ERROR|harness files|rules manifest not written') -and (@(LsA (SM)) -join "|") -ceq 'inside' -and @(LsA (M)).Count -eq 0 -and (GrepQ $LOG 'Skills manifest: .* is a directory') -and -not (GrepQ $LOG 'Preserved: .*aitools-skills-manifest'))
    foreach ($p in @((SM), (M))) { if (Exists $p) { Remove-Item -LiteralPath $p -Recurse -Force } }
    Run-Sk; Trace mfdirgone
    Check "$lang skills: directory removed -- both manifests written again" ($rc -eq 0 -and (IsFile (SM)) -and (IsFile (M)))
    Check "skills parity: trace equals the golden file (sh and ps1 share it)" ((GrepC $script:TRACE '^== ') -ge 12 -and (Test-GoldenMatch "skills.trace" $script:TRACE))

    if ($haveReadonly) {
        $script:TRACE = "$C\trace-ro"
        # Partial backup: an unreadable file in the retired skill's directory
        New-Dirs @("$R\shared\skills\pb")
        W "$R\shared\skills\pb\SKILL.md" "partial`n"
        Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "pb")
        Run-Sk; Trace pbdeploy
        W "$(A)\skills\pb\secret.md" "secret`n"
        Deny-Read "$(A)\skills\pb\secret.md"
        Gitc @("-C", $R, "rm", "-q", "-r", "shared/skills/pb"); Gitc @("-C", $R, "commit", "-q", "-m", "pb-gone")
        Run-Sk; Trace pbfail
        Undeny "$(A)\skills\pb\secret.md"
        Check "$lang skills: partial backup removed again; directory kept (ERROR row, exit 1)" ($rc -eq 1 -and (IsFile "$(A)\skills\pb\SKILL.md") -and (N-Bak pb) -eq 0 -and (Row 'ERROR|harness files|retire failed: pb') -and (GrepQ $LOG 'Retired skill pb: backup failed \(') -and (GrepQ $LOG 'Retired skill pb: removed the incomplete backup'))
        Run-Sk; Trace pbretry
        Check "$lang skills: readable again -- backed up and removed" ($rc -eq 0 -and -not (Exists "$(A)\skills\pb") -and (N-Bak pb) -eq 1 -and (BakLine pb 'secret.md' 'secret'))

        # Partial backup holding a read-only item: cleanup must still work. The .sh
        # makes rs/ro read-only (chmod 555), so the backup's copy of ro is read-only
        # too. The Windows counterpart is the ReadOnly attribute on rs\ro\a.md:
        # File.Copy keeps it, so the partial backup holds a read-only file that
        # Directory.Delete cannot remove until deploy-harness.ps1 clears the
        # attribute (Remove-SkillBackupCopy). a.md is copied before the unreadable
        # secret.md (.NET lists ro\a.md before ro\secret.md).
        New-Dirs @("$R\shared\skills\rs\ro")
        W "$R\shared\skills\rs\SKILL.md" "ro skill`n"
        W "$R\shared\skills\rs\ro\a.md" "ro file`n"
        Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "rs")
        Run-Sk; Trace rsdeploy
        W "$(A)\skills\rs\ro\secret.md" "secret`n"
        Deny-Read "$(A)\skills\rs\ro\secret.md"
        $roFile = "$(A)\skills\rs\ro\a.md"
        [IO.File]::SetAttributes($roFile, [IO.File]::GetAttributes($roFile) -bor [IO.FileAttributes]::ReadOnly)
        Gitc @("-C", $R, "rm", "-q", "-r", "shared/skills/rs"); Gitc @("-C", $R, "commit", "-q", "-m", "rs-gone")
        Run-Sk; Trace rsfail
        [IO.File]::SetAttributes($roFile, [IO.File]::GetAttributes($roFile) -band (-bnot [IO.FileAttributes]::ReadOnly))
        Undeny "$(A)\skills\rs\ro\secret.md"
        Check "$lang skills: partial backup with a read-only subdirectory removed (no leftover, nothing renamed)" ($rc -eq 1 -and (IsFile "$(A)\skills\rs\ro\a.md") -and (N-Bak rs) -eq 0 -and (Row 'ERROR|harness files|retire failed: rs') -and -not (HasRow 'bak cleanup failed') -and (GrepQ $LOG 'Retired skill rs: removed the incomplete backup'))
        Run-Sk; Trace rsretry
        Check "$lang skills: read-only case retried -- backed up and removed" ($rc -eq 0 -and -not (Exists "$(A)\skills\rs") -and (N-Bak rs) -eq 1)

        Gitc @("-C", $R, "rm", "-q", "-r", "shared/skills/s1"); Gitc @("-C", $R, "commit", "-q", "-m", "s1-gone")
        Deny-Write "$(A)\skills"
        Run-Sk; Trace bakfail
        Undeny "$(A)\skills"
        Check "$lang skills: failed backup keeps the directory (ERROR row, exit 1)" ($rc -eq 1 -and (IsFile "$(A)\skills\s1\SKILL.md") -and (Row 'ERROR|harness files|retire failed: s1') -and (GrepQ $LOG 'Retired skill s1: backup failed') -and (N-Bak s1) -eq 0)
        Run-Sk; Trace bakretry
        Check "$lang skills: next run retries -- backed up and removed" ($rc -eq 0 -and -not (Exists "$(A)\skills\s1") -and (N-Bak s1) -eq 1 -and (GrepX (SM) "s1${T}retired"))
        Check "skills read-only parity: trace equals the golden file" (Test-GoldenMatch "skills-readonly.trace" $script:TRACE)
    } else {
        Skip "skills partial and failed backups (a deny ACE does not block reads or writes here)"
    }

    # ---------------------------------------------------------------------------
    # Rule names with an upper- or mixed-case .md extension (plan rules-fanout-claude.md
    # F2/R9; D1 "case-insensitive, *.md only, skipping *.bak.*"): deployed as named,
    # listed in the manifest, no warning on the next run, retired when the source
    # goes; a case variant in the dotprofile is not a source (no duplicate, not
    # deployed); .bak. names are still rejected.
    # ---------------------------------------------------------------------------
    function No-WarnRows { -not (GrepQ (Join-Path $script:C "summary") '^(WARN|ACTION)\|') }
    Setup-Case upper
    W "$R\shared\rules\X.MD" "upper rule`n"
    W "$R\shared\rules\Old.BAK.1.MD" "upper backup`n"
    W "$R\shared\rules\Mixed.Md" "mixed rule`n"
    Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "upper")
    Fresh-Log; Run-DH
    Check "$lang upper: X.MD and Mixed.Md deployed as named, exit 0, no WARN/ACTION row" ($rc -eq 0 -and (Lsx 'X.MD') -and (Lsx 'Mixed.Md') -and (GrepX "$(A)\rules\X.MD" 'upper rule') -and (No-WarnRows))
    Check "$lang upper: listed in the manifest with their source" ((GrepX (M) "X.MD${T}shared") -and (GrepX (M) "Mixed.Md${T}shared"))
    Check "$lang upper: .BAK. name (any case) neither deployed nor listed" (-not (@(LsNames "$(A)\rules") | Where-Object { $_ -imatch '^old\.bak' }) -and -not (GrepQ (M) '^old\.bak' -I))

    Fresh-Log; Run-DH
    Check "$lang upper: rerun -- manifest lines accepted (no 'line ignored', no WARN/ACTION), verified" ($rc -eq 0 -and -not (GrepQ $LOG 'line ignored') -and (No-WarnRows) -and (GrepQ "$C\summary" '^OK\|harness files\|[0-9]+ verified$'))

    W "$R\shared\rules\dup.md" "shared dup`n"
    W "$D\claude\rules\DUP.MD" "dotprofile dup`n"
    Gitc @("-C", $R, "add", "-A"); Gitc @("-C", $R, "commit", "-q", "-m", "dup")
    Gitc @("-C", $D, "add", "-A"); Gitc @("-C", $D, "commit", "-q", "-m", "dup")
    Fresh-Log; Run-DH
    Check "$lang upper: case variant in the dotprofile (DUP.MD) -- not a source: no ERROR row, not deployed" ($rc -eq 0 -and -not (GrepQ "$C\summary" '^ERROR\|') -and (Lsx 'dup.md') -and -not (Lsx 'DUP.MD') -and (GrepX "$(A)\rules\dup.md" 'shared dup') -and (GrepX (M) "dup.md${T}shared") -and -not (GrepQ (M) '^DUP'))
    Gitc @("-C", $D, "rm", "-q", "claude/rules/DUP.MD"); Gitc @("-C", $D, "commit", "-q", "-m", "undup")

    [IO.File]::AppendAllText((M), "Q.MD.BAK.1`tshared`nq.MD.bak.2`tshared`n")
    Fresh-Log; Run-DH
    Check "$lang upper: manifest names with .bak. (any case) still ignored" ($rc -eq 0 -and (GrepC $LOG 'line ignored') -eq 2 -and (GrepQ $LOG 'line ignored: Q.MD.BAK.1<TAB>shared') -and -not (GrepQ (M) '^q\.md\.bak' -I))

    Gitc @("-C", $R, "rm", "-q", "shared/rules/X.MD"); Gitc @("-C", $R, "commit", "-q", "-m", "retire-upper")
    Gitc @("-C", $R, "rm", "-q", "shared/rules/Mixed.Md"); Gitc @("-C", $R, "commit", "-q", "-m", "retire-mixed")
    Fresh-Log; Run-DH
    $rl = @(LsNames "$(A)\rules")
    Check "$lang upper: source removed -- retired (backup kept, file removed), DETAIL rows, no WARN" ($rc -eq 0 -and (GrepX (M) "X.MD${T}retired") -and (GrepX (M) "Mixed.Md${T}retired") -and -not ($rl | Where-Object { $_ -ieq 'x.md' }) -and -not ($rl | Where-Object { $_ -ieq 'mixed.md' }) -and [bool]($rl | Where-Object { $_ -cmatch '^X\.MD\.bak\.' }) -and [bool]($rl | Where-Object { $_ -cmatch '^Mixed\.Md\.bak\.' }) -and (Row 'DETAIL|harness files|retired: rules/X.MD') -and (Row 'DETAIL|harness files|retired: rules/Mixed.Md') -and -not (GrepQ $LOG 'line ignored') -and (No-WarnRows))

    # The lib's manifest reader (Read-HarnessManifest), as setup-user-cursor and
    # setup-user-claude call it: upper- and mixed-case extensions are valid; a
    # case-only duplicate and a .bak. name are invalid. stdout and stderr are
    # captured separately (the .sh compared stdout only).
    Setup-Case reader
    W "$C\mf" "# aitools rules manifest v1`nX.MD`tdotprofile`nMixed.Md`tshared`nx.md`tshared`nY.MD.bak.1`tshared`n"
    W "$C\reader.expected" "rule`tX.MD`tdotprofile`nrule`tMixed.Md`tshared`ninvalid`tx.md<TAB>shared`ninvalid`tY.MD.bak.1<TAB>shared`n"
    W "$C\reader.ps1" (@'
param([string]$Repo, [string]$Mf)
$ErrorActionPreference = "Stop"
. (Join-Path $Repo "scripts/aitools-lib.ps1")
Initialize-Logging "test-deploy-harness-reader"
$r = Read-HarnessManifest -Path $Mf -Kind "rules"
$out = [System.Text.StringBuilder]::new()
foreach ($x in $r.Rules) { [void]$out.Append("rule`t$($x.Name)`t$($x.Source)`n") }
foreach ($x in $r.Invalid) { [void]$out.Append("invalid`t$x`n") }
[Console]::Out.Write($out.ToString())

'@.Replace("`r", ""))
    $envs = @{ HOME = $H; USERPROFILE = $H; AITOOLS_LOG_DIR = "$C\logs" }
    $saved = @{}
    foreach ($k in $envs.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $envs[$k]) }
    try {
        $null | & $pwshExe -NoProfile -NonInteractive -File "$C\reader.ps1" -Repo $root -Mf "$C\mf" > "$C\reader.out" 2> "$C\reader.err"
        $script:rc = $LASTEXITCODE
    } finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    W "$C\reader.out" ((ReadText "$C\reader.out") -replace "`r", "")
    Check "reader ${lang}: X.MD and Mixed.Md valid; case-only duplicate and .bak. invalid" ($rc -eq 0 -and (Same "$C\reader.expected" "$C\reader.out"))

    # ---------------------------------------------------------------------------
    # Arguments
    # ---------------------------------------------------------------------------
    Setup-Case args
    Run-DH "" @('--bogus')
    Check "bad argument: exit 1, ERROR row" ($rc -eq 1 -and (Row 'ERROR|harness files|bad arguments'))
    Run-DH "" @('-Help')
    Check "--help: exit 0, usage shown, nothing deployed" ($rc -eq 0 -and (GrepQ "$C\out" "Usage: deploy-harness.$lang") -and -not (Exists "$(A)\rules"))
} finally {
    # Deny ACEs still in place (a case that threw before its Undeny): removed first,
    # or the temp root cannot be deleted.
    foreach ($p in @($script:Denied | ForEach-Object { $_.Path } | Select-Object -Unique)) {
        try { Undeny $p } catch { Write-Host "      | could not remove the deny ACE on ${p}: $($_.Exception.Message)" }
    }
    # git writes its object files read-only, and Remove-Item -Recurse treats [ ] in
    # names below the root as wildcards (the b[1] skill): clear the attribute and
    # delete with .NET first; Remove-TestTempRoot then removes what is left, or
    # reports why it could not.
    try {
        foreach ($f in [IO.Directory]::GetFiles($tmpRoot, "*", [IO.SearchOption]::AllDirectories)) {
            $attr = [IO.File]::GetAttributes($f)
            if ($attr -band [IO.FileAttributes]::ReadOnly) { [IO.File]::SetAttributes($f, $attr -band (-bnot [IO.FileAttributes]::ReadOnly)) }
        }
        [IO.Directory]::Delete($tmpRoot, $true)
    } catch {
        Write-Host "      | .NET removal of the temp root failed: $($_.Exception.Message)"
    }
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: {3} scripts)" -f $script:pass, $script:fail, $script:skip, $lang)
if ($script:fail -ne 0) { exit 1 }
exit 0
