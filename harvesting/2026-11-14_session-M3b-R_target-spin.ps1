param([string]$Out, [string]$Variant = "job", [string]$Extra = "")
# Spinner evidence target (fix 5).
#   -Variant job   : the worktree lib's Start-AiSpinner / Stop-AiSpinner (Start-Job)
#   -Variant rs    : prototype proto-spinner.ps1 (in-process runspace)
#   -Variant leak  : prototype started, script exits WITHOUT Stop-AiSpinner
$ErrorActionPreference = "Stop"
$LogTag = "spin-$Variant"
. (Join-Path $PSScriptRoot "tcommon.ps1")
if ($Variant -ne "job") { . (Join-Path $PSScriptRoot "proto-spinner.ps1") }
W ("pwsh {0}; stdin redirected={1} stdout redirected={2} UserInteractive={3}" -f $PSVersionTable.PSVersion, [Console]::IsInputRedirected, [Console]::IsOutputRedirected, [Environment]::UserInteractive)
W ("runspaces before start: " + ((Get-Runspace | ForEach-Object { "$($_.Id):$($_.RunspaceStateInfo.State)/$($_.RunspaceAvailability)" }) -join ','))
[Console]::WriteLine("line before the spinner")
$sw = [Diagnostics.Stopwatch]::StartNew()
Start-AiSpinner "merging test..."
$sw.Stop()
W ("Start-AiSpinner returned after {0} ms" -f $sw.ElapsedMilliseconds)
if ($Variant -eq "job") { W ("job state after start: {0}" -f $script:_aiSpinnerJob.State) }
W "READY"
if ($Variant -eq "leak") {
    Start-Sleep -Milliseconds 1500
    W "EXITING without Stop-AiSpinner"
    exit 0
}
if ($Variant -eq "rslog") {
    # What Invoke-AI does right after Start-AiSpinner: Log (Write-Host) to the console
    Start-Sleep -Milliseconds 900
    Log "AI invocation: speed=balanced backend=claude attempt=1"
    W "LOGGED"
    Start-Sleep -Milliseconds 3100
} else {
    Start-Sleep -Seconds 4
}
W ("runspaces while spinning: " + ((Get-Runspace | ForEach-Object { "$($_.Id):$($_.RunspaceStateInfo.State)/$($_.RunspaceAvailability)" }) -join ','))
if ($Variant -eq "job") {
    $j = $script:_aiSpinnerJob
    W ("job state before stop: {0}; child job state: {1}" -f $j.State, ($j.ChildJobs | ForEach-Object { $_.State }))
    $o = (Receive-Job $j -Keep 2>&1 | Out-String)
    $show = $o.Substring(0, [Math]::Min(160, $o.Length)) -replace "`r", '<CR>' -replace "`n", '<LF>' -replace "`e", '<ESC>'
    W ("Receive-Job -Keep: {0} chars: [{1}]" -f $o.Length, $show)
    $err = ($j.ChildJobs | ForEach-Object { $_.Error } | Out-String).Trim()
    W ("job error stream: [{0}]" -f $err)
} else {
    $h = $script:_aiSpinner.Handle
}
$sw = [Diagnostics.Stopwatch]::StartNew()
Stop-AiSpinner
$sw.Stop()
W ("Stop-AiSpinner returned after {0} ms" -f $sw.ElapsedMilliseconds)
if ($Variant -ne "job") { W ("spinner invocation IsCompleted after stop: {0}" -f $h.IsCompleted) }
W ("runspaces after stop: " + ((Get-Runspace | ForEach-Object { "$($_.Id):$($_.RunspaceStateInfo.State)/$($_.RunspaceAvailability)" }) -join ','))
W "STOPPED"
[Console]::Write("  answer: ")
$sw = [Diagnostics.Stopwatch]::StartNew()
$ans = Read-ConsoleChoice "nothing"
$sw.Stop()
W ("Read-ConsoleChoice returned [{0}] after {1} ms" -f $ans, $sw.ElapsedMilliseconds)
W "DONE"
Start-Sleep -Milliseconds 800
