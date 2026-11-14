# run-checks.ps1 -- run check-pre-commit.ps1 and check-pre-push.ps1 from the worktree, logs to scratch.
param([Parameter(Mandatory)][string]$Worktree, [Parameter(Mandatory)][string]$OutDir)
$env:AITOOLS_LOG_DIR = Join-Path $OutDir "check-logs"
Set-Location $Worktree
foreach ($name in @("check-pre-commit", "check-pre-push")) {
    $out = Join-Path $OutDir "$name.log"
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Worktree "scripts/$name.ps1") *> $out
    Write-Output "$name exit $LASTEXITCODE (output: $out)"
}
