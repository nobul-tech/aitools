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

    # [char]27, not `e: hh.ps1 may load this into Windows PowerShell 5.1
    $esc = [char]27
    $tag = "$esc[33m[RELAY]$esc[0m"
    if ($env:CI -and -not $env:RELAY_PROMPT_FORCE) {
        [Console]::WriteLine("$tag $relayRel — uncommitted relay and/or unpushed commits (see git status)")
        return 0
    }

    # Redirected stdin is not a terminal: hint only (interactive-menus.md Console I/O)
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        [Console]::WriteLine("$tag $relayRel — run: git -C `"$RepoPath`" status -sb")
        return 0
    }

    [Console]::WriteLine("")
    [Console]::WriteLine("$tag Outbound relay / git — other machines need your commits.")
    if ($dirty) {
        [Console]::WriteLine("  ${relayRel}: local changes (not committed)")
    }
    if ($ahead -gt 0) {
        [Console]::WriteLine("  ${branchName}: $ahead commit(s) ahead of origin/main (not pushed)")
    }
    if ($behind -gt 0) {
        [Console]::WriteLine("  ${branchName}: also $behind behind origin/main — pull before push if others committed")
    }
    [Console]::WriteLine("")
    [Console]::WriteLine("  Suggested commands:")
    [Console]::WriteLine("    git add $relayRel")
    [Console]::WriteLine('    git commit -m "channel: update relay — …"')
    [Console]::WriteLine("    git push")
    [Console]::WriteLine("")
    [Console]::WriteLine("  [c]ontinue  [q]uit (exit 2)  [s]how git status")
    $choice = Read-RelayOutboundChoice
    if ($choice -eq 'quit') { return 2 }
    if ($choice -eq 'show') {
        # Out-Host: keep git's lines out of this function's return value
        git -C $RepoPath status -sb | Out-Host
        [Console]::WriteLine("")
    }
    return 0
}

# Read the [RELAY] choice from the console. An empty or unrecognised answer
# asks again. Returns 'continue', 'quit' or 'show'. End of input, or 50
# unrecognised answers in a row, continues (the prompt's EOF default) and says so.
# hh.ps1 does not load aitools-lib, so this mirrors the library's
# Read-MenuChoice locally: same hint text, no answer logging.
function Read-RelayOutboundChoice {
    $tries = 0
    while ($true) {
        [Console]::Write("  choice [c/q/s]: ")
        $line = [Console]::ReadLine()
        if ($null -eq $line) {
            [Console]::WriteLine("")
            [Console]::WriteLine("  (no input -- continuing)")
            return 'continue'
        }
        $c = $line.Trim().ToLowerInvariant()
        if ($c -in @('c', 'continue')) { return 'continue' }
        if ($c -in @('q', 'quit')) { return 'quit' }
        if ($c -in @('s', 'show')) { return 'show' }
        $tries++
        if ($tries -ge 50) {
            [Console]::WriteLine("  (no input -- continuing)")
            return 'continue'
        }
        [Console]::WriteLine("  please type one of c/continue/q/quit/s/show")
    }
}
