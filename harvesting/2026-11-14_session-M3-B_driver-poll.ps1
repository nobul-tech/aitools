param([string]$Label, [string]$Target, [string]$Variant = "noguard", [string]$Extra = "", [int]$Timeout = 300)
# Starts a minimized pwsh (own console) running $Target, attaches to that console
# and polls the CONIN$ input mode every 100 ms, logging each change to poll-<Label>.log.
# Never attaches to any console it did not start.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\conmode.cs.ps1"
$out = Join-Path $PSScriptRoot "result-$Label.log"
$poll = Join-Path $PSScriptRoot "poll-$Label.log"
foreach ($f in @($out, $poll)) { if (Test-Path $f) { Remove-Item $f } }
function P([string]$s) { Add-Content -LiteralPath $poll -Value ("{0:HH:mm:ss.fff} {1}" -f (Get-Date), $s) }
$argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot $Target), "-Out", $out, "-Variant", $Variant)
if ($Extra) { $argList += @("-Extra", $Extra) }
$p = Start-Process -FilePath "pwsh" -ArgumentList $argList -PassThru -WindowStyle Minimized
P "started pid $($p.Id): $Target -Variant $Variant -Extra $Extra"
[void][ConMode]::FreeConsole()
$attachDeadline = (Get-Date).AddSeconds(15)
while (-not [ConMode]::AttachConsole([uint32]$p.Id)) {
    if ((Get-Date) -gt $attachDeadline -or $p.HasExited) { P "AttachConsole failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; Get-Content $poll; exit 1 }
    Start-Sleep -Milliseconds 50
}
P "attached"
$last = [uint32]4294967294; $changes = 0
$deadline = (Get-Date).AddSeconds($Timeout)
while ((Get-Date) -lt $deadline -and -not $p.HasExited) {
    $m = [ConMode]::ConinMode()
    if ($m -ne $last) { P ("MODE 0x{0:X}" -f $m); $last = $m; $changes++ }
    if ((Test-Path $out) -and (Select-String -LiteralPath $out -Pattern "DONE" -Quiet)) { break }
    Start-Sleep -Milliseconds 100
}
$m = [ConMode]::ConinMode()
P ("end: mode=0x{0:X} mode changes seen={1}" -f $m, $changes)
[void][ConMode]::FreeConsole()
$p.WaitForExit(10000) | Out-Null
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; P "KILLED (timeout)" }
"=== $out"
if (Test-Path $out) { Get-Content $out }
"=== $poll"
Get-Content $poll
