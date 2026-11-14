param([string]$Out, [string]$Variant = "new", [string]$Extra = "")
# Spinner + Invoke-AI telemetry in a real (driver-owned) console.
#   -Variant main : origin/main lib (Start-Job spinner, Invoke-AI logs with Log = console + file)
#   -Variant new  : worktree lib (in-process spinner, Invoke-AI telemetry file-only)
# Invoke-AI runs against the stub claude.cmd (tcommon, ~3 s) while the spinner is running.
$ErrorActionPreference = "Stop"
$LogTag = "spin-$Variant"; $Lib = $Variant; $Stub = $true; $StubSeconds = 3
. (Join-Path $PSScriptRoot "tcommon.ps1")
W ("pwsh {0}; stdin redirected={1} stdout redirected={2} UserInteractive={3}" -f $PSVersionTable.PSVersion, [Console]::IsInputRedirected, [Console]::IsOutputRedirected, [Environment]::UserInteractive)
W "runspaces before start: $(RS)"
[Console]::WriteLine("line before the spinner")
$sw = [Diagnostics.Stopwatch]::StartNew()
Start-AiSpinner "merging test..."
$sw.Stop()
W ("Start-AiSpinner returned after {0:N1} ms" -f $sw.Elapsed.TotalMilliseconds)
W "READY"
Start-Sleep -Milliseconds 1200
W "runspaces while spinning: $(RS)"
W "INVOKE"
$sw = [Diagnostics.Stopwatch]::StartNew()
$res = "merge prompt" | Invoke-AI -Speed "balanced" -Permissions "none"
$sw.Stop()
W ("Invoke-AI returned after {0} ms: [{1}]" -f $sw.ElapsedMilliseconds, (($res -join '\n') -replace "`r", '' -replace "`n", '\n'))
$sw = [Diagnostics.Stopwatch]::StartNew()
Stop-AiSpinner
$sw.Stop()
W ("Stop-AiSpinner returned after {0:N1} ms" -f $sw.Elapsed.TotalMilliseconds)
W "runspaces after stop: $(RS)"
W "STOPPED"
[Console]::Write("  answer: ")
$sw = [Diagnostics.Stopwatch]::StartNew()
$ans = Read-ConsoleChoice "nothing"
$sw.Stop()
W ("Read-ConsoleChoice returned [{0}] after {1} ms" -f $ans, $sw.ElapsedMilliseconds)
W "counters: errors=$errors warnings=$warnings"
foreach ($l in (Get-Content -LiteralPath (Join-Path $env:AITOOLS_LOG_DIR "deploy.log"))) { if ($l -match 'AI invocation|spinner') { W "deploy.log: $l" } }
W "DONE"
Start-Sleep -Milliseconds 800
