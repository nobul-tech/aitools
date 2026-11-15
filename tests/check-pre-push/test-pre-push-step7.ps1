# test-pre-push-step7.ps1 -- tests for check-pre-push step 7 ("deploy/ matches
# source") against a dotprofile that tracks deploy/ and one that gitignores it.
# The Windows harness of this suite; tests/check-pre-push/test-pre-push-step7.sh
# is the macOS/Linux harness.
#
# Each case runs scripts/check-pre-push.ps1 (the .ps1 twin) with native pwsh
# from a local clone of this repo with one commit ahead of a fake origin/main,
# under a temporary HOME/USERPROFILE whose config.json points at a fixture
# dotprofile. Nothing outside the temp dirs is written; the real HOME and the
# real dotprofile are never touched (build-deploy rebuilds <dotprofile>/deploy;
# step 7 builds into its own temporary copy).
#
# Cases (same names and order as the .sh harness):
#   untracked  the dotprofile has no committed deploy/ (gitignored): step 7 PASS,
#              "untracked, not compared"; the build and the dry runs still run
#   stale      the dotprofile commits a deploy/ that differs from a fresh build:
#              step 7 FAIL "stale" (the comparison still works)
#
# Platform targeting (commander, 2026-11-14: "sh scripts and tests should only
# run on linux/mac and ps1 on windows"): this harness tests the .ps1 twin on
# Windows and refuses other platforms; the .sh twin (scripts/check-pre-push.sh)
# is tested on macOS/Linux by the .sh harness. The harness itself never runs
# bash; check-pre-push.ps1 step 7 runs build-deploy.sh with Git for Windows
# bash (the approved cross-language exception for build-deploy.sh).
#
# Safe to re-run. Needs git, node and Git for Windows (SKIP without node or Git
# Bash, as step 7 cannot build). Exit 1 if any case fails.
# Platform: Windows, pwsh 7 (CI: windows job).
# Usage: pwsh -NoProfile -File tests/check-pre-push/test-pre-push-step7.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 29 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/check-pre-push/test-pre-push-step7.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path

$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:out = $null

function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path) { [IO.File]::ReadAllText($Path) } else { "" } }
# Lines FILE: the file's lines, CR and colour codes removed, without the empty
# string after the last newline
function Lines([string]$Path) {
    $t = ((ReadText $Path) -replace "`e\[[0-9;]*m", "") -replace "`r", ""
    if ($t -eq "") { return @() }
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    return @($t -split "`n")
}

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if ($script:out -and (Test-Path -LiteralPath $script:out)) {
        @(Lines $script:out) | Select-Object -Last 25 | ForEach-Object { Write-Output "      | $_" }
    }
}

function Summary {
    Write-Output ""
    Write-Output ("{0} passed, {1} failed, {2} skipped" -f $script:pass, $script:fail, $script:skip)
}

if (-not (Get-Command node -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Output "SKIP step 7 cases: node not installed"; $script:skip++
    Summary
    exit 0
}
# Command-existence check with an explicit fallback (the SKIP): step 7 of
# check-pre-push.ps1 builds with Git for Windows bash and WARNs without it
if (-not (Resolve-TestGitBash)) {
    Write-Output "SKIP step 7 cases: Git for Windows bash not installed (check-pre-push.ps1 step 7 builds with it)"; $script:skip++
    Summary
    exit 0
}

# GitChecked ARGS...: git with its exit code checked (stderr progress is not an error)
function GitChecked {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $o = & git @args 2>&1 | ForEach-Object { "$_" }
        $grc = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    if ($grc -ne 0) { throw "git $($args -join ' ') failed (exit $grc): $($o -join ' | ')" }
    return $o
}

$tmpRoot = New-TestTempRoot "pre-push-step7"
$script:out = Join-Path $tmpRoot "out"
$gitId = @("-c", "user.name=test", "-c", "user.email=test@example.com")

# mk_dot DIR [with-deploy]: a fixture dotprofile (git repo, no remote)
function Mk-Dot([string]$Dir, [switch]$WithDeploy) {
    New-Item -ItemType Directory -Path (Join-Path $Dir "claude") -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $Dir "claude/CLAUDE.md"), "# Prefs`n")
    if ($WithDeploy) {
        New-Item -ItemType Directory -Path (Join-Path $Dir "deploy") -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $Dir "deploy/stale.txt"), "stale`n")
    } else {
        [IO.File]::WriteAllText((Join-Path $Dir ".gitignore"), "deploy/`n")
    }
    $null = GitChecked -C $Dir init -q
    $null = GitChecked -C $Dir -c core.autocrlf=false add -A
    $null = GitChecked -C $Dir @gitId commit -q -m fixture
}

# Run-Step7 DOTPROFILE: check-pre-push.ps1 under a temp HOME; output -> $out,
# the step 7 result line (colour codes removed) -> $script:step7
function Run-Step7([string]$Dot) {
    $h = Join-Path $tmpRoot ("home-" + (Split-Path -Leaf $Dot))
    New-Item -ItemType Directory -Path (Join-Path $h ".aitools") -Force | Out-Null
    $cfg = '{{"repoPath": "{0}", "userRepoPath": "{1}"}}' -f ($clone -replace '\\', '/'), ($Dot -replace '\\', '/')
    [IO.File]::WriteAllText((Join-Path $h ".aitools/config.json"), $cfg + "`n")
    $envs = @{
        HOME = $h; USERPROFILE = $h; AITOOLS_LOG_DIR = (Join-Path $h "logs")
        AITOOLS_USER_REPO_PATH = $null; AITOOLS_PROFILE_FILE = $null; AITOOLS_MACHINE_ALIAS = $null; AITOOLS_SUMMARY_FILE = $null
    }
    $argv = @("-NoProfile", "-NonInteractive", "-File", (Join-Path $clone "scripts/check-pre-push.ps1"))
    $null = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile $script:out
    $script:step7 = @(@(Lines $script:out) | Where-Object { $_ -cmatch '^\s*7\. deploy/ matches source' })
}
function Step7Has([string]$Text) { [bool]($script:step7 | Where-Object { $_.Contains($Text) }) }

try {
    # A clone of this repo's HEAD with one commit ahead of a fake origin/main, so
    # check-pre-push has something to push and runs every step.
    $clone = Join-Path $tmpRoot "aitools"
    $null = GitChecked clone -q $root $clone
    $null = GitChecked -C $clone update-ref refs/remotes/origin/main HEAD
    $null = GitChecked -C $clone @gitId commit -q --allow-empty -m "test: step 7"
    # The working tree's scripts/ over the clone's, so uncommitted script changes
    # are what gets tested (the clone only has committed files).
    $srcScripts = Join-Path $root "scripts"
    foreach ($f in @(Get-ChildItem -LiteralPath $srcScripts -Recurse -File -Force)) {
        $rel = $f.FullName.Substring($srcScripts.Length).TrimStart('\', '/')
        $dst = Join-Path (Join-Path $clone "scripts") $rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
        Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
    }

    $dotUntracked = Join-Path $tmpRoot "dot-untracked"
    Mk-Dot $dotUntracked
    Run-Step7 $dotUntracked
    Check "untracked deploy/: step 7 PASS, comparison skipped" `
        (Step7Has '[PASS] fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean')
    $porcelain = @(GitChecked -C $dotUntracked status --porcelain | Where-Object { $_ })
    Check "untracked deploy/: the fixture dotprofile is left clean (deploy/ built there is ignored)" ($porcelain.Count -eq 0)

    $dotStale = Join-Path $tmpRoot "dot-stale"
    Mk-Dot $dotStale -WithDeploy
    Run-Step7 $dotStale
    Check "committed deploy/ that differs from a fresh build: step 7 FAIL, stale" (Step7Has '[FAIL] dotprofile deploy/ is stale')
} finally {
    Remove-TestTempRoot $tmpRoot
}

Summary
if ($script:fail -ne 0) { exit 1 }
exit 0
