# run-guard-test.ps1 -- run the console-mode-guard suite with an isolated HOME and
# log dir, tee its output to a log in this scratch dir. Arg 1: log name.
$sc = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input\.scratch\session-M3b-C1"
$name = if ($args.Count -ge 1) { $args[0] } else { "guard-test" }
$iso = Join-Path $sc "iso-home"
New-Item -ItemType Directory -Force -Path $iso, (Join-Path $iso "logs") | Out-Null
$env:HOME = $iso; $env:USERPROFILE = $iso; $env:AITOOLS_LOG_DIR = Join-Path $iso "logs"
$sw = [Diagnostics.Stopwatch]::StartNew()
$out = & pwsh -NoProfile -File "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input\tests\aitools-entry\test-console-mode-guard.ps1" 2>&1 | Out-String
$rc = $LASTEXITCODE
$sw.Stop()
$text = $out + "exit=$rc elapsed=$([int]$sw.Elapsed.TotalMilliseconds)ms`n"
[IO.File]::WriteAllText((Join-Path $sc "$name.log"), $text)
$text
exit $rc
