param([string]$Out = "", [string]$Variant = "", [string]$Extra = "")
# mutate.ps1 -- run tests/aitools-entry/test-console-mode-guard.ps1 against mutated copies of the
# worktree lib (temp tree; the worktree is not touched). Writes mutate-<pipe|console>.log here.
# Run directly (stdin/stdout a pipe: console cases SKIP) or as a driver target (-Out given: the
# suite runs in-process, stdin and stdout are the console, the console cases run).
$ErrorActionPreference = "Stop"
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$sc = Join-Path $wt ".scratch\session-M3b-C2"
$iso = Join-Path $sc "iso-home"
New-Item -ItemType Directory -Force -Path $iso, (Join-Path $iso "logs") | Out-Null
$env:HOME = $iso; $env:USERPROFILE = $iso; $env:AITOOLS_LOG_DIR = Join-Path $iso "logs"
$inProcess = [bool]$Out
$tag = if ($inProcess) { "console" } else { "pipe" }

$libText = [IO.File]::ReadAllText((Join-Path $wt "scripts\aitools-lib.ps1"))
$entryText = [IO.File]::ReadAllText((Join-Path $wt "scripts\aitools.ps1"))
$testText = [IO.File]::ReadAllText((Join-Path $wt "tests\aitools-entry\test-console-mode-guard.ps1"))
$origLibText = [IO.File]::ReadAllText((Join-Path $sc "origin-aitools-lib.ps1"))
$nofinText = [IO.File]::ReadAllText((Join-Path $sc "lib-nofinally.ps1"))

# Anchor match tolerant of CRLF / LF: "`n" in $Old matches "\r?\n"
function Replace-Re([string]$Text, [string]$Old, [string]$New, [switch]$All) {
    $pat = ([regex]::Escape($Old)) -replace '\\n', '\r?\n'
    $n = [regex]::Matches($Text, $pat).Count
    if ($n -eq 0) { throw "mutation anchor not found: $Old" }
    if (-not $All -and $n -gt 1) { throw "mutation anchor not unique ($n): $Old" }
    $eval = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $New }
    if ($All) { return [regex]::Replace($Text, $pat, $eval) }
    return ([regex]::new($pat)).Replace($Text, $eval, 1)
}
function Get-FuncText([string]$Text, [string]$Name) {
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$null, [ref]$null)
    $f = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
    if (-not $f) { throw "function $Name not found" }
    return $f
}
function Swap-Func([string]$Text, [string]$Name, [string]$FromText) {
    $f = Get-FuncText $Text $Name
    $g = Get-FuncText $FromText $Name
    return $Text.Substring(0, $f.Extent.StartOffset) + $g.Extent.Text + $Text.Substring($f.Extent.EndOffset)
}

$m1 = Swap-Func (Swap-Func $libText "Start-AiSpinner" $origLibText) "Stop-AiSpinner" $origLibText
$mutations = [ordered]@{
    "M0 none (control)"                                   = $libText
    "M1 Start-Job spinner back (origin Start-/Stop-AiSpinner)" = $m1
    "M2 Stop-AiSpinner does not dispose"                  = (Replace-Re $libText "        if (`$s.PS.Runspace) { `$s.PS.Runspace.Dispose() }`n        `$s.PS.Dispose()`n        `$s.Stop.Dispose()" "        `$null = 0")
    "M3 Invoke-AI telemetry back to Log"                  = (Replace-Re $libText 'Write-AiLog "AI invocation' 'Log "AI invocation' -All)
    "M4 Invoke-AiMerge without try/finally (lib-nofinally)" = (Swap-Func $libText "Invoke-AiMerge" $nofinText)
    "M5 Start-AiSpinner does not stop a running spinner first" = (Replace-Re $libText "    param([string]`$Message = `"working...`")`n    Stop-AiSpinner`n" "    param([string]`$Message = `"working...`")`n")
    "M6 no redirected-stdout gate"                        = (Replace-Re $libText "    if ([Console]::IsOutputRedirected -or -not [Environment]::UserInteractive) { return }`n" "")
    "M7 Write-AiLog also writes the console"              = (Replace-Re $libText '    [IO.File]::AppendAllText($resolvedLog, "[$ts] [$scriptName] [$Level] $Msg`n", [System.Text.UTF8Encoding]::new($false))' ('    [IO.File]::AppendAllText($resolvedLog, "[$ts] [$scriptName] [$Level] $Msg`n", [System.Text.UTF8Encoding]::new($false)); Write-Host "[$ts] [$scriptName] [$Level] $Msg"'))
    "M8 Stop-AiSpinner does not wait (WaitOne(0), no EndInvoke)" = (Replace-Re (Replace-Re $libText "WaitOne(2000)" "WaitOne(0)") "        `$null = `$s.PS.EndInvoke(`$s.Handle)`n" "")
    "M9 before: origin/main lib (e8ebd07)"                = $origLibText
}

$report = New-Object System.Collections.Generic.List[string]
$report.Add(("######## mutate ($tag) at {0:yyyy-MM-ddTHH:mm:ss} local; stdin redirected={1} stdout redirected={2}" -f (Get-Date), [Console]::IsInputRedirected, [Console]::IsOutputRedirected))
$n = 0
foreach ($k in $mutations.Keys) {
    $n++
    $tree = Join-Path ([IO.Path]::GetTempPath()) ("m3bc2-mut-$n-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $tree "scripts"), (Join-Path $tree "tests\aitools-entry") | Out-Null
    $enc = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText((Join-Path $tree "scripts\aitools-lib.ps1"), $mutations[$k], $enc)
    [IO.File]::WriteAllText((Join-Path $tree "scripts\aitools.ps1"), $entryText, $enc)
    $suite = Join-Path $tree "tests\aitools-entry\test-console-mode-guard.ps1"
    [IO.File]::WriteAllText($suite, $testText, $enc)
    if ($inProcess) {
        $lines = @(& $suite 2>&1 | ForEach-Object { "$_" })
        $rc = $LASTEXITCODE
    } else {
        $lines = @(& pwsh -NoProfile -File $suite 2>&1 | ForEach-Object { "$_" })
        $rc = $LASTEXITCODE
    }
    $fails = @($lines | Where-Object { $_ -like "FAIL *" })
    $total = ($lines | Where-Object { $_ -like "---- *" }) -join ""
    $report.Add("=== $k : exit=$rc $total")
    foreach ($f in $fails) { $report.Add("    " + $(if ($f.Length -gt 200) { $f.Substring(0, 200) + "..." } else { $f })) }
    Remove-Item -Recurse -Force $tree
}
$text = ($report -join "`n") + "`n"
[IO.File]::WriteAllText((Join-Path $sc "mutate-$tag.log"), $text)
if ($inProcess) { Add-Content -LiteralPath $Out -Value $text; Add-Content -LiteralPath $Out -Value "DONE" } else { $text }
