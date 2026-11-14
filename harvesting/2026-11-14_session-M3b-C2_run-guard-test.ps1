param([string]$Name = "guard-test")
# run-guard-test.ps1 -- run tests/aitools-entry/test-console-mode-guard.ps1 (stdin a pipe, as in
# Claude Code / CI) with an isolated HOME / log dir; output to <Name>.log here.
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$sc = Join-Path $wt ".scratch\session-M3b-C2"
$iso = Join-Path $sc "iso-home"
New-Item -ItemType Directory -Force -Path $iso, (Join-Path $iso "logs") | Out-Null
$env:HOME = $iso; $env:USERPROFILE = $iso; $env:AITOOLS_LOG_DIR = Join-Path $iso "logs"
$sw = [Diagnostics.Stopwatch]::StartNew()
$out = $null | & pwsh -NoProfile -File (Join-Path $wt "tests\aitools-entry\test-console-mode-guard.ps1") 2>&1 | Out-String
$rc = $LASTEXITCODE
$sw.Stop()
$text = $out + "exit=$rc elapsed=$([math]::Round($sw.Elapsed.TotalSeconds, 1))s`n"
[IO.File]::WriteAllText((Join-Path $sc "$Name.log"), $text)
$text
