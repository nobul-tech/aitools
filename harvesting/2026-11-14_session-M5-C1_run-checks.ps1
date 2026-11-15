# run-checks.ps1 -- run check-pre-commit.ps1 (or check-pre-push.ps1) from the worktree
# with logs in scratch (AITOOLS_LOG_DIR), never ~/.aitools/logs. Usage: run-checks.ps1 <pre-commit|pre-push> <tag>
param([string]$Which, [string]$Tag)
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\m5-checks"
$sd = Join-Path $wt ".scratch\session-M5-C1"
$env:AITOOLS_LOG_DIR = Join-Path $sd "logs-$Tag"
New-Item -ItemType Directory -Path $env:AITOOLS_LOG_DIR -Force | Out-Null
$out = Join-Path $sd "check-$Tag.log"
& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $wt "scripts\check-$Which.ps1") *> $out
"exit: $LASTEXITCODE"
"output: $out"
"Git Bash lines in deploy.log:"
Get-Content (Join-Path $env:AITOOLS_LOG_DIR "deploy.log") -ErrorAction SilentlyContinue | Select-String "Git Bash"
