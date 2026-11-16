# fixture-runner.ps1 -- the PowerShell runner of the shared logging fixture
# tests/logging/fixtures/summary-cases.txt (its header is the format spec).
# Dot-sourced, not run. Used by tests/logging/test-logging.ps1 (Windows) and
# by scratch harnesses that prove the runner under macOS/Linux pwsh (the
# library has no OS guard; the suite has).
#
# Provides:
#   Read-LoggingFixture PATH          the cases: ordered hashtable id -> list of
#                                     @{ Kw; Rest; Only } (Only: both|sh|ps1)
#   Invoke-LoggingFixture -Path P -Lib L -TmpRoot T [-Ids I]
#                                     run every case for PowerShell (lang both or
#                                     ps1; @sh lines ignored), print (Write-Host)
#                                     one "PASS|FAIL|SKIP fixture <id>" line per case
#                                     (FAIL lines are followed by "      | <why>"
#                                     lines), return @{ Pass; Fail; Skip; Results }
#   Invoke-FixtureSteps PATH          (used inside the generated case and child
#                                     scripts) run the steps in the JSON file PATH
#                                     in the caller's script scope
#
# How a case runs (the fixture header "CASES"): a fresh pwsh process per case,
# in its own directory {CASEDIR}, stdin closed (EOF; not a terminal),
# AITOOLS_LOG_DIR={CASEDIR}/logs, AITOOLS_SUMMARY_FILE={CASEDIR}/summary.txt
# (created empty) unless "summary unset", and the library loaded with script
# name test-logging.
# The steps are data (a JSON file the case script interprets), so no fixture
# text is ever pasted into PowerShell code. Child scripts {CASEDIR}/CHILD.ps1 load
# the library, Initialize-Logging CHILD, run their actions, then
# "exit N". "relay" runs the child in-process (Invoke-ChildRelayed), "relay-native"
# as a separate process (Invoke-NativeRelayed: pwsh -NoProfile -File CHILD.ps1).
# "render" draws with Show-Summary -Keep (the file stays, so "expect record"
# sees it). The case writes its observations to {CASEDIR}/obs.json; the runner
# compares them, deploy.log and the run summary file with the expectations.
#
# Platform: pwsh 7 on any OS (no OS guard: a library of the suite).

$script:FixtureRunnerPath = $PSCommandPath

function ConvertFrom-FixtureEscape([string]$s) {
    $re = [regex]'\\(\\|p|n|r|t|e|s|u\{([0-9A-Fa-f]+)\}|.?)'
    return $re.Replace($s, {
        param($m)
        switch -CaseSensitive ($m.Groups[1].Value) {
            '\' { '\' } 'p' { '|' } 'n' { "`n" } 'r' { "`r" } 't' { "`t" } 'e' { [string][char]27 } 's' { ' ' }
            default {
                if ($m.Groups[2].Success) { [char]::ConvertFromUtf32([Convert]::ToInt32($m.Groups[2].Value, 16)) }
                else { throw "fixture error: bad escape $($m.Value)" }
            }
        }
    })
}

function Split-FixtureRest([string]$Rest) {
    return @($Rest -split '\|' | ForEach-Object { ConvertFrom-FixtureEscape $_ })
}

function Read-LoggingFixture([string]$Path) {
    $lines = [IO.File]::ReadAllLines($Path, [Text.UTF8Encoding]::new($false))
    $cases = [ordered]@{}
    $cur = $null
    foreach ($line in $lines) {
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $only = 'both'
        if ($line -match '^@(sh|ps1) (.*)$') { $only = $Matches[1]; $line = $Matches[2] }
        $sp = $line.IndexOf(' ')
        $kw = if ($sp -lt 0) { $line } else { $line.Substring(0, $sp) }
        $rest = if ($sp -lt 0) { '' } else { $line.Substring($sp + 1) }
        if ($kw -ceq 'case') { $cur = [System.Collections.Generic.List[object]]::new(); $cases[$rest] = $cur; continue }
        if ($null -eq $cur) { throw "fixture error: '$line' before the first case" }
        $cur.Add([pscustomobject]@{ Kw = $kw; Rest = $rest; Only = $only })
    }
    return $cases
}

# ---------------------------------------------------------------------------
# Inside the case and child scripts
# ---------------------------------------------------------------------------
# Invoke-FixtureSteps PATH -- run the steps of PATH (JSON: { casedir, steps: [
# { kw, args } ] }). Runs in the caller's script scope (the counts and the
# library state are the script's). Observations go to $script:FixtureObs.
function Invoke-FixtureSteps([string]$Path) {
    $spec = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
    $casedir = [string]$spec.casedir
    foreach ($step in @($spec.steps)) {
        $a = @($step.args | ForEach-Object {
            $v = [string]$_
            $v = $v.Replace('{CASEDIR}', $casedir)
            if ($null -ne $script:FixtureObs -and $null -ne $script:FixtureObs.result) { $v = $v.Replace('{RESULT}', [string]$script:FixtureObs.result) }
            $v
        })
        switch -CaseSensitive ([string]$step.kw) {
            'record' {
                [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, $a[0] + "`n", [Text.UTF8Encoding]::new($false))
            }
            'file' {
                [IO.File]::WriteAllText((Join-Path $casedir $a[0]), $a[1], [Text.UTF8Encoding]::new($false))
            }
            'stdout' { Write-Host $a[0] }
            'throw' { throw $a[0] }
            'write-error' { Write-Error $a[0] }
            'call' {
                switch -CaseSensitive ($a[0]) {
                    'log'           { Log $a[1] }
                    'log_warn'      { LogWarn $a[1] }
                    'log_error'     { LogError $a[1] }
                    'write_warn'    { Write-AitWarn $a[1] $a[2] }
                    'write_action'  { Write-AitAction $a[1] $a[2] $a[3] }
                    'write_error'   { Write-AitError $a[1] $a[2] $a[3] }
                    'write_summary' { Write-Summary $a[1] $a[2] $a[3] }
                    'error_reason'  { $script:FixtureObs.reason = Get-AitErrorReason -Output $a[1] -ExitCode ([int]$a[2]) }
                    'managed_abort' { Invoke-ManagedAbort }
                    'deploy_tracker_init' { Initialize-DeployTracker }
                    'deploy_managed_file' {
                        $script:FixtureObs.result = Deploy-ManagedFile -Content $a[1] -DestPath $a[2] -ToolName $a[3] -ItemName $a[4]
                    }
                    'deploy_tracker_record' { Record-DeployOutcome -Outcome $a[1] -ToolName $a[2] -ItemName $a[3] }
                    'deploy_tracker_summary' { Write-DeployTrackerSummary -ToolName $a[1] }
                    default { throw "fixture error: unknown helper '$($a[0])'" }
                }
            }
            'relay' {
                $child = Join-Path $casedir ($a[2] + ".ps1")
                $warn = ($a.Count -gt 3 -and $a[3] -ceq 'abort-warn')
                if ($warn) { $script:FixtureObs.relayRc = Invoke-ChildRelayed $a[0] $child @{} $a[1] -AbortAsWarning }
                else { $script:FixtureObs.relayRc = Invoke-ChildRelayed $a[0] $child @{} $a[1] }
                $script:FixtureObs.childRc = $script:AitLibChildRc
            }
            'relay-native' {
                $child = Join-Path $casedir ($a[2] + ".ps1")
                $pw = (Get-Process -Id $PID).Path
                $na = @{ Label = $a[0]; FilePath = $pw; ArgumentList = @("-NoProfile", "-NonInteractive", "-File", $child); SummaryTool = $a[1] }
                if ($a.Count -gt 3 -and $a[3] -ceq 'abort-warn') { $na.AbortAsWarning = $true }
                $script:FixtureObs.relayRc = Invoke-NativeRelayed @na
                $script:FixtureObs.childRc = $script:AitLibChildRc
            }
            'render' {
                $sf = $env:AITOOLS_SUMMARY_FILE
                $script:FixtureObs.summary = if ($sf -and (Test-Path -LiteralPath $sf)) { [IO.File]::ReadAllText($sf, [Text.UTF8Encoding]::new($false)) } else { $null }
                $recs = @(Show-Summary -Keep 6>&1)
                $script:FixtureObs.rendered = $true
                $script:FixtureObs.panel = @($recs | ForEach-Object {
                    $md = $_.MessageData
                    $text = if ($md -is [System.Management.Automation.HostInformationMessage]) { $md.Message } else { [string]$md }
                    $col = if ($md -is [System.Management.Automation.HostInformationMessage] -and $null -ne $md.ForegroundColor) { [string]$md.ForegroundColor } else { "" }
                    [ordered]@{ text = $text; color = $col }
                })
            }
            default { throw "fixture error: unknown step '$($step.kw)'" }
        }
    }
}

# Save-FixtureObs PATH -- write $script:FixtureObs and the counts as JSON
function Save-FixtureObs([string]$Path) {
    $script:FixtureObs.warnings = $script:warnings
    $script:FixtureObs.errors = $script:errors
    [IO.File]::WriteAllText($Path, ($script:FixtureObs | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
}

# ---------------------------------------------------------------------------
# The runner side
# ---------------------------------------------------------------------------
function ConvertTo-FixturePsLiteral([string]$s) { return "'" + $s.Replace("'", "''") + "'" }

function New-FixtureScript([string]$Path, [string]$Lib, [string]$Name, [string]$StepsFile, [string]$Tail) {
    $text = @"
`$ErrorActionPreference = "Continue"
. $(ConvertTo-FixturePsLiteral $Lib)
. $(ConvertTo-FixturePsLiteral $script:FixtureRunnerPath)
Initialize-Logging $(ConvertTo-FixturePsLiteral $Name)
`$script:FixtureObs = [ordered]@{ reason = `$null; result = `$null; relayRc = `$null; childRc = `$null; rendered = `$false; summary = `$null; panel = @() }
$Tail
"@
    [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($false))
}

function Invoke-LoggingFixtureCase {
    param([string]$Id, [object[]]$Lines, [string]$Lib, [string]$TmpRoot)
    $why = [System.Collections.Generic.List[string]]::new()
    $lines = @($Lines | Where-Object { $_.Only -ne 'sh' })
    # A bash-only case is not this harness's (not counted)
    $langLine = @($lines | Where-Object { $_.Kw -ceq 'lang' }) | Select-Object -Last 1
    if ($langLine -and $langLine.Rest -ceq 'sh') { return @{ Status = 'NA'; Why = @() } }
    $lang = 'both'; $summaryUnset = $false; $envs = [ordered]@{}
    $steps = [System.Collections.Generic.List[object]]::new()
    $children = [ordered]@{}
    $expects = [System.Collections.Generic.List[object]]::new()
    $panel = [System.Collections.Generic.List[object]]::new()
    foreach ($l in $lines) {
        switch -CaseSensitive ($l.Kw) {
            'lang' { $lang = $l.Rest }
            'external' { return @{ Status = 'SKIP'; Why = @("external: covered by $($l.Rest) and its .ps1 twin") } }
            'needs' { return @{ Status = 'SKIP'; Why = @("needs $($l.Rest): this harness has no terminal") } }
            'summary' { if ($l.Rest -ceq 'unset') { $summaryUnset = $true } }
            'env' { $kv = (ConvertFrom-FixtureEscape $l.Rest) -split '=', 2; $envs[$kv[0]] = $kv[1] }
            'record' { $steps.Add(@{ kw = 'record'; args = @(ConvertFrom-FixtureEscape $l.Rest) }) }
            { $_ -in 'file', 'call', 'relay', 'relay-native' } { $steps.Add(@{ kw = $l.Kw; args = @(Split-FixtureRest $l.Rest) }) }
            'render' { $steps.Add(@{ kw = 'render'; args = @() }) }
            'child' {
                $m = [regex]::Match($l.Rest, '^(\S+) (\S+)(?: (.*))?$')
                if (-not $m.Success) { throw "fixture error: bad child line '$($l.Rest)'" }
                $cn = $m.Groups[1].Value; $act = $m.Groups[2].Value; $cr = $m.Groups[3].Value
                if (-not $children.Contains($cn)) { $children[$cn] = @{ steps = [System.Collections.Generic.List[object]]::new(); exit = 0 } }
                switch -CaseSensitive ($act) {
                    'call' { $children[$cn].steps.Add(@{ kw = 'call'; args = @(Split-FixtureRest $cr) }) }
                    'exit' { $children[$cn].exit = [int]$cr }
                    { $_ -in 'stdout', 'throw', 'write-error' } { $children[$cn].steps.Add(@{ kw = $act; args = @(ConvertFrom-FixtureEscape $cr) }) }
                    'stderr' { return @{ Status = 'SKIP'; Why = @("child action stderr is for bash children only") } }
                    default { throw "fixture error: unknown child action '$act'" }
                }
            }
            'expect' { $expects.Add($l.Rest) }
            'panel' { $panel.Add($l.Rest) }
            { $_ -in 'plan', 'title', 'spec', 'note' } { }
            default { throw "fixture error: unknown keyword '$($l.Kw)' in case $Id" }
        }
    }
    if ($lang -eq 'sh') { return @{ Status = 'NA'; Why = @() } }

    $casedir = Join-Path $TmpRoot $Id
    New-Item -ItemType Directory -Path (Join-Path $casedir "logs") -Force | Out-Null
    $summary = Join-Path $casedir "summary.txt"
    if (-not $summaryUnset) { [IO.File]::WriteAllText($summary, "") }
    foreach ($cn in $children.Keys) {
        $cs = Join-Path $casedir "$cn.steps.json"
        [IO.File]::WriteAllText($cs, (@{ casedir = $casedir; steps = @($children[$cn].steps) } | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
        New-FixtureScript (Join-Path $casedir "$cn.ps1") $Lib $cn $cs `
            "Invoke-FixtureSteps $(ConvertTo-FixturePsLiteral $cs)`nexit $($children[$cn].exit)"
    }
    $stepsFile = Join-Path $casedir "case.steps.json"
    $obsFile = Join-Path $casedir "obs.json"
    [IO.File]::WriteAllText($stepsFile, (@{ casedir = $casedir; steps = @($steps) } | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    $caseScript = Join-Path $casedir "case.ps1"
    $stop = @($expects | Where-Object { $_ -like 'case-exit *' }).Count -gt 0
    $tail = ""
    if ($stop) { $tail += "`$ErrorActionPreference = `"Stop`"`n" }
    $tail += "try { Invoke-FixtureSteps $(ConvertTo-FixturePsLiteral $stepsFile) } finally { Save-FixtureObs $(ConvertTo-FixturePsLiteral $obsFile) }`nexit 0"
    New-FixtureScript $caseScript $Lib "test-logging" $stepsFile $tail

    # Run the case: a fresh pwsh, stdin closed, its console output to out.txt
    $psi = [System.Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($x in @("-NoProfile", "-NonInteractive", "-File", $caseScript)) { $psi.ArgumentList.Add($x) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $psi.WorkingDirectory = $casedir
    foreach ($n in @("AITOOLS_SUMMARY_FILE", "AITOOLS_FORCE", "AITLIB_RELAYED", "AITOOLS_PRESERVE_SUMMARY",
            "AITOOLS_SUPPRESS_SUMMARY_DISPLAY", "AITOOLS_DRY_RUN", "AITOOLS_RUN_ID", "AITOOLS_ENVIRONMENT")) {
        [void]$psi.Environment.Remove($n)
    }
    $psi.Environment["AITOOLS_LOG_DIR"] = (Join-Path $casedir "logs")
    if (-not $summaryUnset) { $psi.Environment["AITOOLS_SUMMARY_FILE"] = $summary }
    foreach ($k in $envs.Keys) { $psi.Environment[$k] = $envs[$k] }
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    $err = $errTask.Result
    $caseRc = $p.ExitCode
    $p.Dispose()
    [IO.File]::WriteAllText((Join-Path $casedir "out.txt"), "$out`n--- stderr ---`n$err", [Text.UTF8Encoding]::new($false))

    $obs = if (Test-Path -LiteralPath $obsFile) { [IO.File]::ReadAllText($obsFile, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json } else { $null }
    if ($null -eq $obs) {
        $why.Add("no observations (case exit $caseRc); output: $($out.Trim()) $($err.Trim())")
        return @{ Status = 'FAIL'; Why = $why }
    }
    $sumText = if ($obs.rendered) { [string]$obs.summary } elseif (Test-Path -LiteralPath $summary) { [IO.File]::ReadAllText($summary, [Text.UTF8Encoding]::new($false)) } else { "" }
    if ($null -eq $sumText) { $sumText = "" }
    $sumRecs = @(if ($sumText) { $sumText.TrimEnd("`n") -split "`n" })
    $logPath = Join-Path $casedir "logs" "deploy.log"
    $log = @(if (Test-Path -LiteralPath $logPath) { [IO.File]::ReadAllLines($logPath, [Text.UTF8Encoding]::new($false)) })
    $logNoTs = @($log | ForEach-Object { $_ -replace '^\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\] ', '' })

    $expRecords = [System.Collections.Generic.List[string]]::new()
    $hasRecordExp = $false
    foreach ($e in $expects) {
        $sp = $e.IndexOf(' ')
        $k = if ($sp -lt 0) { $e } else { $e.Substring(0, $sp) }
        $v = if ($sp -lt 0) { '' } else { ConvertFrom-FixtureEscape $e.Substring($sp + 1) }
        switch -CaseSensitive ($k) {
            'record' { $hasRecordExp = $true; $expRecords.Add($v) }
            'no-records' { if ($sumRecs.Count -ne 0) { $why.Add("expected no records, got: $($sumRecs -join ' // ')") } }
            'record-count' {
                $n, $pre = $v -split ' ', 2
                $got = @($sumRecs | Where-Object { $_.StartsWith($pre, [StringComparison]::Ordinal) }).Count
                if ($got -ne [int]$n) { $why.Add("record-count '$pre': expected $n, got $got ($($sumRecs -join ' // '))") }
            }
            'count' {
                $what, $n = $v -split ' ', 2
                $got = if ($what -ceq 'warnings') { $obs.warnings } else { $obs.errors }
                if ([int]$got -ne [int]$n) { $why.Add("count $what`: expected $n, got $got") }
            }
            'log' { if (-not ($logNoTs -ccontains $v)) { $why.Add("deploy.log has no line '$v'") } }
            'logsub' {
                $lvl, $txt = $v -split ' ', 2
                $hit = @($log | Where-Object {
                    $mm = [regex]::Match($_, '^\[[^\]]+\] \[[^\]]+\] \[([a-z]+)\] (.*)$')
                    $mm.Success -and $mm.Groups[1].Value -ceq $lvl -and $mm.Groups[2].Value.Contains($txt)
                }).Count
                if ($hit -eq 0) { $why.Add("deploy.log has no [$lvl] line containing '$txt'") }
            }
            'reason' { if ([string]$obs.reason -cne $v) { $why.Add("reason: expected '$v', got '$($obs.reason)'") } }
            'result' { if ([string]$obs.result -cne $v) { $why.Add("result: expected '$v', got '$($obs.result)'") } }
            'relay-rc' { if ("$($obs.relayRc)" -cne $v) { $why.Add("relay-rc: expected $v, got '$($obs.relayRc)'") } }
            'child-rc' { if ("$($obs.childRc)" -cne $v) { $why.Add("child-rc: expected $v, got '$($obs.childRc)'") } }
            'case-exit' { if ($caseRc -ne [int]$v) { $why.Add("case-exit: expected $v, got $caseRc") } }
            'panel-none' { if (@($obs.panel).Count -ne 0) { $why.Add("expected no panel, got $(@($obs.panel).Count) lines") } }
            default { throw "fixture error: unknown expectation '$e'" }
        }
    }
    if ($hasRecordExp) {
        $want = $expRecords -join "`n"
        $got = $sumRecs -join "`n"
        if ($got -cne $want) { $why.Add("records differ:`n        expected: $($expRecords -join "`n                  ")`n        got:      $($sumRecs -join "`n                  ")") }
    }
    if ($panel.Count -gt 0) {
        $gotPanel = @($obs.panel)
        $wantPanel = @($panel | ForEach-Object {
            if ($_ -ceq 'blank') { @{ text = ''; color = $null } }
            elseif ($_ -ceq 'rule') { @{ text = ('-' * 60); color = $null } }
            else {
                $c, $t = $_ -split ' ', 2
                $cmap = @{ green = 'Green'; yellow = 'Yellow'; red = 'Red'; magenta = 'Magenta' }
                @{ text = (ConvertFrom-FixtureEscape $t); color = $cmap[$c] }
            }
        })
        $n = [Math]::Max($gotPanel.Count, $wantPanel.Count)
        for ($i = 0; $i -lt $n; $i++) {
            $g = if ($i -lt $gotPanel.Count) { $gotPanel[$i] } else { $null }
            $w = if ($i -lt $wantPanel.Count) { $wantPanel[$i] } else { $null }
            $ok = ($null -ne $g -and $null -ne $w -and [string]$g.text -ceq [string]$w.text -and ($null -eq $w.color -or [string]$g.color -ceq $w.color))
            if (-not $ok) {
                $gs = if ($g) { "[$($g.color)] '$($g.text)'" } else { "(none)" }
                $ws = if ($w) { "[$($w.color)] '$($w.text)'" } else { "(none)" }
                $why.Add("panel line $($i + 1): expected $ws, got $gs")
            }
        }
    }
    if ($why.Count -gt 0) { return @{ Status = 'FAIL'; Why = $why } }
    return @{ Status = 'PASS'; Why = @() }
}

function Invoke-LoggingFixture {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Lib, [Parameter(Mandatory)][string]$TmpRoot, [string[]]$Ids = @())
    $cases = Read-LoggingFixture $Path
    $res = @{ Pass = 0; Fail = 0; Skip = 0; Results = [ordered]@{} }
    foreach ($id in $cases.Keys) {
        if ($Ids.Count -gt 0 -and $Ids -notcontains $id) { continue }
        try {
            $r = Invoke-LoggingFixtureCase -Id $id -Lines $cases[$id] -Lib $Lib -TmpRoot $TmpRoot
        } catch {
            $r = @{ Status = 'FAIL'; Why = @("runner error: $($_.Exception.Message)") }
        }
        $res.Results[$id] = $r
        # Printed with Write-Host: the function's output is its result only
        switch ($r.Status) {
            'PASS' { $res.Pass++; Write-Host "PASS fixture $id" }
            'SKIP' { $res.Skip++; Write-Host "SKIP fixture $id ($($r.Why -join '; '))" }
            'FAIL' { $res.Fail++; Write-Host "FAIL fixture $id"; foreach ($w in $r.Why) { Write-Host "      | $w" } }
            default { }
        }
    }
    return $res
}
