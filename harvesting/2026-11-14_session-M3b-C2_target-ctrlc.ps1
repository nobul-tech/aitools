param([string]$Out, [string]$Variant = "new", [string]$Extra = "")
# Ctrl+C during the AI merge, with the script run as `pwsh -NoExit -File` so an interactive
# prompt follows (as when aitools.ps1 is typed at a pwsh prompt and runs in that session).
# Fake backend: a session function `claude` that sleeps 20 s (Get-Command finds it first).
#   -Variant nofin : new spinner, Invoke-AiMerge without try/finally (lib-nofinally.ps1)
#   -Variant new   : worktree lib (Stop-AiSpinner in a finally)
$LogTag = "ctrlc-$Variant"; $Lib = $Variant; $Stub = $false
. (Join-Path $PSScriptRoot "tcommon.ps1")
$global:C2Out = $Out
function global:claude {
    $null = @($input)
    Start-Sleep -Seconds 20
    $global:LASTEXITCODE = 0
    "# Title"
    "merged line"
}
# Harness: a process started by Start-Process may inherit "ignore Ctrl+C" (new process group);
# turn Ctrl+C handling back on, as in a terminal a user opened.
Add-Type -Namespace C2 -Name Ctl -MemberDefinition '[DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleCtrlHandler(IntPtr h, bool add);'
W ("SetConsoleCtrlHandler(NULL, FALSE) = {0}; TreatControlCAsInput={1}" -f [C2.Ctl]::SetConsoleCtrlHandler([IntPtr]::Zero, $false), [Console]::TreatControlCAsInput)
# Typed at the prompt by the driver after Ctrl+C: record the runspaces of this session
# (name must not collide with tcommon's RS -- PowerShell names are case-insensitive)
function global:showrs {
    $list = (Get-Runspace | ForEach-Object { "$($_.Id):$($_.RunspaceStateInfo.State)/$($_.RunspaceAvailability)" }) -join ','
    Add-Content -LiteralPath $global:C2Out -Value ("{0:HH:mm:ss.fff} AT PROMPT runspaces: {1}" -f (Get-Date), $list)
}
W "runspaces before: $(RS)"
W "READY"
$r = Invoke-AiMerge -FilePath (Join-Path $PSScriptRoot "a.md") -SourceContent "# Title`nsource line" -LocalContent "# Title`nlocal line"
W "Invoke-AiMerge returned [$r] (not stopped)"
