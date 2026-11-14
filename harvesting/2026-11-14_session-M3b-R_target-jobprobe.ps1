param([string]$Out, [string]$Variant = "", [string]$Extra = "")
# Where does a Start-Job script block's [Console]::Write go? Run inside a real console.
$ErrorActionPreference = "Stop"
$LogTag = "jobprobe"
. (Join-Path $PSScriptRoot "tcommon.ps1")
W ("parent pid {0}: stdout redirected={1}" -f $PID, [Console]::IsOutputRedirected)
$r = Start-Job -ScriptBlock {
    Add-Type -Namespace P -Name K -MemberDefinition '[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();'
    "job pid={0} stdoutRedirected={1} stdinRedirected={2} consoleWindow=0x{3:X}" -f $PID, [Console]::IsOutputRedirected, [Console]::IsInputRedirected, [long][P.K]::GetConsoleWindow()
    [Console]::Write("`r  / probe frame from job")
    "after Console.Write"
} | Receive-Job -Wait -AutoRemoveJob 2>&1
foreach ($line in $r) { W ("job says: $line") }
W "READY"
W "DONE"
Start-Sleep -Milliseconds 500
