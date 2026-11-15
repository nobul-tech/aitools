# test-user-init.ps1 -- `aitools user init` through scripts/aitools.ps1, end to end.
# The Windows harness of this suite; tests/profile/test-user-init.sh is the
# macOS/Linux harness of the same cases for the bash entry point scripts/aitools.
#
# Each case builds an isolated HOME with config.json, a throwaway aitools copy
# (scripts/ + shared/, git-initialised; setup-user-hooks replaced by a stub that
# writes one row and exits $env:HOOK_RC), a gh stub (gh.cmd running a PowerShell
# stub) and a dotprofile with a local bare remote. Machine id and hostname come
# from the resolver's test overrides (AITOOLS_PROFILE_TEST_MACHINE_ID /
# _HOSTNAME): never the real machine id (no registry read), HOME or dotprofile.
# Asserts exit codes, summary rows, profile.json, the remote's commits and the
# config.json machineId.
# M3-FINISH item 2: an unregistered machine runs the writer with -NoMachine and
# gets one machine-profile ERROR (user init's), none of the writer's; a
# registered machine (also one whose id cannot be detected) does not.
# Interactive cases run on a pseudo-terminal (tests/managed-files/pty-run.py with
# pywinpty/ConPTY; SKIP when python3 or pywinpty is unavailable).
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs scripts/aitools.ps1 with native pwsh on Windows only.
# Parity with the bash entry point is checked against the committed golden
# results in tests/profile/golden/userinit-*.txt (exit code, summary rows,
# profile.json with this machine's machine.os / machine.arch as <OS> / <ARCH>,
# commit subjects on both remotes, fixture directory as <D>, path separators
# as /; plus the pty-claim menu), which the .sh harness checks on macOS/Linux
# (Test-GoldenMatch in tests/lib/platform-lib.ps1).
#
# Safe to re-run: everything lives in a temp directory (removed on exit); git's
# global and system config are ignored. Exit 1 on failure.
#
# Usage: pwsh -NoProfile -File tests/profile/test-user-init.ps1 [-Help]

param([switch]$Help)
if ($Help) { foreach ($l in (Get-Content -LiteralPath $PSCommandPath)) { if ($l -notmatch '^#') { break }; $l -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/profile/test-user-init.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$pty = Join-Path $root "tests/managed-files/pty-run.py"
$tmpRoot = New-TestTempRoot "user-init"
$GoldenDir = Join-Path $root "tests/profile/golden"
$GoldenTmp = $tmpRoot
$lang = "ps1"
$utf8 = [Text.UTF8Encoding]::new($false)
$latin1 = [Text.Encoding]::Latin1

# The harness's own git calls (fixtures, checks) ignore the user's git config
# (signing, hooks, templates); each run of aitools.ps1 gets the case's .gitconfig.
$env:GIT_CONFIG_GLOBAL = Join-Path $tmpRoot "gitconfig-empty"
[IO.File]::WriteAllText($env:GIT_CONFIG_GLOBAL, "")
$env:GIT_CONFIG_NOSYSTEM = "1"

$script:pass = 0; $script:fail = 0; $script:skip = 0
function ok([string]$Name) { $script:pass++; Write-Host "  ok   $Name" }
function bad([string]$Name) { $script:fail++; Write-Host "  FAIL $Name" }
function say([string]$Text) { Write-Host $Text }

# python3 + pywinpty = the pty cases run; else they SKIP (reported below).
# Get-Command exempt: command-existence check; $usePty is the fallback branch.
$usePty = [bool](Get-Command python3 -CommandType Application -ErrorAction SilentlyContinue)
if ($usePty) {
    # Windows pty = pywinpty (ConPTY); a failing import means "not installed".
    $ErrorActionPreference = "Continue"
    & python3 -c "import winpty" *> $null
    $usePty = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = "Stop"
}

$THIS_ID = "AAAAAAAA-1111-2222-3333-444444444444"   # as macOS reports it (upper case)
$THIS_KEY = "aaaaaaaa-1111-2222-3333-444444444444"  # the profiles key (lower-cased)
$OTHER_ID = "bbbbbbbb-1111-2222-3333-444444444444"
$GH_USER = "nobul-jose"
$THIS_OS = "win32"

# Paths handed to aitools.ps1, git and config.json use the mixed form (C:/...),
# as the Git Bash harness gave them (cygpath -m) in the Windows CI runs the
# golden files were checked against; the <D> normalization covers every form.
function M([string]$Path) { $Path -replace '\\', '/' }
function Write-Lf([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $utf8) }
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
# Lines PATH: the file's lines as perl/grep read them (LF-split, no trailing empty line)
function Lines([string]$Path) {
    $t = ReadText $Path
    if ($t -eq "") { return @() }
    $l = @($t -split "`n")
    if ($l[-1] -eq "") { $l = @($l | Select-Object -SkipLast 1) }
    return $l
}
# Show PATH: each line, indented (the .sh's perl -pe 's/^/       /')
function Show([string]$Path) { foreach ($l in (Lines $Path)) { Write-Host "       $l" } }
# Edit-Bytes PATH PATTERN EVALUATOR [COUNT]: perl -pi / -0pi on raw bytes (Latin-1
# round trip keeps every byte, CRLF and BOM included); COUNT 1 = first match only
function Edit-Bytes([string]$Path, [string]$Pattern, [scriptblock]$Eval, [int]$Count = -1) {
    $t = $latin1.GetString([IO.File]::ReadAllBytes($Path))
    $re = [regex]::new($Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    $t = $re.Replace($t, [Text.RegularExpressions.MatchEvaluator]$Eval, $Count)
    [IO.File]::WriteAllBytes($Path, $latin1.GetBytes($t))
}
# G ARGS: one fixture git command; a failure stops the suite (the .sh's set -e)
function G {
    $ErrorActionPreference = "Continue"
    $o = & git @args 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "      | git $($args -join ' ') failed (exit $LASTEXITCODE): $($o -join ' / ')"
        throw "fixture: git $($args -join ' ') failed"
    }
}
# GitOut ARGS: stdout+stderr lines of a git command; $script:gitRc its exit code.
# PowerShell unrolls the returned array: wrap the call in @() to index it.
function GitOut {
    $ErrorActionPreference = "Continue"
    $o = @(& git @args 2>&1 | ForEach-Object { "$_" })
    $script:gitRc = $LASTEXITCODE
    return $o
}

try {
    # The throwaway aitools copy (one per run; each case gets its own copy of it)
    $SRC = Join-Path $tmpRoot "src"
    New-Item -ItemType Directory -Path $SRC | Out-Null
    Copy-Item -LiteralPath (Join-Path $root "scripts"), (Join-Path $root "shared") -Destination $SRC -Recurse -Force
    Write-Lf (Join-Path $SRC "scripts/setup-user-hooks.sh") ((@(
        '#!/usr/bin/env bash',
        '# test stub: one structured warn line when HOOK_WARN=1, one summary row, exit $HOOK_RC',
        'if [ "${HOOK_WARN:-}" = "1" ]; then printf ''[2026-01-01T00:00:00Z] [setup-user-hooks] [warn] stub hook warning\n''; fi',
        'if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then printf ''OK|claude hooks|stub\n'' >> "$AITOOLS_SUMMARY_FILE"; fi',
        'exit "${HOOK_RC:-0}"') -join "`n") + "`n")
    Write-Lf (Join-Path $SRC "scripts/setup-user-hooks.ps1") ((@(
        '# test stub: one structured warn line when HOOK_WARN=1, one summary row, exit $env:HOOK_RC',
        'if ($env:HOOK_WARN -eq "1") { Write-Host "[2026-01-01T00:00:00Z] [setup-user-hooks] [warn] stub hook warning" }',
        'if ($env:AITOOLS_SUMMARY_FILE) { [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, "OK|claude hooks|stub`n") }',
        '$rc = 0; if ($env:HOOK_RC) { $rc = [int]$env:HOOK_RC }',
        'exit $rc') -join "`n") + "`n")

    # gh stub: api user -> $GH_USER; repo view -> exit $GH_REPO_VIEW_RC (default 1: no
    # repo); repo clone U/R DIR -> clone of $GH_CLONE_SRC; repo create NAME --private
    # --source DIR --push -> a bare remote $GH_REMOTE, pushed. aitools.ps1 runs
    # bin\gh.cmd (first on PATH), which runs the PowerShell stub with this pwsh
    # (the Git Bash harness ran a bash stub through Git Bash here).
    $binDir = Join-Path $tmpRoot "bin"
    $stubDir = Join-Path $tmpRoot "stub"
    New-Item -ItemType Directory -Path $binDir, $stubDir | Out-Null
    $ghStub = Join-Path $stubDir "gh-stub.ps1"
    Write-Lf $ghStub ((@(
        '$a = @($args)',
        '$key = "$($a[0]) $(if ($a.Count -gt 1) { $a[1] } else { '''' })"',
        'if ($key -ceq "api user") { if ($env:GH_USER) { [Console]::Out.Write("$($env:GH_USER)`n"); exit 0 }; exit 1 }',
        'if ($key -ceq "repo view") { if ($env:GH_REPO_VIEW_RC) { exit [int]$env:GH_REPO_VIEW_RC }; exit 1 }',
        'if ($key -ceq "repo clone") { & git clone -q -b main $env:GH_CLONE_SRC $a[3]; if ($LASTEXITCODE -ne 0) { exit 1 }; exit 0 }',
        'if ($key -ceq "repo create") {',
        '    $src = ""; for ($i = 0; $i -lt $a.Count; $i++) { if ($a[$i] -ceq "--source" -and $i + 1 -lt $a.Count) { $src = $a[$i + 1] } }',
        '    & git init -q --bare -b main $env:GH_REMOTE; if ($LASTEXITCODE -ne 0) { exit 1 }',
        '    & git -C $src remote add origin $env:GH_REMOTE; if ($LASTEXITCODE -ne 0) { exit 1 }',
        '    & git -C $src push -q -u origin main; if ($LASTEXITCODE -ne 0) { exit 1 }',
        '    exit 0',
        '}',
        'exit 1') -join "`n") + "`n")
    [IO.File]::WriteAllText((Join-Path $binDir "gh.cmd"), "@`"$pwshExe`" -NoProfile -NonInteractive -File `"$ghStub`" %*`r`n@exit /b %ERRORLEVEL%`r`n")

    $PJ_TWO = (@(
        '{',
        '  "version": 2,',
        '  "meta": { "schemaRevision": "2.2" },',
        '  "identity": { "github": "nobul-jose", "name": "Jose", "company": "nobul-tech", "git": { "name": "Jose", "email": "jose@example.com" } },',
        '  "profiles": {',
        "    `"$OTHER_ID`": { `"alias`": `"laptop`", `"machine`": { `"id`": `"$OTHER_ID`", `"hostname`": `"laptop-host`" } },",
        '    "nobul-mac": { "machine": { "hostname": "old-host" } }',
        '  }',
        '}') -join "`n")
    $PJ_LEGACY = (@(
        '{',
        '  "version": 2,',
        '  "identity": { "github": "nobul-jose", "name": "Jose", "git": { "name": "Jose", "email": "jose@example.com" } },',
        '  "profiles": {',
        "    `"nobul-mac`": { `"machine`": { `"id`": `"$THIS_ID`", `"hostname`": `"probe-host`", `"shell`": `"zsh`" } },",
        "    `"laptop`": { `"machine`": { `"id`": `"$OTHER_ID`", `"hostname`": `"laptop-host`" } }",
        '  }',
        '}') -join "`n")

    # Fixture CASE PROFILE_JSON [CONFIG_EXTRA] -- HOME, aitools copy, dotprofile with a
    # bare remote. PROFILE_JSON "" = a dotprofile without profile.json; "-" = no
    # dotprofile at all. config.json holds the paths in the mixed form (see M).
    function Fixture([string]$Case, [string]$Pj, [string]$Extra = "") {
        $script:D = Join-Path $tmpRoot $Case
        if (Test-Path -LiteralPath $script:D) { Remove-Item -LiteralPath $script:D -Recurse -Force }
        $script:H = Join-Path $script:D "home"; $script:R = Join-Path $script:D "aitools"
        $script:DP = Join-Path $script:H "repos/aitools-$GH_USER"; $script:BARE = Join-Path $script:D "remote.git"
        New-Item -ItemType Directory -Path (Join-Path $script:H ".aitools"), (Join-Path $script:H "repos") | Out-Null
        Copy-Item -LiteralPath $SRC -Destination $script:R -Recurse
        G -C $script:R init -q
        Write-Lf (Join-Path $script:H ".gitconfig") "[user]`n`tname = Tester`n`temail = tester@example.com`n[init]`n`tdefaultBranch = main`n"
        Write-Lf (Join-Path $script:H ".aitools/config.json") ("{`n  `"version`": 3,`n  `"reposPath`": `"$(M (Join-Path $script:H 'repos'))`",`n  `"repoPath`": `"$(M $script:R)`"$Extra`n}`n")
        if ($Pj -eq "-") { return }
        G init -q --bare -b main (M $script:BARE)
        New-Item -ItemType Directory -Path $script:DP | Out-Null
        Write-Lf (Join-Path $script:DP "notes.txt") "notes`n"
        # A dotprofile with a profile.json also has its CLAUDE.md template (no scaffold commit)
        if ($Pj) {
            Write-Lf (Join-Path $script:DP "profile.json") "$Pj`n"
            New-Item -ItemType Directory -Path (Join-Path $script:DP "claude") | Out-Null
            Write-Lf (Join-Path $script:DP "claude/CLAUDE.md") "# template`n"
        }
        G -C $script:DP init -q -b main
        G -C $script:DP add -A
        G -C $script:DP -c user.name=T -c user.email=t@x commit -q -m init
        G -C $script:DP remote add origin (M $script:BARE)
        G -C $script:DP push -q -u origin main
    }

    # Norm-Run FILE -- in place: terminal control sequences (SGR colours; on ConPTY
    # also cursor moves, cursor-forward as spaces, mode and title sequences) and CR
    # removed; the fixture directory (native, mixed and MSYS forms) replaced by <D>,
    # with backslashes in the rest of that path turned into slashes. The .sh's
    # norm_run regexes, in the same order.
    function Norm-Run([string]$Path) {
        $t = ReadText $Path
        $t = [regex]::Replace($t, "\x1b\[([0-9]*)C", [Text.RegularExpressions.MatchEvaluator]{ param($m) $v = $m.Groups[1].Value; $n = if ($v -eq "" -or $v -eq "0") { 1 } else { [int]$v }; " " * $n })
        $t = [regex]::Replace($t, "\x1b\[[0-9;?]*[ -/]*[@-~]", "")
        $t = [regex]::Replace($t, "\x1b\][^\a\x1b]*(?:\a|\x1b\\)", "")
        $t = $t -replace "`r", ""
        foreach ($f in @($script:D, (M $script:D), (ConvertTo-MsysPath $script:D))) {
            $re = [regex]::new([regex]::Escape($f) + '([^ \t\n\r\f\v|"]*)')
            $t = $re.Replace($t, [Text.RegularExpressions.MatchEvaluator]{ param($m) "<D>" + ($m.Groups[1].Value -replace '\\', '/') })
        }
        Write-Lf $Path $t
    }

    # Run ARGS... -- aitools.ps1 user init in the fixture (bash-style options mapped:
    # --alias -> -Alias, --force -> -Force); $RC, $OUT (console), $SUM (summary
    # rows), both normalized. $CaseEnv is added to the environment; $PtyInput set =
    # the run is on a pseudo-terminal fed those keys (pty-run.py escapes).
    function Run([string[]]$CmdArgs = @()) {
        $envs = [ordered]@{
            AITOOLS_SUMMARY_FILE = $null; AITOOLS_MACHINE_ALIAS = $null; AITOOLS_USER_REPO_PATH = $null
            AITOOLS_PROFILE_FILE = $null; AITOOLS_FORCE = $null
            HOME = (M $script:H); USERPROFILE = (M $script:H)
            PATH = $binDir + [IO.Path]::PathSeparator + $env:PATH
            AITOOLS_LOG_DIR = (M (Join-Path $script:H ".aitools/logs")); AITOOLS_PRESERVE_SUMMARY = "1"
            GIT_CONFIG_GLOBAL = (M (Join-Path $script:H ".gitconfig")); GIT_CONFIG_NOSYSTEM = "1"; GH_USER = $GH_USER
            GH_REMOTE = (M (Join-Path $script:D "gh-remote.git")); GH_CLONE_SRC = (M (Join-Path $script:D "remote.git"))
            AITOOLS_PROFILE_TEST_MACHINE_ID = $THIS_ID; AITOOLS_PROFILE_TEST_HOSTNAME = "probe-host"
        }
        foreach ($k in $script:CaseEnv.Keys) { $envs[$k] = $script:CaseEnv[$k] }
        $pa = @()
        for ($i = 0; $i -lt $CmdArgs.Count; $i++) {
            switch -CaseSensitive ($CmdArgs[$i]) {
                "--alias" { $pa += "-Alias"; if ($i + 1 -lt $CmdArgs.Count) { $pa += $CmdArgs[$i + 1] }; $i++ }
                "--force" { $pa += "-Force" }
                default { $pa += $CmdArgs[$i] }
            }
        }
        $out = Join-Path $script:D "out.txt"
        $ht = @{}; foreach ($k in $envs.Keys) { $ht[$k] = $envs[$k] }
        if ($script:PtyInput) {
            $argv = @($pty, "--input", $script:PtyInput, "--log", (M $out), "--", $pwshExe, "-NoProfile", "-File", (M (Join-Path $script:R "scripts/aitools.ps1")), "user", "init") + $pa
            $py = (Get-Command python3 -CommandType Application | Select-Object -First 1).Source
            $script:RC = Invoke-TestScript -FilePath $py -ArgumentList $argv -Environment $ht -OutFile (Join-Path $script:D "pty-run.txt") -WorkingDirectory $script:D
        } else {
            $argv = @("-NoProfile", "-NonInteractive", "-File", (M (Join-Path $script:R "scripts/aitools.ps1")), "user", "init") + $pa
            $script:RC = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $ht -OutFile $out -WorkingDirectory $script:D
        }
        $script:OUT = $out
        $script:SUM = Join-Path $script:D "summary.txt"
        $last = Join-Path $script:H ".aitools/logs/last-summary.txt"
        # no rows = empty copy (asserted by the cases)
        if (Test-Path -LiteralPath $last -PathType Leaf) { Copy-Item -LiteralPath $last -Destination $script:SUM -Force } else { Write-Lf $script:SUM "" }
        if (-not (Test-Path -LiteralPath $out -PathType Leaf)) { Write-Lf $out "" }
        Norm-Run $script:OUT
        Norm-Run $script:SUM
    }

    # Norm-Pj FILE -- profile.json as compared: CR removed; this machine's machine.os
    # and machine.arch (platform facts written by register) as <OS> and <ARCH>.
    # The object after "<THIS_KEY>": is found by brace matching that skips strings
    # (the .sh's recursive perl pattern); the first "os" / "arch" in it is replaced.
    function Find-ObjectEnd([string]$T, [int]$Start) {
        $depth = 0; $i = $Start
        while ($i -lt $T.Length) {
            $c = $T[$i]
            if ($c -eq '"') {
                $i++
                while ($i -lt $T.Length -and $T[$i] -ne '"') { if ($T[$i] -eq '\') { $i++ }; $i++ }
                if ($i -ge $T.Length) { return -1 }
            } elseif ($c -eq '{') { $depth++ }
            elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { return $i } }
            $i++
        }
        return -1
    }
    function Norm-Pj([string]$Path) {
        $t = (ReadText $Path) -replace "`r", ""
        $re = [regex]::new('"' + [regex]::Escape($THIS_KEY) + '"[ \t\n\f\v]*:[ \t\n\f\v]*(?=\{)')
        $pos = 0
        while ($true) {
            $m = $re.Match($t, $pos)
            if (-not $m.Success) { break }
            $s = $m.Index + $m.Length
            $e = Find-ObjectEnd $t $s
            if ($e -lt 0) { $pos = $m.Index + 1; continue }
            $obj = $t.Substring($s, $e - $s + 1)
            $obj = ([regex]'("os"[ \t\n\f\v]*:[ \t\n\f\v]*)"[^"]*"').Replace($obj, [Text.RegularExpressions.MatchEvaluator]{ param($x) $x.Groups[1].Value + '"<OS>"' }, 1)
            $obj = ([regex]'("arch"[ \t\n\f\v]*:[ \t\n\f\v]*)"[^"]*"').Replace($obj, [Text.RegularExpressions.MatchEvaluator]{ param($x) $x.Groups[1].Value + '"<ARCH>"' }, 1)
            $t = $t.Substring(0, $s) + $obj + $t.Substring($e + 1)
            $pos = $s + $obj.Length
        }
        return $t
    }
    # Log-Subjects BARE -- commit subjects on main of a bare remote ("(none)" when absent)
    function Log-Subjects([string]$Bare) {
        if (-not (Test-Path -LiteralPath $Bare -PathType Container)) { return "(none)`n" }
        $o = GitOut -C $Bare log --format=%s main
        $s = ($o | ForEach-Object { "$_`n" }) -join ""
        if ($script:gitRc -ne 0) { $s += "(no main branch)`n" }  # shown in the golden diff
        return $s
    }
    # Result-Golden [NAME] -- this case's result (exit code, summary rows, profile.json,
    # remote commits) must equal the golden file userinit-NAME.txt (sh and ps1 share
    # it; NAME defaults to this case's name)
    function Result-Golden([string]$Name = "") {
        $g = if ($Name) { $Name } else { $script:CASE }
        $f = Join-Path $script:D "result.txt"
        $pjf = Join-Path $script:DP "profile.json"
        $text = "exit $($script:RC)`n-- summary rows`n" + (ReadText $script:SUM) + "-- profile.json`n"
        $text += if (Test-Path -LiteralPath $pjf -PathType Leaf) { Norm-Pj $pjf } else { "(none)`n" }
        $text += "-- remote.git commits`n" + (Log-Subjects (Join-Path $script:D "remote.git"))
        $text += "-- gh-remote.git commits`n" + (Log-Subjects (Join-Path $script:D "gh-remote.git"))
        Write-Lf $f $text
        if ($g -ne $script:CASE -and $env:AITOOLS_TEST_UPDATE_GOLDEN -eq "1") {
            Write-Host "      | $($script:CASE): compared with userinit-$g.txt, not written"; return
        }
        $suffix = if ($Name) { " userinit-$g.txt" } else { "" }
        if (Test-GoldenMatch "userinit-$g.txt" $f) { ok "$($script:CASE): exit, rows, profile.json and commits match golden$suffix" }
        else { bad "$($script:CASE): result differs from golden userinit-$g.txt" }
    }

    # Case-Run NAME WANT_RC SETUP ARGS... -- SETUP builds the fixture; one run, then the golden
    function Case-Run([string]$Name, [int]$Want, [scriptblock]$Setup, [string[]]$CmdArgs = @()) {
        $script:CASE = $Name
        & $Setup
        Run $CmdArgs
        if ($script:RC -eq $Want) { ok "${Name}: $lang exit $($script:RC)" }
        else { bad "${Name}: $lang exit $($script:RC), want $Want"; Show $script:OUT }
        Result-Golden
    }
    function Has-Row([string]$Row) {
        if (@(Lines $script:SUM) -ccontains $Row) { ok "$($script:CASE): row $Row" } else { bad "$($script:CASE): no row '$Row'"; Show $script:SUM }
    }
    # No-RowLike TEXT -- no summary row contains TEXT (the .sh's grep pattern; every
    # pattern used has no regex metacharacter, so a fixed-string test is the same)
    function No-RowLike([string]$Text) {
        if ((ReadText $script:SUM).Contains($Text)) { bad "$($script:CASE): unexpected row /$Text/"; Show $script:SUM } else { ok "$($script:CASE): no row /$Text/" }
    }
    function Out-Has([string]$Text) {
        if ((ReadText $script:OUT).Contains($Text)) { ok "$($script:CASE): output has '$Text'" } else { bad "$($script:CASE): output lacks '$Text'"; Show $script:OUT }
    }
    # Out-Count STRING N -- the console output has STRING at least N times (ConPTY
    # re-renders the screen and may repeat a line it already sent)
    function Out-Count([string]$Text, [int]$N) {
        $t = ReadText $script:OUT; $n = 0; $i = 0
        while (($i = $t.IndexOf($Text, $i, [StringComparison]::Ordinal)) -ge 0) { $n++; $i += $Text.Length }
        if ($n -ge $N) { ok "$($script:CASE): output has '$Text' $N time(s)" }
        else { bad "$($script:CASE): output has '$Text' $n time(s), want $N"; Show $script:OUT }
    }
    # Log-Has STRING -- the case HOME's deploy.log has STRING (fixed string)
    function Log-Has([string]$Text) {
        $lf = Join-Path $script:H ".aitools/logs/deploy.log"
        if ((Test-Path -LiteralPath $lf -PathType Leaf) -and (ReadText $lf).Contains($Text)) { ok "$($script:CASE): deploy.log has '$Text'" }
        else {
            bad "$($script:CASE): deploy.log lacks '$Text'"
            foreach ($l in (Lines $lf)) { if ($l -cmatch 'menu answer') { Write-Host "       $l" } }
        }
    }
    # Pj-Has REGEX -- the dotprofile's profile.json matches (whole file)
    function Pj-Has([string]$Re) {
        $pjf = Join-Path $script:DP "profile.json"
        if ((Test-Path -LiteralPath $pjf -PathType Leaf) -and [regex]::IsMatch((ReadText $pjf), $Re, [Text.RegularExpressions.RegexOptions]::Singleline)) { ok "$($script:CASE): profile.json /$Re/" }
        else { bad "$($script:CASE): profile.json lacks /$Re/"; Show $pjf }
    }
    function Pj-Lacks([string]$Re) {
        $pjf = Join-Path $script:DP "profile.json"
        if (-not [regex]::IsMatch((ReadText $pjf), $Re, [Text.RegularExpressions.RegexOptions]::Singleline)) { ok "$($script:CASE): profile.json has no /$Re/" }
        else { bad "$($script:CASE): profile.json has /$Re/" }
    }
    # Json-Get FILE SEG... -- a scalar of a JSON file ("" = absent, not a scalar or
    # unreadable), keys matched case-sensitively as aitools-json.pl get does.
    # Json-Has FILE SEG... -- $true when the path exists (aitools-json.pl type).
    function Json-Node([string]$File, [string[]]$Segs) {
        if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { return $null }
        try { $doc = [Text.Json.JsonDocument]::Parse([IO.File]::ReadAllText($File)) } catch { Write-Host "      | $File is not valid JSON: $($_.Exception.Message)"; return $null }
        $el = $doc.RootElement
        foreach ($s in $Segs) {
            $next = [Text.Json.JsonElement]::new()
            if ($el.ValueKind -ne [Text.Json.JsonValueKind]::Object -or -not $el.TryGetProperty($s, [ref]$next)) { return $null }
            $el = $next
        }
        return , $el
    }
    function Json-Get([string]$File, [string[]]$Segs) {
        $el = Json-Node $File $Segs
        if ($null -eq $el) { return "" }
        switch ($el.ValueKind) {
            ([Text.Json.JsonValueKind]::String) { return $el.GetString() }
            ([Text.Json.JsonValueKind]::Number) { return $el.GetRawText() }
            ([Text.Json.JsonValueKind]::True) { return "true" }
            ([Text.Json.JsonValueKind]::False) { return "false" }
        }
        return ""
    }
    function Json-Has([string]$File, [string[]]$Segs) { return ($null -ne (Json-Node $File $Segs)) }
    function Pj-Get([string[]]$Segs) { return (Json-Get (Join-Path $script:DP "profile.json") $Segs) }
    # Pj-Alias KEY ALIAS -- profiles.KEY.alias is ALIAS and its machine.id the key
    function Pj-Alias([string]$Key, [string]$Alias) {
        $a = Pj-Get @("profiles", $Key, "alias"); $m = Pj-Get @("profiles", $Key, "machine", "id")
        if ($a -ceq $Alias -and $m.ToLowerInvariant() -ceq $Key) { ok "$($script:CASE): profiles.$Key alias $Alias" }
        else { bad "$($script:CASE): profiles.$Key alias '$a' id '$m', want alias $Alias"; Show (Join-Path $script:DP "profile.json") }
    }
    function Pj-NoKey([string]$Key) {
        if (Json-Has (Join-Path $script:DP "profile.json") @("profiles", $Key)) { bad "$($script:CASE): profiles.$Key still present" }
        else { ok "$($script:CASE): no profiles.$Key" }
    }
    function Pj-OtherIntact {
        $a = Pj-Get @("profiles", $OTHER_ID, "alias"); $m = Pj-Get @("profiles", $OTHER_ID, "machine", "id"); $hn = Pj-Get @("profiles", $OTHER_ID, "machine", "hostname")
        if ($a -ceq "laptop" -and $m -ceq $OTHER_ID -and $hn -ceq "laptop-host") { ok "$($script:CASE): the other machine's profile is untouched" }
        else { bad "$($script:CASE): other profile changed: alias '$a' id '$m' hostname '$hn'" }
    }
    # Remote-Has BARE SUBJECT -- a commit with this subject reached the bare remote
    function Remote-Has([string]$Bare, [string]$Subject) {
        $subjects = GitOut -C $Bare log --format=%s main
        if ($script:gitRc -ne 0) { $subjects = @() }  # no branch = no commits (reported below)
        if ($subjects -ccontains $Subject) { ok "$($script:CASE): remote has '$Subject'" }
        else {
            bad "$($script:CASE): remote lacks '$Subject'"
            foreach ($l in (GitOut -C $Bare log "--format=       %s" main)) { Write-Host $l }  # diagnostic only
        }
    }
    function Remote-Count([string]$Bare, [int]$N) {
        $o = @(GitOut -C $Bare rev-list --count main)  # @(): one output line must stay an array
        $n = if ($script:gitRc -eq 0) { [int]("$($o[0])".Trim()) } else { 0 }  # no branch = 0 commits
        if ($n -eq $N) { ok "$($script:CASE): remote has $N commit(s)" } else { bad "$($script:CASE): remote has $n commit(s), want $N" }
    }
    # Row-Count PREFIX N -- exactly N summary rows start with PREFIX
    function Row-Count([string]$Prefix, [int]$N) {
        $n = @(Lines $script:SUM | Where-Object { $_.StartsWith($Prefix, [StringComparison]::Ordinal) }).Count
        if ($n -eq $N) { ok "$($script:CASE): $N row(s) '$Prefix'" } else { bad "$($script:CASE): $n row(s) '$Prefix', want $N"; Show $script:SUM }
    }
    # No-MachineFlag yes|no -- M3-FINISH item 2: whether setup-user-config ran with
    # -NoMachine, read from its info line in the output
    function No-MachineFlag([string]$Want) {
        $got = if ((ReadText $script:OUT).Contains("machine registration is left to the caller")) { "yes" } else { "no" }
        if ($got -eq $Want) { ok "$($script:CASE) (${lang}): writer flag --no-machine $Want" }
        else { bad "$($script:CASE) (${lang}): writer flag --no-machine $got, want $Want"; Show $script:OUT }
    }
    # Unregistered-Once -- the machine-profile outcome is reported once, by user init:
    # one "machine profile" ERROR row, none of the writer's (no machine match, its ACTION)
    function Unregistered-Once {
        Row-Count "ERROR|machine profile|" 1
        No-RowLike "no machine match"
        No-RowLike "ACTION||Run: aitools user init (profiles:"
        No-MachineFlag "yes"
    }
    function Cfg-Id([string]$Want) {
        $v = Json-Get (Join-Path $script:H ".aitools/config.json") @("machineId")
        if ($v -ceq $Want) { ok "$($script:CASE): config.json machineId '$Want'" } else { bad "$($script:CASE): config.json machineId '$v', want '$Want'" }
    }
    # Register-This -- this machine's profile added to the fixture's profile.json and pushed
    function Register-This {
        Edit-Bytes (Join-Path $script:DP "profile.json") '("profiles": \{)' { param($m) $m.Groups[1].Value + "`n    `"$THIS_KEY`": { `"alias`": `"mine`", `"machine`": { `"id`": `"$THIS_KEY`", `"hostname`": `"probe-host`" } }," } 1
        G -C $script:DP -c user.name=T -c user.email=t@x commit -q -am "register"
        G -C $script:DP push -q
    }

    say "user init tests (windows: $lang entry point)"
    $script:CaseEnv = @{}
    $script:PtyInput = ""
    $fx_two = { Fixture $script:CASE $PJ_TWO }
    $fx_legacy = { Fixture $script:CASE $PJ_LEGACY }

    say "== decision 1: --alias <new> without a terminal creates this machine's profile (Review3 #82 M1)"
    Case-Run "alias-new" 0 $fx_two @("--alias", "spare")
    Pj-Alias $THIS_KEY "spare"
    Pj-Has "`"id`": `"$THIS_KEY`""
    Has-Row "OK|machine profile|created (spare)"
    Remote-Has $BARE "Register machine profile: spare"
    Cfg-Id $THIS_KEY
    # the summary panel: dashed rule (aitools-lib.ps1 Show-Summary)
    Out-Has "------------------------------------------------------------"
    No-MachineFlag "no"
    # machine.shell (Review3 #82 minor 6): aitools.ps1 records pwsh
    if ((Pj-Get @("profiles", $THIS_KEY, "machine", "shell")) -ceq "pwsh") { ok "$($script:CASE): machine.shell from `$SHELL" }
    else { bad "$($script:CASE): machine.shell '$(Pj-Get @("profiles", $THIS_KEY, "machine", "shell"))'" }
    # machine.os / machine.arch: this platform's facts (the golden holds <OS> / <ARCH>)
    if ((Pj-Get @("profiles", $THIS_KEY, "machine", "os")) -ceq $THIS_OS) { ok "$($script:CASE): machine.os $THIS_OS" }
    else { bad "$($script:CASE): machine.os '$(Pj-Get @("profiles", $THIS_KEY, "machine", "os"))', want $THIS_OS" }
    if (Pj-Get @("profiles", $THIS_KEY, "machine", "arch")) { ok "$($script:CASE): machine.arch set" } else { bad "$($script:CASE): machine.arch missing" }

    say "== re-run: verified, no new commit"
    $script:CASE = "alias-new-rerun"
    Run
    if ($script:RC -eq 0) { ok "$($script:CASE): exit 0" } else { bad "$($script:CASE): exit $($script:RC)"; Show $script:OUT }
    Has-Row "OK|machine profile|verified (spare)"
    Remote-Count $BARE 2

    say "== decision 1: --alias of another machine's profile, no terminal -> refused (exit 1)"
    Case-Run "alias-other" 1 $fx_two @("--alias", "laptop")
    Has-Row "ERROR|machine profile|alias used by another machine"
    Unregistered-Once
    Pj-Lacks "`"$THIS_KEY`""
    Pj-OtherIntact
    Remote-Count $BARE 1

    say "== an unregistered machine without --alias and without a terminal -> ERROR, exit 1"
    Case-Run "unregistered-notty" 1 $fx_two
    Has-Row "ERROR|machine profile|not registered (no terminal)"
    Has-Row "ACTION||Run: aitools user init --alias <name> (or on a terminal)"
    Unregistered-Once

    say "== --alias naming a profile no machine owns: claimed (explicit choice)"
    Case-Run "alias-claim" 0 $fx_two @("--alias", "nobul-mac")
    Pj-Alias $THIS_KEY "nobul-mac"
    Pj-NoKey "nobul-mac"

    say "== batch 5: legacy profiles are re-keyed (migrate), the writer's re-key ACTION clears"
    Case-Run "migrate" 0 $fx_legacy
    Has-Row "OK|profile keys|re-keyed by machine id"
    Pj-Alias $THIS_KEY "nobul-mac"
    Pj-Alias $OTHER_ID "laptop"
    Remote-Has $BARE "Migrate machine profiles to id keys"
    No-RowLike "re-keys machine profiles"
    Cfg-Id $THIS_KEY

    say "== decision 6: Path 1 without profile.json -> scaffold, committed and pushed"
    Case-Run "scaffold-path1" 0 { Fixture $script:CASE "" }
    Pj-Alias $THIS_KEY "probe-host"
    Pj-Has '"schemaRevision": "2.2"'
    Pj-Has "`"github`": `"$GH_USER`""
    Remote-Has $BARE "Register machine profile: probe-host"
    Remote-Has $BARE "Add claude/CLAUDE.md template"

    say "== decision 6: Path 3 (no dotprofile) -> created, scaffold reaches the (gh) remote"
    Case-Run "scaffold-path3" 0 { Fixture $script:CASE "-" } @("--alias", "first")
    Pj-Alias $THIS_KEY "first"
    Remote-Has (Join-Path $D "gh-remote.git") "Initial commit: profile and session archive structure"
    Remote-Has (Join-Path $D "gh-remote.git") "Add claude/CLAUDE.md template"
    $remotePj = (GitOut -C (Join-Path $D "gh-remote.git") show main:profile.json) -join "`n"
    if ($script:gitRc -ne 0) { $remotePj = "" }  # absent = not pushed (asserted)
    if ($remotePj.Contains("`"$THIS_KEY`"")) { ok "$($script:CASE): profile.json on the remote" } else { bad "$($script:CASE): profile.json not on the remote" }
    Has-Row "OK|dotprofile|created"

    say "== decision 2 switch = 0 (default): cached machineAlias, no terminal -> ERROR, exit 1 (same as unregistered)"
    $fx_cached = { Fixture $script:CASE $PJ_TWO ",`n  `"machineAlias`": `"nobul-mac`"" }
    Case-Run "cached-alias-0" 1 $fx_cached
    Has-Row "ERROR|machine profile|not registered (no terminal)"
    Unregistered-Once
    Pj-Lacks "`"$THIS_KEY`""

    say "== decision 2 switch = 1: cached machineAlias -> claimed without asking"
    $fx_cached_on = {
        & $fx_cached
        # .ps1 files are checked out with CRLF (.gitattributes eol=crlf): \r? before the end
        foreach ($f in @((Join-Path $R "scripts/aitools"), (Join-Path $R "scripts/aitools.ps1"))) {
            Edit-Bytes $f '^AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0(\r?)$' { param($m) "AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=1" + $m.Groups[1].Value }
            Edit-Bytes $f '^(\$script:RegisterCachedAliasSilently = )\$false(\r?)$' { param($m) $m.Groups[1].Value + '$true' + $m.Groups[2].Value }
        }
    }
    Case-Run "cached-alias-1" 0 $fx_cached_on
    Pj-Alias $THIS_KEY "nobul-mac"
    $swSh = (@($latin1.GetString([IO.File]::ReadAllBytes((Join-Path $root "scripts/aitools"))) -split "`n" | Where-Object { $_ -cmatch '^AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=' }) -join "`n")
    $swPs = (@($latin1.GetString([IO.File]::ReadAllBytes((Join-Path $root "scripts/aitools.ps1"))) -split "`n" | Where-Object { $_ -cmatch '^\$script:RegisterCachedAliasSilently = ' }) -join "`n")
    if ($swSh -ceq "AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0" -and ($swPs -creplace "`r$", "") -ceq '$script:RegisterCachedAliasSilently = $false') {
        ok 'decision 2 switch: one line per entry point, default 0 / $false'
    } else { bad "decision 2 switch line not found (or not at its default) in scripts/aitools / aitools.ps1" }

    say "== Review3 #82 minor 5: uncommitted edits to profile.json are never committed"
    $fx_dirty = { & $fx_two; Edit-Bytes (Join-Path $DP "profile.json") '"old-host"' { param($m) '"edited-host"' } }
    Case-Run "dirty" 1 $fx_dirty @("--alias", "spare")
    Has-Row "ERROR|machine profile|not registered (local edits)"
    Unregistered-Once
    Pj-Has '"edited-host"'
    Pj-Lacks "`"$THIS_KEY`""
    Remote-Count $BARE 1
    $fx_dirty_reg = {
        Fixture $script:CASE $PJ_TWO
        Register-This
        Edit-Bytes (Join-Path $DP "profile.json") '"old-host"' { param($m) '"edited-host"' }
    }
    Case-Run "dirty-registered" 0 $fx_dirty_reg
    Has-Row "WARN|machine profile|not refreshed (local edits)"
    No-MachineFlag "no"
    Remote-Count $BARE 2

    say "== Review3 #82 minor 4: a rejected push (remote ahead) is told to pull --rebase"
    $fx_ahead = {
        & $fx_two
        $w = Join-Path $D "other"
        G clone -q -b main (M $BARE) (M $w); Write-Lf (Join-Path $w "other.txt") "x`n"; G -C $w add other.txt
        G -C $w -c user.name=O -c user.email=o@x commit -q -m other; G -C $w push -q origin main
    }
    Case-Run "push-rejected" 0 $fx_ahead @("--alias", "spare")
    Out-Has "git pull --rebase, then git push"
    Has-Row "ACTION||git pull --rebase, then git push in <D>/home/repos/aitools-$GH_USER"
    Has-Row "WARN|machine profile|created (spare)"

    say "== D-TS13: the hooks review aborted (exit 2) -> user init exits 2"
    $script:CaseEnv = @{ HOOK_RC = "2" }
    Case-Run "hook-abort" 2 $fx_two @("--alias", "spare")
    # FIX-2 (A-13): the relay records the abort (the stub wrote no ERROR row)
    Has-Row "ERROR|claude hooks|aborted (exit 2)"
    $script:CaseEnv = @{}

    # Jsonl-Count CASE SCRIPT [LEVEL MSG] -- valid records of SCRIPT (with LEVEL and
    # MSG when given) in that fixture's deploy.jsonl; "invalid" when a line is not JSON
    function Jsonl-Count([string]$CaseName, [string]$ScriptName, [string]$Level = $null, [string]$Msg = $null) {
        $f = Join-Path $tmpRoot "$CaseName/home/.aitools/logs/deploy.jsonl"
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { return "0" }
        $n = 0
        foreach ($r in (Lines $f)) {
            try { $o = [Text.Json.JsonDocument]::Parse($r).RootElement } catch { return "invalid" }
            $p = [Text.Json.JsonElement]::new()
            $sv = if ($o.ValueKind -eq [Text.Json.JsonValueKind]::Object -and $o.TryGetProperty("script", [ref]$p)) { "$p" } else { "" }
            if ($sv -cne $ScriptName) { continue }
            if ($PSBoundParameters.ContainsKey("Level")) {
                $lv = if ($o.TryGetProperty("level", [ref]$p)) { "$p" } else { "" }
                $mv = if ($o.TryGetProperty("msg", [ref]$p)) { "$p" } else { "" }
                if ($lv -cne $Level -or $mv -cne $Msg) { continue }
            }
            $n++
        }
        return "$n"
    }

    say "== FIX-2 (A-12, A-13): user init runs setup-user-config and setup-user-hooks through the lib relay"
    # A hooks script that dies (exit 3) without an ERROR row: the relay's row, one error, exit 1
    $script:CaseEnv = @{ HOOK_RC = "3" }
    Case-Run "hook-crash" 1 $fx_two @("--alias", "spare")
    Has-Row "ERROR|claude hooks|script failed (exit 3)"
    Row-Count "ERROR|claude hooks|" 1
    $script:CaseEnv = @{}
    # The children's lines reach deploy.jsonl and the console; a hooks warning is relayed
    $script:CaseEnv = @{ HOOK_WARN = "1" }
    Case-Run "relay-jsonl" 0 $fx_two @("--alias", "spare")
    Out-Has "[setup-user-hooks] [warn] stub hook warning"
    $n = Jsonl-Count "relay-jsonl" "setup-user-hooks" "warn" "stub hook warning"
    if ($n -eq "1") { ok "relay-jsonl (${lang}): hooks warning in deploy.jsonl" }
    else { bad "relay-jsonl (${lang}): hooks warning records '$n', want 1" }
    $n = Jsonl-Count "relay-jsonl" "setup-user-config"
    if ($n -ne "invalid" -and [int]$n -gt 0) { ok "relay-jsonl (${lang}): writer lines in deploy.jsonl ($n)" }
    else { bad "relay-jsonl (${lang}): writer records '$n'" }
    $script:CaseEnv = @{}

    say "== FIX-2 (A-15): --alias without a value is an error through the lib (bash; pwsh binds it itself)"
    $script:CASE = "alias-novalue"
    # The bash entry point's own check; aitools.ps1 binds -Alias through its param block.
    Write-Host "  skip $($script:CASE): bash entry point only (pwsh binds -Alias itself)"; $script:skip++

    say "== review M1: a relative reposPath is refused (nothing created under the current directory)"
    $fx_relative = { Fixture $script:CASE $PJ_TWO; Edit-Bytes (Join-Path $H ".aitools/config.json") '"reposPath": "[^"]*"' { param($m) '"reposPath": "repos"' } }
    Case-Run "relative-repos" 1 $fx_relative @("--alias", "spare")
    Has-Row "ERROR|dotprofile|reposPath not absolute"
    if (Test-Path -LiteralPath (Join-Path $D "repos")) { bad "$($script:CASE): a repos/ directory was created under the cwd" } else { ok "$($script:CASE): nothing created under the cwd" }

    say "== review M2: id undetectable (via=config) -> WARN, the cached machineId survives two runs"
    $fx_viaconfig = { Fixture $script:CASE $PJ_TWO ",`n  `"machineId`": `"$THIS_KEY`""; Register-This }
    $script:CaseEnv = @{ AITOOLS_PROFILE_TEST_MACHINE_ID = "none" }
    Case-Run "via-config" 0 $fx_viaconfig
    Has-Row "WARN|machine profile|not refreshed (no machine id)"
    Cfg-Id $THIS_KEY
    # Registered, id undetectable: machine_key is emptied for the writer, but no flag
    No-MachineFlag "no"
    $script:CASE = "via-config-rerun"
    Run
    if ($script:RC -eq 0) { ok "$($script:CASE): second run exit 0" } else { bad "$($script:CASE): second run exit $($script:RC)"; Show $script:OUT }
    Cfg-Id $THIS_KEY
    $script:CaseEnv = @{}

    say "== review m3: --alias wins over a stale AITOOLS_MACHINE_ALIAS"
    $script:CaseEnv = @{ AITOOLS_MACHINE_ALIAS = "bogus" }
    Case-Run "env-alias-stale" 0 $fx_two @("--alias", "spare")
    Pj-Alias $THIS_KEY "spare"
    Out-Has "AITOOLS_MACHINE_ALIAS=bogus ignored"
    $script:CaseEnv = @{}

    say "== Path 2: the GitHub repo exists, no local clone -> cloned, identity from the profile, registered"
    $fx_path2 = { & $fx_two; Remove-Item -LiteralPath $DP -Recurse -Force }
    $script:CaseEnv = @{ GH_REPO_VIEW_RC = "0" }
    Case-Run "path2" 0 $fx_path2 @("--alias", "spare")
    Has-Row "OK|dotprofile|cloned"
    Pj-Alias $THIS_KEY "spare"
    Remote-Has $BARE "Register machine profile: spare"
    $p2 = @(GitOut -C $DP config user.name)  # @(): one output line must stay an array
    $p2Name = if ($script:gitRc -eq 0) { "$($p2[0])" } else { "" }  # unset = "" (asserted)
    if ($p2Name -ceq "Jose") { ok "$($script:CASE): clone's git identity from identity.git" } else { bad "$($script:CASE): clone identity '$p2Name'" }
    $script:CaseEnv = @{}

    say "== v1 profile.json -> v2 revision 2.2, this machine under its id, other machines kept, committed"
    $PJ_V1 = (@(
        '{ "name": "Jose", "email": "jose@example.com", "github": "nobul-jose", "company": "nobul-tech",',
        '  "git": { "name": "Jose", "email": "jose@example.com" },',
        '  "machines": [ { "hostname": "probe-host.local", "os": "darwin" }, { "hostname": "other-box", "os": "linux" } ],',
        '  "cursor": { "cli": { "model": "auto" } } }') -join "`n")
    Case-Run "v1-migrate" 0 { Fixture $script:CASE $PJ_V1 } @("--alias", "mac1")
    Pj-Alias $THIS_KEY "mac1"
    if ((Pj-Get @("version")) -ceq "2" -and (Pj-Get @("meta", "schemaRevision")) -ceq "2.2") { ok "$($script:CASE): version 2, revision 2.2" } else { bad "$($script:CASE): version '$(Pj-Get @("version"))'" }
    if ((Pj-Get @("profiles", "machine1", "machine", "hostname")) -ceq "other-box") { ok "$($script:CASE): the other v1 machine kept (machine1)" } else { bad "$($script:CASE): machine1 '$(Pj-Get @("profiles", "machine1", "machine", "hostname"))'" }
    if ((Pj-Get @("cursor", "cli", "model")) -ceq "auto") { ok "$($script:CASE): cursor section kept" } else { bad "$($script:CASE): cursor section lost" }
    Remote-Has $BARE "Migrate profile.json from v1 to v2"
    $cfgFile = Join-Path $H ".aitools/config.json"
    $v1n = Json-Node $cfgFile @("machineAlias")
    if ($null -ne $v1n -and $v1n.ValueKind -ne [Text.Json.JsonValueKind]::Object -and $v1n.ValueKind -ne [Text.Json.JsonValueKind]::Array) {
        $v1Alias = Json-Get $cfgFile @("machineAlias")
        if ($v1Alias -ceq "mac1") { ok "$($script:CASE): config.json written by setup-user-config" } else { bad "$($script:CASE): config machineAlias '$v1Alias'" }
    } else { bad "$($script:CASE): config.json has no machineAlias" }

    say "== profile-check.js reads machineId (id keys; legacy machineAlias kept)"
    # profile-check.js is a node script for every platform (aitools.ps1 and scripts/aitools call it)
    $script:CASE = "profile-check"
    Fixture $script:CASE $PJ_TWO (",`n  `"userRepoPath`": `"$(M (Join-Path $tmpRoot 'profile-check/home/repos/aitools-nobul-jose'))`",`n  `"machineId`": `"deadbeef-0000-0000-0000-000000000000`"")
    $pcCfg = M (Join-Path $H ".aitools/config.json")
    $pcJs = M (Join-Path $root "scripts/profile-check.js")
    function Profile-Check {
        $ErrorActionPreference = "Continue"
        $o = (& node $pcJs --config $pcCfg | Out-String)
        if ($LASTEXITCODE -ne 0) { return "" }
        return $o
    }
    $pc = Profile-Check
    if ($pc.Contains('"code":"MACHINE_ID_UNKNOWN"')) { ok "$($script:CASE): unknown machineId reported" } else { bad "$($script:CASE): $pc" }
    if ($pc.Contains('"machineId":"deadbeef-0000-0000-0000-000000000000"')) { ok "$($script:CASE): machineId in the result" } else { bad "$($script:CASE): $pc" }
    Edit-Bytes (Join-Path $H ".aitools/config.json") 'deadbeef-0000-0000-0000-000000000000' { param($m) $OTHER_ID }
    $pc = Profile-Check
    if ($pc.Contains('MACHINE_ID_UNKNOWN')) { bad "$($script:CASE): id-keyed machineId reported: $pc" } else { ok "$($script:CASE): id-keyed machineId found" }
    Edit-Bytes (Join-Path $H ".aitools/config.json") ([regex]::Escape($OTHER_ID)) { param($m) $THIS_ID }
    Edit-Bytes (Join-Path $DP "profile.json") '"old-host"' { param($m) "`"old-host`", `"id`": `"$THIS_ID`"" }
    $pc = Profile-Check
    if ($pc.Contains('MACHINE_ID_UNKNOWN')) { bad "$($script:CASE): legacy (alias-keyed) profile not read: $pc" } else { ok "$($script:CASE): legacy alias-keyed profile found by machine.id" }

    if ($usePty) {
        say "== interactive (pty): claim an unregistered profile; the menu matches the golden (both shells)"
        $script:PtyInput = '1\n'
        Case-Run "pty-claim" 0 $fx_two
        Pj-Alias $THIS_KEY "nobul-mac"
        Pj-OtherIntact
        Out-Has "[-] laptop (registered to another machine)"
        Out-Has "[1] nobul-mac"
        $menu = foreach ($l in (Lines $OUT)) {
            if ($l -cmatch '^Which profile|^  \[|^Choice') { (($l -creplace 'Choice: .*', 'Choice: ') -creplace '[ \t]+$', '') + "`n" }
        }
        Write-Lf (Join-Path $D "menu.txt") (@($menu) -join "")
        if (Test-GoldenMatch "userinit-pty-claim-menu.txt" (Join-Path $D "menu.txt")) { ok "pty-claim: menu matches golden" }
        else { bad "pty-claim: menu differs from golden userinit-pty-claim-menu.txt" }

        say "== interactive (pty): hostname suggestion on another machine's profile carries the label (Review3 #82 M2)"
        $script:CaseEnv = @{ AITOOLS_PROFILE_TEST_HOSTNAME = "laptop-host" }
        $script:PtyInput = 's\n'
        Case-Run "pty-hostname-other" 1 $fx_two
        Out-Has "[-] laptop (suggested, registered to another machine)"
        Out-Has "is registered to another machine"
        Has-Row "WARN|machine profile|skipped"
        Pj-Lacks "`"$THIS_KEY`""
        $script:CaseEnv = @{}

        say "== interactive (pty): alias of another machine's profile -> confirm -> shared alias, other profile untouched"
        $script:PtyInput = '\n\ny\n'
        Case-Run "pty-dup-confirm" 0 $fx_two @("--alias", "laptop")
        Pj-Alias $THIS_KEY "laptop"
        Pj-OtherIntact
        Out-Has "is used by another machine's profile ($OTHER_ID). Use it for this machine too? [y/n]"

        say "== interactive (pty): ... declined -> skipped (WARN row; not registered = exit 1)"
        $script:PtyInput = '\n\nn\n'
        Case-Run "pty-dup-decline" 1 $fx_two @("--alias", "laptop")
        Has-Row "WARN|machine profile|skipped"
        No-MachineFlag "yes"
        No-RowLike "no machine match"
        Pj-Lacks "`"$THIS_KEY`""

        # Re-ask (commander 2026-11-13: "no default or other characters should re-ask"):
        # an empty answer at a choice prompt asks again and applies nothing; the next
        # offered answer gives the same result as answering it at once (the golden of
        # that case). Every answer is logged at detail.
        say "== interactive (pty): empty answer at the which-profile menu -> asked again; then 1 claims"
        $script:CASE = "pty-claim-reask"; & $fx_two
        $script:PtyInput = '\n1\n'
        Run
        if ($script:RC -eq 0) { ok "$($script:CASE): $lang exit $($script:RC)" } else { bad "$($script:CASE): $lang exit $($script:RC), want 0"; Show $script:OUT }
        Result-Golden "pty-claim"
        Pj-Alias $THIS_KEY "nobul-mac"
        Pj-OtherIntact
        Out-Count "please type one of 1/n/s" 1
        Out-Count "Which profile is this machine?" 1
        Log-Has '[detail] menu answer (which profile): "" -> not one of 1/n/s, asked again'
        Log-Has '[detail] menu answer (which profile): "1" -> 1'

        say "== interactive (pty): empty answer at the duplicate-alias confirm -> asked again; then y shares the alias"
        $script:CASE = "pty-dup-reask"; & $fx_two
        $script:PtyInput = '\n\n\ny\n'
        Run @("--alias", "laptop")
        if ($script:RC -eq 0) { ok "$($script:CASE): $lang exit $($script:RC)" } else { bad "$($script:CASE): $lang exit $($script:RC), want 0"; Show $script:OUT }
        Result-Golden "pty-dup-confirm"
        Pj-Alias $THIS_KEY "laptop"
        Pj-OtherIntact
        Out-Count "please type one of y/yes/n/no" 1
        Log-Has '[detail] menu answer (alias laptop): "" -> not one of y/yes/n/no, asked again'
        Log-Has '[detail] menu answer (alias laptop): "y" -> y'

        say "== interactive (pty) with --force: no prompt; an unregistered machine is refused like no terminal"
        $script:PtyInput = '1\n'
        Case-Run "pty-force" 1 $fx_two @("--force")
        Has-Row "ERROR|machine profile|not registered (no terminal)"
        if ((ReadText $OUT).Contains("Which profile is this machine")) { bad "$($script:CASE): --force prompted" } else { ok "$($script:CASE): --force did not prompt" }
        $script:PtyInput = ""
    } else {
        Write-Host "  skip interactive cases (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)"; $script:skip++
    }
} finally {
    Remove-TestTempRoot $tmpRoot
}

say ""
say ("test-user-init: {0} passed, {1} failed, {2} skipped (windows: {3} entry point)" -f $script:pass, $script:fail, $script:skip, $lang)
if ($script:fail -ne 0) { exit 1 }
exit 0
