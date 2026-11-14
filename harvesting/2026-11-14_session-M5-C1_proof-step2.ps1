# proof-step2.ps1 -- check-pre-commit step 2 (.sh syntax) runs Git Bash, also from a
# native pwsh PATH (registry PATH: bare `bash` = the WSL launcher). Temp clone of the
# worktree, a good and a broken .sh staged, run the new and the pre-fix (origin/main)
# check-pre-commit.ps1. HOME/USERPROFILE/AITOOLS_LOG_DIR in the temp dir.
$ErrorActionPreference = "Stop"
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\m5-checks"
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("m5c1-step2-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    & git clone -q $wt (Join-Path $tmp "repo")
    $repo = Join-Path $tmp "repo"
    Copy-Item -Path (Join-Path $wt "scripts\*") -Destination (Join-Path $repo "scripts") -Recurse -Force
    New-Item -ItemType Directory -Path (Join-Path $repo "proof") | Out-Null
    [IO.File]::WriteAllText((Join-Path $repo "proof\good.sh"), "#!/usr/bin/env bash`nset -euo pipefail`necho ok`n")
    [IO.File]::WriteAllText((Join-Path $repo "proof\broken.sh"), "#!/usr/bin/env bash`nif [ 1 = 1 ]; then`necho missing fi`n")
    & git -C $repo add proof/good.sh proof/broken.sh
    $old = & git -C $wt show "origin/main:scripts/check-pre-commit.ps1"
    [IO.File]::WriteAllText((Join-Path $repo "scripts\check-pre-commit-old.ps1"), ($old -join "`n"))
    $home2 = Join-Path $tmp "home"
    New-Item -ItemType Directory -Path (Join-Path $home2 ".aitools") -Force | Out-Null
    $env:HOME = $home2; $env:USERPROFILE = $home2
    # Native PATH (what a pwsh terminal sees), plus pwsh's own dir and git
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    "bare bash under this PATH: $((Get-Command bash -ErrorAction SilentlyContinue).Source)"
    foreach ($v in @("check-pre-commit.ps1", "check-pre-commit-old.ps1")) {
        $env:AITOOLS_LOG_DIR = Join-Path $tmp "logs-$v"
        New-Item -ItemType Directory -Path $env:AITOOLS_LOG_DIR -Force | Out-Null
        Push-Location $repo
        $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts\$v") 2>&1 | Out-String
        $rc = $LASTEXITCODE
        Pop-Location
        "==== $v (exit $rc)"
        ($out -replace "`e\[[0-9;]*m", '') -split "`n" | Where-Object { $_ -match '^\s+2\. |FAIL: proof/' } | ForEach-Object { "  $($_.TrimEnd())" }
        $dl = Join-Path $env:AITOOLS_LOG_DIR "deploy.log"
        if (Test-Path $dl) { Get-Content $dl | Select-String "Git Bash" | ForEach-Object { "  log: $_" } }
    }
} finally {
    Set-Location $wt
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    if (Test-Path $tmp) { "WARN: temp dir not removed: $tmp" }
}
