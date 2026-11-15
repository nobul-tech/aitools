param([string]$Out, [string]$Variant = "", [string]$Extra = "")
# Diagnose the suite's "tty" Run-Child in a driver-owned console: extract the child text from the
# suite, run it with Start-Process -NoNewWindow (stderr to a file), report what happened.
$sc = $PSScriptRoot
$iso = Join-Path $sc "iso-home"
$env:HOME = $iso; $env:USERPROFILE = $iso; $env:AITOOLS_LOG_DIR = Join-Path $sc "logs\ttyprobe"
$suite = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input\tests\aitools-entry\test-console-mode-guard.ps1"
$lib = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input\scripts\aitools-lib.ps1"
$ast = [System.Management.Automation.Language.Parser]::ParseFile($suite, [ref]$null, [ref]$null)
$assign = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$childText' }, $true)
$text = $assign.Right.Expression.Value
$dir = Join-Path $sc "ttyprobe"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$child = Join-Path $dir "child.ps1"; Set-Content -LiteralPath $child -Value $text
$res = Join-Path $dir "result.txt"; if (Test-Path $res) { Remove-Item $res }
$err = Join-Path $dir "stderr.txt"
$p = Start-Process -FilePath (Get-Process -Id $PID).Path -NoNewWindow -Wait -PassThru -RedirectStandardError $err -ArgumentList @(
    "-NoProfile", "-File", "`"$child`"", "-Lib", "`"$lib`"", "-Mode", "spinner-console", "-ResultFile", "`"$res`"")
Add-Content -LiteralPath $Out -Value "exit=$($p.ExitCode)"
Add-Content -LiteralPath $Out -Value ("result: " + $(if (Test-Path $res) { Get-Content -Raw $res } else { "<none>" }))
Add-Content -LiteralPath $Out -Value ("stderr: " + $(if (Test-Path $err) { Get-Content -Raw $err } else { "<none>" }))
Add-Content -LiteralPath $Out -Value "DONE"
