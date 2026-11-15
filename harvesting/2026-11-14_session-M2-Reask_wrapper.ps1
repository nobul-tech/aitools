# ---------------------------------------------------------------------------
# Read-MenuChoice: choice-menu read. Usage:
#   $c = Read-MenuChoice -Valid @("o","a","s","x") -Default "o" -DefaultDesc "overwrite" `
#        -Context "review CLAUDE.md" -Prompt "  choice [o/a/s/x]: "
# -Valid: the accepted answers, lowercase. -Default: the answer taken only at
# EOF (one of -Valid). -DefaultDesc: what the default does (Read-ConsoleChoice's
# EOF warning). -Context: a short label for the log. -Prompt: printed before
# every read; the caller prints the menu.
# Reads through Read-ConsoleChoice, trims surrounding whitespace and lowercases.
# Returns an offered answer. Anything else -- an empty line, a word, a letter
# not offered -- prints "  please type one of a/b/c" and asks again (commander,
# 2026-11-13: "no default or other characters should re-ask"). EOF returns
# -Default. Every answer is logged at detail (deploy.log only). Writes nothing
# to the pipeline except the answer.
# EOF detection: Read-ConsoleChoice returns "" both at EOF and for a typed empty
# line. $script:ReadConsoleEof = $true after the read marks EOF (contract for
# Read-ConsoleChoice, see the M2-Reask PR "Contract change"); until
# Read-ConsoleChoice sets it, an empty answer with $script:warnings raised
# during the read is EOF (its EOF branch calls LogWarn). 50 unrecognised
# answers in a row are treated as EOF, so a closed input that is not detected
# cannot loop forever.
# Spec: .claude/rules/interactive-menus.md "Answers";
# reference/managed-file-deployment.md "Menus". Parity: read_menu_choice in
# aitools-lib.sh.
# ---------------------------------------------------------------------------
$script:ReadConsoleEof = $false
function Read-MenuChoice {
    param(
        [string[]]$Valid,
        [string]$Default,
        [string]$DefaultDesc,
        [string]$Context,
        [string]$Prompt
    )
    $hint = $Valid -join "/"
    $tries = 0
    while ($true) {
        [Console]::Write($Prompt)
        $script:ReadConsoleEof = $false
        $w0 = [int]$script:warnings
        $raw = Read-ConsoleChoice $DefaultDesc
        if ($null -eq $raw) { $raw = "" }
        if ($script:ReadConsoleEof -or ($raw -eq "" -and [int]$script:warnings -gt $w0)) {
            LogDetail "menu answer (${Context}): EOF -> $Default"
            return $Default
        }
        $ans = $raw.Trim().ToLowerInvariant()
        if ($Valid -ccontains $ans) {
            LogDetail "menu answer (${Context}): `"$raw`" -> $ans"
            return $ans
        }
        LogDetail "menu answer (${Context}): `"$raw`" -> not one of $hint, asked again"
        $tries++
        if ($tries -ge 50) {
            LogWarn "No valid answer after 50 tries at $Context -- treating input as ended, defaulting to $DefaultDesc"
            return $Default
        }
        [Console]::WriteLine("  please type one of $hint")
    }
}
