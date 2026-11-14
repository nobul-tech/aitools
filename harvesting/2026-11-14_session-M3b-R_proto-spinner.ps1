# ---------------------------------------------------------------------------
# PROTOTYPE (M3b-Finish-R, fix 5) -- replacement for Start-AiSpinner /
# Stop-AiSpinner in scripts/aitools-lib.ps1. Not wired into any tracked file.
#
# Spinner for AI operations (visual progress indicator). Runs in-process: a
# second runspace on its own thread ([powershell]::Create() + BeginInvoke), so
# [Console]::Write reaches THIS process's console. (Start-Job runs the loop in
# a separate pwsh process whose stdout is the job's redirected pipe, so nothing
# is drawn.) No module dependency (no ThreadJob).
# Parity: _start_spinner / _stop_spinner in aitools-lib.sh -- same frame
# "`r  <c> <msg>", chars / - \ |, 200 ms period, stop clears with "`r  `e[K".
# Bash writes /dev/tty only; here the spinner is a no-op when stdout is
# redirected or the session is not interactive, so no frames land in a pipe,
# a log or CI output.
# Stop is synchronous: it signals the loop, waits for the invocation to finish
# (2 s cap, then PowerShell.Stop()), disposes the runspace, and only then clears
# the line -- no background thread outlives Stop-AiSpinner.
# ---------------------------------------------------------------------------
$script:_aiSpinner = $null

function Start-AiSpinner {
    param([string]$Message = "working...")
    Stop-AiSpinner   # at most one spinner at a time
    if ([Console]::IsOutputRedirected -or -not [Environment]::UserInteractive) { return }
    $stop = [System.Threading.ManualResetEventSlim]::new($false)
    $ps = [powershell]::Create()
    [void]$ps.AddScript({
        param($msg, $stop)
        $chars = '/-\|'
        $i = 0
        do {
            [Console]::Write("`r  $($chars[$i % 4]) $msg")
            $i++
        } while (-not $stop.Wait(200))
    }).AddArgument($Message).AddArgument($stop)
    $script:_aiSpinner = @{ PS = $ps; Stop = $stop; Handle = $ps.BeginInvoke() }
}

function Stop-AiSpinner {
    $s = $script:_aiSpinner
    if (-not $s) { return }
    $script:_aiSpinner = $null
    $s.Stop.Set()
    try {
        if (-not $s.Handle.AsyncWaitHandle.WaitOne(2000)) { $s.PS.Stop() }
        $null = $s.PS.EndInvoke($s.Handle)
    } catch {
        LogDetail "AI spinner stop: $($_.Exception.Message)"
    } finally {
        $s.PS.Runspace.Dispose()
        $s.PS.Dispose()
        $s.Stop.Dispose()
    }
    [Console]::Write("`r  `e[K")  # clear spinner line
}
