param([string]$Mode = "2E8", [string]$Out, [switch]$Conin)
# Child process: sets the (shared) console input mode to $Mode (hex) and exits
# without restoring it -- simulates a child that leaves the console raw.
# -Conin: open CONIN$ directly instead of using stdin (works even when the child's
# stdin is a pipe, as long as it is attached to the console).
. "$PSScriptRoot\conmode.cs.ps1"
if ($Conin) {
    $h = [ConMode]::CreateFileW('CONIN$', [uint32]3221225472, 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
} else {
    $h = [ConMode]::GetStdHandle(-10)
}
$before = [ConMode]::ConinMode()
$ok = [ConMode]::SetConsoleMode($h, [Convert]::ToUInt32($Mode, 16))
$after = [ConMode]::ConinMode()
Add-Content -LiteralPath $Out -Value ("{0:HH:mm:ss.fff} CHILD pid {1}: conin={2} stdinRedirected={3} before=0x{4:X} set 0x{5} ok={6} after=0x{7:X}" -f (Get-Date), $PID, [bool]$Conin, [Console]::IsInputRedirected, $before, $Mode, $ok, $after)
