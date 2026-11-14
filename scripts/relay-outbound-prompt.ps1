# relay-outbound-prompt.ps1 -- [RELAY] prompt when relay.md is dirty or main is ahead of origin
#
# Dot-source then: Invoke-RelayOutboundPrompt -RepoPath $repo
# Used by scripts/aitools.ps1 and hh.ps1
# ASCII only: aitools.ps1 (no version requirement) may load this into Windows
# PowerShell 5.1 (hh.ps1 is PowerShell 7 only), which reads a file without a BOM
# as ANSI, where the UTF-8 bytes of an em dash include a quote character.
# Non-ASCII output text is built with [char] codes.

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

    # [char] codes, not `e or literal UTF-8: this file may be loaded into Windows PowerShell 5.1
    $esc = [char]27
    $dash = [char]0x2014   # em dash
    $ell = [char]0x2026    # horizontal ellipsis
    $tag = "$esc[33m[RELAY]$esc[0m"
    if ($env:CI -and -not $env:RELAY_PROMPT_FORCE) {
        [Console]::WriteLine("$tag $relayRel $dash uncommitted relay and/or unpushed commits (see git status)")
        return 0
    }

    # Redirected stdin is not a terminal: hint only (interactive-menus.md Console I/O)
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        [Console]::WriteLine("$tag $relayRel $dash run: git -C `"$RepoPath`" status -sb")
        return 0
    }

    [Console]::WriteLine("")
    [Console]::WriteLine("$tag Outbound relay / git $dash other machines need your commits.")
    if ($dirty) {
        [Console]::WriteLine("  ${relayRel}: local changes (not committed)")
    }
    if ($ahead -gt 0) {
        [Console]::WriteLine("  ${branchName}: $ahead commit(s) ahead of origin/main (not pushed)")
    }
    if ($behind -gt 0) {
        [Console]::WriteLine("  ${branchName}: also $behind behind origin/main $dash pull before push if others committed")
    }
    [Console]::WriteLine("")
    [Console]::WriteLine("  Suggested commands:")
    [Console]::WriteLine("    git add $relayRel")
    [Console]::WriteLine("    git commit -m `"channel: update relay $dash $ell`"")
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

# Read the [RELAY] choice from the console. Returns 'continue', 'quit' or 'show'.
# The read goes through the library's Read-MenuChoice (scripts/aitools-lib.ps1):
# only c/continue/q/quit/s/show count, anything else asks again ("please type
# one of ..."), end of input or 50 unrecognised answers in a row continue (the
# prompt's default), every answer is logged at detail, and on a Windows console
# Read-ConsoleChoice reads in cooked line mode and puts the previous input mode
# back. A child run in this console before the prompt can leave it raw (no echo,
# no line editing); a plain [Console]::ReadLine() would then miss keys
# (reference/cross-platform-detail.md "Windows console: input mode, jobs, spinner").
# scripts/aitools.ps1 has loaded the library: its functions and log are used.
# hh.ps1 has not: the library is dot-sourced here, inside this function, so its
# functions end with the call (hh.ps1 itself runs in its own script scope), and
# its log is initialized as "relay-outbound". Without the library (missing, or it
# fails to load) the local loop below reads the console directly: same answers,
# hint, re-ask, default and 50-try limit, but no cooked-mode guard and no logging.
function Read-RelayOutboundChoice {
    $valid = @('c', 'continue', 'q', 'quit', 's', 'show')
    # Get-Command exempt: command-existence check; the else path loads the library
    $haveLib = [bool](Get-Command Read-MenuChoice -CommandType Function -ErrorAction SilentlyContinue)
    if (-not $haveLib) {
        $lib = Join-Path $PSScriptRoot "aitools-lib.ps1"
        if (Test-Path -LiteralPath $lib) {
            try {
                . $lib
                $haveLib = [bool](Get-Command Read-MenuChoice -CommandType Function -ErrorAction SilentlyContinue)
            } catch {
                [Console]::WriteLine("  (aitools-lib.ps1 did not load: $($_.Exception.Message) -- reading without it)")
            }
            if ($haveLib) {
                try {
                    Initialize-Logging "relay-outbound"
                } catch {
                    # A log that cannot be set up must not stop the prompt
                    # (reference/logging.md section 5); the answers are then not
                    # logged (Windows PowerShell 5.1 ends here: Join-Path with 3 arguments)
                    $null = $_
                }
            }
        } else {
            [Console]::WriteLine("  (aitools-lib.ps1 not found next to this script -- reading without it)")
        }
    }
    if ($haveLib) {
        $ans = Read-MenuChoice -Valid $valid -Default 'c' -DefaultDesc 'continue' `
            -Context 'relay outbound' -Prompt "  choice [c/q/s]: "
        if ($ans -in @('q', 'quit')) { return 'quit' }
        if ($ans -in @('s', 'show')) { return 'show' }
        return 'continue'
    }
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
