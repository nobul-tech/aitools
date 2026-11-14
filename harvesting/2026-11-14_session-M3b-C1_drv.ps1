param([string]$Label, [string]$Target, [string]$Variant = "", [string]$Extra = "", [string]$Steps = "", [int]$Timeout = 60)
# M3b-Finish-R real-console driver. Starts a minimized pwsh in its OWN new console
# running $Target, attaches only to that console, and executes $Steps ('|'-separated):
#   wait:MARK        wait until result-<Label>.log contains MARK
#   sleep:MS         sleep MS milliseconds
#   peek             append the console's last 4 screen rows + CONIN$ mode to the log
#   mode             append the CONIN$ input mode to the log
#   send:KEYS        write KEYS into the console input (<CR> = Enter)
#   sendunless:M:K   send K only when the log does not contain M yet
#   exit:MS          wait up to MS for the process to exit; log EXITED or STILL RUNNING
# Never attaches to a console it did not start. Never reads or writes any other console.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\conmode.cs.ps1"
$out = Join-Path $PSScriptRoot "result-$Label.log"
if (Test-Path $out) { Remove-Item $out }
function D([string]$s) {
    $line = "{0:HH:mm:ss.fff} DRIVER {1}" -f (Get-Date), $s
    for ($i = 0; $i -lt 20; $i++) { try { Add-Content -LiteralPath $out -Value $line -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds 25 } }
    Write-Output "LOST LOG LINE: $line"
}
function Has([string]$m) { (Test-Path $out) -and (Select-String -LiteralPath $out -Pattern $m -SimpleMatch -Quiet) }
$argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot $Target), "-Out", $out)
if ($Variant) { $argList += @("-Variant", $Variant) }
if ($Extra) { $argList += @("-Extra", $Extra) }
$p = Start-Process -FilePath "pwsh" -ArgumentList $argList -PassThru -WindowStyle Minimized
D "started pid $($p.Id): $Target -Variant $Variant -Extra $Extra"
[void][ConMode]::FreeConsole()
$attachDeadline = (Get-Date).AddSeconds(15)
while (-not [ConMode]::AttachConsole([uint32]$p.Id)) {
    if ((Get-Date) -gt $attachDeadline -or $p.HasExited) { D "AttachConsole failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; Get-Content $out; exit 1 }
    Start-Sleep -Milliseconds 50
}
$peekN = 0
foreach ($step in ($Steps -split '\|')) {
    if (-not $step) { continue }
    $kind, $arg = $step -split ':', 2
    switch ($kind) {
        "wait" {
            $deadline = (Get-Date).AddSeconds($Timeout)
            while (-not (Has $arg)) {
                if ((Get-Date) -gt $deadline -or $p.HasExited) { D "TIMEOUT/EXIT waiting for $arg"; break }
                Start-Sleep -Milliseconds 50
            }
        }
        "sleep" { Start-Sleep -Milliseconds ([int]$arg) }
        "peek" {
            $peekN++
            $t = [ConMode]::ScreenTail(4)
            $rows = ($t -split "`r?`n" | Where-Object { $_ -ne "" }) -join ' || '
            D ("PEEK {0} mode=0x{1:X} screen: {2}" -f $peekN, [ConMode]::ConinMode(), $rows)
        }
        "mode" { D ("MODE 0x{0:X}" -f [ConMode]::ConinMode()) }
        "send" { D "sends $arg"; [void][ConMode]::SendKeys(($arg -replace '<CR>', "`r" -replace '<LF>', "`n")) }
        "sendunless" {
            $m, $k = $arg -split ':', 2
            if (Has $m) { D "skip send ($m seen)" } else { D "sends $k"; [void][ConMode]::SendKeys(($k -replace '<CR>', "`r" -replace '<LF>', "`n")) }
        }
        "exit" {
            if ($p.WaitForExit([int]$arg)) { D "EXITED code=$($p.ExitCode)" } else { D "STILL RUNNING after $arg ms" }
        }
        default { D "unknown step $step" }
    }
}
[void][ConMode]::FreeConsole()
if (-not $p.WaitForExit(5000)) { Stop-Process -Id $p.Id -Force; D "KILLED by driver" }
Get-Content $out
