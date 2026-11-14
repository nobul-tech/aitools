# test-b8-consumers.ps1 -- dotprofile-resolver consumers outside tests/profile:
# setup-user-skills.ps1, setup-user-cursor.ps1 (cli-config step) and
# check-lib.ps1, on a dotprofile resolver error (rc 3) and on the cursor dry run.
# The Windows harness of this suite; tests/b8-consumers/test-b8-consumers.sh is
# the macOS/Linux harness of the same cases for the .sh scripts.
#
# Checks the S3-MF-Audit fixes: A-22 (skills writes the same rows and message on
# rc 3 as the .sh), A-23 (cursor counts its own rc 3 error, row "not merged:
# dotprofile error"), A-24 (a check run with a resolver error reports a WARN
# step), A-26 cursor part (the cli-config dry run writes a summary row).
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs the .ps1 scripts with native pwsh on Windows only. Parity
# with the .sh scripts is checked against the committed golden summary rows in
# tests/b8-consumers/golden/, which the .sh harness checks on macOS/Linux
# (Test-GoldenMatch in tests/lib/platform-lib.ps1).
#
# Safe to re-run: every case runs in a child pwsh under its own temp HOME
# (removed on exit) with stub rg/agent on PATH; the real HOME is never read or
# written. Exit 1 on failure.
#
# Usage: pwsh -NoProfile -File tests/b8-consumers/test-b8-consumers.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 23 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/b8-consumers/test-b8-consumers.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$tmpRoot = New-TestTempRoot "b8-consumers"
$GoldenDir = Join-Path $root "tests/b8-consumers/golden"
$GoldenTmp = $tmpRoot
$lang = "ps1"

$script:pass = 0; $script:fail = 0; $script:skip = 0

function Strip([string]$Text) { ($Text -replace "`e\[[0-9;]*m", "") -replace "`r", "" }
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path) { [IO.File]::ReadAllText($Path) } else { "" } }

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    $out = Join-Path $script:C "out"
    if ($script:C -and (Test-Path -LiteralPath $out)) {
        @((Strip (ReadText $out)) -split "`n") | Select-Object -Last 25 | ForEach-Object { Write-Output "      | $_" }
    }
}

# Setup-Case NAME: fresh HOME, logs, summary and stub bin (rg, agent: version
# only, as .cmd files native pwsh can run).
function Setup-Case([string]$Name) {
    $script:C = Join-Path $tmpRoot $Name
    $script:H = Join-Path $script:C "home"
    foreach ($d in @($script:H, (Join-Path $script:C "bin"), (Join-Path $script:C "logs"))) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
    [IO.File]::WriteAllText((Join-Path $script:C "bin/rg.cmd"), "@echo ripgrep 14.1.0`r`n")
    [IO.File]::WriteAllText((Join-Path $script:C "bin/agent.cmd"), "@echo 2026.05.21-stub`r`n")
    [IO.File]::WriteAllText((Join-Path $script:C "summary"), "")
    $script:CaseEnv = @{}
}

# Run-Script BASE [ARGS...]: scripts/BASE.ps1, non-interactive, case HOME;
# $CaseEnv is added to the environment.
function Run-Script([string]$Base, [string[]]$ScriptArgs = @()) {
    $envs = @{
        HOME = $script:H; USERPROFILE = $script:H
        AITOOLS_LOG_DIR = (Join-Path $script:C "logs"); AITOOLS_SUMMARY_FILE = (Join-Path $script:C "summary")
        PATH = (Join-Path $script:C "bin") + [IO.Path]::PathSeparator + $env:PATH
    }
    foreach ($k in $script:CaseEnv.Keys) { $envs[$k] = $script:CaseEnv[$k] }
    $argv = @("-NoProfile", "-NonInteractive", "-File", (Join-Path $root "scripts/$Base.ps1")) + $ScriptArgs
    $script:rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile (Join-Path $script:C "out")
}

function SummaryLines { @((ReadText (Join-Path $script:C "summary")) -replace "`r", "" -split "`n" | Where-Object { $_ -ne "" }) }
# Rows FILE: the summary rows without DETAIL, ordinal sort (LC_ALL=C sort), LF-terminated
function Write-Rows([string]$File) {
    $rows = [string[]]@(SummaryLines | Where-Object { $_ -notmatch '^DETAIL' })
    [Array]::Sort($rows, [StringComparer]::Ordinal)
    $text = if ($rows.Count) { ($rows -join "`n") + "`n" } else { "" }
    [IO.File]::WriteAllText($File, $text)
}
function HasRow([string]$Row) { @(SummaryLines) -ccontains $Row }
function SummaryMatch([string]$Pattern) { [bool](@(SummaryLines) | Where-Object { $_ -cmatch $Pattern }) }
function InLog([string]$Text) {
    (Strip ((ReadText (Join-Path $script:C "out")) + "`n" + (ReadText (Join-Path $script:C "logs/deploy.log")))).Contains($Text)
}
function Nowhere { @{ AITOOLS_USER_REPO_PATH = (($script:C -replace '\\', '/') + "/nowhere") } }

try {
    # --- A-22: setup-user-skills on a resolver error (rc 3) ------------------------
    Setup-Case "skills-rc3-$lang"
    $script:CaseEnv = Nowhere
    Run-Script setup-user-skills
    Check "skills $lang rc3: exit 1" ($script:rc -eq 1)
    Check "skills $lang rc3: lib ERROR row dotprofile" (SummaryMatch '^ERROR\|dotprofile\|')
    Check "skills $lang rc3: ERROR row claude skills" (HasRow 'ERROR|claude skills|not deployed: dotprofile error')
    Check "skills $lang rc3: ERROR row cursor skills" (HasRow 'ERROR|cursor skills|not deployed: dotprofile error')
    Check "skills $lang rc3: no non-canonical 'skills' row" (-not (SummaryMatch '^[A-Z]*\|skills\|'))
    Check "skills $lang rc3: no 'skipped' detail" (-not ((ReadText (Join-Path $C "summary")) -match 'skipped'))
    Check "skills $lang rc3: consumer error logged" (InLog 'Dotprofile unresolved (resolver error above) -- skills not deployed, so shared copies cannot replace dotprofile versions')
    Check "skills $lang rc3: nothing deployed" (-not (Test-Path (Join-Path $H ".claude/skills")) -and -not (Test-Path (Join-Path $H ".cursor/skills")))
    Write-Rows (Join-Path $tmpRoot "skills-rc3.rows")
    Check "skills rc3 parity: summary rows match golden (sh and ps1 share it)" (Test-GoldenMatch "skills-rc3.rows" (Join-Path $tmpRoot "skills-rc3.rows"))

    # --- A-23: setup-user-cursor cli-config on a resolver error (rc 3) -------------
    # The dry run keeps steps 1-2 to version checks; the rc 3 branch comes first.
    Setup-Case "cursor-rc3-$lang"
    $script:CaseEnv = Nowhere
    Run-Script setup-user-cursor @("-DryRun")
    Check "cursor $lang rc3: exit 1" ($script:rc -eq 1)
    Check "cursor $lang rc3: ERROR row not merged" (HasRow 'ERROR|cursor cli|not merged: dotprofile error')
    Check "cursor $lang rc3: no 'skipped' detail" (-not ((ReadText (Join-Path $C "summary")) -match 'skipped'))
    Check "cursor $lang rc3: consumer error logged as error" ((Strip (ReadText (Join-Path $C "logs/deploy.log"))) -match '\[error\] Dotprofile unresolved \(resolver error above\) -- .*cli-config.json not merged, so defaults cannot replace the profile preferences')
    Check "cursor $lang rc3: error counted (consumer + lib)" (InLog 'FAILED with 2 error(s)')
    Check "cursor $lang rc3: no cli-config written" (-not (Test-Path (Join-Path $H ".cursor/cli-config.json")))
    Write-Rows (Join-Path $tmpRoot "cursor-rc3.rows")
    Check "cursor rc3 parity: summary rows match golden" (Test-GoldenMatch "cursor-rc3.rows" (Join-Path $tmpRoot "cursor-rc3.rows"))

    # --- A-26 (cursor part): cli-config dry run writes a row ------------------------
    # No dotprofile (rc 1, defaults). First a dry run on a missing cli-config (would
    # update), then a real run (created), then a dry run on the written file (verified).
    Setup-Case "cursor-dry-$lang"
    Run-Script setup-user-cursor @("-DryRun")
    Check "cursor $lang dry (missing config): exit 0" ($script:rc -eq 0)
    Check "cursor $lang dry (missing config): OK row dry-run: would update" (HasRow 'OK|cursor cli|dry-run: would update')
    Check "cursor $lang dry (missing config): nothing written" (-not (Test-Path (Join-Path $H ".cursor/cli-config.json")))
    Write-Rows (Join-Path $tmpRoot "cursor-dry1.rows")
    Check "cursor dry parity (missing config): rows match golden" (Test-GoldenMatch "cursor-dry1.rows" (Join-Path $tmpRoot "cursor-dry1.rows"))
    [IO.File]::WriteAllText((Join-Path $C "summary"), "")
    Run-Script setup-user-cursor
    Check "cursor $lang real run: OK row created" (HasRow 'OK|cursor cli|created')
    [IO.File]::WriteAllText((Join-Path $C "summary"), "")
    Run-Script setup-user-cursor @("-DryRun")
    Check "cursor $lang dry (up to date): exit 0" ($script:rc -eq 0)
    Check "cursor $lang dry (up to date): OK row verified" (HasRow 'OK|cursor cli|verified')
    Write-Rows (Join-Path $tmpRoot "cursor-dry2.rows")
    Check "cursor dry parity (up to date): rows match golden" (Test-GoldenMatch "cursor-dry2.rows" (Join-Path $tmpRoot "cursor-dry2.rows"))

    # --- A-24: check-lib reports a resolver error as a WARN step --------------------
    # A minimal check script in the check-script block order (check-lib, init-logging,
    # ResolveConfig, CheckLogInit), one PASS step, summary.
    $cl = Join-Path $tmpRoot "mini-check.ps1"
    $clLines = @(
        "`$ErrorActionPreference = 'Stop'",
        ". '$(Join-Path $root 'scripts/check-lib.ps1')'",
        ". '$(Join-Path $root 'scripts/init-logging.ps1')'",
        'ResolveConfig', 'CheckLogInit "mini"', 'StepPass "1" "Something"', 'PrintSummary'
    )
    [IO.File]::WriteAllText($cl, ($clLines -join "`n") + "`n")
    foreach ($mode in @("rc3", "rc1")) {
        Setup-Case "checklib-$mode-$lang"
        $envs = @{ HOME = $H; USERPROFILE = $H; AITOOLS_LOG_DIR = (Join-Path $C "logs") }
        if ($mode -eq "rc3") { foreach ($kv in (Nowhere).GetEnumerator()) { $envs[$kv.Key] = $kv.Value } }
        $script:rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $cl) -Environment $envs -OutFile (Join-Path $C "out")
        Check "check-lib $lang ${mode}: exit 0" ($script:rc -eq 0)
        $out = Strip (ReadText (Join-Path $C "out"))
        if ($mode -eq "rc3") {
            Check "check-lib $lang rc3: WARN step on console" ($out -match '(?m)^ +0\. Dotprofile resolution +\[WARN\] resolver error \(rc 3, see deploy.log\)')
            Check "check-lib $lang rc3: summary counts it" ($out.Contains('=== SUMMARY: 1 PASS, 0 SKIP, 1 WARN, 0 FAIL ==='))
            Check "check-lib $lang rc3: WARN step in checks.jsonl" ((ReadText (Join-Path $C "logs/checks.jsonl")).Contains('"label":"Dotprofile resolution","result":"WARN"'))
        } else {
            Check "check-lib $lang rc1: no dotprofile step" (-not $out.Contains('Dotprofile resolution'))
            Check "check-lib $lang rc1: clean summary" ($out.Contains('=== SUMMARY: 1 PASS, 0 SKIP, 0 WARN, 0 FAIL ==='))
        }
    }
} finally {
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: {3} scripts)" -f $script:pass, $script:fail, $script:skip, $lang)
if ($script:fail -ne 0) { exit 1 }
exit 0
