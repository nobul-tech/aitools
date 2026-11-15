param([string]$Out, [string]$Variant = "new", [string]$Extra = "")
# Timings of the worktree lib's helper in a real console (no keys needed):
# cold Initialize-AitConsoleInput (Add-Type), warm call, EnterCooked+Set x50,
# Save+Restore x50 (warm).
$ErrorActionPreference = "Stop"
$Lib = "new"
$LogTag = "timing-$Extra"
. (Join-Path $PSScriptRoot "tcommon.ps1")
W ("stdin redirected={0}" -f [Console]::IsInputRedirected)
$sw = [Diagnostics.Stopwatch]::StartNew(); $ok = Initialize-AitConsoleInput; $sw.Stop()
W ("cold Initialize-AitConsoleInput (Add-Type) = {0}: {1} ms" -f $ok, $sw.Elapsed.TotalMilliseconds.ToString("0.0"))
$sw = [Diagnostics.Stopwatch]::StartNew(); $ok2 = Initialize-AitConsoleInput; $sw.Stop()
W ("warm Initialize-AitConsoleInput = {0}: {1} ms" -f $ok2, $sw.Elapsed.TotalMilliseconds.ToString("0.000"))
$m0 = [AitConsoleInput]::Get()
$sw = [Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 50; $i++) { $m = [AitConsoleInput]::EnterCooked(); $null = [AitConsoleInput]::Set($m) }
$sw.Stop()
W ("warm EnterCooked+Set x50: {0} ms total, {1} ms each; mode 0x{2:X} -> 0x{3:X}" -f $sw.Elapsed.TotalMilliseconds.ToString("0.0"), ($sw.Elapsed.TotalMilliseconds / 50).ToString("0.000"), $m0, [AitConsoleInput]::Get())
$sw = [Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 50; $i++) { $s = Save-ConsoleInputMode; $null = Restore-ConsoleInputMode $s "timing" }
$sw.Stop()
W ("warm Save+Restore x50 (detail log line each): {0} ms total, {1} ms each" -f $sw.Elapsed.TotalMilliseconds.ToString("0.0"), ($sw.Elapsed.TotalMilliseconds / 50).ToString("0.000"))
W "DONE"
