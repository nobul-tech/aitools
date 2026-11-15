# test-check-no-git-bash.ps1 -- the Windows check scripts run no Git Bash, except
# check-pre-push step 7, which runs build-deploy.sh (bash-only, the approved
# cross-language exception in .claude/rules/cross-platform.md).
#
# Commander, 2026-11-14: "for the check-*.ps1 can youj explain this further? id
# like to avoid calling git bash on thowse ps1 scripts."
#
# What it checks:
#   Static (PowerShell AST of every scripts/check-*.ps1):
#   - only check-pre-push.ps1 calls ResolveGitBash, once, into $d7Bash, and its
#     one `& $d7Bash` call runs scripts/build-deploy.sh;
#   - no check-*.ps1 runs bash or sh (by name, by a literal path, or with
#     Start-Process), and none but check-lib.ps1 holds a Git for Windows bash path.
#   Behaviour (each step's section, cut out of the script by its header comments
#   and run in a child pwsh with stub Step*/Log* functions):
#   - check-pre-commit step 2: a staged .sh with a syntax error gives SKIP for
#     "Script syntax (.sh)", naming CI and check-pre-commit.sh (no bash -n);
#   - check-post-push step 4: runs scripts/aitools.ps1 --version with pwsh: PASS
#     with the "aitools ..." line and the tag; FAIL on a nonzero exit, on output
#     without an "aitools ..." line, and when pwsh is not on PATH; the real
#     aitools.ps1 passes under an empty profile;
#   - check-post-push step 6: a .sh with a syntax error gives SKIP for "Full
#     syntax (.sh)", naming CI and check-post-push.sh; the .ps1 half still
#     passes a good file and fails a bad one.
#
# Usage: pwsh -NoProfile -File tests/check-no-git-bash/test-check-no-git-bash.ps1 [-Help]
# Safe to re-run: everything is written under a temp dir, removed on exit.
# Platform: Windows only (pwsh 7; OS guard below): the check-*.ps1 scripts are
# Windows-only. Exit 1 if any case fails.

param([switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 30
    exit 0
}

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. The check-*.ps1 scripts it tests are Windows-only; on macOS/Linux the .sh twins run.")
    exit 1
}

$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
$scripts = Join-Path $root "scripts"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-nogitbash-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$pwshExe = [Environment]::ProcessPath

$script:pass = 0
$script:fail = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ }
    else { Write-Output "FAIL $Name$(if ($Detail) { " -- $Detail" })"; $script:fail++ }
}

# Run-Native FILE ARGS [ENV]: each argument passed as is, stdin closed at once,
# stdout and stderr read as UTF-8; ENV entries are set for the child only.
function Run-Native([string]$File, [string[]]$Arguments, [hashtable]$Env = @{}) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    foreach ($k in $Env.Keys) { $psi.Environment[$k] = $Env[$k] }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(180000)) {
        $p.Kill($true)
        return [pscustomobject]@{ rc = -1; out = $outTask.Result; err = "timeout after 180 s`n" + $errTask.Result }
    }
    $p.WaitForExit()
    return [pscustomobject]@{ rc = $p.ExitCode; out = $outTask.Result; err = $errTask.Result }
}

# Get-Section FILE FROM TO: the lines of FILE from the line matching FROM up to,
# not including, the line matching TO (both regexes on whole lines); $null if
# either is missing
function Get-Section([string]$File, [string]$From, [string]$To) {
    $lines = [IO.File]::ReadAllLines($File)
    $a = -1; $b = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($a -lt 0 -and $lines[$i] -match $From) { $a = $i; continue }
        if ($a -ge 0 -and $lines[$i] -match $To) { $b = $i; break }
    }
    if ($a -lt 0 -or $b -lt 0) { return $null }
    return ($lines[$a..($b - 1)] -join "`n")
}

# The stubs every section runs with: Step* print "<STATUS> <n> <name>|<detail>"
$stubs = @'
$ErrorActionPreference = "Stop"
function StepPass([string]$n, [string]$name, [string]$detail = "") { [Console]::WriteLine("PASS $n $name|$detail") }
function StepFail([string]$n, [string]$name, [string]$detail = "") { [Console]::WriteLine("FAIL $n $name|$detail") }
function StepWarn([string]$n, [string]$name, [string]$detail = "") { [Console]::WriteLine("WARN $n $name|$detail") }
function StepSkip([string]$n, [string]$name, [string]$detail = "") { [Console]::WriteLine("SKIP $n $name|$detail") }
function LogDetail([string]$m) { [Console]::WriteLine("DETAIL $m") }
function InvokeGit { if ($args[0] -eq "describe") { return "v0.0.0-test" } return "" }
function ResolveGitBash { [Console]::WriteLine("CALLED ResolveGitBash"); return "C:\no\such\bash.exe" }
'@

# Run-Section NAME SECTION SETUP [ENV]: write stubs + SETUP + SECTION to a file
# and run it in a child pwsh; returns the Run-Native result
function Run-Section([string]$Name, [string]$Section, [string]$Setup, [hashtable]$Env = @{}) {
    $f = Join-Path $tmpRoot "$Name.ps1"
    [IO.File]::WriteAllText($f, ($stubs + "`n" + $Setup + "`n" + $Section + "`n"), $utf8)
    return Run-Native $pwshExe @("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $f) $Env
}

function Lines([string]$Text) { @(($Text -split "`r?`n") | Where-Object { $_ }) }
function Q([string]$s) { "'" + ($s -replace "'", "''") + "'" }

try {
    # -----------------------------------------------------------------------
    # Static: who calls Git Bash
    # -----------------------------------------------------------------------
    $checkFiles = @(Get-ChildItem -Path $scripts -Filter "check-*.ps1" -File)
    Check "static: check-*.ps1 scripts found" ($checkFiles.Count -ge 3) "found $($checkFiles.Count)"
    $resolveCalls = @{}
    $bashNamed = @()
    $d7Calls = @()
    foreach ($f in $checkFiles) {
        $errs = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
        if ($errs.Count -gt 0) { Check "static: $($f.Name) parses" $false ($errs[0].Message); continue }
        $cmds = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
        foreach ($c in $cmds) {
            $name = $c.GetCommandName()
            if ($name -eq "ResolveGitBash") {
                $parent = $c.Parent
                while ($parent -and -not ($parent -is [System.Management.Automation.Language.AssignmentStatementAst])) { $parent = $parent.Parent }
                $target = if ($parent) { $parent.Left.Extent.Text } else { "(not assigned)" }
                if (-not $resolveCalls.ContainsKey($f.Name)) { $resolveCalls[$f.Name] = @() }
                $resolveCalls[$f.Name] += $target
            }
            if ($name -in @("bash", "bash.exe", "sh", "sh.exe")) { $bashNamed += "$($f.Name):$($c.Extent.StartLineNumber)" }
            # A bash by literal path (& "C:\...\Git\bin\bash.exe") or started with Start-Process
            if ($name -match '(?i)(^|[\\/])(ba)?sh(\.exe)?$' -and $name -notin @("bash", "bash.exe", "sh", "sh.exe")) { $bashNamed += "$($f.Name):$($c.Extent.StartLineNumber): $name" }
            if ($name -eq "Start-Process" -and $c.Extent.Text -match '(?i)\b(ba)?sh(\.exe)?\b') { $bashNamed += "$($f.Name):$($c.Extent.StartLineNumber): Start-Process" }
            if ($c.InvocationOperator -eq "Ampersand" -and $c.CommandElements[0].Extent.Text -eq '$d7Bash') {
                $d7Calls += [pscustomobject]@{ file = $f.Name; text = $c.Extent.Text }
            }
        }
        # Any string in the code (not comments) naming a Git for Windows bash, outside
        # check-lib.ps1, whose ResolveGitBash holds the one probe list
        if ($f.Name -ne "check-lib.ps1") {
            $strs = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst] }, $true)
            foreach ($s in $strs) {
                if ($s.Value -match '(?i)\\Git\\(usr\\)?bin\\|(^|[\\/])bash\.exe\b') { $bashNamed += "$($f.Name):$($s.Extent.StartLineNumber): string '$($s.Value)'" }
            }
        }
    }
    $callers = @($resolveCalls.Keys | Sort-Object)
    Check "static: only check-pre-push.ps1 calls ResolveGitBash" (($callers -join ",") -eq "check-pre-push.ps1") ("callers: " + ($callers -join ", "))
    Check "static: check-pre-push.ps1 calls it once, into `$d7Bash" ((@($resolveCalls["check-pre-push.ps1"]) -join ",") -eq '$d7Bash') ("assigned to: " + (@($resolveCalls["check-pre-push.ps1"]) -join ", "))
    Check "static: one `& `$d7Bash` call, in check-pre-push.ps1, running build-deploy.sh" `
        ($d7Calls.Count -eq 1 -and $d7Calls[0].file -eq "check-pre-push.ps1" -and $d7Calls[0].text -match 'scripts/build-deploy\.sh') `
        (($d7Calls | ForEach-Object { "$($_.file): $($_.text)" }) -join "; ")
    Check "static: no check-*.ps1 runs a command named bash or sh" ($bashNamed.Count -eq 0) ($bashNamed -join ", ")

    # -----------------------------------------------------------------------
    # check-pre-commit step 2
    # -----------------------------------------------------------------------
    $preCommit = Join-Path $scripts "check-pre-commit.ps1"
    $sec2 = Get-Section $preCommit '^# 2\. Script syntax validation' '^# 3\. Build freshness'
    Check "pre-commit: step 2 section found (# 2. ... # 3. headers)" ($null -ne $sec2)
    if ($sec2) {
        $repo = Join-Path $tmpRoot "pc-repo"
        New-Item -ItemType Directory -Path $repo | Out-Null
        [IO.File]::WriteAllText((Join-Path $repo "bad.sh"), "#!/usr/bin/env bash`nif then fi (`n", $utf8)
        $setup = "`$script:RepoRoot = $(Q $repo)`n`$stagedSh = @('bad.sh')`n`$stagedPs1 = @()`n`$stagedFiles = @('bad.sh')"
        $r = Run-Section "pc-step2" $sec2 $setup
        $out = Lines $r.out
        Check "pre-commit 2: section runs (exit 0)" ($r.rc -eq 0) "rc=$($r.rc) err=$($r.err.Trim())"
        $shLine = $out | Where-Object { $_ -match '^\w+ 2 Script syntax \(\.sh\)\|' }
        Check "pre-commit 2: a staged .sh with a syntax error is SKIP, not checked here" `
            (@($shLine).Count -eq 1 -and $shLine -match '^SKIP 2 Script syntax \(\.sh\)\|1 \.sh staged') ($out -join " / ")
        Check "pre-commit 2: the SKIP names CI and check-pre-commit.sh" ($shLine -match 'CI' -and $shLine -match 'check-pre-commit\.sh') "$shLine"
        Check "pre-commit 2: ResolveGitBash not called" (-not ($out -match '^CALLED')) ($out -join " / ")
        $setup = "`$script:RepoRoot = $(Q $repo)`n`$stagedSh = @()`n`$stagedPs1 = @()`n`$stagedFiles = @()"
        $r = Run-Section "pc-step2-none" $sec2 $setup
        Check "pre-commit 2: nothing staged gives the two no-scripts SKIPs" `
            (((Lines $r.out) -join " / ") -eq "SKIP 2 Script syntax (.sh)|no scripts staged / SKIP 2 Script syntax (.ps1)|no scripts staged") ((Lines $r.out) -join " / ")
    }

    # -----------------------------------------------------------------------
    # check-post-push step 4
    # -----------------------------------------------------------------------
    $postPush = Join-Path $scripts "check-post-push.ps1"
    $sec4 = Get-Section $postPush '^# 4\. CLI entry point \+ version' '^# 5\. Session archive readiness'
    Check "post-push: step 4 section found (# 4. ... # 5. headers)" ($null -ne $sec4)
    if ($sec4) {
        $emptyHome = Join-Path $tmpRoot "home-empty"
        New-Item -ItemType Directory -Path $emptyHome | Out-Null
        $isoEnv = @{ HOME = $emptyHome; USERPROFILE = $emptyHome; AITOOLS_LOG_DIR = (Join-Path $tmpRoot "logs") }

        # The real aitools.ps1, empty profile: "aitools <version>" and the repo not found
        $r = Run-Section "pp4-real" $sec4 "`$scriptDir = $(Q $scripts)" $isoEnv
        $l4 = (Lines $r.out) | Where-Object { $_ -match '^\w+ 4 ' }
        Check "post-push 4: the real scripts/aitools.ps1 --version passes" (@($l4).Count -eq 1 -and $l4 -match '^PASS 4 CLI entry point \+ version\|aitools \S+ \(tag: v0\.0\.0-test\)$') ((Lines $r.out) -join " / ")
        Check "post-push 4: ResolveGitBash not called" (-not ((Lines $r.out) -match '^CALLED')) ((Lines $r.out) -join " / ")
        # pwsh writes its own startup cache under the profile (AppData\Local\Microsoft\PowerShell)
        $stray = @(Get-ChildItem -LiteralPath $emptyHome -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($emptyHome.Length + 1) } |
            Where-Object { $_ -notmatch '^AppData\\Local\\Microsoft\\PowerShell\\' })
        Check "post-push 4: the real aitools.ps1 writes nothing under an empty profile (pwsh's own cache aside)" ($stray.Count -eq 0) ($stray -join ", ")

        $stubCases = @(
            @{ name = "exit 3"; body = "Write-Host 'aitools 1.2.3'`nexit 3"; want = '^FAIL 4 CLI entry point \+ version\|aitools\.ps1 --version failed \(exit 3\)$' },
            @{ name = "no aitools line"; body = "Write-Host 'something else'`nexit 0"; want = '^FAIL 4 CLI entry point \+ version\|aitools\.ps1 --version failed \(exit 0\)$' },
            @{ name = "version line"; body = "if (`$args -contains '--version') { Write-Host 'aitools 9.9.9'; Write-Host '  repo: x' } else { exit 5 }`nexit 0"; want = '^PASS 4 CLI entry point \+ version\|aitools 9\.9\.9 \(tag: v0\.0\.0-test\)$' }
        )
        $i = 0
        foreach ($c in $stubCases) {
            $i++
            $dir = Join-Path $tmpRoot "pp4-stub$i"
            New-Item -ItemType Directory -Path $dir | Out-Null
            [IO.File]::WriteAllText((Join-Path $dir "aitools.ps1"), $c.body, $utf8)
            $r = Run-Section "pp4-stub$i" $sec4 "`$scriptDir = $(Q $dir)" $isoEnv
            $l4 = (Lines $r.out) | Where-Object { $_ -match '^\w+ 4 ' }
            Check "post-push 4: stub aitools.ps1 ($($c.name))" (@($l4).Count -eq 1 -and $l4 -match $c.want) ((Lines $r.out) -join " / ")
        }
        $noPath = Join-Path $tmpRoot "empty-path"
        New-Item -ItemType Directory -Path $noPath | Out-Null
        # PATH is set inside the child: pwsh puts its own directory first on PATH at startup
        $r = Run-Section "pp4-nopwsh" $sec4 "`$scriptDir = $(Q $scripts)`n`$env:PATH = $(Q $noPath)" $isoEnv
        $l4 = (Lines $r.out) | Where-Object { $_ -match '^\w+ 4 ' }
        Check "post-push 4: pwsh not on PATH fails the step" (@($l4).Count -eq 1 -and $l4 -match '^FAIL 4 CLI entry point \+ version\|pwsh \(PowerShell 7\) not found') ((Lines $r.out) -join " / ")
    }

    # -----------------------------------------------------------------------
    # check-post-push step 6
    # -----------------------------------------------------------------------
    $sec6 = Get-Section $postPush '^# 6\. Full script syntax validation' '^# 7\. deploy/ drift audit'
    Check "post-push: step 6 section found (# 6. ... # 7. headers)" ($null -ne $sec6)
    if ($sec6) {
        foreach ($case in @(@{ n = "good"; ps1 = "Write-Output 'ok'`n"; want = '^PASS 6 Full syntax \(\.ps1\)\|' }, @{ n = "bad"; ps1 = "function x {`n"; want = '^FAIL 6 Full syntax \(\.ps1\)\|1 file\(s\) failed$' })) {
            $repo = Join-Path $tmpRoot "pp6-$($case.n)"
            New-Item -ItemType Directory -Path (Join-Path $repo "scripts"), (Join-Path $repo "shared\hooks") -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $repo "scripts\bad.sh"), "#!/usr/bin/env bash`nif then fi (`n", $utf8)
            [IO.File]::WriteAllText((Join-Path $repo "shared\hooks\bad-hook.sh"), "#!/usr/bin/env bash`ncase in`n", $utf8)
            [IO.File]::WriteAllText((Join-Path $repo "scripts\x.ps1"), $case.ps1, $utf8)
            $r = Run-Section "pp6-$($case.n)" $sec6 "`$script:RepoRoot = $(Q $repo)"
            $out = Lines $r.out
            $shLine = $out | Where-Object { $_ -match '^\w+ 6 Full syntax \(\.sh\)\|' }
            Check "post-push 6 ($($case.n) .ps1): .sh with syntax errors is SKIP, not checked here" (@($shLine).Count -eq 1 -and $shLine -match '^SKIP 6 Full syntax \(\.sh\)\|') ($out -join " / ")
            Check "post-push 6 ($($case.n) .ps1): the SKIP names CI and check-post-push.sh" ($shLine -match 'CI' -and $shLine -match 'check-post-push\.sh') "$shLine"
            $psLine = $out | Where-Object { $_ -match '^\w+ 6 Full syntax \(\.ps1\)\|' }
            Check "post-push 6 ($($case.n) .ps1): the .ps1 half still runs" (@($psLine).Count -eq 1 -and $psLine -match $case.want) ($out -join " / ")
            Check "post-push 6 ($($case.n) .ps1): ResolveGitBash not called" (-not ($out -match '^CALLED')) ($out -join " / ")
        }
    }
} finally {
    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot }
}

Write-Output "---- $($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
