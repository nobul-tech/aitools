# test-menu-choice.ps1 -- tests for the choice-menu read Read-MenuChoice in
# scripts/aitools-lib.ps1: an offered answer is returned (case and surrounding
# whitespace ignored); an empty line, a word or a letter not offered prints
# "  please type one of a/b/c" and asks again; EOF returns the default with the
# EOF warning; every answer is logged at detail (deploy.log only); 50
# unrecognised answers in a row end with the default and a warning; the prompt
# is printed as data; $script:ReadConsoleEof = $true from Read-ConsoleChoice is
# honoured as EOF; the function returns exactly one value.
# The real menus end to end: Deploy-ManagedFile's text review (with and without
# an adopt target), its JSON field review (a differing field and a field only
# in LOCAL) and the AI merge preview (a stub `claude` on PATH) re-ask on an
# empty line, a word or a letter not offered, then apply the offered answer;
# EOF at the review menu still overwrites; -Force on a console and a
# non-interactive run show no menu and log no answer.
# EOF at each prompt of issue #29 takes its documented default: a JSON field
# (Deploy-ManagedFile's JSON review) -> o; a JSON field only in LOCAL -> s; a
# field in the settings sync (Sync-ManagedJson) -> o; the AI merge preview ->
# n, back to the review menu (EOF there -> o, the merge written nowhere); the
# [r]efine feedback read -> empty feedback, the merge refined (the stub claude
# records each prompt in bin/calls.txt).
# The [RELAY] prompt (Read-RelayOutboundChoice in scripts/relay-outbound-prompt.ps1)
# reads through Read-MenuChoice: with the library loaded by the caller
# (aitools.ps1), loaded by the prompt itself (hh.ps1; nothing left behind), and
# under Windows PowerShell 5.1; without the library next to it, a local loop with
# the same answers. On a pseudo-terminal, Invoke-RelayOutboundPrompt reads in
# cooked mode when the console was left raw, and puts the raw mode back.
# Mirror of tests/menus/test-menu-choice.sh.
#
# Safe to re-run: every case runs in a child pwsh with its own temp HOME/log dir,
# removed on exit. No pty: the case feeds the real Read-ConsoleChoice through
# [Console]::SetIn(StringReader) (an empty reader is EOF) and captures the
# console with [Console]::SetOut(StringWriter). The guard, flag and CR cases
# replace Read-ConsoleChoice with a stub. The real-menu cases replace
# Test-InteractiveConsole with $true (the child's stdin is redirected, so it
# would report no console); everything below it -- Prompt-DiffReview,
# Prompt-JsonFieldReview, Invoke-AiMerge, Read-MenuChoice, Read-ConsoleChoice --
# is the real code. One case also runs on a pseudo-terminal
# (tests/managed-files/pty-run.py, pywinpty/ConPTY on Windows; SKIP without it).
# The JSON cases need node (SKIP without it).
# Platform: Windows (pwsh 7; aitools-lib.ps1 is a Windows library, so CI runs
# this suite on the windows job only, plans/ci-platform-targeting.md).
# Spec: .claude/rules/interactive-menus.md; reference/managed-file-deployment.md
# "Menus"; commander 2026-11-13: "no default or other characters should re-ask".
# Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/menus/test-menu-choice.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 46 | Select-Object -Skip 1; exit 0 }

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$lib = Join-Path $root "scripts/aitools-lib.ps1"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("menu-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
$pwshExe = (Get-Process -Id $PID).Path
$pty = Join-Path $root "tests/managed-files/pty-run.py"

$script:pass = 0; $script:fail = 0; $script:skip = 0
$havePty = [bool](Get-Command python3 -ErrorAction SilentlyContinue)
# Get-Command exempt: command-existence check; $havePty is the fallback branch
if ($havePty -and $IsWindows) {
    # Windows pty = pywinpty (ConPTY); a failing import means "not installed".
    & python3 -c "import winpty" 2>$null
    $havePty = ($LASTEXITCODE -eq 0)
}
$haveNode = [bool](Get-Command node -ErrorAction SilentlyContinue)
# Get-Command exempt: command-existence check; the JSON cases SKIP without node

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

# --- The real menus: Deploy-ManagedFile and the AI merge preview ---
# The child: dot-source the lib, run one Deploy-ManagedFile (DMF_SRC ->
# DMF_DEST, adopt target DMF_ADOPT) and write every value it returned to
# "result" (joined by |: exactly one is expected). DMF_MODE:
#   console -- Test-InteractiveConsole replaced with $true (this child's stdin
#              is redirected); input.txt fed through [Console]::SetIn (an empty
#              reader is EOF); the console captured to console.txt
#   plain   -- the same capture, the real Test-InteractiveConsole (no console)
#   pty     -- nothing replaced or captured: run on pty-run.py, output in "out"
$dmfChild = @'
. $env:MC_LIB
Initialize-Logging "t"
$C = $env:MC_C
if ($env:DMF_MODE -eq "console") { function Test-InteractiveConsole { return $true } }
$capture = ($env:DMF_MODE -ne "pty")
if ($capture) {
    [Console]::SetIn([IO.StringReader]::new([IO.File]::ReadAllText((Join-Path $C "input.txt"))))
    $orig = [Console]::Out
    $sw = [IO.StringWriter]::new()
    [Console]::SetOut($sw)
}
try {
    $r = @(Deploy-ManagedFile -Content ([IO.File]::ReadAllText($env:DMF_SRC)) -DestPath $env:DMF_DEST -ToolName "tool" -ItemName "item" -AdoptPath $env:DMF_ADOPT)
} finally {
    if ($capture) {
        [Console]::SetOut($orig)
        [IO.File]::WriteAllText((Join-Path $C "console.txt"), $sw.ToString())
    }
}
[IO.File]::WriteAllText((Join-Path $C "result"), ($r -join "|"))
'@

# The settings-sync child (Run-Dmf -Child $syncChild): Sync-ManagedJson of the
# live file DMF_DEST against the profile DMF_SRC (mirror "claude.settings"),
# Test-InteractiveConsole replaced with $true, input.txt fed through
# [Console]::SetIn, the console captured to console.txt; the result
# ($script:SyncManagedJsonResult) is written to "result".
$syncChild = @'
. $env:MC_LIB
Initialize-Logging "t"
$C = $env:MC_C
function Test-InteractiveConsole { return $true }
[Console]::SetIn([IO.StringReader]::new([IO.File]::ReadAllText((Join-Path $C "input.txt"))))
$orig = [Console]::Out
$sw = [IO.StringWriter]::new()
[Console]::SetOut($sw)
try {
    $null = Sync-ManagedJson -LiveFile $env:DMF_DEST -ProfileFile $env:DMF_SRC -SubPath "claude.settings"
} finally {
    [Console]::SetOut($orig)
    [IO.File]::WriteAllText((Join-Path $C "console.txt"), $sw.ToString())
}
[IO.File]::WriteAllText((Join-Path $C "result"), [string]$script:SyncManagedJsonResult)
'@

# Setup-Dmf <name>: a case directory with home, logs, dest, repo (a git repo:
# the adopt target) and bin (first on PATH: the stub claude)
function Setup-Dmf([string]$Name) {
    $script:C = Join-Path $tmpRoot $Name
    foreach ($d in @("home", "logs", "dest", "repo", "bin")) { New-Item -ItemType Directory -Path (Join-Path $script:C $d) -Force | Out-Null }
    & git -C (Join-Path $script:C "repo") init -q
    if ($LASTEXITCODE -ne 0) { throw "git init failed in $script:C" }
}
# W <relative path> <text>: write a case file (text + newline)
function W([string]$Rel, [string]$Text) { [IO.File]::WriteAllText((Join-Path $script:C $Rel), "$Text`n") }
# Stub-Claude: a fake AI CLI that prints a fixed valid merge. Each prompt it
# gets is appended to bin/calls.txt, followed by a line "==CALL==".
function Stub-Claude {
    $text = "# Title`nmerged line"
    if ($IsWindows) {
        # Native Windows runs a .cmd: append the prompt from stdin to calls.txt,
        # then print the canned answer line by line
        $lines = ($text -split "`n" | ForEach-Object { "echo $_" }) -join "`r`n"
        $rec = 'more >> "%~dp0calls.txt"' + "`r`n" + 'echo ==CALL==>> "%~dp0calls.txt"'
        [IO.File]::WriteAllText((Join-Path $script:C "bin/claude.cmd"), "@echo off`r`n$rec`r`n$lines`r`n")
        return
    }
    $path = Join-Path $script:C "bin/claude"
    $rec = 'cat >> "$(dirname "$0")/calls.txt"' + "`n" + 'printf "\n==CALL==\n" >> "$(dirname "$0")/calls.txt"'
    [IO.File]::WriteAllText($path, "#!/usr/bin/env bash`n$rec`nprintf '%s\n' '# Title' 'merged line'`n")
    & chmod +x $path
}

# Run-Dmf <src> <dest> <adopt> [-InputText] [-Mode console|plain|pty] [-ForceRun] [-Child]:
# one Deploy-ManagedFile in a child pwsh (paths relative to the case directory;
# adopt "" = no adopt target). -ForceRun sets AITOOLS_FORCE=1. -Child: the child
# script (default $dmfChild; $syncChild runs the settings sync instead).
function Run-Dmf([string]$Src, [string]$Dest, [string]$Adopt, [string]$InputText = "", [string]$Mode = "console", [switch]$ForceRun, [string]$Child = $dmfChild) {
    $C = $script:C
    [IO.File]::WriteAllText((Join-Path $C "input.txt"), $InputText)
    $snip = Join-Path $C "snippet.ps1"
    [IO.File]::WriteAllText($snip, $Child)
    $vars = @{
        HOME = (Join-Path $C "home"); USERPROFILE = (Join-Path $C "home")
        AITOOLS_LOG_DIR = (Join-Path $C "logs"); AITOOLS_SUMMARY_FILE = (Join-Path $C "summary")
        PATH = (Join-Path $C "bin") + [IO.Path]::PathSeparator + $env:PATH
        TERM = "xterm"; NO_COLOR = $null
        AITOOLS_FORCE = $(if ($ForceRun) { "1" } else { $null })
        MC_LIB = $lib; MC_C = $C; DMF_MODE = $Mode
        DMF_SRC = (Join-Path $C $Src); DMF_DEST = (Join-Path $C $Dest)
        DMF_ADOPT = $(if ($Adopt) { Join-Path $C $Adopt } else { $null })
    }
    $old = @{}
    foreach ($k in $vars.Keys) { $old[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
    try {
        if ($Mode -eq "pty") {
            # pty-run.py decodes \n escapes; the input is passed as typed
            & python3 $pty --input $InputText --log (Join-Path $C "out") --timeout 60 -- $pwshExe -NoProfile -File $snip
        } else {
            $null | & $pwshExe -NoProfile -NonInteractive -File $snip *> (Join-Path $C "out")
        }
        Set-Content -Path (Join-Path $C "rc") -Value $LASTEXITCODE
    } finally {
        foreach ($k in $old.Keys) { [Environment]::SetEnvironmentVariable($k, $old[$k]) }
    }
}
# DmfIs <outcome>: the child exited 0 and Deploy-ManagedFile returned exactly this one value
function DmfIs([string]$Want) { (Rc) -eq "0" -and (Txt "result") -ceq $Want }
# FileIs <relative path> <text>: the file's content without the trailing newline(s)
function FileIs([string]$Rel, [string]$Want) { ((Txt $Rel) -replace '[\r\n]+$', '') -ceq $Want }
# JsonIs <relative path> <compact json>: the file's JSON without whitespace (the values here have none)
function JsonIs([string]$Rel, [string]$Want) { ((Txt $Rel) -replace '\s', '') -ceq $Want }

# --- The [RELAY] prompt (scripts/relay-outbound-prompt.ps1) ---
$relayScript = Join-Path $root "scripts/relay-outbound-prompt.ps1"
# The child: optionally dot-source the lib first (RO_LIB=1: the aitools.ps1
# path; else the hh.ps1 path, where the prompt loads it), dot-source the relay
# script (RO_RELAY), feed input.txt through [Console]::SetIn and call
# Read-RelayOutboundChoice. Writes the answer(s), their number, whether
# Read-MenuChoice is still defined after the call, and the captured console.
# Results go to files: a console swapped with SetOut can lose the child's later
# stdout.
$relayChild = @'
$ErrorActionPreference = "Stop"
$C = $env:MC_C
if ($env:RO_LIB -eq "1") { . $env:MC_LIB; Initialize-Logging "t" }
. $env:RO_RELAY
[Console]::SetIn((New-Object IO.StringReader([IO.File]::ReadAllText((Join-Path $C "input.txt")))))
$orig = [Console]::Out
$sw = New-Object IO.StringWriter
[Console]::SetOut($sw)
try {
    $r = @(Read-RelayOutboundChoice)
} finally {
    [Console]::SetOut($orig)
}
[IO.File]::WriteAllText((Join-Path $C "console.txt"), $sw.ToString())
[IO.File]::WriteAllText((Join-Path $C "result"), ($r -join "|"))
[IO.File]::WriteAllText((Join-Path $C "count"), [string]$r.Count)
[IO.File]::WriteAllText((Join-Path $C "leaked"), [string][bool](Get-Command Read-MenuChoice -ErrorAction SilentlyContinue))
'@

# Run-Relay <name> <input> [-WithLib] [-Exe <path>] [-Relay <path>]: one
# Read-RelayOutboundChoice in a child (pwsh by default) with its own HOME and log
# dir. (Not -Lib: PowerShell names are case-insensitive, it would hide $lib.)
function Run-Relay([string]$Name, [string]$InputText, [switch]$WithLib, [string]$Exe = $pwshExe, [string]$Relay = $relayScript) {
    $script:C = Join-Path $tmpRoot $Name
    foreach ($d in @("home", "logs")) { New-Item -ItemType Directory -Path (Join-Path $script:C $d) -Force | Out-Null }
    [IO.File]::WriteAllText((Join-Path $script:C "input.txt"), $InputText)
    $snip = Join-Path $script:C "snippet.ps1"
    [IO.File]::WriteAllText($snip, $relayChild)
    $vars = @{
        HOME = (Join-Path $script:C "home"); USERPROFILE = (Join-Path $script:C "home")
        AITOOLS_LOG_DIR = (Join-Path $script:C "logs"); AITOOLS_SUMMARY_FILE = (Join-Path $script:C "summary")
        MC_LIB = $lib; MC_C = $script:C; RO_RELAY = $Relay; RO_LIB = $(if ($WithLib) { "1" } else { $null })
    }
    $old = @{}
    foreach ($k in $vars.Keys) { $old[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
    try {
        $null | & $Exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $snip *> (Join-Path $script:C "out")
        Set-Content -Path (Join-Path $script:C "rc") -Value $LASTEXITCODE
    } finally {
        foreach ($k in $old.Keys) { [Environment]::SetEnvironmentVariable($k, $old[$k]) }
    }
}
$relayHint = "  please type one of c/continue/q/quit/s/show"
# NoLog: no menu answer was logged (the local loop logs nothing)
function NoLog { -not (Has "menu answer" (Log)) }

# The pty child: an aitools-like repo whose relay.md is uncommitted, the console
# input mode set raw (line input and echo off) before the prompt, then the whole
# Invoke-RelayOutboundPrompt on the hh.ps1 path (the prompt loads the lib). The
# AitConsoleInput type is compiled from the lib's own source to set the raw mode.
$relayPtyChild = @'
$C = $env:MC_C
$ast = [System.Management.Automation.Language.Parser]::ParseFile($env:MC_LIB, [ref]$null, [ref]$null)
$init = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq "Initialize-AitConsoleInput" }, $true)
$src = $init.Find({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -match 'class AitConsoleInput' }, $true)
Add-Type -TypeDefinition $src.Value -ErrorAction Stop
$before = [AitConsoleInput]::Get()
$raw = $before -band (-bnot 0x6)
$setRc = [AitConsoleInput]::Set($raw)
. $env:RO_RELAY
$rc = Invoke-RelayOutboundPrompt -RepoPath $env:RO_REPO
$after = [AitConsoleInput]::Get()
$null = [AitConsoleInput]::Set($before)
[IO.File]::WriteAllText((Join-Path $C "result"), "rc=$rc before=$before raw=$raw setrc=$setRc after=$after")
'@

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

    # ======================================================================
    # The real menus: Deploy-ManagedFile and the AI merge preview
    # ======================================================================
    # --- Without a console: no menu, no answer logged (unchanged behaviour) ---
    Setup-Dmf "dmf-noninteractive"; W "src.md" "new"; W "dest/a.md" "old"
    Run-Dmf "src.md" "dest/a.md" "repo/a.md" -Mode "plain"
    Check "non-interactive text review: overwrite, no menu" ((DmfIs "updated") -and (FileIs "dest/a.md" "new") -and -not (Has "choice [" (Console)) -and -not (Test-Path "$C/repo/a.md"))
    Check "non-interactive text review: no answer logged" (-not (Has "menu answer" (Log)))

    if ($haveNode) {
        Setup-Dmf "dmf-json-noninteractive"; W "repo/c.json" '{"a":1,"b":2}'; W "dest/c.json" '{"a":9,"b":2,"z":0}'
        Run-Dmf "repo/c.json" "dest/c.json" "repo/c.json" -Mode "plain"
        Check "non-interactive JSON review: field overwritten, LOCAL-only kept, no menu" ((DmfIs "updated") -and (JsonIs "dest/c.json" '{"a":1,"b":2,"z":0}') -and -not (Has "choice [" (Console)))
        Check "non-interactive JSON review: no answer logged" (-not (Has "menu answer" (Log)))
    }

    # --- Text review with an adopt target: empty, word, letter not offered, then s ---
    Setup-Dmf "dmf-reask-adopt"; W "src.md" "new"; W "dest/a.md" "old"
    Run-Dmf "src.md" "dest/a.md" "repo/a.md" -InputText "`nskip`nq`ns`n"
    Check "text review (adopt): empty, 'skip', 'q' re-ask, then s -> skipped (one value)" (DmfIs "skipped")
    Check "text review (adopt): LOCAL unchanged, nothing adopted" ((FileIs "dest/a.md" "old") -and -not (Test-Path "$C/repo/a.md"))
    Check "text review (adopt): 3 hints '  please type one of o/a/m/s/x'" ((Occ "  please type one of o/a/m/s/x" (Console)) -eq 3)
    Check "text review (adopt): prompt asked 4 times" ((Occ "  choice [o/a/m/s/x]: " (Console)) -eq 4)
    Check "text review (adopt): 4 answers logged at detail" ((Occ "[detail] menu answer (review a.md): " (Log)) -eq 4)
    Check "text review (adopt): empty, word and letter logged as not offered" ((Has '[detail] menu answer (review a.md): "" -> not one of o/a/m/s/x, asked again' (Log)) -and (Has '[detail] menu answer (review a.md): "skip" -> not one of o/a/m/s/x, asked again' (Log)) -and (Has '[detail] menu answer (review a.md): "q" -> not one of o/a/m/s/x, asked again' (Log)))
    Check "text review (adopt): s logged" (Has '[detail] menu answer (review a.md): "s" -> s' (Log))
    Check "text review (adopt): re-ask prints the hint and the prompt, not the menu again" ((Occ "  [s]kip            : nothing written; asked again next run" (Console)) -eq 1)

    # --- Text review without an adopt target: a and m are not offered ---
    Setup-Dmf "dmf-reask-noadopt"; W "src.md" "new"; W "dest/a.md" "old"
    Run-Dmf "src.md" "dest/a.md" "" -InputText "a`nm`no`n"
    Check "text review (no adopt): a and m re-ask, then o -> updated" ((DmfIs "updated") -and (FileIs "dest/a.md" "new"))
    Check "text review (no adopt): 2 hints '  please type one of o/s/x'" ((Occ "  please type one of o/s/x" (Console)) -eq 2)
    Check "text review (no adopt): a and m logged as not offered, o accepted" ((Has '[detail] menu answer (review a.md): "a" -> not one of o/s/x, asked again' (Log)) -and (Has '[detail] menu answer (review a.md): "m" -> not one of o/s/x, asked again' (Log)) -and (Has '[detail] menu answer (review a.md): "o" -> o' (Log)))
    Check "text review (no adopt): no AI merge started, nothing adopted" (-not (Has "AI merge" (Console)) -and -not (Test-Path "$C/repo/a.md"))

    # --- Text review: case and surrounding spaces ignored ---
    Setup-Dmf "dmf-case-space"; W "src.md" "new"; W "dest/a.md" "old"
    Run-Dmf "src.md" "dest/a.md" "" -InputText " O `n"
    Check "text review: ' O ' -> o, updated, no hint" ((DmfIs "updated") -and (FileIs "dest/a.md" "new") -and (Occ "please type one of" (Console)) -eq 0)
    Check "text review: raw answer logged" (Has '[detail] menu answer (review a.md): " O " -> o' (Log))

    # --- EOF at the review menu: overwrite (unchanged) ---
    Setup-Dmf "dmf-eof"; W "src.md" "new"; W "dest/a.md" "old"
    Run-Dmf "src.md" "dest/a.md" "repo/a.md" -InputText ""
    Check "EOF at the review menu: overwrite" ((DmfIs "updated") -and (FileIs "dest/a.md" "new"))
    Check "EOF at the review menu: warning and 'EOF -> o' logged, no hint" ((Has "[warn] No input at prompt (EOF) -- defaulting to overwrite" (Log)) -and (Has "[detail] menu answer (review a.md): EOF -> o" (Log)) -and (Occ "please type one of" (Console)) -eq 0)

    # --- -Force on a console: no menu, no answer read or logged ---
    Setup-Dmf "dmf-force"; W "src.md" "new"; W "dest/a.md" "old"
    Run-Dmf "src.md" "dest/a.md" "repo/a.md" -InputText "a`n" -ForceRun
    Check "-Force on a console: overwrite, no menu" ((DmfIs "updated") -and (FileIs "dest/a.md" "new") -and -not (Has "choice [" (Console)) -and -not (Test-Path "$C/repo/a.md"))
    Check "-Force on a console: no answer logged" (-not (Has "menu answer" (Log)))

    # --- AI merge preview: empty and a word re-ask, then y ---
    Setup-Dmf "dmf-merge-reask"; Stub-Claude; W "repo/a.md" "# Title`nsource line"; W "dest/a.md" "# Title`nlocal line"
    Run-Dmf "repo/a.md" "dest/a.md" "repo/a.md" -InputText "m`n`nmaybe`ny`n"
    Check "merge preview: empty and 'maybe' re-ask, then y -> accept & adopt (one value)" (DmfIs "accept & adopt")
    Check "merge preview: the merge in LOCAL and the repo" ((Txt "dest/a.md") -match "merged line" -and (Txt "dest/a.md") -ceq (Txt "repo/a.md"))
    Check "merge preview: 2 hints '  please type one of y/r/n'" ((Occ "  please type one of y/r/n" (Console)) -eq 2)
    Check "merge preview: m, the two re-asks and y logged" ((Has '[detail] menu answer (review a.md): "m" -> m' (Log)) -and (Has '[detail] menu answer (merge preview a.md): "" -> not one of y/r/n, asked again' (Log)) -and (Has '[detail] menu answer (merge preview a.md): "maybe" -> not one of y/r/n, asked again' (Log)) -and (Has '[detail] menu answer (merge preview a.md): "y" -> y' (Log)))

    # --- JSON field review: a differing field, then a field only in LOCAL ---
    if ($haveNode) {
        Setup-Dmf "dmf-json-reask"; W "repo/c.json" '{"a":1,"b":2}'; W "dest/c.json" '{"a":9,"b":2,"z":0}'
        Run-Dmf "repo/c.json" "dest/c.json" "repo/c.json" -InputText "`no`no`ns`n"
        Check "json review: a: empty re-asks, then o; z (only in LOCAL): o re-asks, then s -> skipped" (DmfIs "skipped")
        Check "json review: a overwritten, z kept in LOCAL, the repo unchanged" ((JsonIs "dest/c.json" '{"a":1,"b":2,"z":0}') -and (JsonIs "repo/c.json" '{"a":1,"b":2}'))
        Check "json review: one hint '  please type one of o/a/s/x' (field a)" ((Occ "  please type one of o/a/s/x" (Console)) -eq 1)
        Check "json review: one hint '  please type one of a/s/x' (field z: no overwrite)" ((Occ "  please type one of a/s/x" (Console)) -eq 1)
        Check "json review: field a answers logged" ((Has '[detail] menu answer (json item: a): "" -> not one of o/a/s/x, asked again' (Log)) -and (Has '[detail] menu answer (json item: a): "o" -> o' (Log)))
        Check "json review: field z answers logged" ((Has '[detail] menu answer (json item: z): "o" -> not one of a/s/x, asked again' (Log)) -and (Has '[detail] menu answer (json item: z): "s" -> s' (Log)))
    } else {
        Write-Output "SKIP JSON review cases (node not on PATH)"; $script:skip++
    }

    # ======================================================================
    # EOF at each prompt (issue #29): the JSON field review, the settings
    # sync, the AI merge preview and the [r]efine feedback read take their
    # documented default (reference/managed-file-deployment.md "Menus",
    # "AI-Assisted Merge Detail"). Once the [Console]::SetIn reader is
    # exhausted, every further read is EOF.
    # ======================================================================
    if ($haveNode) {
        # A differing field: EOF -> o (overwrite from source)
        Setup-Dmf "eof-json"; W "repo/c.json" '{"a":1,"b":2}'; W "dest/c.json" '{"a":9,"b":2}'
        Run-Dmf "repo/c.json" "dest/c.json" "repo/c.json" -InputText ""
        Check "EOF at a JSON field: overwrite (o), the repo unchanged" ((DmfIs "updated") -and (JsonIs "dest/c.json" '{"a":1,"b":2}') -and (JsonIs "repo/c.json" '{"a":1,"b":2}'))
        Check "EOF at a JSON field: warning and 'EOF -> o' logged, no hint" ((Has "[warn] No input at prompt (EOF) -- defaulting to overwriting from source" (Log)) -and (Has "[detail] menu answer (json item: a): EOF -> o" (Log)) -and (Occ "please type one of" (Console)) -eq 0)

        # A field only in LOCAL ([a/s/x], no overwrite): EOF -> s (skip)
        Setup-Dmf "eof-json-local"; W "repo/c.json" '{"a":1}'; W "dest/c.json" '{"a":1,"z":0}'
        Run-Dmf "repo/c.json" "dest/c.json" "repo/c.json" -InputText ""
        Check "EOF at a JSON field only in LOCAL: skip (s), LOCAL and the repo unchanged" ((DmfIs "skipped") -and (JsonIs "dest/c.json" '{"a":1,"z":0}') -and (JsonIs "repo/c.json" '{"a":1}'))
        Check "EOF at a JSON field only in LOCAL: [a/s/x] asked, warning and 'EOF -> s' logged" (((Occ "  choice [a/s/x]: " (Console)) -eq 1) -and (Has "[warn] No input at prompt (EOF) -- defaulting to skipping (only in local)" (Log)) -and (Has "[detail] menu answer (json item: z): EOF -> s" (Log)))

        # The settings sync (settings.json <-> profile.json): EOF -> o
        Setup-Dmf "eof-sync"
        New-Item -ItemType Directory -Path (Join-Path $C "home/.claude") -Force | Out-Null
        W "home/.claude/settings.json" '{"theme":"dark","keep":1}'; W "profile.json" '{"claude":{"settings":{"theme":"light","keep":1}}}'
        Run-Dmf "profile.json" "home/.claude/settings.json" "" -InputText "" -Child $syncChild
        Check "EOF at the settings sync: overwrite (o) from profile.json, profile.json unchanged" ((DmfIs "updated") -and (JsonIs "home/.claude/settings.json" '{"theme":"light","keep":1}') -and (JsonIs "profile.json" '{"claude":{"settings":{"theme":"light","keep":1}}}'))
        Check "EOF at the settings sync: warning and 'EOF -> o' logged, no hint" ((Has "[warn] No input at prompt (EOF) -- defaulting to overwriting from profile.json" (Log)) -and (Has "[detail] menu answer (json theme): EOF -> o" (Log)) -and (Occ "please type one of" (Console)) -eq 0)
    }
    # (without node these cases are covered by the "SKIP JSON review cases" line above)

    # The AI merge preview: EOF -> n (reject), back to the review menu; EOF
    # there -> o (overwrite). The merge is written nowhere.
    Setup-Dmf "eof-merge-preview"; Stub-Claude; W "repo/a.md" "# Title`nsource line"; W "dest/a.md" "# Title`nlocal line"
    Run-Dmf "repo/a.md" "dest/a.md" "repo/a.md" -InputText "m`n"
    Check "EOF at the merge preview: rejected (n), back to the review menu" ((Has "[warn] No input at prompt (EOF) -- defaulting to reject the merge (back to the review menu)" (Log)) -and (Has "[detail] menu answer (merge preview a.md): EOF -> n" (Log)) -and (Has "merge rejected -- back to the review menu" (Console)) -and ((Occ "[detail] menu answer (review a.md): " (Log)) -eq 2))
    Check "EOF at the merge preview, then at the review menu: overwrite, the merge not written" ((DmfIs "updated") -and (Has "[detail] menu answer (review a.md): EOF -> o" (Log)) -and (FileIs "dest/a.md" "# Title`nsource line") -and -not (Has "merged line" (Txt "dest/a.md")) -and -not (Has "merged line" (Txt "repo/a.md")))

    # The [r]efine feedback read: EOF -> empty feedback, the merge is refined
    # (a second AI call); then EOF at the preview rejects it and EOF at the
    # review menu overwrites.
    Setup-Dmf "eof-refine"; Stub-Claude; W "repo/a.md" "# Title`nsource line"; W "dest/a.md" "# Title`nlocal line"
    Run-Dmf "repo/a.md" "dest/a.md" "repo/a.md" -InputText "m`nr`n"
    $aiCalls = Txt "bin/calls.txt"
    Check "EOF at the refine feedback: warning logged, the refine prompt has empty feedback" ((Has "[warn] No input at prompt (EOF) -- defaulting to no feedback" (Log)) -and ((Occ "You are refining" $aiCalls) -eq 1) -and ($aiCalls -match '## User Feedback\s*## Rules'))
    Check "EOF at the refine feedback: the merge refined (AI called twice), then EOF rejects it and EOF overwrites" (((Occ "==CALL==" $aiCalls) -eq 2) -and (Has '[detail] menu answer (merge preview a.md): "r" -> r' (Log)) -and (Has "[detail] menu answer (merge preview a.md): EOF -> n" (Log)) -and (Has "[detail] menu answer (review a.md): EOF -> o" (Log)) -and (DmfIs "updated") -and (FileIs "dest/a.md" "# Title`nsource line") -and -not (Has "merged line" (Txt "repo/a.md")))

    # --- On a real console (pty): an empty answer re-asks, then s ---
    if ($havePty) {
        Setup-Dmf "dmf-pty"; W "src.md" "new"; W "dest/a.md" "old"
        Run-Dmf "src.md" "dest/a.md" "repo/a.md" -InputText '\ns\n' -Mode "pty"
        # ConPTY may repeat a line it already sent: the hint count is a minimum here
        Check "pty: empty re-asks, then s -> skipped, LOCAL unchanged" ((DmfIs "skipped") -and (FileIs "dest/a.md" "old"))
        Check "pty: the hint reached the terminal" ((Occ "please type one of o/a/m/s/x" (Txt "out")) -ge 1)
        Check "pty: both answers logged" ((Has '[detail] menu answer (review a.md): "" -> not one of o/a/m/s/x, asked again' (Log)) -and (Has '[detail] menu answer (review a.md): "s" -> s' (Log)))
    } else {
        Write-Output "SKIP pty case (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)"; $script:skip++
    }

    # ======================================================================
    # The [RELAY] prompt: Read-RelayOutboundChoice reads through Read-MenuChoice
    # ======================================================================
    # --- Library loaded by the caller (scripts/aitools.ps1) ---
    Run-Relay "relay-lib-reask" "x`n`nquit`n" -WithLib
    Check "relay (lib loaded by caller): 'x' and empty re-ask, then 'quit' -> quit (one value)" ((Rc) -eq "0" -and (Txt "count") -eq "1" -and (Txt "result") -ceq "quit")
    Check "relay (lib loaded by caller): 2 hints '$relayHint'" ((Occ $relayHint (Console)) -eq 2)
    Check "relay (lib loaded by caller): prompt '  choice [c/q/s]: ' asked 3 times" ((Occ "  choice [c/q/s]: " (Console)) -eq 3)
    Check "relay (lib loaded by caller): answers logged in the caller's log" ((Has '[t] [detail] menu answer (relay outbound): "x" -> not one of c/continue/q/quit/s/show, asked again' (Log)) -and (Has '[t] [detail] menu answer (relay outbound): "quit" -> quit' (Log)))

    # --- Library loaded by the prompt itself (hh.ps1) ---
    Run-Relay "relay-hh-c" "C`n"
    Check "relay (hh path): 'C' -> continue (one value), no hint" ((Rc) -eq "0" -and (Txt "count") -eq "1" -and (Txt "result") -ceq "continue" -and (Occ "please type one of" (Console)) -eq 0)
    Check "relay (hh path): answer logged as relay-outbound" (Has '[relay-outbound] [detail] menu answer (relay outbound): "C" -> c' (Log))
    Check "relay (hh path): the lib's functions do not outlive the call" ((Txt "leaked") -eq "False")

    Run-Relay "relay-hh-s" " s `n"
    Check "relay (hh path): ' s ' -> show" ((Txt "result") -ceq "show")

    Run-Relay "relay-hh-q" "maybe`nq`n"
    Check "relay (hh path): 'maybe' re-asks, then q -> quit" ((Txt "result") -ceq "quit" -and (Occ $relayHint (Console)) -eq 1)

    Run-Relay "relay-hh-eof" ""
    Check "relay (hh path): EOF -> continue (one value)" ((Rc) -eq "0" -and (Txt "count") -eq "1" -and (Txt "result") -ceq "continue")
    Check "relay (hh path): EOF warning and 'EOF -> c' logged" ((Has "[warn] No input at prompt (EOF) -- defaulting to continue" (Log)) -and (Has "[detail] menu answer (relay outbound): EOF -> c" (Log)))

    Run-Relay "relay-hh-50" ("x`n" * 50)
    Check "relay (hh path): 50 unrecognised answers -> continue, warning, 49 hints" ((Txt "result") -ceq "continue" -and (Has "[warn] No valid answer after 50 tries at relay outbound -- treating input as ended, defaulting to continue" (Log)) -and (Occ $relayHint (Console)) -eq 49)

    # --- Without the library next to the prompt: the local loop ---
    $soloDir = Join-Path $tmpRoot "relay-solo"
    New-Item -ItemType Directory -Path $soloDir -Force | Out-Null
    $soloRelay = Join-Path $soloDir "relay-outbound-prompt.ps1"
    Copy-Item -LiteralPath $relayScript -Destination $soloRelay
    Run-Relay "relay-nolib-q" "x`nQ`n" -Relay $soloRelay
    Check "relay (no lib): 'x' re-asks, then 'Q' -> quit, said why" ((Txt "result") -ceq "quit" -and (Occ $relayHint (Console)) -eq 1 -and (Has "aitools-lib.ps1 not found next to this script" (Console)))
    Check "relay (no lib): nothing logged" (NoLog)
    Run-Relay "relay-nolib-eof" "" -Relay $soloRelay
    Check "relay (no lib): EOF -> continue, '(no input -- continuing)'" ((Txt "result") -ceq "continue" -and (Has "(no input -- continuing)" (Console)))

    # --- Windows PowerShell 5.1 (hh.ps1 may run there) ---
    $ps51 = $null
    if ($IsWindows) {
        # Get-Command exempt: command-existence check; the cases SKIP without it
        $ps51 = Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    }
    if ($ps51) {
        $parse51 = Join-Path $tmpRoot "parse51.ps1"
        [IO.File]::WriteAllText($parse51, '$e = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile($args[0], [ref]$null, [ref]$e); "errors=$(@($e).Count)"')
        $p51 = (& $ps51 -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $parse51 $relayScript | Out-String).Trim()
        Check "relay (PS 5.1): relay-outbound-prompt.ps1 parses" ($p51 -eq "errors=0")
        $ascii = -not ([IO.File]::ReadAllText($relayScript) -match '[^\x00-\x7F]')
        Check "relay (PS 5.1): relay-outbound-prompt.ps1 is ASCII (5.1 reads a file without a BOM as ANSI)" $ascii
        Run-Relay "relay-ps51" "x`ns`n" -Exe $ps51
        Check "relay (PS 5.1, hh path): 'x' re-asks, then s -> show (one value)" ((Rc) -eq "0" -and (Txt "count") -eq "1" -and (Txt "result") -ceq "show" -and (Occ $relayHint (Console)) -eq 1)
        Check "relay (PS 5.1, hh path): answers logged" (Has '[relay-outbound] [detail] menu answer (relay outbound): "s" -> s' (Log))
    } else {
        Write-Output "SKIP relay PS 5.1 cases (Windows PowerShell not available)"; $script:skip++
    }

    # --- On a real console (pty): the read runs in cooked mode, the raw mode is put back ---
    if ($havePty -and $IsWindows) {
        $script:C = Join-Path $tmpRoot "relay-pty"
        $C = $script:C
        foreach ($d in @("home", "logs", "repo/.aitools/channel")) { New-Item -ItemType Directory -Path (Join-Path $C $d) -Force | Out-Null }
        & git -C (Join-Path $C "repo") init -q
        if ($LASTEXITCODE -ne 0) { throw "git init failed in $C" }
        W "repo/.aitools/channel/relay.md" "# relay"
        $snip = Join-Path $C "snippet.ps1"
        [IO.File]::WriteAllText($snip, $relayPtyChild)
        $vars = @{
            HOME = (Join-Path $C "home"); USERPROFILE = (Join-Path $C "home")
            AITOOLS_LOG_DIR = (Join-Path $C "logs"); MC_LIB = $lib; MC_C = $C
            RO_RELAY = $relayScript; RO_REPO = (Join-Path $C "repo")
            CI = $null; AITOOLS_SKIP_RELAY_PROMPT = $null; RELAY_PROMPT_FORCE = $null; TERM = "xterm"
        }
        $old = @{}
        foreach ($k in $vars.Keys) { $old[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
        try {
            & python3 $pty --input 'x\nq\n' --log (Join-Path $C "out") --timeout 60 -- $pwshExe -NoProfile -File $snip
            Set-Content -Path (Join-Path $C "rc") -Value $LASTEXITCODE
        } finally {
            foreach ($k in $old.Keys) { [Environment]::SetEnvironmentVariable($k, $old[$k]) }
        }
        $res = Txt "result"
        $m = [regex]::Match($res, 'rc=(\d+) before=(\d+) raw=(\d+) setrc=(\d+) after=(-?\d+)')
        Check "relay pty: the console was set raw before the prompt" ($m.Success -and $m.Groups[4].Value -eq "0" -and (([long]$m.Groups[3].Value -band 0x6) -eq 0))
        if (-not $m.Success) { Write-Output "      result| $res" }
        Check "relay pty: [RELAY] shown, 'x' re-asks, then q -> 2 (quit)" ($m.Success -and $m.Groups[1].Value -eq "2" -and (Has "[RELAY]" (Txt "out")) -and (Has "please type one of c/continue/q/quit/s/show" (Txt "out")))
        Check "relay pty: the reads ran in cooked mode (Read-ConsoleChoice saw line input / echo off)" ((Occ "at prompt (line input or echo off) -- read in cooked mode" (Log)) -ge 2)
        Check "relay pty: the raw mode is put back after the prompt" ($m.Success -and $m.Groups[5].Value -eq $m.Groups[3].Value)
        Check "relay pty: both answers logged" ((Has '[relay-outbound] [detail] menu answer (relay outbound): "x" -> not one of c/continue/q/quit/s/show, asked again' (Log)) -and (Has '[relay-outbound] [detail] menu answer (relay outbound): "q" -> q' (Log)))
    } else {
        Write-Output "SKIP relay pty case (Windows console API, and a pseudo-terminal: pywinpty)"; $script:skip++
    }
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}

Write-Output ""
Write-Output "$($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
