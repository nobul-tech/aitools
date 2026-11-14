# test-console-mode-guard.ps1 -- tests for the console input mode helper in
# scripts/aitools-lib.ps1 (type AitConsoleInput, Initialize-AitConsoleInput,
# Read-ConsoleChoice, Save-/Restore-ConsoleInputMode) and its use around Step 2
# (build-deploy via Git Bash) of the PowerShell entry point, scripts/aitools.ps1.
#
# Safe to re-run: every case uses its own temp dir (HOME, USERPROFILE and
# AITOOLS_LOG_DIR point into it), removed on exit.
# Platform: Windows, macOS, Linux (pwsh 7). The P/Invoke type cases need Windows
# and are reported as SKIP elsewhere; the console case needs this suite's stdin to
# be a console and is SKIP otherwise (CI, Claude Code). Exit 1 if any case fails.
# What it checks: with a pipe for stdin the helpers are a no-op, never throw and
# compile nothing; Read-ConsoleChoice returns the piped line, or "" and a warn at
# EOF; the C# type has Get/Set/EnterCooked; Read-ConsoleChoice enters cooked mode
# and restores the mode in a finally; aitools.ps1 has no copy of the helpers and
# Step 2 gives build-deploy a pipe for stdin inside the save/restore.
# AI-merge spinner (Start-/Stop-AiSpinner): in-process (no Start-Job), stops a
# running spinner first, no-op with redirected stdout, Stop disposes and clears
# like bash _stop_spinner; Invoke-AiMerge stops it in a finally; Invoke-AI
# telemetry goes to the log file only (Write-AiLog), never the console. The
# console case (frames drawn, runspace back to baseline) needs stdin and stdout
# to be a console and is SKIP otherwise.
# The real-console behaviour (a raw mode left by a child; the spinner on screen)
# is evidenced by the harness in the PR (sessions M3-Fixes-B, M3b-Finish-R,
# M3b-Finish-C1, M3b-Finish-C2).
#
# Usage: pwsh -NoProfile -File tests/aitools-entry/test-console-mode-guard.ps1 [-Help]

param([switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 25
    exit 0
}

$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
$lib = Join-Path $root "scripts" "aitools-lib.ps1"
$entry = Join-Path $root "scripts" "aitools.ps1"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-conguard-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
$pwshExe = (Get-Process -Id $PID).Path

$script:pass = 0
$script:fail = 0
$script:skip = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ }
    else { Write-Output "FAIL $Name$(if ($Detail) { " -- $Detail" })"; $script:fail++ }
}
function Skip([string]$Name, [string]$Why) { Write-Output "SKIP $Name ($Why)"; $script:skip++ }

function Find-Function($Ast, [string]$Name) {
    return $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
}

# The child: dot-sources the lib under the case's HOME / log dir, then runs one mode.
$childText = @'
param([string]$Lib, [string]$Mode, [string]$ResultFile = "")
$ErrorActionPreference = "Stop"
. $Lib
Initialize-Logging "console-guard-test"
"REDIRECTED $([Console]::IsInputRedirected)"
switch ($Mode) {
    "no-console" {
        $s = Save-ConsoleInputMode
        "SAVE mode=$($s.Mode) reason=$($s.Reason)"
        "RESTORE $(Restore-ConsoleInputMode $s 'test-build')"
        "RESTORE-NULL $(Restore-ConsoleInputMode $null 'test-null')"
        "INIT $(Initialize-AitConsoleInput)"
        "LOADED-AFTER-SAVE $([bool]('AitConsoleInput' -as [type]))"
        $r = Read-ConsoleChoice "overwrite"
        "READ [$r]"
        "EOFFLAG $script:ReadConsoleEof"
        "LOADED-AFTER-READ $([bool]('AitConsoleInput' -as [type]))"
        if ($IsWindows) {
            # Compile the type from the lib's own source (no console needed to compile)
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Lib, [ref]$null, [ref]$null)
            $init = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq "Initialize-AitConsoleInput" }, $true)
            $src = $init.Find({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -match 'class AitConsoleInput' }, $true)
            Add-Type -TypeDefinition $src.Value -ErrorAction Stop
            $methods = @([AitConsoleInput].GetMethods() | ForEach-Object { $_.Name }) | Sort-Object -Unique
            "METHODS $($methods -join ',')"
            $ec = [AitConsoleInput]::EnterCooked()
            "TYPE get=$([AitConsoleInput]::Get()) set=$([AitConsoleInput]::Set(503)) setneg=$([AitConsoleInput]::Set(-1)) cooked=$ec lasterror=$([AitConsoleInput]::LastError)"
        }
    }
    "piped" {
        $script:ReadConsoleEof = $true   # a stale flag must be cleared by the next read
        $r = Read-ConsoleChoice "overwrite"
        "READ [$r]"
        "EOFFLAG $script:ReadConsoleEof"
        "LOADED-AFTER-READ $([bool]('AitConsoleInput' -as [type]))"
    }
    "console" {
        # Stdin is the console of the shell that runs this suite: read and put back
        # its mode only, no key is read.
        "INIT $(Initialize-AitConsoleInput)"
        $before = [AitConsoleInput]::Get()
        $prev = [AitConsoleInput]::EnterCooked()
        $mid = [AitConsoleInput]::Get()
        $rc = [AitConsoleInput]::Set($prev)
        $after = [AitConsoleInput]::Get()
        "CONSOLE before=$before prev=$prev mid=$mid lasterror=$([AitConsoleInput]::LastError) rc=$rc after=$after"
    }
    "spinner-redirected" {
        # Stdout is a pipe here: the spinner must create nothing and write nothing
        Stop-AiSpinner
        "STOP-WITHOUT-START done"
        $before = @(Get-Runspace).Count
        Start-AiSpinner "spinner-probe-text"
        "SPIN registered=$([bool]$script:_aiSpinner) before=$before during=$(@(Get-Runspace).Count)"
        Start-Sleep -Milliseconds 500
        Stop-AiSpinner
        "SPIN-AFTER registered=$([bool]$script:_aiSpinner) after=$(@(Get-Runspace).Count)"
    }
    "telemetry" {
        # Fake AI CLI: a session function named claude (Get-Command finds it first)
        function global:claude {
            $null = @($input)
            $global:LASTEXITCODE = 0
            switch ($env:CONGUARD_FAKE_AI) {
                "empty" { "" }
                "throw" { throw "fake CLI failure" }
                default { "fake merge output" }
            }
        }
        function RejectAll { param($o) $script:AIRejectReason = "test reject"; return $false }
        Log "CONTROL console line"
        $env:CONGUARD_FAKE_AI = "ok"
        $a = "prompt one" | Invoke-AI -Speed "balanced" -Permissions "none"
        "AI-OK [$a]"
        $b = "prompt two" | Invoke-AI -Speed "balanced" -Permissions "none" -ValidateFn "RejectAll" -MaxRetries 1
        "AI-REJECT [$b] reason=$($script:AIRejectReason)"
        $env:CONGUARD_FAKE_AI = "empty"
        $c = "prompt three" | Invoke-AI -Speed "balanced" -Permissions "none"
        "AI-EMPTY [$c] reason=$($script:AIRejectReason)"
        $env:CONGUARD_FAKE_AI = "throw"
        $d = "prompt four" | Invoke-AI -Speed "balanced" -Permissions "none"
        "AI-THROW [$d] reason=$($script:AIRejectReason)"
        # (Remove-Item function:global:claude leaves the function in place; this form removes it)
        Remove-Item -Path Function:\claude
        $emptyBin = Join-Path $HOME "empty-bin"
        New-Item -ItemType Directory -Force -Path $emptyBin | Out-Null
        $env:PATH = $emptyBin
        $e = "prompt five" | Invoke-AI -Speed "balanced" -Permissions "none"
        "AI-NOCLI [$e] reason=$($script:AIRejectReason)"
    }
    "spinner-console" {
        # Stdin and stdout are this suite's console: results go to $ResultFile
        # (not "R": that is the built-in alias of Invoke-History, and aliases win)
        function Add-Result([string]$s) { Add-Content -LiteralPath $ResultFile -Value $s }
        Add-Result "OUT-REDIRECTED $([Console]::IsOutputRedirected)"
        [Console]::WriteLine("")
        $msg = "spinner console probe"
        $before = @(Get-Runspace).Count
        $sw = [Diagnostics.Stopwatch]::StartNew(); Start-AiSpinner $msg; $sw.Stop(); $startMs = $sw.Elapsed.TotalMilliseconds
        Start-Sleep -Milliseconds 450
        $col = [Console]::CursorLeft
        $during = @(Get-Runspace).Count
        $sw = [Diagnostics.Stopwatch]::StartNew(); Stop-AiSpinner; $sw.Stop(); $stopMs = $sw.Elapsed.TotalMilliseconds
        $colAfter = [Console]::CursorLeft
        $after = @(Get-Runspace).Count
        [Console]::WriteLine("")
        Add-Result ("CONSPIN before={0} during={1} after={2} col={3} want={4} colafter={5} registered={6} startms={7:N1} stopms={8:N1}" -f $before, $during, $after, $col, (4 + $msg.Length), $colAfter, [bool]$script:_aiSpinner, $startMs, $stopMs)
        Add-Result "END errors=$errors warnings=$warnings"
    }
}
"END errors=$errors warnings=$warnings"
'@

# Run-Child CASE MODE [STDIN]: run the child in its own HOME / USERPROFILE / log dir.
# STDIN: "none" = an empty pipe (EOF), "console" = inherit this suite's stdin,
# "tty" = inherit this suite's stdin AND stdout (Start-Process -NoNewWindow; the
# child writes its results to a file, returned as Out), anything else = that text
# piped in.
function Run-Child([string]$Case, [string]$Mode, [string]$Stdin = "none") {
    $caseDir = Join-Path $tmpRoot $Case
    New-Item -ItemType Directory -Path (Join-Path $caseDir "home") -Force | Out-Null
    $child = Join-Path $caseDir "child.ps1"
    Set-Content -LiteralPath $child -Value $childText
    $logDir = Join-Path $caseDir "logs"
    $old = @{ HOME = $env:HOME; USERPROFILE = $env:USERPROFILE; AITOOLS_LOG_DIR = $env:AITOOLS_LOG_DIR }
    $env:HOME = Join-Path $caseDir "home"; $env:USERPROFILE = $env:HOME; $env:AITOOLS_LOG_DIR = $logDir
    try {
        if ($Stdin -eq "none") {
            $out = $null | & $pwshExe -NoProfile -File $child -Lib $lib -Mode $Mode 2>&1 | Out-String
        } elseif ($Stdin -eq "console") {
            $out = & $pwshExe -NoProfile -File $child -Lib $lib -Mode $Mode 2>&1 | Out-String
        } elseif ($Stdin -eq "tty") {
            $resFile = Join-Path $caseDir "result.txt"
            $p = Start-Process -FilePath $pwshExe -NoNewWindow -Wait -PassThru -ArgumentList @(
                "-NoProfile", "-File", "`"$child`"", "-Lib", "`"$lib`"", "-Mode", $Mode, "-ResultFile", "`"$resFile`"")
            $global:LASTEXITCODE = $p.ExitCode
            $out = if (Test-Path $resFile) { Get-Content -LiteralPath $resFile -Raw } else { "" }
        } else {
            $out = $Stdin | & $pwshExe -NoProfile -File $child -Lib $lib -Mode $Mode 2>&1 | Out-String
        }
        $rc = $LASTEXITCODE
    } finally {
        $env:HOME = $old.HOME; $env:USERPROFILE = $old.USERPROFILE; $env:AITOOLS_LOG_DIR = $old.AITOOLS_LOG_DIR
    }
    $log = ""
    $logFile = Join-Path $logDir "deploy.log"
    if (Test-Path $logFile) { $log = Get-Content -LiteralPath $logFile -Raw }
    return [pscustomobject]@{ Out = $out; Rc = $rc; Log = $log }
}

try {
    # -----------------------------------------------------------------------
    # Where the helpers live: the lib, once; no copy in aitools.ps1
    # -----------------------------------------------------------------------
    $parseErrors = $null
    $libAst = [System.Management.Automation.Language.Parser]::ParseFile($lib, [ref]$null, [ref]$parseErrors)
    Check "lib: aitools-lib.ps1 parses" ($parseErrors.Count -eq 0)
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($entry, [ref]$null, [ref]$parseErrors)
    Check "entry: aitools.ps1 parses" ($parseErrors.Count -eq 0)
    foreach ($name in @("Initialize-AitConsoleInput", "Read-ConsoleChoice", "Save-ConsoleInputMode", "Restore-ConsoleInputMode")) {
        $defs = @($libAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))
        Check "lib: defines $name once" ($defs.Count -eq 1) "found $($defs.Count)"
    }
    $entryCopies = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $n.Name -in @("Save-ConsoleInputMode", "Restore-ConsoleInputMode", "Read-ConsoleChoice", "Initialize-AitConsoleInput") }, $true))
    Check "entry: defines none of the console helpers (they come from the lib)" ($entryCopies.Count -eq 0) (($entryCopies | ForEach-Object { $_.Name }) -join ", ")
    $entryText = [IO.File]::ReadAllText($entry)
    Check "entry: compiles no console type of its own (no Add-Type of AitConsoleModeGuard / AitConsoleInput)" (-not ($entryText -match 'class\s+AitConsole')) ""
    $libText = [IO.File]::ReadAllText($lib)
    $typeDefs = [regex]::Matches($libText, 'public static class AitConsole\w*').Count
    Check "lib: one console type (AitConsoleInput) is defined" (($typeDefs -eq 1) -and ($libText -match 'public static class AitConsoleInput\b')) "found $typeDefs"

    # -----------------------------------------------------------------------
    # The C# source: Get / Set / EnterCooked, cooked = (m | 0x7) & ~0x200
    # -----------------------------------------------------------------------
    $initFn = Find-Function $libAst "Initialize-AitConsoleInput"
    $csharp = ""
    if ($initFn) {
        $srcAst = $initFn.Find({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -match 'class AitConsoleInput' }, $true)
        if ($srcAst) { $csharp = $srcAst.Value }
    }
    Check "type: Initialize-AitConsoleInput carries the AitConsoleInput source" ([bool]$csharp)
    foreach ($m in @('public static long Get\(\)', 'public static int Set\(long m\)', 'public static long EnterCooked\(\)')) {
        Check "type: source declares $($m -replace '\\', '')" ($csharp -match $m)
    }
    Check "type: EnterCooked sets PROCESSED | LINE | ECHO and clears VIRTUAL_TERMINAL_INPUT" `
        ($csharp -match 'SetConsoleMode\(h, \(m \| ProcessedInput \| LineInput \| EchoInput\) & ~VirtualTerminalInput\)')
    Check "type: Initialize-AitConsoleInput compiles nothing off Windows or with redirected stdin" `
        (($initFn.Extent.Text -match '-not \$IsWindows\) \{ return \$false \}') -and ($initFn.Extent.Text -match '\[Console\]::IsInputRedirected\) \{ return \$false \}'))

    # -----------------------------------------------------------------------
    # Structure of Read-ConsoleChoice: EnterCooked before the try, ReadLine in the
    # try, the saved mode put back with Set in the finally
    # -----------------------------------------------------------------------
    $readFn = Find-Function $libAst "Read-ConsoleChoice"
    $readTry = $null
    if ($readFn) { $readTry = $readFn.Find({ param($n) $n -is [System.Management.Automation.Language.TryStatementAst] }, $true) }
    Check "read: Read-ConsoleChoice has a try statement" ($null -ne $readTry)
    if ($readTry) {
        $isMember = { param($n, $member) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Static -and
            $n.Expression.Extent.Text -match '^\[(AitConsoleInput|Console)\]$' -and $n.Member.Extent.Text -eq $member }
        $readLine = $readTry.Body.Find({ param($n) & $isMember $n "ReadLine" }, $true)
        Check "read: [Console]::ReadLine() runs inside the try" ($null -ne $readLine)
        $setInFinally = $null
        if ($readTry.Finally) { $setInFinally = $readTry.Finally.Find({ param($n) (& $isMember $n "Set") -and $n.Expression.Extent.Text -eq '[AitConsoleInput]' }, $true) }
        Check "read: the finally block puts the saved mode back ([AitConsoleInput]::Set)" ($null -ne $setInFinally)
        $enter = $readFn.Find({ param($n) (& $isMember $n "EnterCooked") -and $n.Expression.Extent.Text -eq '[AitConsoleInput]' }, $true)
        Check "read: [AitConsoleInput]::EnterCooked() is called" ($null -ne $enter)
        Check "read: EnterCooked runs before the try" (($null -ne $enter) -and ($enter.Extent.EndOffset -le $readTry.Extent.StartOffset))
        $savedVar = ""
        if ($setInFinally -and $setInFinally.Arguments.Count -eq 1) { $savedVar = $setInFinally.Arguments[0].Extent.Text }
        $enterAssign = $null
        if ($enter) { $enterAssign = $enter.Parent; while ($enterAssign -and -not ($enterAssign -is [System.Management.Automation.Language.AssignmentStatementAst])) { $enterAssign = $enterAssign.Parent } }
        Check "read: Set in the finally restores the mode EnterCooked returned" (($savedVar -ne "") -and ($null -ne $enterAssign) -and ($enterAssign.Left.Extent.Text -eq $savedVar)) "set arg '$savedVar'"
    }

    # -----------------------------------------------------------------------
    # Helpers with a pipe for stdin (no console): no-op, no throw, nothing compiled
    # -----------------------------------------------------------------------
    $r = Run-Child "no-console" "no-console" "none"
    $out = $r.Out
    Check "no console: child ran without error (exit 0)" ($r.Rc -eq 0) $out.Trim()
    Check "no console: stdin of the child is a pipe" ($out -match 'REDIRECTED True') $out.Trim()
    $expectReason = if ($IsWindows) { "not a console" } else { "not Windows" }
    Check "no console: Save-ConsoleInputMode returns mode -1, '$expectReason'" ($out -match "SAVE mode=-1 reason=$expectReason") $out.Trim()
    Check "no console: Restore-ConsoleInputMode returns '$expectReason' (nothing to restore)" ($out -match "RESTORE $expectReason") $out.Trim()
    Check "no console: Restore-ConsoleInputMode with nothing saved returns 'not saved'" ($out -match 'RESTORE-NULL not saved') $out.Trim()
    Check "no console: Initialize-AitConsoleInput returns False" ($out -match 'INIT False') $out.Trim()
    Check "no console: deploy.log has the detail line" ($r.Log -match "\[detail\] console input mode around test-build: not guarded \($expectReason\)") $r.Log
    Check "EOF: Read-ConsoleChoice returns an empty string" ($out -match 'READ \[\]') $out.Trim()
    Check "EOF: the warn line is logged" ($r.Log -match '\[warn\] No input at prompt \(EOF\) -- defaulting to overwrite') $r.Log
    Check "EOF: one warning counted, no error" ($out -match 'END errors=0 warnings=1') $out.Trim()
    Check "EOF: Read-ConsoleChoice sets `$script:ReadConsoleEof (Read-MenuChoice contract)" ($out -match 'EOFFLAG True') $out.Trim()
    Check "no console: AitConsoleInput is not loaded by Save/Restore or the read" (($out -match 'LOADED-AFTER-SAVE False') -and ($out -match 'LOADED-AFTER-READ False')) $out.Trim()
    if ($IsWindows) {
        $want = @("EnterCooked", "Get", "Set")
        $got = if ($out -match 'METHODS (\S+)') { $Matches[1] -split ',' } else { @() }
        $missing = @($want | Where-Object { $_ -notin $got })
        Check "type: AitConsoleInput compiles and exposes Get, Set, EnterCooked" ($missing.Count -eq 0) "methods: $($got -join ',')"
        # Without a console: Get() and EnterCooked() are -1, Set() returns a Win32 error, never an exception
        Check "type: Get() is -1 without a console" ($out -match 'TYPE get=-1 ') $out.Trim()
        Check "type: Set() without a console returns a Win32 error code" ($out -match 'TYPE get=-1 set=[1-9]\d* ') $out.Trim()
        Check "type: Set(-1) is refused (87)" ($out -match 'setneg=87 ') $out.Trim()
        Check "type: EnterCooked() without a console returns -1 and a Win32 error" ($out -match 'cooked=-1 lasterror=[1-9]\d*') $out.Trim()
    } else {
        foreach ($n in @("type: AitConsoleInput compiles and exposes Get, Set, EnterCooked",
                         "type: Get() is -1 without a console",
                         "type: Set() without a console returns a Win32 error code",
                         "type: Set(-1) is refused (87)",
                         "type: EnterCooked() without a console returns -1 and a Win32 error")) {
            Skip $n "kernel32 console API is Windows only"
        }
    }

    # -----------------------------------------------------------------------
    # Read-ConsoleChoice with a piped line
    # -----------------------------------------------------------------------
    $r = Run-Child "piped" "piped" "o"
    Check "piped: child ran without error (exit 0)" ($r.Rc -eq 0) $r.Out.Trim()
    Check "piped: Read-ConsoleChoice returns the piped line" ($r.Out -match 'READ \[o\]') $r.Out.Trim()
    Check "piped: no warning or error counted" ($r.Out -match 'END errors=0 warnings=0') $r.Out.Trim()
    Check "piped: a read that is not EOF clears `$script:ReadConsoleEof" ($r.Out -match 'EOFFLAG False') $r.Out.Trim()
    Check "piped: AitConsoleInput is not loaded (nothing compiled)" ($r.Out -match 'LOADED-AFTER-READ False') $r.Out.Trim()

    # -----------------------------------------------------------------------
    # With a console for stdin (a developer's terminal): compile + mode round trip
    # -----------------------------------------------------------------------
    $consoleNames = @("console: Initialize-AitConsoleInput compiles the type", "console: EnterCooked turns line input and echo on, VT input off",
                      "console: Set(previous) puts the mode back")
    if (-not $IsWindows) {
        foreach ($n in $consoleNames) { Skip $n "kernel32 console API is Windows only" }
    } elseif ([Console]::IsInputRedirected) {
        foreach ($n in $consoleNames) { Skip $n "this suite's stdin is not a console" }
    } else {
        $r = Run-Child "console" "console" "console"
        Check $consoleNames[0] ($r.Out -match 'INIT True') $r.Out.Trim()
        $ok = $false; $same = $false
        if ($r.Out -match 'CONSOLE before=(\d+) prev=(\d+) mid=(\d+) lasterror=0 rc=0 after=(\d+)') {
            $mid = [long]$Matches[3]
            $ok = (($mid -band 0x7) -eq 0x7) -and (($mid -band 0x200) -eq 0)
            $same = ($Matches[1] -eq $Matches[2]) -and ($Matches[1] -eq $Matches[4])
        }
        Check $consoleNames[1] $ok $r.Out.Trim()
        Check $consoleNames[2] $same $r.Out.Trim()
    }

    # -----------------------------------------------------------------------
    # AI-merge spinner: structure (parity with bash _start_spinner / _stop_spinner)
    # -----------------------------------------------------------------------
    $isCmd = { param($n) $n -is [System.Management.Automation.Language.CommandAst] }
    foreach ($name in @("Start-AiSpinner", "Stop-AiSpinner", "Write-AiLog")) {
        $defs = @($libAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))
        Check "lib: defines $name once" ($defs.Count -eq 1) "found $($defs.Count)"
    }
    $startFn = Find-Function $libAst "Start-AiSpinner"
    $stopFn = Find-Function $libAst "Stop-AiSpinner"
    $startText = if ($startFn) { $startFn.Extent.Text } else { "" }
    $stopText = if ($stopFn) { $stopFn.Extent.Text } else { "" }
    $spinCmds = @()
    foreach ($fn in @($startFn, $stopFn)) { if ($fn) { $spinCmds += @($fn.FindAll($isCmd, $true) | ForEach-Object { $_.GetCommandName() }) } }
    Check "spinner: no job cmdlets (Start-Job draws nothing: no console in a job)" (($spinCmds.Count -gt 0) -and -not ($spinCmds -match '-Job$')) ($spinCmds -join ",")
    $createAt = $startText.IndexOf('[powershell]::Create()')
    Check "spinner: runs in-process ([powershell]::Create() + BeginInvoke())" (($createAt -ge 0) -and $startText.Contains('.BeginInvoke()'))
    $firstCmd = $null
    if ($startFn) { $firstCmd = @($startFn.Body.FindAll($isCmd, $true) | Sort-Object { $_.Extent.StartOffset })[0] }
    Check "spinner: Start-AiSpinner stops a running spinner first (one at a time)" (($null -ne $firstCmd) -and $firstCmd.GetCommandName() -eq "Stop-AiSpinner" -and
        ($createAt -lt 0 -or ($firstCmd.Extent.StartOffset - $startFn.Extent.StartOffset) -lt $createAt)) "first command: $(if ($firstCmd) { $firstCmd.GetCommandName() })"
    $gate = 'if ([Console]::IsOutputRedirected -or -not [Environment]::UserInteractive) { return }'
    $gateAt = $startText.IndexOf($gate)
    Check "spinner: Start-AiSpinner returns before creating anything when stdout is redirected or not interactive" (($gateAt -ge 0) -and ($gateAt -lt $createAt))
    Check "spinner: frame, chars and period match bash (`"``r  <c> <msg>`", /-\|, 200 ms)" (
        $startText.Contains('[Console]::Write("`r  $($chars[$i % 4]) $msg")') -and $startText.Contains('$chars = ''/-\|''') -and $startText.Contains('.Wait(200)'))
    $clear = '[Console]::Write("`r  `e[K")'
    Check "spinner: Stop-AiSpinner clears the line like bash (`"``r  ``e[K`") after EndInvoke" (
        ($stopText.IndexOf('EndInvoke') -ge 0) -and ($stopText.IndexOf($clear) -gt $stopText.IndexOf('EndInvoke')))
    Check "spinner: Stop-AiSpinner with no spinner returns before writing anything" (
        ($stopText.IndexOf('if (-not $s) { return }') -ge 0) -and ($stopText.IndexOf('if (-not $s) { return }') -lt $stopText.IndexOf($clear)))
    $stopTry = $null
    if ($stopFn) { $stopTry = $stopFn.Find({ param($n) $n -is [System.Management.Automation.Language.TryStatementAst] -and $n.Finally }, $true) }
    $finText = if ($stopTry) { $stopTry.Finally.Extent.Text } else { "" }
    Check "spinner: Stop-AiSpinner waits with a 2 s cap, then disposes the runspace, the PowerShell and the event in a finally" (
        $stopText.Contains('WaitOne(2000)') -and ($finText -match 'Runspace\.Dispose\(\)') -and ([regex]::Matches($finText, '\.Dispose\(\)').Count -ge 3)) $finText

    # Invoke-AiMerge: Start-AiSpinner, then Invoke-AI in a try whose finally stops the spinner
    $mergeFn = Find-Function $libAst "Invoke-AiMerge"
    $mergeTry = $null; $stopCalls = @(); $startCall = $null
    if ($mergeFn) {
        $mergeTry = $mergeFn.Find({ param($n) $n -is [System.Management.Automation.Language.TryStatementAst] -and
            $n.Body.Find({ param($m) (& $isCmd $m) -and $m.GetCommandName() -eq "Invoke-AI" }, $true) }, $true)
        $stopCalls = @($mergeFn.FindAll({ param($n) (& $isCmd $n) -and $n.GetCommandName() -eq "Stop-AiSpinner" }, $true))
        $startCall = $mergeFn.Find({ param($n) (& $isCmd $n) -and $n.GetCommandName() -eq "Start-AiSpinner" }, $true)
    }
    $finStop = $null
    if ($mergeTry -and $mergeTry.Finally) { $finStop = $mergeTry.Finally.Find({ param($n) (& $isCmd $n) -and $n.GetCommandName() -eq "Stop-AiSpinner" }, $true) }
    Check "merge: Invoke-AI runs in a try whose finally calls Stop-AiSpinner (Ctrl+C or a throw stops the spinner)" ($null -ne $finStop)
    Check "merge: Start-AiSpinner comes before that try, and Stop-AiSpinner is called only in the finally" (
        ($null -ne $startCall) -and ($null -ne $mergeTry) -and ($startCall.Extent.EndOffset -le $mergeTry.Extent.StartOffset) -and ($stopCalls.Count -eq 1)) "Stop-AiSpinner calls: $($stopCalls.Count)"

    # Invoke-AI: telemetry through Write-AiLog only (parity: _ai_log in aitools-lib.sh)
    $aiFn = Find-Function $libAst "Invoke-AI"
    $aiCmds = @(); $aiStrings = @()
    if ($aiFn) {
        $aiCmds = @($aiFn.FindAll($isCmd, $true) | ForEach-Object { $_.GetCommandName() })
        $aiStrings = @($aiFn.FindAll({ param($n) ($n -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -or
            $n -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and $n.Value -match '^AI invocation' }, $true))
    }
    $consoleLog = @($aiCmds | Where-Object { $_ -in @("Log", "LogOk", "LogWarn", "LogError", "Write-Host") })
    Check "telemetry: Invoke-AI calls no console logger (Log, LogOk, LogWarn, LogError, Write-Host)" (($aiCmds.Count -gt 0) -and $consoleLog.Count -eq 0) ($consoleLog -join ",")
    $notAiLog = @($aiStrings | Where-Object { -not ((& $isCmd $_.Parent) -and $_.Parent.GetCommandName() -eq "Write-AiLog") })
    Check "telemetry: every 'AI invocation' line goes through Write-AiLog" (($aiStrings.Count -ge 7) -and $notAiLog.Count -eq 0) "lines: $($aiStrings.Count), not via Write-AiLog: $($notAiLog.Count)"
    $aiLogFn = Find-Function $libAst "Write-AiLog"
    $aiLogText = if ($aiLogFn) { $aiLogFn.Extent.Text } else { "" }
    Check "telemetry: Write-AiLog writes the log file only and counts nothing" (
        $aiLogText.Contains('AppendAllText') -and $aiLogText.Contains('$logFile') -and -not ($aiLogText -match 'Write-Host|\[Console\]::|errors|warnings'))

    # -----------------------------------------------------------------------
    # Spinner with stdout redirected (CI, a pipe): nothing created, nothing written
    # -----------------------------------------------------------------------
    $r = Run-Child "spinner-redirected" "spinner-redirected" "none"
    Check "spinner, redirected: child ran without error (exit 0)" ($r.Rc -eq 0) $r.Out.Trim()
    Check "spinner, redirected: Stop-AiSpinner without Start is a no-op" ($r.Out -match 'STOP-WITHOUT-START done') $r.Out.Trim()
    $noRs = $false
    if ($r.Out -match 'SPIN registered=(\w+) before=(\d+) during=(\d+)') { $noRs = ($Matches[1] -eq "False") -and ($Matches[2] -eq $Matches[3]) }
    Check "spinner, redirected: Start-AiSpinner creates no runspace" $noRs $r.Out.Trim()
    Check "spinner, redirected: nothing is written (no frame, no clear sequence)" (-not ($r.Out -match 'spinner-probe-text') -and -not $r.Out.Contains("$([char]27)[K")) ($r.Out -replace "$([char]27)", '<ESC>').Trim()
    Check "spinner, redirected: no warning or error counted" ($r.Out -match 'END errors=0 warnings=0') $r.Out.Trim()

    # -----------------------------------------------------------------------
    # Invoke-AI telemetry: deploy.log only, same format, nothing on the console
    # -----------------------------------------------------------------------
    $r = Run-Child "telemetry" "telemetry" "none"
    Check "telemetry: child ran without error (exit 0)" ($r.Rc -eq 0) $r.Out.Trim()
    Check "telemetry: the console is captured (a Log control line is on it)" ($r.Out -match 'CONTROL console line') $r.Out.Trim()
    Check "telemetry: no 'AI invocation' line on the console" (-not ($r.Out -match 'AI invocation')) $r.Out.Trim()
    Check "telemetry: Invoke-AI results unchanged (output; rejected; empty; CLI error; no CLI)" (
        ($r.Out -match 'AI-OK \[fake merge output\]') -and ($r.Out -match 'AI-REJECT \[\] reason=test reject') -and
        ($r.Out -match 'AI-EMPTY \[\] reason=Empty output from claude') -and ($r.Out -match 'AI-THROW \[\] reason=Empty output from claude') -and
        ($r.Out -match 'AI-NOCLI \[\] reason=No AI CLI available \(claude or agent\)')) $r.Out.Trim()
    $ts = '\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\] \[console-guard-test\]'
    $want = @(
        "$ts \[info\] AI invocation: speed=balanced backend=claude attempt=1\r?$",
        "$ts \[info\] AI invocation: speed=balanced backend=claude attempt=1 result=accepted\r?$",
        "$ts \[warn\] AI invocation: speed=balanced backend=claude attempt=1 result=rejected reason=test reject\r?$",
        "$ts \[detail\] ai-rejected: fake merge output\r?$",
        "$ts \[warn\] AI invocation: speed=balanced backend=claude exhausted after 2 attempts\r?$",
        "$ts \[warn\] AI invocation: speed=balanced backend=claude attempt=1 result=empty\r?$",
        "$ts \[warn\] AI invocation error: fake CLI failure\r?$",
        "$ts \[error\] AI invocation: no CLI available \(claude or agent\)\r?$")
    $missing = @($want | Where-Object { -not ([regex]::IsMatch($r.Log, "(?m)^$_")) })
    Check "telemetry: deploy.log has every line in the [ts] [script] [level] format (accepted, rejected, exhausted, empty, error, no CLI)" ($missing.Count -eq 0) ("missing: " + ($missing -join " ; "))
    Check "telemetry: Write-AiLog counts no warning or error (as before)" ($r.Out -match 'END errors=0 warnings=0') $r.Out.Trim()

    # -----------------------------------------------------------------------
    # Spinner on a real console: frames drawn, line cleared, runspace back to baseline
    # -----------------------------------------------------------------------
    $spinNames = @("console spinner: frames are drawn on the console (cursor after `"  <c> <msg>`")",
                   "console spinner: Stop-AiSpinner clears the line (cursor at column 2) and unregisters it",
                   "console spinner: runspace count back to baseline after Stop-AiSpinner",
                   "console spinner: Start and Stop return quickly (Stop under the 2 s cap)")
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        foreach ($n in $spinNames) { Skip $n "this suite's stdin or stdout is not a console" }
    } else {
        $r = Run-Child "spinner-console" "spinner-console" "tty"
        $m = [regex]::Match($r.Out, 'CONSPIN before=(\d+) during=(\d+) after=(\d+) col=(\d+) want=(\d+) colafter=(\d+) registered=(\w+) startms=([\d.,]+) stopms=([\d.,]+)')
        if ($m.Success -and $r.Out -match 'OUT-REDIRECTED False') {
            $g = $m.Groups
            Check $spinNames[0] (($g[4].Value -eq $g[5].Value) -and ([int]$g[2].Value -eq [int]$g[1].Value + 1)) $m.Value
            Check $spinNames[1] (($g[6].Value -eq "2") -and ($g[7].Value -eq "False")) $m.Value
            Check $spinNames[2] ($g[3].Value -eq $g[1].Value) $m.Value
            Check $spinNames[3] (([double]($g[8].Value -replace ',', '') -lt 1000) -and ([double]($g[9].Value -replace ',', '') -lt 1000)) $m.Value
        } else {
            foreach ($n in $spinNames) { Check $n $false "child result: $($r.Out.Trim())" }
        }
    }

    # -----------------------------------------------------------------------
    # aitools.ps1: the lib is dot-sourced before Step 2
    # -----------------------------------------------------------------------
    $builds = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.PipelineAst] -and $n.Extent.Text -match 'build-deploy\.sh' }, $true))
    $dotLib = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.InvocationOperator -eq 'Dot' -and
        $n.CommandElements[0].Extent.Text -eq '$aitoolsLib' }, $true)
    Check "entry: the lib is dot-sourced (. `$aitoolsLib) before Step 2 runs build-deploy" (($null -ne $dotLib) -and ($builds.Count -ge 1) -and ($dotLib.Extent.EndOffset -lt $builds[0].Extent.StartOffset))

    # -----------------------------------------------------------------------
    # Structure of Step 2: pipe stdin + save before the try + restore in finally
    # -----------------------------------------------------------------------
    Check "step 2: build-deploy.sh is run from exactly one pipeline" ($builds.Count -eq 1) "found $($builds.Count)"
    if ($builds.Count -ge 1) {
        $pipe = $builds[0]
        $first = $pipe.PipelineElements[0]
        $nullFirst = ($first -is [System.Management.Automation.Language.CommandExpressionAst]) -and
            ($first.Expression -is [System.Management.Automation.Language.VariableExpressionAst]) -and
            ($first.Expression.VariablePath.UserPath -eq "null")
        Check "step 2: build-deploy gets a pipe for stdin (`$null | & `$bashExe ...)" $nullFirst $pipe.Extent.Text
        $try = $pipe.Parent
        while ($try -and -not ($try -is [System.Management.Automation.Language.TryStatementAst])) { $try = $try.Parent }
        Check "step 2: build-deploy runs inside a try statement" ($null -ne $try)
        if ($try) {
            $restore = $null
            if ($try.Finally) {
                $restore = $try.Finally.Find({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq "Restore-ConsoleInputMode" }, $true)
            }
            Check "step 2: the finally block calls Restore-ConsoleInputMode" ($null -ne $restore)
            $savedVar = ""
            if ($restore -and $restore.CommandElements.Count -ge 2 -and
                $restore.CommandElements[1] -is [System.Management.Automation.Language.VariableExpressionAst]) {
                $savedVar = $restore.CommandElements[1].VariablePath.UserPath
            }
            # The assignment from Save-ConsoleInputMode comes before the try, in the same block
            $block = $try.Parent
            $saveOk = $false
            if ($block -is [System.Management.Automation.Language.NamedBlockAst] -or $block -is [System.Management.Automation.Language.StatementBlockAst]) {
                foreach ($st in $block.Statements) {
                    if ($st -eq $try) { break }
                    if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                        $st.Left.Extent.Text -eq "`$$savedVar" -and $st.Right.Extent.Text -match '^Save-ConsoleInputMode\b') {
                        $saveOk = $true
                    }
                }
            }
            Check "step 2: `$$savedVar = Save-ConsoleInputMode runs before the try" ($savedVar -and $saveOk)
        }
    }
} finally {
    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot }
}

Write-Output "---- $($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
