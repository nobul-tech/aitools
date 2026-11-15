# test-claude-mdm.ps1 -- tests for setup-user-claude.ps1 (dev path) and the
# generated MDM copies that scripts/build-deploy.sh writes into <dotprofile>/deploy/
# The Windows harness of this suite; tests/claude-mdm/test-claude-mdm.sh is the
# macOS/Linux harness of the same cases for the .sh scripts.
#
# Cases (S3-MF-Audit ids):
#   A-25  the CLAUDE.md footer hostname is the resolver's ($script:AitLibMachineHostname),
#         "unknown" when empty; dev and MDM
#   A-26  -DryRun writes one claude.md row: "dry-run: would create", "verified",
#         "dry-run: would update" (same rows as the .sh: golden)
#   A-19  every generated .ps1 that embeds the profile resolver removes its temp
#         dir and restores AITOOLS_PROFILE_PS1 on every exit (try/finally), also
#         in-process (& script), through a dry run
#   A-20  build-deploy output has no colour codes when stderr is not a terminal,
#         and the standalone child resolver's console lines are not repeated in
#         it (they are in deploy.log once); on a terminal both stay visible
#   FO-4  the generated MDM copies fan out ~/.aitools/skills
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs setup-user-claude.ps1 and the generated
# deploy/setup-user-claude.ps1 with native pwsh on Windows only. build-deploy.sh
# is cross-platform bash (cross-platform.md "Build scripts"), so the build and
# A-20 cases run it here with Git Bash (Resolve-TestGitBash, never a bare bash:
# in native pwsh that can be the WSL launcher); without Git Bash they are SKIP.
# The dry-run rows are compared with the committed golden files in
# tests/claude-mdm/golden/, which the .sh harness checks on macOS/Linux
# (Test-GoldenMatch in tests/lib/platform-lib.ps1).
#
# Safe to re-run: every case runs under its own temp HOME/USERPROFILE (never the
# real HOME or a real dotprofile; build-deploy.sh writes only the temp fixture
# dotprofile's deploy/), removed on exit. The resolver is stubbed through
# AITOOLS_PROFILE_PS1 (the lib's lookup override) to fix the hostname it
# reports. Needs git; node and Git Bash for the build; python3 with pywinpty for
# the terminal case. Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/claude-mdm/test-claude-mdm.ps1 [-Help]

param([switch]$Help)
if ($Help) { foreach ($l in (Get-Content -LiteralPath $PSCommandPath)) { if ($l -notmatch '^#') { break }; $l -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/claude-mdm/test-claude-mdm.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$PTY = Join-Path $root "tests/managed-files/pty-run.py"
$tmpRoot = New-TestTempRoot "claude-mdm"
$GoldenDir = Join-Path $root "tests/claude-mdm/golden"
$GoldenTmp = $tmpRoot
$W = Join-Path $tmpRoot "work"
New-Item -ItemType Directory -Path $W | Out-Null
$lang = "ps1"
$ESC = [string][char]27

$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:OUT = ""
$script:Rc = @{}

function Strip([string]$Text) { ($Text -replace "`e\[[0-9;]*m", "") -replace "`r", "" }
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
# Lines FILE: the lines of FILE, CRs removed (none when the file is missing)
function Lines([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $t = ([IO.File]::ReadAllText($Path)) -replace "`r", ""
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    if ($t -eq "") { return @() }
    return @($t -split "`n")
}
# Mixed PATH: C:\a\b -> C:/a/b (what cygpath -m gave the Git Bash harness)
function Mixed([string]$Path) { $Path -replace '\\', '/' }

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if ($script:OUT -and (Test-Path -LiteralPath $script:OUT -PathType Leaf)) {
        @((Strip (ReadText $script:OUT)) -split "`n") | Select-Object -Last 20 | ForEach-Object { Write-Output "      | $_" }
    }
}
function Skip([string]$Name) { Write-Output "SKIP $Name"; $script:skip++ }
# NoEmbed DIR: DIR exists and holds no aitools-embed-* entry (other runtime
# files .NET may leave in the temp dir are not this test's business)
function NoEmbed([string]$Dir) {
    (Test-Path -LiteralPath $Dir -PathType Container) -and
        (@(Get-ChildItem -LiteralPath $Dir -Force -Filter 'aitools-embed-*').Count -eq 0)
}
# HasLine FILE LINE: FILE (CRs removed) holds LINE as a whole line
function HasLine([string]$Path, [string]$Line) { @(Lines $Path) -ccontains $Line }
# FileHas FILE TEXT: FILE contains TEXT (grep -F)
function FileHas([string]$Path, [string]$Text) { (Test-Path -LiteralPath $Path -PathType Leaf) -and ([IO.File]::ReadAllText($Path)).Contains($Text) }
# CountMatch FILE REGEX: the number of lines (CRs removed) matching REGEX (grep -c)
function CountMatch([string]$Path, [string]$Regex) { @(Lines $Path | Where-Object { $_ -cmatch $Regex }).Count }

# Invoke-Git ARGS...: git with a fixed identity; output captured, a failure throws
function Invoke-Git {
    $o = & git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit $LASTEXITCODE): $($o -join ' ')" }
}

# Set-TestEnv HASHTABLE: set the variables ($null removes one); returns the old values
function Set-TestEnv([hashtable]$Vars) {
    $old = @{}
    foreach ($k in @($Vars.Keys)) { $old[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $Vars[$k]) }
    return $old
}
function Restore-TestEnv([hashtable]$Old) {
    foreach ($k in @($Old.Keys)) { [Environment]::SetEnvironmentVariable($k, $Old[$k]) }
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        # Get-Command exempt: command-existence check; the branch is the fallback
        Write-Output "SKIP all cases (git not found)"
        exit 0
    }
    $haveNode = [bool](Get-Command node -ErrorAction SilentlyContinue)
    # Get-Command exempt: command-existence check; $haveNode drives the skip below
    $gitBash = Resolve-TestGitBash
    $havePty = [bool](Get-Command python3 -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $PTY -PathType Leaf)
    # Get-Command exempt: command-existence check; $havePty is the fallback branch
    if ($havePty) {
        # Windows pty = pywinpty (ConPTY); a failing import means "not installed".
        & python3 -c "import winpty" 2>$null
        $havePty = ($LASTEXITCODE -eq 0)
    }

    # --- Fixture dotprofile (a git repo in the temp dir) ---
    $DP = Join-Path $tmpRoot "aitools-tess"
    New-Item -ItemType Directory -Path (Join-Path $DP "claude/rules") -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $DP "claude/CLAUDE.md"), "# Prefs for {{PROFILE_NAME}}`n`n## Code Style`n`n- keep it simple`n")
    [IO.File]::WriteAllText((Join-Path $DP "claude/rules/r1.md"), "rule one`n")
    [IO.File]::WriteAllText((Join-Path $DP "profile.json"), '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}' + "`n")
    Invoke-Git -C $DP init -q
    Invoke-Git -C $DP add -A
    Invoke-Git -C $DP commit -q -m fixture

    # WriteConfig HOME_DIR: config.json with userRepoPath (forward slashes, as
    # cygpath -m gave the Git Bash harness)
    function WriteConfig([string]$HomeDir) {
        New-Item -ItemType Directory -Path (Join-Path $HomeDir ".aitools") -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $HomeDir ".aitools/config.json"), ('{"userRepoPath":"' + (Mixed $DP) + '","machineAlias":"m1"}' + "`n"))
    }

    # --- Resolver stubs: the real resolver, with its hostname result replaced ---
    # stub-host: "stub-host"; no-host: empty (the footer must say "unknown"). The
    # Windows lib reads only AITOOLS_PROFILE_PS1, so only .ps1 stubs are needed.
    foreach ($v in @("stub-host", "no-host")) {
        $h = if ($v -eq "no-host") { "" } else { $v }
        $stub = '$out = @(& "' + (Mixed $root) + '/scripts/aitools-profile.ps1" @args)' + "`n" +
            '$rc = $LASTEXITCODE' + "`n" +
            'foreach ($l in $out) { if ("$l".StartsWith("hostname`t")) { "hostname`t' + $h + '" } else { "$l" } }' + "`n" +
            'exit $rc' + "`n"
        [IO.File]::WriteAllText((Join-Path $W "$v.ps1"), $stub)
    }
    # fail: a resolver error (exit 2), so the lib's resolve returns 3. build-deploy.sh
    # (bash) gets both overrides, as in the .sh harness; on Windows its lib runs the .ps1.
    [IO.File]::WriteAllText((Join-Path $W "fail.sh"), "#!/usr/bin/env bash`nprintf `"via\tnone\nerror\tstub resolver failure\n`"`nexit 2`n")
    [IO.File]::WriteAllText((Join-Path $W "fail.ps1"), '[Console]::Out.WriteLine("via`tnone")' + "`n" + '[Console]::Out.WriteLine("error`tstub resolver failure")' + "`n" + "exit 2`n")

    # The live resolver hostname. Isolated HOME and log dir: the resolver logs
    # (review N-1). stderr dropped: an unavailable hostname is checked through
    # $liveHost being empty.
    New-Item -ItemType Directory -Path (Join-Path $W "home-host") | Out-Null
    $old = Set-TestEnv @{ HOME = (Mixed (Join-Path $W "home-host")); USERPROFILE = (Mixed (Join-Path $W "home-host")); AITOOLS_LOG_DIR = (Mixed (Join-Path $W "logs-host")) }
    try {
        $hostOut = @($null | & $pwshExe -NoProfile -NonInteractive -File (Join-Path $root "scripts/aitools-profile.ps1") hostname 2>$null)
    } finally { Restore-TestEnv $old }
    $liveHost = ((@($hostOut) -join "`n") -replace "`r", "").TrimEnd("`n")
    if (-not $liveHost) { $liveHost = "unknown" }

    # Run-Claude CASE STUB [ARGS]: scripts/setup-user-claude.ps1; HOME = $tmpRoot/CASE
    # (kept between calls of the same CASE); STUB = stub-host|no-host|live.
    function Run-Claude([string]$Name, [string]$Stub, [string[]]$ScriptArgs = @()) {
        $h = Join-Path $tmpRoot $Name
        if (-not (Test-Path -LiteralPath (Join-Path $h ".aitools/config.json"))) { WriteConfig $h }
        $script:OUT = Join-Path $tmpRoot "$Name.out"
        [IO.File]::WriteAllText((Join-Path $tmpRoot "$Name.summary"), "")
        $envs = @{
            AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null; AITOOLS_USER_REPO_PATH = $null; AITOOLS_PROFILE_FILE = $null
            HOME = (Mixed $h); USERPROFILE = (Mixed $h); AITOOLS_LOG_DIR = (Mixed (Join-Path $h "logs"))
            AITOOLS_SUMMARY_FILE = (Mixed (Join-Path $tmpRoot "$Name.summary"))
            AITOOLS_PROFILE_SH = $null; AITOOLS_PROFILE_PS1 = $null
        }
        if ($Stub -ne "live") { $envs.AITOOLS_PROFILE_PS1 = Mixed (Join-Path $W "$Stub.ps1") }
        $argv = @("-NoProfile", "-NonInteractive", "-File", (Join-Path $root "scripts/setup-user-claude.ps1")) + $ScriptArgs
        $script:Rc[$Name] = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile $script:OUT
    }
    function RcOf([string]$Name) { $script:Rc[$Name] }
    function Row([string]$Name, [string]$Line) { HasLine (Join-Path $tmpRoot "$Name.summary") $Line }
    function MdOf([string]$Name) { Join-Path $tmpRoot "$Name/.claude/CLAUDE.md" }
    # ClaudeRows CASE: the summary lines holding |claude.md| (grep '|claude.md|'), as one string
    function ClaudeRows([string]$Name) { (@(Lines (Join-Path $tmpRoot "$Name.summary") | Where-Object { $_ -cmatch '\|claude.md\|' }) -join "`n") }
    function WriteRows([string]$Name, [string]$File) {
        $r = ClaudeRows $Name
        [IO.File]::WriteAllText($File, $(if ($r) { $r + "`n" } else { "" }))
    }

    # ---------------------------------------------------------------------------
    # A-25 / A-26, dev path
    # ---------------------------------------------------------------------------
    Run-Claude "$lang-host" stub-host
    Check "$lang A-25: footer hostname is the resolver's (stub-host)" `
        ((RcOf "$lang-host") -eq 0 -and (FileHas (MdOf "$lang-host") '(stub-host; profile m1)'))
    Run-Claude "$lang-nohost" no-host
    Check "$lang A-25: empty resolver hostname -> footer 'unknown'" `
        ((RcOf "$lang-nohost") -eq 0 -and (FileHas (MdOf "$lang-nohost") '(unknown; profile m1)'))
    Run-Claude "$lang-live" live
    Check "$lang A-25: no stub -> footer hostname equals 'aitools-profile hostname' ($liveHost)" `
        ((RcOf "$lang-live") -eq 0 -and (FileHas (MdOf "$lang-live") "($liveHost; profile m1)"))

    Run-Claude "$lang-dry" stub-host @("-DryRun")
    Check "$lang A-26: dry run, no CLAUDE.md -> one row 'dry-run: would create', nothing written" `
        ((RcOf "$lang-dry") -eq 0 -and (ClaudeRows "$lang-dry") -ceq 'OK|claude.md|dry-run: would create' -and -not (Test-Path -LiteralPath (MdOf "$lang-dry")))
    WriteRows "$lang-dry" (Join-Path $tmpRoot "dry-1.rows")
    Check "parity A-26 (no CLAUDE.md): claude.md rows match golden (sh and ps1 share it)" `
        (Test-GoldenMatch "dry-1.rows" (Join-Path $tmpRoot "dry-1.rows"))
    Run-Claude "$lang-dry" stub-host
    Run-Claude "$lang-dry" stub-host @("-DryRun")
    Check "$lang A-26: dry run after a deploy -> 'verified'" `
        ((RcOf "$lang-dry") -eq 0 -and (ClaudeRows "$lang-dry") -ceq 'OK|claude.md|verified')
    WriteRows "$lang-dry" (Join-Path $tmpRoot "dry-2.rows")
    Check "parity A-26 (after a deploy): claude.md rows match golden" `
        (Test-GoldenMatch "dry-2.rows" (Join-Path $tmpRoot "dry-2.rows"))
    # The local edit; when the deploy above wrote nothing the error is printed and
    # the suite goes on (the checks below then fail), as the .sh harness's printf does.
    try {
        [IO.File]::AppendAllText((MdOf "$lang-dry"), "- local edit`n")
        Copy-Item -LiteralPath (MdOf "$lang-dry") -Destination (Join-Path $tmpRoot "$lang-dry.edited")
    } catch { Write-Output "      | local edit not written: $($_.Exception.Message)" }
    Run-Claude "$lang-dry" stub-host @("-DryRun")
    $edited = Join-Path $tmpRoot "$lang-dry.edited"
    $sameBytes = (Test-Path -LiteralPath (MdOf "$lang-dry") -PathType Leaf) -and (Test-Path -LiteralPath $edited -PathType Leaf) -and
        [Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes((MdOf "$lang-dry")), [IO.File]::ReadAllBytes($edited))
    Check "$lang A-26: dry run on an edited CLAUDE.md -> 'dry-run: would update', file untouched" `
        ((RcOf "$lang-dry") -eq 0 -and (ClaudeRows "$lang-dry") -ceq 'OK|claude.md|dry-run: would update' -and $sameBytes)
    WriteRows "$lang-dry" (Join-Path $tmpRoot "dry-3.rows")
    Check "parity A-26 (edited CLAUDE.md): claude.md rows match golden" `
        (Test-GoldenMatch "dry-3.rows" (Join-Path $tmpRoot "dry-3.rows"))
    # Unreadable CLAUDE.md (review B-1, golden dry-4.rows): the .sh harness makes the
    # file unreadable with chmod 000, which NTFS does not honour; the Git Bash harness
    # skipped it on Windows, and so does this one (same SKIP line).
    Skip "$lang unreadable CLAUDE.md case (chmod does not block reads here)"

    # ---------------------------------------------------------------------------
    # Build (isolated HOME, fixture dotprofile; stderr is a file, not a terminal).
    # build-deploy.sh is cross-platform bash: Git Bash runs it, with HOME in MSYS
    # form as the Git Bash harness passed it; its child pwsh (resolver, PS1
    # validation) reads USERPROFILE, so both are set.
    # ---------------------------------------------------------------------------
    if (-not $haveNode -or -not $gitBash) {
        if (-not $haveNode) {
            Skip "build and MDM cases (node not found; build-deploy needs it)"
        } else {
            Skip "build and MDM cases (Git Bash not found; build-deploy.sh is bash)"
        }
    } else {
        $buildSh = ConvertTo-MsysPath (Join-Path $root "scripts/build-deploy.sh")
        $HB = Join-Path $tmpRoot "home-build"
        WriteConfig $HB
        $script:OUT = Join-Path $tmpRoot "build.out"
        $envs = @{
            AITOOLS_USER_REPO_PATH = $null; AITOOLS_SUMMARY_FILE = $null; AITOOLS_PROFILE_SH = $null; AITOOLS_PROFILE_PS1 = $null
            HOME = (ConvertTo-MsysPath $HB); USERPROFILE = (Mixed $HB); AITOOLS_LOG_DIR = (Mixed (Join-Path $HB "logs"))
        }
        $buildRc = Invoke-TestScript -FilePath $gitBash -ArgumentList @($buildSh) -Environment $envs -OutFile $script:OUT
        $G = Join-Path $DP "deploy"
        # test -x through Git Bash: the .sh harness's executable check, as Git Bash sees it
        $isExec = Join-Path $W "is-exec.sh"
        [IO.File]::WriteAllText($isExec, "test -x `"`$1`"`n")
        $execRc =Invoke-TestScript -FilePath $gitBash -ArgumentList @((ConvertTo-MsysPath $isExec), (ConvertTo-MsysPath (Join-Path $G "setup-user-claude.sh"))) -OutFile (Join-Path $W "is-exec.out")
        Check "build: exit 0, setup-user-claude.sh/.ps1 generated" `
            ($buildRc -eq 0 -and $execRc -eq 0 -and (Test-Path -LiteralPath (Join-Path $G "setup-user-claude.ps1") -PathType Leaf))
        $genSh = Join-Path $G "setup-user-claude.sh"
        $genPs1 = Join-Path $G "setup-user-claude.ps1"
        Check "build (port): generated claude scripts take the footer hostname from the lib (A-25)" `
            ((FileHas $genSh 'MACHINE_HOST="${AITLIB_MACHINE_HOSTNAME:-}"') -and -not (FileHas $genSh 'scutil --get LocalHostName 2>&1) || _host_rc') -and (FileHas $genPs1 '$machineHost = [string]$script:AitLibMachineHostname') -and -not (FileHas $genPs1 'COMPUTERNAME).Split'))
        Check "build (port): generated claude scripts write the dry-run rows (A-26)" `
            ((CountMatch $genSh 'claude.md" "dry-run: would') -eq 2 -and (CountMatch $genPs1 'claude.md" "dry-run: would') -eq 2)
        Check "build A-20: no colour codes in non-terminal output" (-not (ReadText $script:OUT).Contains($ESC))
        $bashN = $true
        foreach ($s in @("setup-user-claude.sh", "setup-user-cursor.sh", "setup-user-settings.sh")) {
            $rcN = Invoke-TestScript -FilePath $gitBash -ArgumentList @("-n", (ConvertTo-MsysPath (Join-Path $G $s))) -OutFile (Join-Path $W "bash-n.out")
            if ($rcN -ne 0) { $bashN = $false; break }
        }
        Check "build: bash -n on the generated .sh (bash)" $bashN

        $embedPs1 = @("setup-user-claude.ps1", "setup-user-cursor.ps1", "setup-user-settings.ps1")
        $finallyRe = '^\} finally \{ Remove-AitoolsEmbed \}'
        $a19Static = $true
        foreach ($f in $embedPs1) {
            $fl = @(Lines (Join-Path $G $f))
            # one "try {" at column 0 per file: the embed block's own try (inside the
            # block, indented) does not count
            $nTry = @($fl | Where-Object { $_ -cmatch '^try \{' }).Count
            $nFin = @($fl | Where-Object { $_ -cmatch $finallyRe }).Count
            $last = @($fl | Where-Object { $_ -match '\S' }) | Select-Object -Last 1
            if ($nFin -ne 1 -or -not ("$last" -cmatch $finallyRe) -or $nTry -lt 1) { $a19Static = $false }
        }
        Check "build A-19: each resolver-embedding .ps1 ends with '} finally { Remove-AitoolsEmbed }'" $a19Static

        # -------------------------------------------------------------------------
        # A-19 runtime: each generated .ps1 runs (dry run) and exits normally
        # -------------------------------------------------------------------------
        $parseOk = $true
        foreach ($f in $embedPs1) {
            $pe = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $G $f), [ref]$null, [ref]$pe)
            if ($pe.Count -gt 0) { $pe | ForEach-Object { Write-Host "      | $f : $($_.Message)" }; $parseOk = $false }
        }
        Check "build A-19: pwsh parser accepts the three generated .ps1" $parseOk
        $a19How = "dry-run exit"
        $inProc = 'if ($env:G_ARGS) { & $env:G_SCRIPT -DryRun } else { & $env:G_SCRIPT }; if ($env:AITOOLS_PROFILE_PS1) { [Console]::WriteLine("LEAK $($env:AITOOLS_PROFILE_PS1)") } else { [Console]::WriteLine("ENV-RESTORED") }'
        foreach ($f in $embedPs1) {
            $n = $f -replace '\.ps1$', ''
            $T = Join-Path $tmpRoot "tmp-$n"; New-Item -ItemType Directory -Path $T -Force | Out-Null
            $h = Join-Path $tmpRoot "g-$n"; WriteConfig $h
            $script:OUT = Join-Path $tmpRoot "g-$n.out"
            # TMP/TEMP: .NET's temp dir on Windows (TMPDIR kept as the .sh harness sets it)
            $envs = @{
                AITOOLS_PROFILE_PS1 = $null; AITOOLS_PROFILE_FILE = $null; AITOOLS_DRY_RUN = $null
                HOME = (Mixed $h); USERPROFILE = (Mixed $h); TMPDIR = ((Mixed $T) + "/"); TMP = (Mixed $T); TEMP = (Mixed $T)
                AITOOLS_LOG_DIR = (Mixed (Join-Path $h "logs")); AITOOLS_SUMMARY_FILE = (Mixed (Join-Path $tmpRoot "g-$n.summary"))
            }
            $script:Rc["g-$n"] = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", (Join-Path $G $f), "-DryRun") -Environment $envs -OutFile $script:OUT
            Check "A-19 ${f}: $a19How leaves no aitools-embed-* temp dir" (NoEmbed $T)
            $script:OUT = Join-Path $tmpRoot "gi-$n.out"
            $envs.G_SCRIPT = Mixed (Join-Path $G $f); $envs.G_ARGS = "-DryRun"
            $null = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-Command", $inProc) -Environment $envs -OutFile $script:OUT
            Check "A-19 ${f}: in-process (& script) $a19How restores AITOOLS_PROFILE_PS1" `
                ((HasLine $script:OUT 'ENV-RESTORED') -and (NoEmbed $T))
        }

        # Full run of the generated claude .ps1, stub hostname
        $T = Join-Path $tmpRoot "tmp-full"; New-Item -ItemType Directory -Path $T -Force | Out-Null
        $h = Join-Path $tmpRoot "gps-full"; WriteConfig $h
        New-Item -ItemType Directory -Path (Join-Path $h ".aitools/skills/sk1") -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $h ".aitools/skills/sk1/SKILL.md"), "skill one`n")
        [IO.File]::WriteAllText((Join-Path $h ".aitools/skills/.aitools-skills-manifest"), "# aitools skills manifest v1`nsk1`tdotprofile`n")
        $script:OUT = Join-Path $tmpRoot "gps-full.out"
        [IO.File]::WriteAllText((Join-Path $tmpRoot "gps-full.summary"), "")
        $envs = @{
            AITOOLS_PROFILE_FILE = $null; AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null
            HOME = (Mixed $h); USERPROFILE = (Mixed $h); TMP = (Mixed $T); TEMP = (Mixed $T)
            AITOOLS_LOG_DIR = (Mixed (Join-Path $h "logs")); AITOOLS_SUMMARY_FILE = (Mixed (Join-Path $tmpRoot "gps-full.summary"))
            AITOOLS_PROFILE_PS1 = (Mixed (Join-Path $W "stub-host.ps1"))
        }
        $script:Rc["gps-full"] = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $genPs1) -Environment $envs -OutFile $script:OUT
        Check "MDM ps1 full run: exit 0, footer stub-host, claude.md row, temp dir removed" `
            ((RcOf "gps-full") -eq 0 -and (FileHas (Join-Path $h ".claude/CLAUDE.md") '(stub-host; profile m1)') -and (CountMatch (Join-Path $tmpRoot "gps-full.summary") '^OK\|claude.md\|created') -ge 1 -and (NoEmbed $T))
        Check "MDM ps1 full run: skills fanned out from ~/.aitools/skills" `
            ((HasLine (Join-Path $h ".claude/skills/sk1/SKILL.md") 'skill one') -and (Row "gps-full" 'OK|claude skills|1 added'))

        # -------------------------------------------------------------------------
        # MDM smoke runs (generated script, isolated HOME, the embedded resolver: no stub)
        # -------------------------------------------------------------------------
        function Run-Mdm([string]$Name, [string[]]$ScriptArgs = @()) {
            $h = Join-Path $tmpRoot $Name
            if (-not (Test-Path -LiteralPath (Join-Path $h ".aitools/config.json"))) { WriteConfig $h }
            $script:OUT = Join-Path $tmpRoot "$Name.out"
            [IO.File]::WriteAllText((Join-Path $tmpRoot "$Name.summary"), "")
            $envs = @{
                AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null; AITOOLS_USER_REPO_PATH = $null; AITOOLS_PROFILE_FILE = $null; AITOOLS_PROFILE_PS1 = $null
                HOME = (Mixed $h); USERPROFILE = (Mixed $h); AITOOLS_LOG_DIR = (Mixed (Join-Path $h "logs"))
                AITOOLS_SUMMARY_FILE = (Mixed (Join-Path $tmpRoot "$Name.summary"))
            }
            $argv = @("-NoProfile", "-NonInteractive", "-File", $genPs1) + $ScriptArgs
            $script:Rc[$Name] = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile $script:OUT
        }
        $M = "mdm-$lang"
        $MH = Join-Path $tmpRoot $M
        Run-Mdm $M @("-DryRun")
        Check "MDM $lang dry run: exit 0, 'dry-run: would create', nothing written" `
            ((RcOf $M) -eq 0 -and (ClaudeRows $M) -ceq 'OK|claude.md|dry-run: would create' -and -not (Test-Path -LiteralPath (MdOf $M)))
        Check "MDM $lang dry run without ~/.aitools/rules: claude rules n/a, rules not embedded" `
            ((Row $M 'OK|claude rules|n/a (no harness rules)') -and (CountMatch $genSh 'Rules fallback') -eq 0 -and (CountMatch $genPs1 'Rules fallback') -eq 0)
        # The rules reach ~/.claude/rules through ~/.aitools/rules, which deploy-harness
        # fills first on an endpoint: seed it as deploy-harness would (manifest included)
        New-Item -ItemType Directory -Path (Join-Path $MH ".aitools/rules") -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $MH ".aitools/rules/r1.md"), "rule one`n")
        [IO.File]::WriteAllText((Join-Path $MH ".aitools/rules/.aitools-rules-manifest"), "# aitools rules manifest v1`nr1.md`tdotprofile`n")
        Check "MDM $lang dry run without ~/.aitools/skills: no claude skills row (setup-user-skills owns it)" `
            (-not (FileHas (Join-Path $tmpRoot "$M.summary") '|claude skills|'))
        # The skills likewise reach ~/.claude/skills through ~/.aitools/skills (FO-4):
        # one skill, a nested file, the skills manifest
        New-Item -ItemType Directory -Path (Join-Path $MH ".aitools/skills/sk1/tests") -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $MH ".aitools/skills/sk1/SKILL.md"), "skill one`n")
        [IO.File]::WriteAllText((Join-Path $MH ".aitools/skills/sk1/tests/t.md"), "nested`n")
        [IO.File]::WriteAllText((Join-Path $MH ".aitools/skills/.aitools-skills-manifest"), "# aitools skills manifest v1`nsk1`tdotprofile`n")
        Run-Mdm $M
        Check "MDM $lang run: exit 0, created, footer hostname = resolver's ($liveHost), rules fanned out from ~/.aitools/rules" `
            ((RcOf $M) -eq 0 -and (Row $M 'OK|claude.md|created') -and (FileHas (MdOf $M) "($liveHost; profile m1)") -and (HasLine (Join-Path $MH ".claude/rules/r1.md") 'rule one') -and (Row $M 'OK|claude rules|1 added'))
        Check "MDM $lang run: skills fanned out from ~/.aitools/skills" `
            ((HasLine (Join-Path $MH ".claude/skills/sk1/SKILL.md") 'skill one') -and (HasLine (Join-Path $MH ".claude/skills/sk1/tests/t.md") 'nested') -and (Row $M 'OK|claude skills|2 added'))
        Run-Mdm $M @("-DryRun")
        Check "MDM $lang dry run after the deploy: 'verified'" `
            ((RcOf $M) -eq 0 -and (ClaudeRows $M) -ceq 'OK|claude.md|verified')

        # -------------------------------------------------------------------------
        # A-20: the standalone child resolver (no AITOOLS_USER_REPO_PATH) fails. Both
        # overrides are set (MSYS form, as the Git Bash harness passed them); the
        # bash lib under Git Bash runs fail.ps1 through pwsh.
        # -------------------------------------------------------------------------
        $HF = Join-Path $tmpRoot "home-fail"; WriteConfig $HF
        $script:OUT = Join-Path $tmpRoot "build-fail.out"
        $failEnv = @{
            AITOOLS_USER_REPO_PATH = $null; AITOOLS_SUMMARY_FILE = $null
            HOME = (ConvertTo-MsysPath $HF); USERPROFILE = (Mixed $HF); AITOOLS_LOG_DIR = (Mixed (Join-Path $HF "logs"))
            AITOOLS_PROFILE_SH = (ConvertTo-MsysPath (Join-Path $W "fail.sh")); AITOOLS_PROFILE_PS1 = (ConvertTo-MsysPath (Join-Path $W "fail.ps1"))
        }
        $script:Rc["build-fail"] = Invoke-TestScript -FilePath $gitBash -ArgumentList @($buildSh) -Environment $failEnv -OutFile $script:OUT
        $bfText = ReadText $script:OUT
        Check "A-20 resolver error: build skips (exit 0) with a plain-text warning" `
            ((RcOf "build-fail") -eq 0 -and (CountMatch $script:OUT '\[build-deploy\] \[warn\] Dotprofile resolver failed') -ge 1 -and -not $bfText.Contains($ESC))
        Check "A-20 resolver error: the child's error line is in deploy.log once, not in the build output" `
            ((CountMatch $script:OUT 'stub resolver failure') -eq 0 -and (CountMatch (Join-Path $HF "logs/deploy.log") '\[error\] dotprofile: stub resolver failure') -eq 1)
        if ($havePty) {
            $script:OUT = Join-Path $tmpRoot "build-fail-tty.out"
            $old = Set-TestEnv $failEnv
            try {
                & python3 $PTY --input= --log $script:OUT -- $gitBash $buildSh
            } finally { Restore-TestEnv $old }
            # ConPTY re-renders the screen, so its colour sequence may differ from
            # the [33m the build writes: any SGR sequence counts.
            Check "A-20 on a terminal: the warning is coloured and the child's error line is shown" `
                ((ReadText $script:OUT).Contains($ESC + "[") -and (CountMatch $script:OUT 'stub resolver failure') -ge 1)
        } else {
            Skip "A-20 terminal case (python3 pty not available)"
        }
    }
} finally {
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: {3} scripts)" -f $script:pass, $script:fail, $script:skip, $lang)
if ($script:fail -ne 0) { exit 1 }
exit 0
