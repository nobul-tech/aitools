# test-console-mode-guard.ps1 -- tests for the console input mode guard around
# Step 2 (build-deploy via Git Bash) of the PowerShell entry point, scripts/aitools.ps1.
#
# Safe to re-run: every case uses its own temp dir, removed on exit.
# Platform: Windows, macOS, Linux (pwsh 7). The P/Invoke type case needs Windows
# and is reported as SKIP elsewhere. Exit 1 if any case fails.
# What it checks: Save-ConsoleInputMode / Restore-ConsoleInputMode (extracted from
# aitools.ps1 with the PowerShell AST) are a no-op without a console (stdin is a
# pipe here) and never throw; the AitConsoleModeGuard C# type compiles; Step 2 gives
# build-deploy a pipe for stdin and wraps it in the save/restore.
# The real-console behaviour (a raw mode restored) needs a console this suite does
# not have; it is evidenced by the harness in the PR (session M3-Fixes-B).
#
# Usage: pwsh -NoProfile -File tests/aitools-entry/test-console-mode-guard.ps1 [-Help]

param([switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 13
    exit 0
}

$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
$lib = Join-Path $root "scripts" "aitools-lib.ps1"
$entry = Join-Path $root "scripts" "aitools.ps1"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-conguard-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

$script:pass = 0
$script:fail = 0
$script:skip = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ }
    else { Write-Output "FAIL $Name$(if ($Detail) { " -- $Detail" })"; $script:fail++ }
}
function Skip([string]$Name, [string]$Why) { Write-Output "SKIP $Name ($Why)"; $script:skip++ }

$FnAst = [System.Management.Automation.Language.FunctionDefinitionAst]

try {
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($entry, [ref]$null, [ref]$parseErrors)
    Check "entry: aitools.ps1 parses" ($parseErrors.Count -eq 0)
    $saveFn = $ast.Find({ param($n) $n -is $FnAst -and $n.Name -eq "Save-ConsoleInputMode" }, $true)
    $restoreFn = $ast.Find({ param($n) $n -is $FnAst -and $n.Name -eq "Restore-ConsoleInputMode" }, $true)
    Check "entry: defines Save-ConsoleInputMode" ($null -ne $saveFn)
    Check "entry: defines Restore-ConsoleInputMode" ($null -ne $restoreFn)

    # -----------------------------------------------------------------------
    # Helpers run with a pipe for stdin (no console): no-op, no throw
    # -----------------------------------------------------------------------
    $caseDir = Join-Path $tmpRoot "no-console"
    New-Item -ItemType Directory -Path $caseDir | Out-Null
    $child = Join-Path $caseDir "child.ps1"
    $childText = @'
param([string]$Lib, [string]$Entry, [string]$LogDir)
$ErrorActionPreference = "Stop"
$env:AITOOLS_LOG_DIR = $LogDir
. $Lib
Initialize-Logging "console-guard-test"
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Entry, [ref]$null, [ref]$null)
foreach ($name in @("Save-ConsoleInputMode", "Restore-ConsoleInputMode")) {
    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
    . ([scriptblock]::Create($fn.Extent.Text))
}
"REDIRECTED $([Console]::IsInputRedirected)"
$s = Save-ConsoleInputMode
"SAVE mode=$($s.Mode) reason=$($s.Reason)"
"RESTORE $(Restore-ConsoleInputMode $s 'test-build')"
"RESTORE-NULL $(Restore-ConsoleInputMode $null 'test-null')"
if ($IsWindows) {
    $saveAst = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq "Save-ConsoleInputMode" }, $true)
    $src = $saveAst.Find({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -match 'class AitConsoleModeGuard' }, $true)
    Add-Type -TypeDefinition $src.Value -ErrorAction Stop
    "TYPE get=$([AitConsoleModeGuard]::Get()) set=$([AitConsoleModeGuard]::Set(503)) setneg=$([AitConsoleModeGuard]::Set(-1))"
}
"END errors=$errors warnings=$warnings"
'@
    Set-Content -LiteralPath $child -Value $childText
    $logDir = Join-Path $caseDir "logs"
    $out = $null | & pwsh -NoProfile -File $child -Lib $lib -Entry $entry -LogDir $logDir 2>&1 | Out-String
    $rc = $LASTEXITCODE
    $log = ""
    $logFile = Join-Path $logDir "deploy.log"
    if (Test-Path $logFile) { $log = Get-Content -LiteralPath $logFile -Raw }
    Check "no console: child ran without error (exit 0)" ($rc -eq 0) $out.Trim()
    Check "no console: stdin of the child is a pipe" ($out -match 'REDIRECTED True') $out.Trim()
    $expectReason = if ($IsWindows) { "not a console" } else { "not Windows" }
    Check "no console: Save-ConsoleInputMode returns mode -1, '$expectReason'" ($out -match "SAVE mode=-1 reason=$expectReason") $out.Trim()
    Check "no console: Restore-ConsoleInputMode returns '$expectReason' (nothing to restore)" ($out -match "RESTORE $expectReason") $out.Trim()
    Check "no console: Restore-ConsoleInputMode with nothing saved returns 'not saved'" ($out -match 'RESTORE-NULL not saved') $out.Trim()
    Check "no console: no warning or error counted" ($out -match 'END errors=0 warnings=0') $out.Trim()
    Check "no console: deploy.log has the detail line" ($log -match "\[detail\] console input mode around test-build: not guarded \($expectReason\)") $log
    if ($IsWindows) {
        # Get(): -1 (stdin is not a console); Set(): a Win32 error, never an exception
        Check "type: AitConsoleModeGuard compiles; Get() is -1 without a console" ($out -match 'TYPE get=-1 ') $out.Trim()
        Check "type: Set() without a console returns a Win32 error code" ($out -match 'TYPE get=-1 set=[1-9]\d* ') $out.Trim()
        Check "type: Set(-1) is refused (87)" ($out -match 'setneg=87') $out.Trim()
    } else {
        foreach ($n in @("type: AitConsoleModeGuard compiles; Get() is -1 without a console",
                         "type: Set() without a console returns a Win32 error code",
                         "type: Set(-1) is refused (87)")) {
            Skip $n "kernel32 console API is Windows only"
        }
    }

    # -----------------------------------------------------------------------
    # Structure of Step 2: pipe stdin + save before the try + restore in finally
    # -----------------------------------------------------------------------
    $builds = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.PipelineAst] -and $n.Extent.Text -match 'build-deploy\.sh' }, $true))
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
