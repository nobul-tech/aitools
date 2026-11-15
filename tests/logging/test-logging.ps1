# test-logging.ps1 -- unit tests for the shared logging framework (scripts/aitools-lib.ps1),
# the check-lib.ps1 / aitools-profile.ps1 log writers, and the entry point (scripts/aitools.ps1).
#
# Safe to re-run: every case uses its own temp log dir, removed on exit.
# Platform: Windows, macOS, Linux (pwsh 7). Entry-point run cases need Windows
# (aitools.ps1 has a Windows OS guard) and are reported as SKIP elsewhere.
# Exit 1 if any case fails.
# Spec: .claude/rules/script-standards.md (log line format, levels, counters,
# end-of-run summary), reference/logging.md (incl. section 5, fail-safe writes), reference/script-standards-detail.md
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

    # Fail-safe log writes (reference/logging.md section 5): a failed log write
    # is swallowed. deploy.log is held open by this process with no sharing
    # (another process's lock) while the child logs at every level, under
    # $ErrorActionPreference = "Stop" and inside its own try: no exception, the
    # console lines still print, the counters still count.
    $lockDir = Join-Path $tmpRoot "locked" "logs"
    New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
    $lockLog = Join-Path $lockDir "deploy.log"
    [IO.File]::WriteAllText($lockLog, "")
    $snippet = '$ErrorActionPreference = "Stop"; try { Log "info-line"; LogDetail "detail-line"; LogWarn "warn-line"; LogError "error-line"; LogOk "ok-line"; Write-AiLog "ai-line"; Write-Output "COUNTS=$($script:errors)/$($script:warnings)"; Write-Output "REACHED-END" } catch { Write-Output "CAUGHT: $($_.Exception.Message)" }'
    $env:AITOOLS_LOG_DIR = $lockDir
    $h = [IO.File]::Open($lockLog, 'Open', 'ReadWrite', 'None')
    try {
        $lockOut = & pwsh -NoProfile -Command ". '$lib'; Initialize-Logging 't'; $snippet" *>&1 | Out-String
        $lockRc = $LASTEXITCODE
    } finally {
        $h.Dispose()
        $env:AITOOLS_LOG_DIR = $null
    }
    Check "lib: locked deploy.log -- no exception, the run goes on (exit 0)" (($lockRc -eq 0) -and ($lockOut -match 'REACHED-END') -and -not ($lockOut -match 'CAUGHT|Exception|AppendAllText'))
    Check "lib: locked deploy.log -- console lines still printed (info, warn, error, ok)" (($lockOut -match '\[info\] info-line') -and ($lockOut -match '\[warn\] warn-line') -and ($lockOut -match '\[error\] error-line') -and ($lockOut -match '\[ok\] ok-line'))
    Check "lib: locked deploy.log -- LogError/LogWarn still count" ($lockOut -match 'COUNTS=1/1')
    Check "lib: locked deploy.log -- detail and AI telemetry stay off the console" (-not ($lockOut -match 'detail-line|ai-line'))
    if ($IsWindows) {
        Check "lib: locked deploy.log -- nothing written to it (the lock held)" ((Get-Item $lockLog).Length -eq 0)
    } else {
        # .NET maps FileShare.None to an advisory lock off Windows (not verified here)
        Skip "lib: locked deploy.log -- nothing written to it (the lock held)" "Windows file locks only"
    }

    # The log directory cannot be created (its parent is a file)
    $notDir = Join-Path $tmpRoot "not-a-dir"
    [IO.File]::WriteAllText($notDir, "")
    $env:AITOOLS_LOG_DIR = Join-Path $notDir "logs"
    $ndOut = & pwsh -NoProfile -Command ". '$lib'; `$ErrorActionPreference = 'Stop'; Initialize-Logging 't'; LogWarn 'still-here'; Write-Output ""COUNTS=`$(`$script:errors)/`$(`$script:warnings)""" *>&1 | Out-String
    $ndRc = $LASTEXITCODE
    $env:AITOOLS_LOG_DIR = $null
    Check "lib: log dir cannot be created -- Initialize-Logging and LogWarn go on" (($ndRc -eq 0) -and ($ndOut -match '\[warn\] still-here') -and ($ndOut -match 'COUNTS=0/1') -and -not ($ndOut -match 'Exception|New-Item'))

    # -----------------------------------------------------------------------
    # scripts/check-lib.ps1 -- checks.log / checks.jsonl writers (incident #174)
    # -----------------------------------------------------------------------
    # Under $ErrorActionPreference = "Stop" and inside a try: a checks.log /
    # checks.jsonl that cannot be written (a directory, a lock held by another
    # process, a log dir that cannot be created) ends nothing, every step line
    # still prints and every step counter still counts. A writable pair still gets
    # every line, and the check lines never land in deploy.log (Write-CheckLogText
    # points Add-AitLibLogText at the check file for one call only).
    $checkLib = Join-Path $root "scripts" "check-lib.ps1"
    $checkChild = Join-Path $tmpRoot "checklib-child.ps1"
    [IO.File]::WriteAllText($checkChild, @'
param([string]$CheckLib)
. $CheckLib
$ErrorActionPreference = "Stop"
try {
    CheckLogInit "probe"
    StepPass "1" "pass-step"
    StepFail "2" "fail-step" 'a "quoted" detail'
    StepWarn "3" "warn-step"
    StepSkip "4" "skip-step"
    PrintSummary
    Write-Output "COUNTS=$($script:PassCount)/$($script:FailCount)/$($script:WarnCount)/$($script:SkipCount)"
    Write-Output "LOGFILE=$($script:logFile)"
    Write-Output "REACHED-END"
} catch { Write-Output "CAUGHT: $($_.Exception.Message)" }
'@)
    # Invoke-CheckLibCase LOGDIR [-Lock] -- @{ Out; Rc }; -Lock holds checks.log and
    # checks.jsonl open with no sharing while the child runs
    function Invoke-CheckLibCase([string]$LogDir, [switch]$Lock) {
        $handles = @()
        if ($Lock) {
            foreach ($n in "checks.log", "checks.jsonl") { $handles += [IO.File]::Open((Join-Path $LogDir $n), 'Open', 'ReadWrite', 'None') }
        }
        $env:AITOOLS_LOG_DIR = $LogDir
        try {
            $o = & pwsh -NoProfile -NonInteractive -File $checkChild -CheckLib $checkLib *>&1 | Out-String
            $c = $LASTEXITCODE
        } finally {
            foreach ($h in $handles) { $h.Dispose() }
            $env:AITOOLS_LOG_DIR = $null
        }
        return @{ Out = $o; Rc = $c }
    }
    function Test-CheckLibRun([string]$What, [hashtable]$R) {
        Check "check-lib: $What -- Stop run goes on (exit 0, no catch)" (($R.Rc -eq 0) -and ($R.Out -match 'REACHED-END') -and -not ($R.Out -match 'CAUGHT|Exception|Add-Content|being used by another process'))
        Check "check-lib: $What -- step lines still printed" (($R.Out -match 'pass-step\s+\[PASS\]') -and ($R.Out -match 'fail-step\s+\[FAIL\]') -and ($R.Out -match 'warn-step\s+\[WARN\]') -and ($R.Out -match 'skip-step\s+\[SKIP\]') -and ($R.Out -match 'SUMMARY: 1 PASS, 1 SKIP, 1 WARN, 1 FAIL'))
        Check "check-lib: $What -- step counters still count" ($R.Out -match 'COUNTS=1/1/1/1')
    }

    # Writable
    $cwDir = Join-Path $tmpRoot "checks-written" "logs"
    $r = Invoke-CheckLibCase $cwDir
    Test-CheckLibRun "writable" $r
    $cwLog = if (Test-Path (Join-Path $cwDir "checks.log")) { [IO.File]::ReadAllText((Join-Path $cwDir "checks.log")) } else { "" }
    $cwLines = @($cwLog -split "`r?`n" | Where-Object { $_ -match 'RUN START|pass-step|fail-step.*a "quoted" detail|warn-step|skip-step|=== SUMMARY: 1 PASS, 1 SKIP, 1 WARN, 1 FAIL' })
    Check "check-lib: writable -- checks.log has run start, the 4 steps and the summary" ($cwLines.Count -eq 6)
    $cwJson = if (Test-Path (Join-Path $cwDir "checks.jsonl")) { @([IO.File]::ReadAllLines((Join-Path $cwDir "checks.jsonl")) | Where-Object { $_ }) } else { @() }
    $cwBad = 0
    foreach ($l in $cwJson) { try { $null = $l | ConvertFrom-Json -ErrorAction Stop } catch { $cwBad++ } }
    Check "check-lib: writable -- checks.jsonl has 6 records, each valid JSON" (($cwJson.Count -eq 6) -and ($cwBad -eq 0))
    $cwDeploy = if (Test-Path (Join-Path $cwDir "deploy.log")) { [IO.File]::ReadAllText((Join-Path $cwDir "deploy.log")) } else { "" }
    Check "check-lib: writable -- no check line in deploy.log, the bridged log file is still deploy.log" ((-not ($cwDeploy -match 'pass-step|RUN START')) -and ($r.Out -match 'LOGFILE=.*deploy\.log'))

    # checks.log and checks.jsonl are directories
    $cdDir = Join-Path $tmpRoot "checks-dir" "logs"
    New-Item -ItemType Directory -Path (Join-Path $cdDir "checks.log"), (Join-Path $cdDir "checks.jsonl") -Force | Out-Null
    Test-CheckLibRun "checks.log/.jsonl are directories" (Invoke-CheckLibCase $cdDir)

    # checks.log and checks.jsonl held open with no sharing by this process
    # (another process's lock); Windows only
    if ($IsWindows) {
        $clDir = Join-Path $tmpRoot "checks-locked" "logs"
        New-Item -ItemType Directory -Path $clDir -Force | Out-Null
        foreach ($n in "checks.log", "checks.jsonl") { [IO.File]::WriteAllText((Join-Path $clDir $n), "") }
        Test-CheckLibRun "checks.log/.jsonl locked" (Invoke-CheckLibCase $clDir -Lock)
        Check "check-lib: checks.log/.jsonl locked -- nothing written to them (the lock held)" (((Get-Item (Join-Path $clDir "checks.log")).Length -eq 0) -and ((Get-Item (Join-Path $clDir "checks.jsonl")).Length -eq 0))
    } else {
        foreach ($n in @("Stop run goes on (exit 0, no catch)", "step lines still printed", "step counters still count", "nothing written to them (the lock held)")) {
            Skip "check-lib: checks.log/.jsonl locked -- $n" "Windows file locks only"
        }
    }

    # The log directory cannot be created (its parent is a file)
    $cnFile = Join-Path $tmpRoot "checks-notadir"
    [IO.File]::WriteAllText($cnFile, "")
    Test-CheckLibRun "log dir cannot be created" (Invoke-CheckLibCase (Join-Path $cnFile "logs"))

    # -----------------------------------------------------------------------
    # scripts/aitools-profile.ps1 -- its Log override (incident #174)
    # -----------------------------------------------------------------------
    # deploy.log held open with no sharing by this process while the resolver
    # runs; AITOOLS_ENVIRONMENT=bogus makes Initialize-Logging log a warning
    # through the resolver's Log override. The resolver must still answer (exit 0,
    # its data on stdout; before #174 its trap turned the write error into exit 2)
    # and the warning must reach stderr. A directory in place of deploy.log and a
    # writable one: tests/profile/test-profile.sh. Windows only (OS guard).
    $profileScript = Join-Path $root "scripts" "aitools-profile.ps1"
    if ($IsWindows) {
        $plDir = Join-Path $tmpRoot "profile-locked"
        New-Item -ItemType Directory -Path (Join-Path $plDir "logs"), (Join-Path $plDir "home") -Force | Out-Null
        $plLog = Join-Path $plDir "logs" "deploy.log"
        [IO.File]::WriteAllText($plLog, "")
        $plErr = Join-Path $plDir "stderr.txt"
        $savedHome = $env:HOME; $savedProfile = $env:USERPROFILE
        $env:HOME = Join-Path $plDir "home"; $env:USERPROFILE = $env:HOME
        $env:AITOOLS_LOG_DIR = Join-Path $plDir "logs"; $env:AITOOLS_ENVIRONMENT = "bogus"
        $h = [IO.File]::Open($plLog, 'Open', 'ReadWrite', 'None')
        try {
            $plOut = & pwsh -NoProfile -NonInteractive -File $profileScript hostname --hostname-value probe-host 2> $plErr | Out-String
            $plRc = $LASTEXITCODE
        } finally {
            $h.Dispose()
            $env:HOME = $savedHome; $env:USERPROFILE = $savedProfile
            $env:AITOOLS_LOG_DIR = $null; $env:AITOOLS_ENVIRONMENT = $null
        }
        $plErrText = if (Test-Path $plErr) { [IO.File]::ReadAllText($plErr) } else { "" }
        Check "profile: locked deploy.log -- the resolver answers (exit 0, data on stdout)" (($plRc -eq 0) -and ($plOut.Trim() -eq "probe-host"))
        Check "profile: locked deploy.log -- the warning reached stderr, no write error" (($plErrText -match "\[aitools-profile\] \[warn\] AITOOLS_ENVIRONMENT='bogus' ignored") -and -not ($plErrText -match 'Exception|AppendAllText|being used by another process'))
        Check "profile: locked deploy.log -- nothing written to it (the lock held)" ((Get-Item $plLog).Length -eq 0)
    } else {
        foreach ($n in @("the resolver answers (exit 0, data on stdout)", "the warning reached stderr, no write error", "nothing written to it (the lock held)")) {
            Skip "profile: locked deploy.log -- $n" "aitools-profile.ps1 runs on Windows only"
        }
    }

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
