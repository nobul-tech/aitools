# test-logging.ps1 -- unit tests for the shared logging framework (scripts/aitools-lib.ps1)
# and for the PowerShell entry point's use of it (scripts/aitools.ps1).
#
# Safe to re-run: every case uses its own temp log dir, removed on exit.
# Platform: Windows, macOS, Linux (pwsh 7). Entry-point run cases need Windows
# (aitools.ps1 has a Windows OS guard) and are reported as SKIP elsewhere.
# Exit 1 if any case fails.
# Spec: .claude/rules/script-standards.md (log line format, levels, counters,
# end-of-run summary), reference/logging.md, reference/script-standards-detail.md
# "Logging overrides".
#
# Usage: pwsh -NoProfile -File tests/logging/test-logging.ps1 [-Help]

param([switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 11
    exit 0
}

$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
$lib = Join-Path $root "scripts" "aitools-lib.ps1"
$entry = Join-Path $root "scripts" "aitools.ps1"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-logtest-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

$script:pass = 0
$script:fail = 0
$script:skip = 0
$tsRe = '\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\]'

function Check([string]$Name, [bool]$Ok) {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ } else { Write-Output "FAIL $Name"; $script:fail++ }
}
function Skip([string]$Name, [string]$Why) { Write-Output "SKIP $Name ($Why)"; $script:skip++ }

# Run a snippet in a fresh pwsh with the lib dot-sourced and an isolated log dir.
# Returns @{ Out = console text; Log = deploy.log text; Dir = case dir }.
function Invoke-LibCase([string]$Case, [string]$Snippet, [string]$SummaryFile = "") {
    $dir = Join-Path $tmpRoot $Case
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $env:AITOOLS_LOG_DIR = Join-Path $dir "logs"
    $env:AITOOLS_SUMMARY_FILE = $SummaryFile
    $code = ". '$lib'; Initialize-Logging 't'; $Snippet"
    $out = & pwsh -NoProfile -Command $code *>&1 | Out-String
    $logPath = Join-Path $env:AITOOLS_LOG_DIR "deploy.log"
    $log = if (Test-Path $logPath) { [IO.File]::ReadAllText($logPath) } else { "" }
    $env:AITOOLS_LOG_DIR = $null
    $env:AITOOLS_SUMMARY_FILE = $null
    return @{ Out = $out; Log = $log; Dir = $dir }
}

try {
    # -----------------------------------------------------------------------
    # aitools-lib.ps1
    # -----------------------------------------------------------------------
    $r = Invoke-LibCase "format" 'Log "hello world"'
    Check "lib: log line format [ts] [script] [level] message" ($r.Log -match "(?m)^$tsRe \[t\] \[info\] hello world$")
    Check "lib: log file is AITOOLS_LOG_DIR/deploy.log" (Test-Path (Join-Path $r.Dir "logs" "deploy.log"))

    $r = Invoke-LibCase "levels" 'LogOk a; LogWarn b; LogError c; Log d'
    Check "lib: levels ok/warn/error/info recorded" (($r.Log -match '\[ok\] a') -and ($r.Log -match '\[warn\] b') -and ($r.Log -match '\[error\] c') -and ($r.Log -match '\[info\] d'))
    Check "lib: log file has no ANSI codes" (-not ($r.Log -match "`e\["))
    Check "lib: console shows every level" (($r.Out -match '\[warn\] b') -and ($r.Out -match '\[error\] c') -and ($r.Out -match '\[info\] d'))

    $r = Invoke-LibCase "detail" 'LogDetail "secret diff line"'
    Check "lib: LogDetail writes the log" ($r.Log -match '\[detail\] secret diff line')
    Check "lib: LogDetail stays off the console" (-not ($r.Out -match 'secret diff line'))

    $r = Invoke-LibCase "counters" 'LogError x; LogError y; LogWarn z; Write-Output "COUNTS=$($script:errors)/$($script:warnings)"'
    Check "lib: LogError/LogWarn increment the counters" ($r.Out -match 'COUNTS=2/1')

    $r = Invoke-LibCase "reset" 'LogError x; Initialize-Logging "t2"; Write-Output "COUNTS=$($script:errors)/$($script:warnings)"'
    Check "lib: Initialize-Logging resets the counters" ($r.Out -match 'COUNTS=0/0')

    $r = Invoke-LibCase "nosummary" 'Write-Summary "ERROR" "tool" "detail"; Write-Output "DONE"'
    Check "lib: Write-Summary is a no-op without AITOOLS_SUMMARY_FILE" ($r.Out -match 'DONE')

    $sum = Join-Path $tmpRoot "summary.txt"
    $r = Invoke-LibCase "summary" 'Write-Summary "ERROR" "tool" "it failed"; Write-Summary "OK" "tool2" "v1"' $sum
    $rows = if (Test-Path $sum) { Get-Content $sum } else { @() }
    Check "lib: Write-Summary writes CAT|tool|detail" ($rows -contains "ERROR|tool|it failed")
    Check "lib: Write-Summary OK stays OK with no warnings" ($rows -contains "OK|tool2|v1")

    $sum2 = Join-Path $tmpRoot "summary2.txt"
    $r = Invoke-LibCase "promote" 'LogWarn w; Write-Summary "OK" "tool" "v1"' $sum2
    $rows = if (Test-Path $sum2) { Get-Content $sum2 } else { @() }
    Check "lib: Write-Summary promotes OK to WARN after a warning" ($rows -contains "WARN|tool|v1")

    $rotDir = Join-Path $tmpRoot "rotate" "logs"
    New-Item -ItemType Directory -Path $rotDir -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $rotDir "deploy.log"), ("x" * 5242880))
    $env:AITOOLS_LOG_DIR = $rotDir
    # Console output is irrelevant here; the check below inspects the rotated files.
    & pwsh -NoProfile -Command ". '$lib'; Initialize-Logging 't'; Log 'after'" *>&1 | Out-Null
    $env:AITOOLS_LOG_DIR = $null
    $rotated = Test-Path (Join-Path $rotDir "deploy.log.1")
    $fresh = (Test-Path (Join-Path $rotDir "deploy.log")) -and ((Get-Item (Join-Path $rotDir "deploy.log")).Length -lt 1000)
    Check "lib: Initialize-Logging rotates a 5 MB log to deploy.log.1" ($rotated -and $fresh)

    # -----------------------------------------------------------------------
    # scripts/aitools.ps1 (entry point) -- uses the lib's logging, defines none of its own
    # -----------------------------------------------------------------------
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($entry, [ref]$null, [ref]$null)
    $own = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -match '^(Log|LogOk|LogWarn|LogError|LogDetail)$' }, $true))
    Check "entry: defines no log functions (uses aitools-lib)" ($own.Count -eq 0)

    if ($IsWindows) {
        # Fake USERPROFILE with config.json -> a repo dir holding the lib.
        function New-FakeRepo([string]$Case, [bool]$WithLib) {
            $d = Join-Path $tmpRoot $Case
            New-Item -ItemType Directory -Path (Join-Path $d "home" ".aitools"), (Join-Path $d "repo" ".git"), (Join-Path $d "repo" "scripts") -Force | Out-Null
            if ($WithLib) { Copy-Item $lib (Join-Path $d "repo" "scripts") }
            $cfg = @{ version = 2; repoPath = (Join-Path $d "repo") } | ConvertTo-Json
            [IO.File]::WriteAllText((Join-Path $d "home" ".aitools" "config.json"), $cfg)
            return $d
        }
        function Invoke-Entry([string]$Dir, [string[]]$EntryArgs) {
            $savedProfile = $env:USERPROFILE
            $env:USERPROFILE = Join-Path $Dir "home"
            $env:AITOOLS_LOG_DIR = Join-Path $Dir "logs"
            $out = & pwsh -NoProfile -File $entry @EntryArgs *>&1 | Out-String
            $rc = $LASTEXITCODE
            $env:USERPROFILE = $savedProfile
            $env:AITOOLS_LOG_DIR = $null
            $logPath = Join-Path $Dir "logs" "deploy.log"
            $log = if (Test-Path $logPath) { [IO.File]::ReadAllText($logPath) } else { "" }
            return @{ Out = $out; Rc = $rc; Log = $log }
        }
        $d = New-FakeRepo "unknown" $true
        $r = Invoke-Entry $d @("bogus-command")
        Check "entry: unknown command exits 1" ($r.Rc -eq 1)
        Check "entry: unknown command logged by the lib ([aitools] [error])" ($r.Log -match "$tsRe \[aitools\] \[error\] unknown command 'bogus-command'")

        $d = New-FakeRepo "nolib" $false
        $r = Invoke-Entry $d @("bogus-command")
        Check "entry: missing aitools-lib exits 1" ($r.Rc -eq 1)
        Check "entry: missing aitools-lib names the path" ($r.Out -match 'aitools-lib.ps1 not found at')

        $d = New-FakeRepo "version" $false
        Remove-Item -Recurse -Force (Join-Path $d "repo")
        $r = Invoke-Entry $d @("-Version")
        Check "entry: -Version answers without the repo" (($r.Rc -eq 0) -and ($r.Out -match 'repo: not found'))
    } else {
        foreach ($n in @("entry: unknown command exits 1", "entry: unknown command logged by the lib ([aitools] [error])",
                         "entry: missing aitools-lib exits 1", "entry: missing aitools-lib names the path",
                         "entry: -Version answers without the repo")) {
            Skip $n "aitools.ps1 runs on Windows only"
        }
    }
} finally {
    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot }
}

Write-Output "---- $($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
