# hh.ps1 — honest harness (Windows): git pull, status, then aitools
# Resolves repo: AITOOLS_REPO, or walk up from cwd when Path is non-empty, then
# ~/.aitools/config.json (repoPath / aiToolingRepoPath).
# Usage: hh [-n|-status-only] [-NoPull]  (-n = no aitools; -NoPull = skip git pull)

param(
    [switch]$n,
    [Alias("status-only")]
    [switch]$StatusOnly,
    [switch]$NoPull
)

$ErrorActionPreference = "Stop"

function Find-AitoolsRepo {
    if ($env:AITOOLS_REPO -and (Test-Path (Join-Path $env:AITOOLS_REPO "scripts\build-deploy.sh"))) {
        return $env:AITOOLS_REPO
    }
    # Walk up from cwd only when Path is non-empty — (Get-Location).Path can be
    # empty in some pwsh sessions (e.g. certain home-dir / provider states), which
    # would throw on Join-Path before we read ~/.aitools/config.json.
    $cur = (Get-Location).Path
    if (-not [string]::IsNullOrWhiteSpace($cur)) {
        while ($true) {
            $bd = Join-Path $cur "scripts\build-deploy.sh"
            $git = Join-Path $cur ".git"
            if ((Test-Path $bd) -and (Test-Path $git)) { return $cur }
            $parent = Split-Path $cur -Parent
            # Split-Path 'C:\' -Parent is '' — next Join-Path would throw if we continued
            if ($parent -eq $cur -or [string]::IsNullOrWhiteSpace($cur) -or [string]::IsNullOrWhiteSpace($parent)) { break }
            $cur = $parent
        }
    }
    $cfg = Join-Path $env:USERPROFILE ".aitools\config.json"
    if (Test-Path $cfg) {
        try {
            $j = Get-Content $cfg -Raw | ConvertFrom-Json
            $rp = $j.repoPath
            if (-not $rp) { $rp = $j.aiToolingRepoPath }
            if ($rp -and (Test-Path (Join-Path $rp "scripts\build-deploy.sh"))) { return $rp }
        } catch {}
    }
    return $null
}

$repo = Find-AitoolsRepo
if (-not $repo) {
    Write-Error "hh: cannot find aitools repo (cd into clone, set repoPath in .aitools\config.json, or set AITOOLS_REPO)"
    exit 1
}

Set-Location $repo

Write-Host "== hh (honest harness) @ $repo =="
Write-Host ""

if (-not $NoPull -and $env:HH_NO_PULL -ne "1") {
    Write-Host "-- git pull --"
    git pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "hh: git pull failed — continuing with local tip"
    }
    Write-Host ""
}

Write-Host "-- Branch --"
git status -sb
Write-Host ""
Write-Host "-- Harness paths (relay, shared, deploy, build script, .cursorignore) --"
git status --short -- `
    .aitools/channel/relay.md `
    shared/ `
    deploy/ `
    scripts/build-deploy.sh `
    .cursorignore `
    2>$null
Write-Host ""
Write-Host "Reminder: commit/push relay + shared when ready; aitools syncs relay -> `$env:USERPROFILE\.cursor\AGENTS.md ([RELAY] after aitools/hh -n if uncommitted or unpushed)."
Write-Host ""

if ($n -or $StatusOnly) {
    $rob = Join-Path $repo "scripts\relay-outbound-prompt.ps1"
    if (Test-Path $rob) {
        . $rob
        $relayRc = Invoke-RelayOutboundPrompt -RepoPath $repo
        if ($relayRc -eq 2) { exit 2 }
    }
    exit 0
}

$aitoolsPs1 = Join-Path $env:USERPROFILE ".local\bin\aitools.ps1"
if (Test-Path $aitoolsPs1) {
    & $aitoolsPs1
    exit $LASTEXITCODE
}
Write-Error "hh: aitools.ps1 not found at $aitoolsPs1 — run aitools-install"
exit 1
