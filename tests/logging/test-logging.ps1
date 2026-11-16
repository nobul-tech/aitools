# test-logging.ps1 -- unit tests for the shared logging framework (scripts/aitools-lib.ps1),
# the check-lib.ps1 / aitools-profile.ps1 log writers, and the entry point (scripts/aitools.ps1).
#
# Safe to re-run: every case uses its own temp log dir, removed on exit.
# Platform: Windows only (pwsh 7; OS guard below; commander, 2026-11-14: "sh scripts
# and tests should only run on linux/mac and ps1 on windows"). On macOS/Linux,
# tests/logging/test-logging.sh tests the bash side (aitools-lib.sh, check-lib.sh,
# scripts/aitools).
# Exit 1 if any case fails.
# Spec: .claude/rules/script-standards.md (log line format, levels, counters,
# end-of-run summary), reference/logging.md (section 5, fail-safe writes;
# section 8, warnings and errors across scripts: records, the relay, the panel).
# Cases: every PowerShell case (lang both|ps1) of the shared fixture
# tests/logging/fixtures/summary-cases.txt (L1-L32; run by
# tests/logging/fixture-runner.ps1, shared with scratch harnesses), then this
# suite's own cases: the library's log writers, options and counters, the
# summary file lifecycle, the relay options, Invoke-RelaySync, the dotprofile push
# reasons, JSON non-interactive warnings, check-lib.ps1, aitools-profile.ps1, entry.
#
# Usage: pwsh -NoProfile -File tests/logging/test-logging.ps1 [-Help]

param([switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 19
    exit 0
}
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/logging/test-logging.sh with bash.")
    exit 1
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

    $r = Invoke-LibCase "nosummary" 'Write-Summary "OK" "tool" "detail"; Write-Output "DONE"'
    Check "lib: Write-Summary is a no-op without AITOOLS_SUMMARY_FILE" ($r.Out -match 'DONE')

    $sum = Join-Path $tmpRoot "summary.txt"
    $r = Invoke-LibCase "summary" 'Write-Summary "DETAIL" "tool" "it ran"; Write-Summary "OK" "tool2" "v1"' $sum
    $rows = if (Test-Path $sum) { Get-Content $sum } else { @() }
    Check "lib: Write-Summary writes CAT|tool|detail" ($rows -contains "DETAIL|tool|it ran")
    Check "lib: Write-Summary OK stays OK with no warnings" ($rows -contains "OK|tool2|v1")

    # The promotion is gone (logging.md 8.3: an OK record is never recoloured)
    $sum2 = Join-Path $tmpRoot "summary2.txt"
    $r = Invoke-LibCase "promote" 'LogWarn w; Write-Summary "OK" "tool" "v1"' $sum2
    $rows = if (Test-Path $sum2) { Get-Content $sum2 } else { @() }
    Check "lib: Write-Summary keeps OK after a warning (no promotion)" (($rows -ccontains "OK|tool|v1") -and -not ($rows -ccontains "WARN|tool|v1"))

    # -----------------------------------------------------------------------
    # The shared fixture (logging.md section 8): every lang both|ps1 case
    # -----------------------------------------------------------------------
    . (Join-Path $PSScriptRoot "fixture-runner.ps1")
    $fxRoot = Join-Path $tmpRoot "fixture"
    New-Item -ItemType Directory -Path $fxRoot | Out-Null
    $fx = Invoke-LoggingFixture -Path (Join-Path $PSScriptRoot "fixtures" "summary-cases.txt") -Lib $lib -TmpRoot $fxRoot
    $script:pass += $fx.Pass; $script:fail += $fx.Fail; $script:skip += $fx.Skip

    # -----------------------------------------------------------------------
    # aitools-lib.ps1: options, the summary file lifecycle, relay options,
    # Invoke-RelaySync, Repair-UvToolEnv (the I1 contract and its addendum)
    # -----------------------------------------------------------------------
    $pwsh = (Get-Process -Id $PID).Path
    # Invoke-LibScript CASE BODY [SUMMARY] [-Files @{ name = text }] -- run BODY
    # (a script, after the lib and Initialize-Logging "t") in a fresh pwsh with
    # stdin closed; extra files are written into the case dir first ({DIR} and
    # {LIB} in them, and in BODY, are replaced). Returns @{ Out; Err; Rc; Log;
    # Jsonl; Summary (lines); Dir }.
    function Invoke-LibScript([string]$Case, [string]$Body, [string]$SummaryFile = "", [hashtable]$Files = @{}) {
        $dir = Join-Path $tmpRoot $Case
        New-Item -ItemType Directory -Path (Join-Path $dir "logs") -Force | Out-Null
        foreach ($k in $Files.Keys) {
            [IO.File]::WriteAllText((Join-Path $dir $k), $Files[$k].Replace('{DIR}', $dir).Replace('{LIB}', $lib).Replace('{PWSH}', $pwsh), [Text.UTF8Encoding]::new($false))
        }
        $script_ = Join-Path $dir "case.ps1"
        $text = ". '$lib'`nInitialize-Logging 't'`n" + $Body.Replace('{DIR}', $dir).Replace('{LIB}', $lib).Replace('{PWSH}', $pwsh)
        [IO.File]::WriteAllText($script_, $text, [Text.UTF8Encoding]::new($false))
        $psi = [System.Diagnostics.ProcessStartInfo]::new($pwsh)
        foreach ($x in @("-NoProfile", "-NonInteractive", "-File", $script_)) { $psi.ArgumentList.Add($x) }
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false); $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
        foreach ($n in @("AITOOLS_SUMMARY_FILE", "AITOOLS_FORCE", "AITLIB_RELAYED", "AITOOLS_PRESERVE_SUMMARY", "AITOOLS_RUN_ID")) { [void]$psi.Environment.Remove($n) }
        $psi.Environment["AITOOLS_LOG_DIR"] = Join-Path $dir "logs"
        if ($SummaryFile) { $psi.Environment["AITOOLS_SUMMARY_FILE"] = $SummaryFile }
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.StandardInput.Close()
        $errTask = $p.StandardError.ReadToEndAsync()
        $out = $p.StandardOutput.ReadToEnd()
        $p.WaitForExit()
        $res = @{ Out = $out; Err = $errTask.Result; Rc = $p.ExitCode; Dir = $dir }
        $p.Dispose()
        $lp = Join-Path $dir "logs" "deploy.log"
        $jp = Join-Path $dir "logs" "deploy.jsonl"
        $res.Log = if (Test-Path $lp) { [IO.File]::ReadAllText($lp) } else { "" }
        $res.Jsonl = @(if (Test-Path $jp) { [IO.File]::ReadAllLines($jp) | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json } })
        $res.Summary = @(if ($SummaryFile -and (Test-Path $SummaryFile)) { [IO.File]::ReadAllLines($SummaryFile, [Text.UTF8Encoding]::new($false)) | Where-Object { $_ } })
        return $res
    }

    # Options: stderr console (recording off), jsonl; LogWarn / LogError record
    $s = Join-Path $tmpRoot "opt-stderr.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "opt-stderr" '$script:AitLibOptConsoleStderr = $true; LogWarn "w2"; Write-AitWarn "t" "w3"; Write-Output "COUNTS=$($script:errors)/$($script:warnings)"' $s
    Check "lib: stderr console option -- console lines on stderr, none on stdout" (($r.Err -match '\[warn\] w2') -and ($r.Err -match '\[warn\] w3') -and -not ($r.Out -match '\[warn\]'))
    Check "lib: stderr console option -- recording off, counts still count" (($r.Summary.Count -eq 0) -and ($r.Out -match 'COUNTS=0/2'))
    $r = Invoke-LibScript "opt-jsonl" '$script:AitLibOptJsonl = $true; Log "j-line"; LogDetail "j-detail"'
    Check "lib: jsonl option -- Log writes one deploy.jsonl record, LogDetail none" ((@($r.Jsonl | Where-Object { $_.msg -ceq 'j-line' -and $_.script -ceq 't' -and $_.level -ceq 'info' }).Count -eq 1) -and (@($r.Jsonl | Where-Object { $_.msg -ceq 'j-detail' }).Count -eq 0))
    $s = Join-Path $tmpRoot "log-records.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "log-records" 'LogWarn "lw"; LogError "le"; Write-AitWarn "tool" "ww"' $s
    Check "lib: LogWarn / LogError record under the script name, Write-AitWarn under its tool (no switch: plan step I5)" (($r.Summary.Count -eq 3) -and ($r.Summary[0] -ceq 'WARN|t|lw') -and ($r.Summary[1] -ceq 'ERROR|t|le|') -and ($r.Summary[2] -ceq 'WARN|tool|ww'))

    # Summary file lifecycle (addendum 1)
    $r = Invoke-LibScript "life-owner" 'Start-AitSummary; $f = $env:AITOOLS_SUMMARY_FILE; Write-AitWarn "tool" "w"; Write-Output "OWNER=$($script:AitLibSummaryOwner)"; Complete-AitSummary; Write-Output "GONE=$(-not (Test-Path -LiteralPath $f)) ENV=[$env:AITOOLS_SUMMARY_FILE]"'
    Check "lib: Start-AitSummary with no file -- creates and owns it" ($r.Out -match 'OWNER=True')
    Check "lib: Complete-AitSummary as the owner -- draws the panel, deletes the file, unsets it" (($r.Out -match '\[!\]\s+tool\s+w') -and ($r.Out -match 'GONE=True ENV=\[\]'))
    $s = Join-Path $tmpRoot "life-other.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "life-other" 'Start-AitSummary; Write-AitWarn "tool" "w"; Write-Output "OWNER=$($script:AitLibSummaryOwner)"; Complete-AitSummary' $s
    Check "lib: Start-AitSummary with a file set -- not the owner; Complete-AitSummary draws nothing, the file stays" (($r.Out -match 'OWNER=False') -and -not ($r.Out -match '\[!\]') -and ($r.Summary -ccontains 'WARN|tool|w'))
    $s = Join-Path $tmpRoot "life-keep.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "life-keep" 'Write-AitWarn "tool" "w"; Show-Summary -Keep; Write-Output "KEPT=$(Test-Path -LiteralPath $env:AITOOLS_SUMMARY_FILE)"' $s
    Check "lib: Show-Summary -Keep draws and keeps the file" (($r.Out -match '\[!\]\s+tool\s+w') -and ($r.Out -match 'KEPT=True'))
    $s = Join-Path $tmpRoot "life-path.txt"; [IO.File]::WriteAllText($s, "OK|alt|1.0`n")
    $r = Invoke-LibScript "life-path" "Show-Summary -Path '$s'; Write-Output ""GONE=`$(-not (Test-Path -LiteralPath '$s'))"""
    Check "lib: Show-Summary -Path draws that file, then deletes it" (($r.Out -match '\[ok\]\s+alt\s+1\.0') -and ($r.Out -match 'GONE=True'))

    # Relay options and decisions not in the fixture
    $child = @'
. '{LIB}'
Initialize-Logging "rchild"
Log "child-info"
LogWarn "child-warn"
exit 0
'@
    $r = Invoke-LibScript "relay-quiet" ('$rc = Invoke-ChildRelayed "q" "{DIR}/rchild.ps1" @{} "" -Quiet; Write-Output "RC=$rc"') "" @{ "rchild.ps1" = $child }
    Check "relay: -Quiet prints the child's warn line, not its info line" (($r.Out -match '\[rchild\] \[warn\] child-warn') -and -not ($r.Out -match 'child-info') -and ($r.Out -match 'RC=0'))
    $r = Invoke-LibScript "relay-mirror" '$rc = Invoke-ChildRelayed "m" "{DIR}/rchild.ps1" @{} ""' "" @{ "rchild.ps1" = $child }
    Check "relay: mirrors each structured child line to deploy.jsonl once" ((@($r.Jsonl | Where-Object { $_.msg -ceq 'child-info' }).Count -eq 1) -and (@($r.Jsonl | Where-Object { $_.msg -ceq 'child-warn' }).Count -eq 1))
    $r = Invoke-LibScript "relay-nomirror" '$rc = Invoke-ChildRelayed "m" "{DIR}/rchild.ps1" @{} "" -NoMirror' "" @{ "rchild.ps1" = $child }
    Check "relay: -NoMirror writes no deploy.jsonl record" (@($r.Jsonl | Where-Object { $_.msg -like 'child-*' }).Count -eq 0)

    # Only the outermost relay mirrors (addendum 6): a native child with the
    # jsonl option on relays a grandchild in-process
    $mid = @'
. '{LIB}'
Initialize-Logging "mid"
$script:AitLibOptJsonl = $true
Log "mid-line"
$rc = Invoke-ChildRelayed "gc" "{DIR}/gc.ps1" @{} ""
exit $rc
'@
    $gc = @'
. '{LIB}'
Initialize-Logging "gc"
Log "gc-line"
exit 0
'@
    $r = Invoke-LibScript "relay-nested" '$rc = Invoke-NativeRelayed -Label "mid" -FilePath "{PWSH}" -ArgumentList @("-NoProfile", "-NonInteractive", "-File", "{DIR}/mid.ps1"); Write-Output "RC=$rc"' "" @{ "mid.ps1" = $mid; "gc.ps1" = $gc }
    Check "relay: nested relays -- each structured line in deploy.jsonl exactly once" ((@($r.Jsonl | Where-Object { $_.msg -ceq 'mid-line' }).Count -eq 1) -and (@($r.Jsonl | Where-Object { $_.msg -ceq 'gc-line' }).Count -eq 1) -and ($r.Out -match 'RC=0'))

    # Nested relays: the middle script's own exit code and own error lines
    # decide; a grandchild's error line it relays (here from captured output,
    # Send-ChildLog: no failure decision of its own) is shown, not counted
    $mid2 = @'
. '{LIB}'
Initialize-Logging "mid2"
Log "mid2 runs its child"
$lines = @(& "{DIR}/gc2.ps1" 6>&1)
Send-ChildLog $lines
exit 0
'@
    $gc2 = @'
. '{LIB}'
Initialize-Logging "gc2"
LogError "gc2 error line"
exit 0
'@
    $r = Invoke-LibScript "relay-own" '$rc = Invoke-ChildRelayed "mid2" "{DIR}/mid2.ps1" @{} ""; Write-Output "RC=$rc CE=$($script:AitLibChildErrors)"' "" @{ "mid2.ps1" = $mid2; "gc2.ps1" = $gc2 }
    Check "relay: a grandchild's error line is shown, not counted in the middle script (it exited 0)" (($r.Out -match '\[gc2\] \[error\] gc2 error line') -and ($r.Out -match 'RC=0 CE=0'))
    # A child that logs under another name than its file's: every line counts
    $other = @'
. '{LIB}'
Initialize-Logging "not-the-file-name"
LogError "an error line"
exit 0
'@
    $r = Invoke-LibScript "relay-othername" '$rc = Invoke-ChildRelayed "on" "{DIR}/othername.ps1" @{} ""; Write-Output "RC=$rc CE=$($script:AitLibChildErrors)"' "" @{ "othername.ps1" = $other }
    Check "relay: a child logging under another name -- its error line counts (exit 0 with errors fails)" ($r.Out -match 'RC=1 CE=1')

    # An abort is recorded only when the child recorded no WARN or ERROR record
    $ab = @'
. '{LIB}'
Initialize-Logging "abchild"
Write-AitWarn "ab tool" "first a warning"
Invoke-ManagedAbort
'@
    $s = Join-Path $tmpRoot "relay-abort.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "relay-abort" '$rc = Invoke-ChildRelayed "ab" "{DIR}/abchild.ps1" @{} "ab tool"; Write-Output "RC=$rc CHILD=$($script:AitLibChildRc) COUNTS=$($script:errors)/$($script:warnings)"' $s @{ "abchild.ps1" = $ab }
    Check "relay: an abort after the child recorded a warning -- not recorded again, one parent error" ((($r.Summary -join '//') -ceq 'WARN|ab tool|first a warning') -and ($r.Out -match 'RC=1 CHILD=2 COUNTS=1/0'))

    # Not run: a native command that does not exist
    $s = Join-Path $tmpRoot "relay-notrun.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "relay-notrun" '$rc = Invoke-NativeRelayed -Label "nr" -FilePath "{DIR}/no-such-command" -SummaryTool "nr tool"; Write-Output "RC=$rc COUNTS=$($script:errors)"' $s
    Check "relay: a command that cannot be found -- one recorded error, '<label> not run'" ((@($r.Summary | Where-Object { $_ -like 'ERROR|nr tool|nr not run|command not found: *' }).Count -eq 1) -and ($r.Out -match 'RC=1 COUNTS=1'))

    # Native child stderr: teed (still on the console) and the failure reason
    $errChild = @'
[Console]::Error.WriteLine("boom on stderr")
exit 4
'@
    $s = Join-Path $tmpRoot "relay-stderr.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "relay-stderr" '$rc = Invoke-NativeRelayed -Label "se" -FilePath "{PWSH}" -ArgumentList @("-NoProfile", "-NonInteractive", "-File", "{DIR}/errchild.ps1"); Write-Output "RC=$rc"' $s @{ "errchild.ps1" = $errChild }
    Check "relay: native stderr is teed to the console and is the reason" (($r.Err -match 'boom on stderr') -and (($r.Summary -join '//') -ceq 'ERROR|errchild|se failed (exit 4)|boom on stderr') -and ($r.Out -match 'RC=1'))

    # Invoke-RelaySync (addendum 2)
    $s = Join-Path $tmpRoot "sync-ok.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "sync-ok" '$rc = Invoke-RelaySync "{PWSH}" @("-NoProfile", "-NonInteractive", "-Command", "Write-Output synced-line"); Write-Output "RC=$rc"' $s
    Check "lib: Invoke-RelaySync success -- output at detail, exit 0, no record" (($r.Out -match 'RC=0') -and ($r.Log -match '\[detail\] relay sync: synced-line') -and ($r.Summary.Count -eq 0))
    $s = Join-Path $tmpRoot "sync-fail.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "sync-fail" '$rc = Invoke-RelaySync "{PWSH}" @("-NoProfile", "-NonInteractive", "-Command", "Write-Output ''error: sync broke''; exit 3"); Write-Output "RC=$rc COUNTS=$($script:warnings)"' $s
    Check "lib: Invoke-RelaySync failure -- one warning 'relay sync' with the reason" ((($r.Summary -join '//') -ceq 'WARN|relay sync|relay -> AGENTS.md sync failed (exit 3, non-fatal): error: sync broke') -and ($r.Out -match 'RC=3 COUNTS=1'))

    $s = Join-Path $tmpRoot "sync-nocmd.txt"; [IO.File]::WriteAllText($s, "")
    $r = Invoke-LibScript "sync-nocmd" '$rc = Invoke-RelaySync "aitools-no-such-python" @("x.py"); Write-Output "RC=$rc COUNTS=$($script:warnings)"' $s
    Check "lib: Invoke-RelaySync, command not found -- one warning 'not run', exit 127" ((($r.Summary -join '//') -ceq 'WARN|relay sync|relay -> AGENTS.md sync not run (non-fatal): aitools-no-such-python not found') -and ($r.Out -match 'RC=127 COUNTS=1'))

    # Repair-UvToolEnv: not applicable returns 1 and logs nothing
    $r = Invoke-LibScript "uv-na" '$rc = Repair-UvToolEnv -ToolName "modal" -UpgradeOutput "some other failure" -Tool "modal cli"; Write-Output "RC=$rc COUNTS=$($script:errors)/$($script:warnings)"'
    Check "lib: Repair-UvToolEnv on other output -- returns 1, nothing logged" ($r.Out -match 'RC=1 COUNTS=0/0')

    # Invoke-DotprofileCommitPush: a failed commit or push is one warning under
    # -Tool whose text carries "(exit N: <reason>)", the reason from git's output
    # (logging.md 8.3; the same text as dotprofile_commit_push in bash)
    # Get-Command exempt: command-existence check; the else branch reports the skip
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $dpBody = @'
Set-Location -LiteralPath '{DIR}'
& git init -q --bare remote.git
& git clone -q remote.git dp 2>&1 | Out-Null
& git -C dp config user.name t
& git -C dp config user.email t@example.invalid
[IO.File]::WriteAllText('{DIR}/dp/init.md', "init`n")
& git -C dp add init.md
& git -C dp commit -q -m init
& git -C dp push -q -u origin HEAD 2>&1 | Out-Null
$script:AitLibUserRepoPath = '{DIR}/dp'
# Commit failure: a pre-commit hook refuses the commit
[IO.File]::WriteAllText('{DIR}/dp/.git/hooks/pre-commit', "#!/bin/sh`necho `"error: blocked by hook`" >&2`nexit 1`n")
[IO.File]::WriteAllText('{DIR}/dp/x.md', "x`n")
Invoke-DotprofileCommitPush -File '{DIR}/dp/x.md' -Message "add x" -Tool "dp tool"
Write-Output "COMMIT=$($script:AitLibDotprofilePush) W=$($script:warnings)"
Copy-Item -LiteralPath $env:AITOOLS_SUMMARY_FILE -Destination '{DIR}/summary-commit.txt'
[IO.File]::WriteAllText($env:AITOOLS_SUMMARY_FILE, "")
Remove-Item -LiteralPath '{DIR}/dp/.git/hooks/pre-commit'
# Push failure: the remote is gone
Remove-Item -LiteralPath '{DIR}/remote.git' -Recurse -Force
[IO.File]::WriteAllText('{DIR}/dp/y.md', "y`n")
Invoke-DotprofileCommitPush -File '{DIR}/dp/y.md' -Message "add y" -Tool "dp tool"
Write-Output "PUSH=$($script:AitLibDotprofilePush) W=$($script:warnings)"
'@
        $s = Join-Path $tmpRoot "dp-push.txt"; [IO.File]::WriteAllText($s, "")
        $r = Invoke-LibScript "dp-push" $dpBody $s
        $dpDir = "$($r.Dir)/dp"
        $commitRecs = @([IO.File]::ReadAllLines((Join-Path $r.Dir "summary-commit.txt")) | Where-Object { $_ })
        Check "lib: Invoke-DotprofileCommitPush, a failed commit -- one warning under -Tool with git's error line as its reason" (($r.Out -match 'COMMIT=commit-failed W=1') -and (($commitRecs -join '//') -ceq "WARN|dp tool|dotprofile commit failed (exit 1: error: blocked by hook) -- commit and push x.md in $dpDir by hand//ACTION||commit and push x.md in $dpDir"))
        $pushRe = '^WARN\|dp tool\|dotprofile push failed \(exit [1-9][0-9]*: fatal: .*\) -- run git push in ' + [regex]::Escape($dpDir) + '$'
        Check "lib: Invoke-DotprofileCommitPush, a failed push -- one warning under -Tool with git's error line as its reason" (($r.Out -match 'PUSH=push-failed W=2') -and ($r.Summary.Count -eq 2) -and (@($r.Summary | Where-Object { $_ -cmatch $pushRe }).Count -eq 1) -and ($r.Summary -ccontains "ACTION||run git push in $dpDir"))
        Check "lib: Invoke-DotprofileCommitPush, git's output is in deploy.log as detail lines" ($r.Log -match '\[detail\] output: error: blocked by hook')
    } else {
        Write-Output "SKIP Invoke-DotprofileCommitPush cases: git not found"; $script:skip++
    }

    # The JSON field review and the settings sync: a field overwritten in a
    # non-interactive run is one warning under the caller's tool (logging.md 8.3
    # "What is a warning", as for a text file: L32b); under -Force it is info; a
    # field only in LOCAL is kept, no warning; a live file that is created, none
    # Get-Command exempt: command-existence check; the else branch reports the skip
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $localJson = "{`n  `"a`": 1,`n  `"b`": 2,`n  `"z`": 9`n}`n"
        $jsonBody = @'
$src = '{"a": 5, "b": 2, "c": 3}'
Copy-Item -LiteralPath '{DIR}/local.json' -Destination '{DIR}/x.json'
$res = Deploy-ManagedFile -Content $src -DestPath '{DIR}/x.json' -ToolName "json tool" -ItemName "x.json"
Write-Output "NI=$res W=$($script:warnings)"
Copy-Item -LiteralPath $env:AITOOLS_SUMMARY_FILE -Destination '{DIR}/summary-ni.txt'
[IO.File]::WriteAllText($env:AITOOLS_SUMMARY_FILE, "")
Copy-Item -LiteralPath '{DIR}/local.json' -Destination '{DIR}/x.json' -Force
$env:AITOOLS_FORCE = "1"
$res = Deploy-ManagedFile -Content $src -DestPath '{DIR}/x.json' -ToolName "json tool" -ItemName "x.json"
$env:AITOOLS_FORCE = $null
Write-Output "FORCE=$res W=$($script:warnings)"
Copy-Item -LiteralPath $env:AITOOLS_SUMMARY_FILE -Destination '{DIR}/summary-force.txt'
[IO.File]::WriteAllText($env:AITOOLS_SUMMARY_FILE, "")
[IO.File]::WriteAllText('{DIR}/settings.json', "{`"theme`": `"dark`"}`n")
[IO.File]::WriteAllText('{DIR}/profile.json', "{`"claude`": {`"settings`": {`"theme`": `"light`"}}}`n")
Sync-ManagedJson -LiveFile '{DIR}/settings.json' -ProfileFile '{DIR}/profile.json' -SubPath "claude.settings" -Tool "claude settings"
Write-Output "SYNC=$($script:SyncManagedJsonResult) W=$($script:warnings)"
Copy-Item -LiteralPath $env:AITOOLS_SUMMARY_FILE -Destination '{DIR}/summary-sync.txt'
[IO.File]::WriteAllText($env:AITOOLS_SUMMARY_FILE, "")
Remove-Item -LiteralPath '{DIR}/settings.json'
Sync-ManagedJson -LiveFile '{DIR}/settings.json' -ProfileFile '{DIR}/profile.json' -SubPath "claude.settings" -Tool "claude settings"
Write-Output "NEW=$($script:SyncManagedJsonResult) W=$($script:warnings)"
'@
        $s = Join-Path $tmpRoot "json-overwrite.txt"; [IO.File]::WriteAllText($s, "")
        $r = Invoke-LibScript "json-overwrite" $jsonBody $s @{ "local.json" = $localJson }
        $niRecs = @([IO.File]::ReadAllLines((Join-Path $r.Dir "summary-ni.txt")) | Where-Object { $_ })
        $forceRecs = @([IO.File]::ReadAllLines((Join-Path $r.Dir "summary-force.txt")) | Where-Object { $_ })
        $syncRecs = @([IO.File]::ReadAllLines((Join-Path $r.Dir "summary-sync.txt")) | Where-Object { $_ })
        Check "lib: JSON field review, non-interactive -- one warning per overwritten field under -ToolName; a local-only field kept" (($r.Out -match 'NI=updated W=2') -and (($niRecs -join '//') -ceq 'WARN|json tool|Divergence in x.json: a -- overwriting from source (non-interactive)//WARN|json tool|Divergence in x.json: c -- overwriting from source (non-interactive)') -and ([IO.File]::ReadAllText((Join-Path $r.Dir "x.json")) -match '"z": 9'))
        Check "lib: JSON field review, non-interactive -- the warning is logged at warn" ($r.Log -match '\[warn\] Divergence in x\.json: a -- overwriting from source \(non-interactive\)')
        Check "lib: JSON field review, -Force -- info, no warning, no record" (($r.Out -match 'FORCE=updated W=2') -and ($forceRecs.Count -eq 0) -and ($r.Log -match '\[info\] Divergence in x\.json: a -- overwriting from source \(--force\)'))
        Check "lib: settings sync, non-interactive -- an overwritten leaf is one warning under -Tool" (($r.Out -match 'SYNC=updated W=3') -and (($syncRecs -join '//') -ceq 'WARN|claude settings|Divergence in theme -- overwriting from profile.json (non-interactive)'))
        Check "lib: settings sync -- a live file created from the profile, no warning" (($r.Out -match 'NEW=created W=3') -and ($r.Summary.Count -eq 0))
    } else {
        Write-Output "SKIP JSON field review cases: node not found"; $script:skip++
    }

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
    Check "lib: locked deploy.log -- nothing written to it (the lock held)" ((Get-Item $lockLog).Length -eq 0)

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
    # (another process's lock)
    $clDir = Join-Path $tmpRoot "checks-locked" "logs"
    New-Item -ItemType Directory -Path $clDir -Force | Out-Null
    foreach ($n in "checks.log", "checks.jsonl") { [IO.File]::WriteAllText((Join-Path $clDir $n), "") }
    Test-CheckLibRun "checks.log/.jsonl locked" (Invoke-CheckLibCase $clDir -Lock)
    Check "check-lib: checks.log/.jsonl locked -- nothing written to them (the lock held)" (((Get-Item (Join-Path $clDir "checks.log")).Length -eq 0) -and ((Get-Item (Join-Path $clDir "checks.jsonl")).Length -eq 0))

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

    # -----------------------------------------------------------------------
    # scripts/aitools.ps1 (entry point) -- uses the lib's logging, defines none of its own
    # -----------------------------------------------------------------------
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($entry, [ref]$null, [ref]$null)
    $own = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -match '^(Log|LogOk|LogWarn|LogError|LogDetail)$' }, $true))
    Check "entry: defines no log functions (uses aitools-lib)" ($own.Count -eq 0)

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
} finally {
    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot }
}

Write-Output "---- $($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
