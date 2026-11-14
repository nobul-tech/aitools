# test-win-forwarder.ps1 -- the bash entry point scripts/aitools, run in Git Bash on
# Windows, hands its arguments to aitools.ps1 before aitools-lib.sh is sourced
# (commander, 2026-11-14, RFI 38dc-3: one runtime per platform).
#
# What it checks:
#   static   -- in scripts/aitools the forward runs inside main(), before the
#               argument parse loop and before `source "$aitools_lib"`; it checks
#               `command -v pwsh` and execs pwsh -NoProfile -ExecutionPolicy Bypass
#               -File "$(cygpath -w ...)"
#   args     -- scripts/aitools, run with Git Bash under an isolated HOME whose
#               config.json points at a fixture repo, runs a stub aitools.ps1 that
#               has the real aitools.ps1 param block: what binds there for each
#               documented command and flag (--skip-gh-auth, --repos-path,
#               --skip-drive-detection, --dry-run, --addmcp A B, --alias, dashboard
#               arguments, quotes, spaces, $); the stub's exit code (0, 1, 2, 7) is
#               the entry point's; stdin reaches aitools.ps1; USERPROFILE is this
#               HOME even when the caller's differs; the fixture aitools-lib.sh (it
#               writes a marker and exits 99) is never sourced
#   errors   -- no pwsh on PATH, or no aitools.ps1 anywhere: exit 1, a clear
#               message, nothing run; aitools.ps1 beside the entry point is used
#               when the repo copy is missing (~/.local/bin/aitools.ps1)
#   e2e      -- the real aitools.ps1 behind the forward: `dashboard --background
#               --project-root P` reaches aitools-dashboard.ps1 (a stub with its
#               real param block) as -Background, through pwsh -File, and its exit
#               code comes back (the dashboard-serve SessionStart hook's call);
#               later dashboard arguments (--dry-run) reach it unchanged;
#               `--addmcp vercel bogus` is split into two names; `--addmcp` alone
#               reports "requires at least one server name"; an unknown argument,
#               or an installer flag without install, is "unknown argument", exit 1
#   native   -- a pwsh user's call of aitools.ps1: a leading flag does not swallow
#               the command; `--addmcp` names are not unknown arguments
#
# The stubs and fixtures live in a temp dir (HOME, USERPROFILE and AITOOLS_LOG_DIR
# point into it), removed on exit; the real HOME and the real repos are never
# touched. Needs Git for Windows (bash.exe) and pwsh 7.
# Platform: Windows only (the forward runs only there; on macOS/Linux
# scripts/aitools is unchanged). Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/aitools-entry/test-win-forwarder.ps1 [-Help]

param([switch]$Help)

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. It tests the Windows forward of scripts/aitools, which macOS/Linux never run.")
    exit 1
}

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 39 | ForEach-Object { $_ -replace '^# ?', '' }
    exit 0
}

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
$entry = Join-Path $root "scripts" "aitools"
$entryPs1 = Join-Path $root "scripts" "aitools.ps1"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-winfwd-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

$script:pass = 0
$script:fail = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ }
    else { Write-Output "FAIL $Name$(if ($Detail) { " -- $Detail" })"; $script:fail++ }
}
function Fwd([string]$Path) { return $Path -replace '\\', '/' }

# Git for Windows bash.exe: beside git.exe's install, never the WSL launcher
function Find-GitBash {
    $cands = @()
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($git) { $cands += Join-Path (Split-Path -Parent (Split-Path -Parent $git.Source)) "bin\bash.exe" }
    $cands += Join-Path $env:ProgramFiles "Git\bin\bash.exe"
    foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { return $c } }
    return $null
}

# The dump every stub runs: bound parameters (sorted, switches as True, arrays as
# [a][b]), $args of a script that is not advanced, a stdin line on request; the
# lines go to $env:STUB_OUT and the stub exits with $env:STUB_EXIT.
$dumpBody = @'

$lines = @()
foreach ($k in @($PSBoundParameters.Keys | Sort-Object)) {
    $v = $PSBoundParameters[$k]
    if ($v -is [System.Management.Automation.SwitchParameter]) { $s = [string][bool]$v }
    elseif ($v -is [array]) { $s = (@($v) | ForEach-Object { "[$_]" }) -join '' }
    else { $s = [string]$v }
    $lines += "$k=$s"
}
if ($args.Count) { $lines += "ARGS=" + ((@($args) | ForEach-Object { "[$_]" }) -join '') }
if ($env:STUB_READ_STDIN) { $lines += "STDIN=[" + [Console]::In.ReadLine() + "]" }
if ($env:STUB_SHOW_PROFILE) { $lines += "PROFILE=" + $env:USERPROFILE }
[IO.File]::WriteAllLines($env:STUB_OUT, [string[]]$lines)
exit [int]$env:STUB_EXIT
'@

function New-Stub([string]$Source, [string]$Dest) {
    $e = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Source, [ref]$null, [ref]$e)
    if ($e.Count -gt 0 -or -not $ast.ParamBlock) { throw "cannot read the param block of $Source" }
    [IO.File]::WriteAllText($Dest, "# stub: the param block of $Source`r`n" + $ast.ParamBlock.Extent.Text + "`r`n" + $dumpBody)
}

# A fixture repo: scripts/aitools-lib.sh writes a marker and exits 99 if sourced
function New-FixtureRepo([string]$Dir) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Dir "scripts"), (Join-Path $Dir ".git") | Out-Null
    [IO.File]::WriteAllText((Join-Path $Dir "scripts\aitools-lib.sh"), "printf 'sourced\n' > `"`$HOME/lib-sourced`"`nexit 99`n")
}

# A case: its own HOME (config.json repoPath = $RepoPath), log dir, cwd, stub output
function New-Case([string]$Name, [string]$RepoPath) {
    $c = Join-Path $tmpRoot $Name
    $h = Join-Path $c "home"
    New-Item -ItemType Directory -Force -Path (Join-Path $h ".aitools"), (Join-Path $c "cwd") | Out-Null
    [IO.File]::WriteAllText((Join-Path $h ".aitools\config.json"), "{ `"repoPath`": `"$(Fwd $RepoPath)`" }`n")
    return [pscustomobject]@{ Dir = $c; Home = $h; Out = (Join-Path $c "stub-out.txt"); Cwd = (Join-Path $c "cwd") }
}

# Run FILE with ARGS (one per argv entry) in the case's HOME and USERPROFILE, extra
# environment, stdin text. Returns Rc, Out (stdout), Err (stderr).
function Invoke-Proc($Case, [string]$File, [string[]]$Arguments, [hashtable]$Env = @{}, [string]$Stdin = "") {
    $psi = [System.Diagnostics.ProcessStartInfo]::new($File)
    foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    $psi.WorkingDirectory = $Case.Cwd
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment["HOME"] = $Case.Home
    $psi.Environment["USERPROFILE"] = $Case.Home
    $psi.Environment["AITOOLS_LOG_DIR"] = Join-Path $Case.Dir "logs"
    $psi.Environment["STUB_OUT"] = $Case.Out
    $psi.Environment["STUB_EXIT"] = "0"
    $psi.Environment.Remove("STUB_READ_STDIN") | Out-Null
    foreach ($k in $Env.Keys) { $psi.Environment[$k] = [string]$Env[$k] }
    $p = [System.Diagnostics.Process]::Start($psi)
    $so = $p.StandardOutput.ReadToEndAsync()
    $se = $p.StandardError.ReadToEndAsync()
    if ($Stdin) { $p.StandardInput.Write($Stdin) }
    $p.StandardInput.Close()
    if (-not $p.WaitForExit(180000)) { $p.Kill($true); throw "timeout: $($Arguments -join ' ')" }
    $p.WaitForExit()
    return [pscustomobject]@{ Rc = $p.ExitCode; Out = $so.Result; Err = $se.Result }
}
# Run ENTRY (a bash script, default scripts/aitools) with Git Bash
function Invoke-Entry($Case, [string[]]$Arguments, [hashtable]$Env = @{}, [string]$Stdin = "", [string]$Entry = $entry) {
    return Invoke-Proc $Case $script:gitBash (@((Fwd $Entry)) + @($Arguments)) $Env $Stdin
}
# Call aitools.ps1 the way a pwsh user does: through the profile function that
# setup-user-shell.ps1 writes (function aitools { & "...\aitools.ps1" @args })
function Invoke-Native($Case, [string]$Ps1, [string]$ArgText) {
    $pwshExe = [Environment]::ProcessPath
    return Invoke-Proc $Case $pwshExe @("-NoProfile", "-Command", "function aitools { & '$Ps1' @args }; aitools $ArgText; exit `$LASTEXITCODE")
}

function Read-Stub($Case) {
    if (-not (Test-Path -LiteralPath $Case.Out)) { return $null }
    # The comma keeps an empty result an empty array (a bare @() return becomes $null)
    return , @([IO.File]::ReadAllLines($Case.Out) | Where-Object { $_ -ne "" } | Sort-Object)
}
function Same([string[]]$A, [string[]]$B) {
    return ((@($A) | Sort-Object) -join "`n") -ceq ((@($B) | Sort-Object) -join "`n")
}
function LibSourced($Case) { return Test-Path -LiteralPath (Join-Path $Case.Home "lib-sourced") }

try {
    $script:gitBash = Find-GitBash
    Check "setup: Git for Windows bash.exe found" ([bool]$script:gitBash) "searched beside git.exe and in Program Files"
    if (-not $script:gitBash) { throw "no Git Bash" }

    # -----------------------------------------------------------------------
    # static: where the forward sits in scripts/aitools
    # -----------------------------------------------------------------------
    $lines = [IO.File]::ReadAllLines($entry)
    function LineOf([string]$Pattern) { for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $Pattern) { return $i + 1 } }; return 0 }
    $mainAt = LineOf '^main\(\) \{$'
    $caseAt = LineOf '^case "\$\(uname -s\)" in$'
    $callAt = LineOf '^        aitools_win_forward "\$@"$'
    $parseAt = LineOf '^while \[\[ \$# -gt 0 \]\]; do$'
    $libAt = LineOf '^source "\$aitools_lib"$'
    Check "static: the forward runs inside main(), before the argument parse loop and before aitools-lib.sh is sourced" (
        $mainAt -gt 0 -and $caseAt -gt $mainAt -and $callAt -eq $caseAt + 2 -and $parseAt -gt $callAt -and $libAt -gt $parseAt) "main=$mainAt case=$caseAt call=$callAt parse=$parseAt lib=$libAt"
    Check "static: the forward is guarded by MINGW*|MSYS*|CYGWIN* and returns 1 when it comes back" (
        $lines[$caseAt] -match '^    MINGW\*\|MSYS\*\|CYGWIN\*\)$' -and $lines[$callAt] -match '^        return 1 ;;$')
    $fwdText = (($lines | Select-Object -Skip ((LineOf '^aitools_win_forward\(\) \{$') - 1)) -join "`n") -replace '(?s)\n\}\n.*', ''
    $pwshCheck = $fwdText.IndexOf('if ! command -v pwsh >/dev/null 2>&1; then')
    $execAt = $fwdText.IndexOf('exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ps1")"')
    Check "static: aitools_win_forward checks command -v pwsh, then execs pwsh -NoProfile -ExecutionPolicy Bypass -File with cygpath -w" (
        $pwshCheck -ge 0 -and $execAt -gt $pwshCheck) "check=$pwshCheck exec=$execAt"

    # -----------------------------------------------------------------------
    # args: a stub aitools.ps1 with the real param block
    # -----------------------------------------------------------------------
    $repoA = Join-Path $tmpRoot "repo-a"
    New-FixtureRepo $repoA
    New-Stub $entryPs1 (Join-Path $repoA "scripts\aitools.ps1")

    $argCases = @(
        @{ N = "no arguments (the sync)"; A = @(); W = @() },
        @{ N = "--version"; A = @("--version"); W = @("Version=True") },
        @{ N = "-v"; A = @("-v"); W = @("Version=True") },
        @{ N = "--help"; A = @("--help"); W = @("Help=True") },
        @{ N = "install with every installer flag"; A = @("install", "--skip-gh-auth", "--repos-path", "/c/Users/x y/repos", "--skip-drive-detection", "--force")
           W = @("Command=install", "SkipGhAuth=True", "ReposPath=C:\Users\x y\repos", "SkipDriveDetection=True", "Force=True") },
        @{ N = "gitpull --patch"; A = @("gitpull", "--patch"); W = @("Command=gitpull", "Patch=True") },
        @{ N = "--dry-run mcp"; A = @("--dry-run", "mcp"); W = @("DryRun=True", "Command=mcp") },
        @{ N = "--addmcp vercel webflow"; A = @("--addmcp", "vercel", "webflow"); W = @("AddMcp=[vercel,webflow]") },
        @{ N = "--addmcp twice, a flag between"; A = @("--addmcp", "vercel", "--dry-run", "--addmcp", "webflow"); W = @("AddMcp=[vercel,webflow]", "DryRun=True") },
        @{ N = "--addmcp with no name"; A = @("--addmcp"); W = @("AddMcp=[]") },
        @{ N = "user init --alias with a space"; A = @("user", "init", "--alias", "my box"); W = @("Command=user", "Alias=my box", "Remaining=[init]") },
        @{ N = "sessions list with a space"; A = @("sessions", "list", "proj name"); W = @("Command=sessions", "Remaining=[list][proj name]") },
        @{ N = "dashboard arguments unchanged (the dashboard-serve hook's call)"; A = @("dashboard", "--background", "--project-root", "C:/a b")
           W = @("Command=dashboard", "Remaining=[--background][--project-root][C:/a b]") },
        @{ N = "dashboard: the forward does not rewrite --dry-run after dashboard"; A = @("dashboard", "--stop", "--dry-run"); W = @("Command=dashboard", "Remaining=[--stop][--dry-run]") },
        @{ N = "quotes, `$ and backticks are kept"; A = @("sessions", "move", 'a"b', 'c$d ''q'' `e'); W = @("Command=sessions", "Remaining=[move][a`"b][c`$d 'q' ``e]") }
    )
    $i = 0
    foreach ($ac in $argCases) {
        $i++
        $c = New-Case "args-$i" $repoA
        $r = Invoke-Entry $c $ac.A
        $got = Read-Stub $c
        $ok = ($r.Rc -eq 0) -and ($null -ne $got) -and (Same $got $ac.W) -and -not (LibSourced $c)
        Check "args: $($ac.N) -> $(if ($ac.W.Count) { $ac.W -join ', ' } else { 'nothing bound' })" $ok "rc=$($r.Rc) got=[$(@($got) -join ', ')] lib-sourced=$(LibSourced $c) err=$($r.Err.Trim())"
    }

    foreach ($code in @(0, 1, 2, 7)) {
        $c = New-Case "exit-$code" $repoA
        $r = Invoke-Entry $c @("mcp") @{ STUB_EXIT = "$code" }
        Check "exit: aitools.ps1 exit $code is the entry point's exit code" (($r.Rc -eq $code) -and (Test-Path -LiteralPath $c.Out) -and -not (LibSourced $c)) "rc=$($r.Rc) err=$($r.Err.Trim())"
    }

    $c = New-Case "profile" $repoA
    $otherProfile = Join-Path $c.Dir "other-profile"
    New-Item -ItemType Directory -Path $otherProfile | Out-Null
    $r = Invoke-Entry $c @("mcp") @{ USERPROFILE = $otherProfile; STUB_SHOW_PROFILE = "1" }
    $stubLines = Read-Stub $c
    $prof = @(@($stubLines) | Where-Object { $_ -like "PROFILE=*" } | ForEach-Object { $_ -replace '^PROFILE=', '' })
    Check "profile: HOME and USERPROFILE differ -> aitools.ps1 gets USERPROFILE = this HOME (Windows form)" (
        ($r.Rc -eq 0) -and ($prof.Count -eq 1) -and ($prof[0].TrimEnd('\') -ieq $c.Home.TrimEnd('\'))) "rc=$($r.Rc) profile=[$($prof -join ',')] home=$($c.Home) err=$($r.Err.Trim())"

    $c = New-Case "stdin" $repoA
    $r = Invoke-Entry $c @("user", "init") @{ STUB_READ_STDIN = "1" } "o`n"
    $got = Read-Stub $c
    Check "stdin: a line on the entry point's stdin reaches aitools.ps1 (menus)" (($r.Rc -eq 0) -and ($got -contains "STDIN=[o]")) "got=[$(@($got) -join ', ')] err=$($r.Err.Trim())"

    # -----------------------------------------------------------------------
    # errors and the fallback
    # -----------------------------------------------------------------------
    $c = New-Case "no-pwsh" $repoA
    $r = Invoke-Entry $c @("mcp") @{ PATH = "$env:SystemRoot\System32;$env:SystemRoot" }
    Check "no pwsh: exit 1, a clear error, nothing run, lib not sourced" (
        ($r.Rc -eq 1) -and ($r.Err -match 'pwsh \(PowerShell 7\) not found') -and -not (Test-Path -LiteralPath $c.Out) -and -not (LibSourced $c)) "rc=$($r.Rc) err=$($r.Err.Trim())"

    $emptyRepo = Join-Path $tmpRoot "repo-empty"
    New-FixtureRepo $emptyRepo
    $c = New-Case "sibling" $emptyRepo
    $bin = Join-Path $c.Dir "bin"
    New-Item -ItemType Directory -Path $bin | Out-Null
    Copy-Item -LiteralPath $entry -Destination (Join-Path $bin "aitools")
    New-Stub $entryPs1 (Join-Path $bin "aitools.ps1")
    $r = Invoke-Entry $c @("mcp") -Entry (Join-Path $bin "aitools")
    Check "fallback: no repo copy -> the aitools.ps1 beside the entry point (~/.local/bin) runs" (
        ($r.Rc -eq 0) -and (Same (Read-Stub $c) @("Command=mcp")) -and -not (LibSourced $c)) "rc=$($r.Rc) err=$($r.Err.Trim())"

    $c = New-Case "none" $emptyRepo
    $bin = Join-Path $c.Dir "bin"
    New-Item -ItemType Directory -Path $bin | Out-Null
    Copy-Item -LiteralPath $entry -Destination (Join-Path $bin "aitools")
    $r = Invoke-Entry $c @("mcp") -Entry (Join-Path $bin "aitools")
    Check "no aitools.ps1: exit 1, a clear error, lib not sourced" (
        ($r.Rc -eq 1) -and ($r.Err -match 'aitools\.ps1 not found') -and -not (LibSourced $c)) "rc=$($r.Rc) err=$($r.Err.Trim())"

    # -----------------------------------------------------------------------
    # e2e: the real aitools.ps1 behind the forward
    # -----------------------------------------------------------------------
    $repoB = Join-Path $tmpRoot "repo-b"
    New-FixtureRepo $repoB
    foreach ($f in @("aitools.ps1", "aitools-lib.ps1", "aitools-json.ps1")) {
        Copy-Item -LiteralPath (Join-Path $root "scripts" $f) -Destination (Join-Path $repoB "scripts" $f)
    }
    New-Stub (Join-Path $root "scripts" "aitools-dashboard.ps1") (Join-Path $repoB "scripts\aitools-dashboard.ps1")

    $c = New-Case "e2e-dash-bg" $repoB
    $r = Invoke-Entry $c @("dashboard", "--background", "--project-root", "C:/a b") @{ STUB_EXIT = "5" }
    $got = Read-Stub $c
    Check "e2e: dashboard --background reaches aitools-dashboard.ps1 as -Background (pwsh -File binding)" (
        ($null -ne $got) -and (Same $got @("Background=True", "ARGS=[--project-root][C:/a b]")) -and -not (LibSourced $c)) "got=[$(@($got) -join ', ')] out=$($r.Out.Trim()) err=$($r.Err.Trim())"
    Check "e2e: the dashboard script's exit code (5) comes back through aitools.ps1 and the entry point" ($r.Rc -eq 5) "rc=$($r.Rc)"

    $c = New-Case "e2e-dash-status" $repoB
    $r = Invoke-Entry $c @("dashboard", "--status")
    Check "e2e: dashboard --status reaches aitools-dashboard.ps1 as -Status" (Same (Read-Stub $c) @("Status=True")) "rc=$($r.Rc) err=$($r.Err.Trim())"

    $c = New-Case "e2e-dash-dryrun" $repoB
    $r = Invoke-Entry $c @("dashboard", "--status", "--dry-run")
    Check "e2e: arguments after dashboard reach aitools-dashboard.ps1 unchanged (--dry-run not taken by aitools.ps1)" (
        Same (Read-Stub $c) @("Status=True", "ARGS=[--dry-run]")) "got=[$(@(Read-Stub $c) -join ', ')] rc=$($r.Rc) err=$($r.Err.Trim())"

    foreach ($u in @(
            @{ A = @("--bogus-flag"); W = "--bogus-flag" },
            @{ A = @("mcp", "extra"); W = "extra" },
            @{ A = @("--skip-gh-auth"); W = "--skip-gh-auth" },
            @{ A = @("--repos-path", "C:/x"); W = "--repos-path" })) {
        $c = New-Case ("e2e-unknown-" + ($u.W -replace '[^a-z]', '')) $repoB
        $r = Invoke-Entry $c $u.A
        $all = $r.Out + $r.Err
        Check "e2e: $($u.A -join ' ') -> unknown argument '$($u.W)', exit 1 (bash parity; no sync runs)" (
            ($r.Rc -eq 1) -and ($all -match [regex]::Escape("unknown argument '$($u.W)'"))) "rc=$($r.Rc) out=$($all.Trim())"
    }

    # A pwsh user's native call (aitools.ps1 from ~/.local/bin): GNU flags arrive as strings
    $realPs1 = Join-Path $repoB "scripts\aitools.ps1"
    $c = New-Case "native-flag-first" $repoB
    $r = Invoke-Native $c $realPs1 "--force dashboard --status"
    Check "native: aitools --force dashboard --status -> the command after a leading flag is still the command" (
        Same (Read-Stub $c) @("Status=True")) "got=[$(@(Read-Stub $c) -join ', ')] rc=$($r.Rc) out=$(($r.Out + $r.Err).Trim())"
    $c = New-Case "native-addmcp" $repoB
    $r = Invoke-Native $c $realPs1 "--addmcp vercel bogus"
    $all = $r.Out + $r.Err
    Check "native: aitools --addmcp vercel bogus -> unknown MCP server 'bogus' (the names are not unknown arguments)" (
        ($r.Rc -eq 1) -and ($all -match "unknown MCP server 'bogus'") -and -not ($all -match 'unknown argument')) "rc=$($r.Rc) out=$($all.Trim())"

    $c = New-Case "e2e-addmcp" $repoB
    $r = Invoke-Entry $c @("--addmcp", "vercel", "bogus")
    $all = $r.Out + $r.Err
    Check "e2e: --addmcp vercel bogus -> aitools.ps1 checks two names (unknown MCP server 'bogus', exit 1)" (
        ($r.Rc -eq 1) -and ($all -match "unknown MCP server 'bogus'") -and -not ($all -match "'vercel,bogus'")) "rc=$($r.Rc) out=$($all.Trim())"

    $c = New-Case "e2e-addmcp-empty" $repoB
    $r = Invoke-Entry $c @("--addmcp")
    $all = $r.Out + $r.Err
    Check "e2e: --addmcp with no name -> 'requires at least one server name', exit 1" (
        ($r.Rc -eq 1) -and ($all -match '--addmcp requires at least one server name')) "rc=$($r.Rc) out=$($all.Trim())"
} catch {
    Check "unexpected error" $false $_.Exception.Message
} finally {
    if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
}

Write-Output "---- $($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
