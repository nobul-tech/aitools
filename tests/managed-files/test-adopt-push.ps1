# test-adopt-push.ps1 -- tests for N-Q2 in scripts/aitools-lib.ps1: an adopt into
# the dotprofile through Deploy-ManagedFile (accept & adopt, merge & adopt,
# JSON field adopt) is committed (that file only) and pushed by
# Invoke-DotprofileCommitPush; an adopt target outside the dotprofile is not
# committed; commit and push failures are a warning + ACTION and leave the
# deploy outcome unchanged. Mirror of tests/managed-files/test-adopt-push.sh.
#
# Safe to re-run: every case runs in a child pwsh with its own temp HOME, a
# throwaway dotprofile git repo and a bare remote, removed on exit. The real
# dotprofile is never touched (AITOOLS_USER_REPO_PATH points into the temp dir;
# git's global and system config are ignored). Interactive cases run on a
# pseudo-terminal (tests/managed-files/pty-run.py, python3; skipped on Windows).
# Platform: macOS, Linux (pwsh 7); Windows runs the non-interactive cases.
# Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/managed-files/test-adopt-push.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 16 | Select-Object -Skip 1; exit 0 }

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$lib = Join-Path $root "scripts/aitools-lib.ps1"
$pty = Join-Path $root "tests/managed-files/pty-run.py"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("adopt-push-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
$pwshExe = (Get-Process -Id $PID).Path
# The user's git config (signing, hooks, templates) must not reach these repos.
$env:GIT_CONFIG_GLOBAL = Join-Path $tmpRoot "gitconfig"
[IO.File]::WriteAllText($env:GIT_CONFIG_GLOBAL, "")
$env:GIT_CONFIG_NOSYSTEM = "1"

$script:pass = 0; $script:fail = 0; $script:skip = 0
$havePty = (-not $IsWindows) -and [bool](Get-Command python3 -ErrorAction SilentlyContinue)
# Get-Command exempt: command-existence check; $havePty is the fallback branch

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++ }
    else {
        Write-Output "FAIL $Name"; $script:fail++
        $outFile = Join-Path $script:C "out"
        if (Test-Path $outFile) {
            (Get-Content $outFile -Tail 25) | ForEach-Object { Write-Output ("      | " + ($_ -replace "`e\[[0-9;]*m", "")) }
        }
    }
}

# G DIR ARGS: quiet git for fixture setup; throws on failure
function G {
    $out = & git -C @args 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "git -C $($args -join ' ') failed: $out" }
}

function Setup-Case([string]$Name) {
    $script:C = Join-Path $tmpRoot $Name
    $script:DP = Join-Path $script:C "dotprofile"; $script:REMOTE = Join-Path $script:C "remote.git"; $script:OTHER = Join-Path $script:C "other"
    foreach ($d in @("home", "dest", "bin", "logs", "dotprofile/claude/rules", "other")) { New-Item -ItemType Directory -Path (Join-Path $script:C $d) -Force | Out-Null }
    G $script:C init -q --bare -b main $script:REMOTE
    G $script:C init -q -b main $script:DP
    G $script:C init -q -b main $script:OTHER
    foreach ($r in @($script:DP, $script:OTHER)) { G $r config user.name "Test User"; G $r config user.email "test@example.com" }
    W "dotprofile/claude/rules/r.md" "source rule"; W "dotprofile/profile.json" '{"a":1,"b":2}'; W "dotprofile/notes.md" "notes"
    G $script:DP add -A; G $script:DP commit -q -m init; G $script:DP remote add origin $script:REMOTE; G $script:DP push -q -u origin main
    W "other/o.md" "other source"
    G $script:OTHER add -A; G $script:OTHER commit -q -m init
    Set-Content -Path (Join-Path $script:C "summary") -Value "" -NoNewline
}

function Run-Lib([string]$Snippet, [string]$InputKeys = "") {
    $C = $script:C
    # aitools-profile.ps1 refuses to run off Windows (OS guard), so the snippet
    # starts as a caller that already ran Resolve-UserRepoPath; the resolver
    # fallback inside Invoke-DotprofileCommitPush is exercised on Windows only.
    $resolved = if ($IsWindows) { "" } else { "`$script:AitLibUserRepoPath = '$($script:DP)'" }
    $body = @"
. '$lib'
Initialize-Logging "t"
`$C = '$C'
$resolved
$Snippet
"@
    $snip = Join-Path $C "snippet.ps1"
    [IO.File]::WriteAllText($snip, $body)
    $saved = @{}
    foreach ($k in @("HOME", "USERPROFILE", "AITOOLS_LOG_DIR", "AITOOLS_SUMMARY_FILE", "AITOOLS_USER_REPO_PATH", "PATH", "TERM")) { $saved[$k] = [Environment]::GetEnvironmentVariable($k) }
    $env:HOME = Join-Path $C "home"; $env:USERPROFILE = $env:HOME
    $env:AITOOLS_LOG_DIR = Join-Path $C "logs"; $env:AITOOLS_SUMMARY_FILE = Join-Path $C "summary"
    $env:AITOOLS_USER_REPO_PATH = $script:DP
    $env:PATH = (Join-Path $C "bin") + [IO.Path]::PathSeparator + $saved["PATH"]
    $env:TERM = "dumb"
    try {
        if ($InputKeys) {
            & python3 $pty --input $InputKeys --log (Join-Path $C "out") -- $pwshExe -NoProfile -File $snip
        } else {
            $null | & $pwshExe -NoProfile -NonInteractive -File $snip *> (Join-Path $C "out")
        }
        Set-Content -Path (Join-Path $C "rc") -Value $LASTEXITCODE
    } finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

function W([string]$Rel, [string]$Text) { [IO.File]::WriteAllText((Join-Path $script:C $Rel), "$Text`n") }
function Txt([string]$Rel) { $f = Join-Path $script:C $Rel; if (Test-Path $f) { (Get-Content $f -Raw) -replace '[\r\n]+$', '' } else { $null } }
function Result { Txt "result" }
function PushState { Txt "push" }
function Rc { Txt "rc" }
function Log { $f = Join-Path $script:C "logs/deploy.log"; if (Test-Path $f) { Get-Content $f -Raw } else { "" } }
function Summary { @(Get-Content (Join-Path $script:C "summary")) }
function RemoteHas([string]$Path, [string]$Text) { $o = (& git -C $script:REMOTE show "main:$Path" 2>$null | Out-String) -replace '[\r\n]+$', ''; ($LASTEXITCODE -eq 0) -and ($o -eq $Text) }
function Commits { (& git -C $script:DP rev-list --count HEAD | Out-String).Trim() }
function CommittedFiles { ((& git -C $script:DP show --name-only --format= HEAD | Out-String).Trim() -split "`n" | Where-Object { $_ }) -join " " }
function HeadMsg { (& git -C $script:DP log -1 --format=%s | Out-String).Trim() }
function Dcp([string]$File, [string]$Msg) { "Invoke-DotprofileCommitPush -File '$File' -Message '$Msg'; Set-Content -Path `"`$C/push`" -Value `$script:AitLibDotprofilePush -NoNewline" }
$dmf = '$r = Deploy-ManagedFile -Content ([IO.File]::ReadAllText($src)) -DestPath $dest -ToolName "tool" -ItemName "item" -AdoptPath $adopt; Set-Content -Path "$C/result" -Value $r -NoNewline; $ps = Get-Variable -Name AitLibDotprofilePush -Scope Script -ValueOnly -ErrorAction SilentlyContinue; if (-not $ps) { $ps = "unset" }; Set-Content -Path "$C/push" -Value $ps -NoNewline'

try {
    # --- Helper, called directly ---
    Setup-Case "direct-pushed"
    W "dotprofile/claude/rules/r.md" "edited rule"; W "dotprofile/notes.md" "unrelated hand edit"; W "dotprofile/staged.md" "staged"; G $DP add staged.md
    Run-Lib (Dcp "$DP/claude/rules/r.md" "Adopt r.md from the deployed copy")
    Check "direct: committed-pushed" ((PushState) -eq "committed-pushed")
    Check "direct: commit holds that file only" ((CommittedFiles) -eq "claude/rules/r.md" -and (HeadMsg) -eq "Adopt r.md from the deployed copy")
    Check "direct: remote has the adopted file" (RemoteHas "claude/rules/r.md" "edited rule")
    Check "direct: unrelated unstaged change not committed" ((Txt "dotprofile/notes.md") -eq "unrelated hand edit" -and (RemoteHas "notes.md" "notes"))
    Check "direct: unrelated staged file still staged" ((& git -C $DP diff --cached --name-only | Out-String).Trim() -eq "staged.md")
    Check "direct: ok line logged, no warning" ((Log) -match "\[ok\] dotprofile: claude/rules/r.md committed and pushed" -and (Log) -notmatch "\[warn\]" -and -not ((Summary) -match "^ACTION"))

    Setup-Case "direct-unchanged"
    Run-Lib (Dcp "$DP/claude/rules/r.md" "Adopt r.md")
    Check "unchanged: no commit, no push, no warning" ((PushState) -eq "unchanged" -and (Commits) -eq "1" -and (Log) -notmatch "\[warn\]")

    Setup-Case "direct-other-repo"; W "other/o.md" "other edit"
    Run-Lib (Dcp "$OTHER/o.md" "Adopt o.md")
    Check "not in the dotprofile: nothing committed" ((PushState) -eq "not-dotprofile" -and (& git -C $OTHER rev-list --count HEAD | Out-String).Trim() -eq "1")

    Setup-Case "direct-preresolved"; W "dotprofile/claude/rules/r.md" "edited"
    Run-Lib ("`$script:AitLibUserRepoPath = ''; " + (Dcp "$DP/claude/rules/r.md" "Adopt r.md"))
    Check "caller resolved shared-only (empty): not-dotprofile" ((PushState) -eq "not-dotprofile" -and (Commits) -eq "1")

    Setup-Case "direct-push-fail"; G $DP remote remove origin; W "dotprofile/claude/rules/r.md" "edited rule"
    Run-Lib (Dcp "$DP/claude/rules/r.md" "Adopt r.md")
    Check "push failure: push-failed, committed locally" ((PushState) -eq "push-failed" -and (Commits) -eq "2")
    Check "push failure: WARN logged, ACTION 'run git push in <dotprofile>'" ((Log) -match "\[warn\] dotprofile push failed" -and ((Summary) -ccontains "ACTION||run git push in $DP"))
    Check "push failure: exit 0" ((Rc) -eq "0")

    Setup-Case "direct-push-rejected"
    G $C clone -q -b main $REMOTE (Join-Path $C "elsewhere")
    $elsewhere = Join-Path $C "elsewhere"; G $elsewhere config user.name x; G $elsewhere config user.email x@example.com
    W "elsewhere/notes.md" "from elsewhere"; G $elsewhere commit -q -am other; G $elsewhere push -q
    W "dotprofile/claude/rules/r.md" "edited rule"
    Run-Lib (Dcp "$DP/claude/rules/r.md" "Adopt r.md")
    Check "push rejected: push-failed, ACTION pull --rebase" ((PushState) -eq "push-failed" -and (Log) -match "\[warn\] dotprofile push rejected" -and ((Summary) -ccontains "ACTION||git pull --rebase, then git push in $DP"))

    if (-not $IsWindows) {
        Setup-Case "direct-commit-fail"
        [IO.File]::WriteAllText((Join-Path $DP ".git/hooks/pre-commit"), "#!/bin/sh`nexit 1`n"); & chmod +x (Join-Path $DP ".git/hooks/pre-commit")
        W "dotprofile/claude/rules/r.md" "edited rule"
        Run-Lib (Dcp "$DP/claude/rules/r.md" "Adopt r.md")
        Check "commit failure: commit-failed, WARN + ACTION, nothing pushed" ((PushState) -eq "commit-failed" -and (Log) -match "\[warn\] dotprofile commit failed" -and ((Summary) -ccontains "ACTION||commit and push claude/rules/r.md in $DP") -and (RemoteHas "claude/rules/r.md" "source rule"))
    }

    # --- Through Deploy-ManagedFile (interactive adopt) ---
    if ($havePty) {
        Setup-Case "adopt-dotprofile"; W "dest/r.md" "local edit"; W "dotprofile/notes.md" "unrelated hand edit"
        Run-Lib "`$src='$DP/claude/rules/r.md'; `$dest='$C/dest/r.md'; `$adopt='$DP/claude/rules/r.md'; $dmf" "a\n"
        Check "accept & adopt into the dotprofile: result unchanged, committed-pushed" ((Result) -eq "accept & adopt" -and (PushState) -eq "committed-pushed")
        Check "accept & adopt: remote has LOCAL, commit is that file only" ((RemoteHas "claude/rules/r.md" "local edit") -and (CommittedFiles) -eq "claude/rules/r.md")
        Check "accept & adopt: unrelated change not committed, no 'Uncommitted change' line" ((RemoteHas "notes.md" "notes") -and (Log) -notmatch "Uncommitted change in")

        Setup-Case "json-dotprofile"; W "dest/profile.json" '{"a":9,"b":2}'
        Run-Lib "`$src='$DP/profile.json'; `$dest='$C/dest/profile.json'; `$adopt='$DP/profile.json'; $dmf" "a\n"
        $remoteJson = ((& git -C $REMOTE show main:profile.json | Out-String) -replace '\s', '')
        Check "JSON field adopt into the dotprofile: committed and pushed" ((Result) -eq "accept & adopt" -and (PushState) -eq "committed-pushed" -and $remoteJson -eq '{"a":9,"b":2}')

        Setup-Case "adopt-push-fail"; G $DP remote remove origin; W "dest/r.md" "local edit"
        Run-Lib "`$src='$DP/claude/rules/r.md'; `$dest='$C/dest/r.md'; `$adopt='$DP/claude/rules/r.md'; $dmf" "a\n"
        Check "adopt, push fails: outcome still accept & adopt, files written" ((Result) -eq "accept & adopt" -and (Txt "dotprofile/claude/rules/r.md") -eq "local edit" -and (Rc) -eq "0")
        Check "adopt, push fails: push-failed, WARN + ACTION" ((PushState) -eq "push-failed" -and (Log) -match "\[warn\] dotprofile push failed" -and ((Summary) -ccontains "ACTION||run git push in $DP"))

        Setup-Case "adopt-other-repo"; W "dest/o.md" "local edit"
        Run-Lib "`$src='$OTHER/o.md'; `$dest='$C/dest/o.md'; `$adopt='$OTHER/o.md'; $dmf" "a\n"
        Check "adopt outside the dotprofile: working tree only, not committed" ((Result) -eq "accept & adopt" -and (PushState) -eq "not-dotprofile" -and (Txt "other/o.md") -eq "local edit" -and (& git -C $OTHER rev-list --count HEAD | Out-String).Trim() -eq "1")
        Check "adopt outside the dotprofile: 'Uncommitted change' logged" ((Log) -match "Uncommitted change in")
    } else {
        Write-Output "SKIP interactive cases (no python3 pty on this platform)"; $script:skip++
    }

    # --- No adopt: overwrite never commits ---
    Setup-Case "overwrite-no-commit"; W "dest/r.md" "local edit"
    Run-Lib "`$src='$DP/claude/rules/r.md'; `$dest='$C/dest/r.md'; `$adopt='$DP/claude/rules/r.md'; $dmf"
    Check "non-interactive overwrite: dotprofile untouched, helper not called" ((Result) -eq "updated" -and (PushState) -eq "unset" -and (Commits) -eq "1")
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}

Write-Output ""
Write-Output "$($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
