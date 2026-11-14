# test-menu-choice.ps1 -- tests for the choice-menu read Read-MenuChoice in
# scripts/aitools-lib.ps1: an offered answer is returned (case and surrounding
# whitespace ignored); an empty line, a word or a letter not offered prints
# "  please type one of a/b/c" and asks again; EOF returns the default with the
# EOF warning; every answer is logged at detail (deploy.log only); 50
# unrecognised answers in a row end with the default and a warning; the prompt
# is printed as data; $script:ReadConsoleEof = $true from Read-ConsoleChoice is
# honoured as EOF; the function returns exactly one value.
# Mirror of tests/menus/test-menu-choice.sh.
#
# Safe to re-run: every case runs in a child pwsh with its own temp HOME/log dir,
# removed on exit. No pty: the case feeds the real Read-ConsoleChoice through
# [Console]::SetIn(StringReader) (an empty reader is EOF) and captures the
# console with [Console]::SetOut(StringWriter). The guard, flag and CR cases
# replace Read-ConsoleChoice with a stub.
# Platform: Windows (pwsh 7; aitools-lib.ps1 is a Windows library, so CI runs
# this suite on the windows job only, plans/ci-platform-targeting.md).
# Spec: .claude/rules/interactive-menus.md; reference/managed-file-deployment.md
# "Menus"; commander 2026-11-13: "no default or other characters should re-ask".
# Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/menus/test-menu-choice.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 22 | Select-Object -Skip 1; exit 0 }

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$lib = Join-Path $root "scripts/aitools-lib.ps1"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("menu-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
$pwshExe = (Get-Process -Id $PID).Path

$script:pass = 0; $script:fail = 0; $script:skip = 0

# The child script: dot-source the lib, optionally a Read-ConsoleChoice stub,
# feed input.txt as the console input, call Read-MenuChoice with the MC_*
# arguments and write the answer, the number of values returned, the warnings
# counter and the captured console to the case directory.
$snippet = @'
$ErrorActionPreference = "Stop"
. $env:MC_LIB
Initialize-Logging "t"
$C = $env:MC_C
if ($env:MC_STUB) { . $env:MC_STUB }
[Console]::SetIn([IO.StringReader]::new([IO.File]::ReadAllText((Join-Path $C "input.txt"))))
$orig = [Console]::Out
$sw = [IO.StringWriter]::new()
[Console]::SetOut($sw)
try {
    $r = @(Read-MenuChoice -Valid ($env:MC_VALID -split ' ') -Default $env:MC_DEFAULT -DefaultDesc $env:MC_DESC -Context $env:MC_CTX -Prompt $env:MC_PROMPT)
} finally {
    [Console]::SetOut($orig)
}
[IO.File]::WriteAllText((Join-Path $C "console.txt"), $sw.ToString())
[IO.File]::WriteAllText((Join-Path $C "result"), ($r -join "|"))
[IO.File]::WriteAllText((Join-Path $C "count"), [string]$r.Count)
[IO.File]::WriteAllText((Join-Path $C "warnings"), [string]$script:warnings)
'@

$stubs = @{
    # Closed input that Read-ConsoleChoice does not report: "" with no warning, no flag
    silent = 'function Read-ConsoleChoice { param([string]$DefaultDesc) return "" }'
    # Contract flag: EOF reported through $script:ReadConsoleEof only (no LogWarn)
    flag   = 'function Read-ConsoleChoice { param([string]$DefaultDesc) $script:ReadConsoleEof = $true; return "" }'
    # A trailing CR (Windows line ending) left on the answer
    cr     = 'function Read-ConsoleChoice { param([string]$DefaultDesc) return "a`r" }'
}

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++ }
    else {
        Write-Output "FAIL $Name"; $script:fail++
        Write-Output ("      console| " + ((Console) -replace "`n", "`n      console| "))
        (Log) -split "`n" | Where-Object { $_ -match 'menu answer|\[warn\]' } | Select-Object -Last 10 | ForEach-Object { Write-Output "      log| $_" }
    }
}

# Run-Menu <name> <input> <valid> <default> [prompt] [stub]: one case in a child pwsh
function Run-Menu([string]$Name, [string]$InputText, [string]$Valid, [string]$Default, [string]$Prompt = "  choice: ", [string]$Stub = "") {
    $script:C = Join-Path $tmpRoot $Name
    foreach ($d in @("home", "logs")) { New-Item -ItemType Directory -Path (Join-Path $script:C $d) -Force | Out-Null }
    [IO.File]::WriteAllText((Join-Path $script:C "input.txt"), $InputText)
    $snip = Join-Path $script:C "snippet.ps1"
    [IO.File]::WriteAllText($snip, $snippet)
    $stubFile = ""
    if ($Stub) {
        $stubFile = Join-Path $script:C "stub.ps1"
        [IO.File]::WriteAllText($stubFile, $stubs[$Stub])
    }
    $vars = @{
        HOME = (Join-Path $script:C "home"); USERPROFILE = (Join-Path $script:C "home")
        AITOOLS_LOG_DIR = (Join-Path $script:C "logs"); AITOOLS_SUMMARY_FILE = (Join-Path $script:C "summary")
        MC_LIB = $lib; MC_C = $script:C; MC_STUB = $stubFile
        MC_VALID = $Valid; MC_DEFAULT = $Default; MC_DESC = "overwrite"; MC_CTX = $Name; MC_PROMPT = $Prompt
    }
    $old = @{}
    foreach ($k in $vars.Keys) { $old[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
    try {
        $null | & $pwshExe -NoProfile -NonInteractive -File $snip *> (Join-Path $script:C "out")
        Set-Content -Path (Join-Path $script:C "rc") -Value $LASTEXITCODE
    } finally {
        foreach ($k in $old.Keys) { [Environment]::SetEnvironmentVariable($k, $old[$k]) }
    }
}

function Txt([string]$Rel) { $f = Join-Path $script:C $Rel; if (Test-Path $f) { Get-Content $f -Raw } else { "" } }
function Console { Txt "console.txt" }
function Log { Txt "logs/deploy.log" }
function Rc { (Txt "rc").Trim() }
# ResIs <answer>: the child exited 0, returned exactly one value, and it is <answer>
function ResIs([string]$Answer) { (Rc) -eq "0" -and (Txt "count") -eq "1" -and (Txt "result") -ceq $Answer }
# Occ <fixed string> <text>: how many times the string occurs in the text
function Occ([string]$S, [string]$Text) { [regex]::Matches([string]$Text, [regex]::Escape($S)).Count }
function Has([string]$S, [string]$Text) { ([string]$Text).Contains($S) }

try {
    # --- Real Read-ConsoleChoice, input through [Console]::SetIn ---
    # Default s (not o): an empty line taken as the default would end with s
    Run-Menu "reask" "`n`nskip`nq`no`n" "o a m s x" "s"
    Check "re-ask: empty, empty, word, letter not offered, then o -> o (default s not taken, one value)" (ResIs "o")
    Check "re-ask: 4 hints '  please type one of o/a/m/s/x'" ((Occ "  please type one of o/a/m/s/x" (Console)) -eq 4)
    Check "re-ask: prompt printed before every read (5)" ((Occ "  choice: " (Console)) -eq 5)
    Check "re-ask: 5 answers logged at detail" ((Occ "[detail] menu answer (reask): " (Log)) -eq 5)
    Check "re-ask: empty line logged as not offered" (Has '[detail] menu answer (reask): "" -> not one of o/a/m/s/x, asked again' (Log))
    Check "re-ask: word logged as not offered" (Has '[detail] menu answer (reask): "skip" -> not one of o/a/m/s/x, asked again' (Log))
    Check "re-ask: accepted answer logged" (Has '[detail] menu answer (reask): "o" -> o' (Log))
    Check "re-ask: answers not on the console" (-not (Has "menu answer" (Console)) -and -not (Has "menu answer" (Txt "out")))
    Check "re-ask: no warning" (-not (Has "[warn]" (Log)) -and (Txt "warnings") -eq "0")

    Run-Menu "case-space" "  S `n" "o a m s x" "o"
    Check "case and whitespace: '  S ' -> s" (ResIs "s")
    Check "case and whitespace: raw answer logged" (Has '[detail] menu answer (case-space): "  S " -> s' (Log))
    Check "case and whitespace: no hint" ((Occ "please type one of" (Console)) -eq 0)

    Run-Menu "word" "Yes`n" "y yes n no" "n" "  [y/n]: "
    Check "word answer: 'Yes' with y/yes/n/no -> yes" (ResIs "yes")

    Run-Menu "numbers" "3`n0`n2`n" "1 2 n s" "s"
    Check "numbers: 3 and 0 not offered, then 2 -> 2" (ResIs "2")
    Check "numbers: 2 hints '  please type one of 1/2/n/s'" ((Occ "  please type one of 1/2/n/s" (Console)) -eq 2)

    Run-Menu "eof" "" "o a m s x" "o"
    Check "EOF: default returned (one value)" (ResIs "o")
    Check "EOF: Read-ConsoleChoice warning logged" (Has "[warn] No input at prompt (EOF) -- defaulting to overwrite" (Log))
    Check "EOF: logged at detail" (Has "[detail] menu answer (eof): EOF -> o" (Log))
    Check "EOF: no hint" ((Occ "please type one of" (Console)) -eq 0)

    Run-Menu "reask-eof" "`n" "o s x" "o"
    Check "re-ask then EOF: default returned" (ResIs "o")
    Check "re-ask then EOF: one hint, then EOF logged" (((Occ "  please type one of o/s/x" (Console)) -eq 1) -and (Has '[detail] menu answer (reask-eof): "" -> not one of o/s/x, asked again' (Log)) -and (Has "[detail] menu answer (reask-eof): EOF -> o" (Log)))

    Run-Menu "prompt-data" "o`n" "o s x" "o" "  pick %s 100%: {0} "
    Check "prompt printed as data: '%s 100%: {0}' literal" ((ResIs "o") -and (Has "  pick %s 100%: {0} " (Console)))

    # --- Stubbed Read-ConsoleChoice ---
    Run-Menu "guard" "" "o s x" "o" -Stub "silent"
    Check "50-try guard: default returned (one value)" (ResIs "o")
    Check "50-try guard: warning logged" (Has "[warn] No valid answer after 50 tries at guard -- treating input as ended, defaulting to overwrite" (Log))
    Check "50-try guard: 50 answers logged, 49 hints" (((Occ '[detail] menu answer (guard): "" -> not one of o/s/x, asked again' (Log)) -eq 50) -and ((Occ "  please type one of o/s/x" (Console)) -eq 49))

    Run-Menu "flag" "" "o s x" "o" -Stub "flag"
    Check "ReadConsoleEof = true: default returned, EOF logged" ((ResIs "o") -and (Has "[detail] menu answer (flag): EOF -> o" (Log)))
    Check "ReadConsoleEof = true: no warning, no hint" ((Txt "warnings") -eq "0" -and -not (Has "[warn]" (Log)) -and (Occ "please type one of" (Console)) -eq 0)

    Run-Menu "cr" "" "o a s x" "o" -Stub "cr"
    Check "trailing CR trimmed: 'a<CR>' -> a" (ResIs "a")
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}

Write-Output ""
Write-Output "$($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
