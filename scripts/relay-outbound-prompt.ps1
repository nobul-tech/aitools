# relay-outbound-prompt.ps1 — [RELAY] prompt when relay.md is dirty or main is ahead of origin
#
# Dot-source then: Invoke-RelayOutboundPrompt -RepoPath $repo
# Used by scripts/aitools.ps1 and hh.ps1

function Invoke-RelayOutboundPrompt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    if ($env:AITOOLS_SKIP_RELAY_PROMPT -eq '1') { return 0 }

    $relayRel = '.aitools/channel/relay.md'
    $relayFull = Join-Path $RepoPath $relayRel
    if (-not (Test-Path (Join-Path $RepoPath '.git'))) { return 0 }
    if (-not (Test-Path $relayFull)) { return 0 }

    $porcelain = git -C $RepoPath status --porcelain -- $relayRel 2>$null
    $dirty = [bool]$porcelain

    $ahead = 0
    $behind = 0
    $branchName = (git -C $RepoPath branch --show-current 2>$null)
    if (-not $branchName) { $branchName = 'main' }

    git -C $RepoPath rev-parse --verify origin/main 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $aOut = git -C $RepoPath rev-list --count 'origin/main..HEAD' 2>$null
        $bOut = git -C $RepoPath rev-list --count 'HEAD..origin/main' 2>$null
        if ($aOut -match '^\d+$') { $ahead = [int]$aOut }
        if ($bOut -match '^\d+$') { $behind = [int]$bOut }
    }

    if (-not $dirty -and $ahead -le 0) { return 0 }

    if ($env:CI -and -not $env:RELAY_PROMPT_FORCE) {
        Write-Host "[RELAY] $relayRel — uncommitted relay and/or unpushed commits (see git status)" -ForegroundColor Yellow
        return 0
    }

    if (-not [Environment]::UserInteractive) {
        Write-Host "[RELAY] $relayRel — run: git -C `"$RepoPath`" status -sb" -ForegroundColor Yellow
        return 0
    }

    Write-Host ""
    Write-Host "[RELAY] Outbound relay / git — other machines need your commits." -ForegroundColor Yellow
    if ($dirty) {
        Write-Host "  ${relayRel}: local changes (not committed)"
    }
    if ($ahead -gt 0) {
        Write-Host "  ${branchName}: $ahead commit(s) ahead of origin/main (not pushed)"
    }
    if ($behind -gt 0) {
        Write-Host "  ${branchName}: also $behind behind origin/main — pull before push if others committed"
    }
    Write-Host ""
    Write-Host "  Suggested commands:"
    Write-Host "    git add $relayRel"
    Write-Host '    git commit -m "channel: update relay — …"'
    Write-Host "    git push"
    Write-Host ""
    Write-Host "  [c]ontinue  [q]uit (exit 2)  [s]how git status"
    $choice = Read-Host "  choice [c/q/s] (default c)"
    $c = if ($null -eq $choice) { '' } else { "$choice".Trim().ToLowerInvariant() }
    if ($c -match '^q') { return 2 }
    if ($c -match '^s') {
        git -C $RepoPath status -sb
        Write-Host ""
    }
    return 0
}
