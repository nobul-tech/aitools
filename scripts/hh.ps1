# hh.ps1 — honest harness (Windows): show git status for harness paths, then run aitools
# Usage: hh [-n|-status-only]  (-n = status only, no aitools)

param(
    [switch]$n,
    [Alias("status-only")]
    [switch]$StatusOnly
)

$ErrorActionPreference = "Stop"

function Find-AitoolsRepo {
    if ($env:AITOOLS_REPO -and (Test-Path (Join-Path $env:AITOOLS_REPO "scripts\build-deploy.sh"))) {
        return $env:AITOOLS_REPO
    }
    $cur = (Get-Location).Path
    while ($true) {
        $bd = Join-Path $cur "scripts\build-deploy.sh"
        $git = Join-Path $cur ".git"
        if ((Test-Path $bd) -and (Test-Path $git)) { return $cur }
        $parent = Split-Path $cur -Parent
        if ($parent -eq $cur -or $cur -eq "") { break }
        $cur = $parent
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
