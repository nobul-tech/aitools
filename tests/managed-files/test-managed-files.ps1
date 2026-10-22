# test-managed-files.ps1 -- tests for the managed-file model in scripts/aitools-lib.ps1:
# Deploy-ManagedFile, Prompt-DiffReview, Review-JsonFields, the tracker, and the
# [x]abort (exit 2). Mirror of tests/managed-files/test-managed-files.sh.
#
# Safe to re-run: every case runs in a child pwsh with its own temp HOME/log dir,
# removed on exit. Interactive cases run on a pseudo-terminal
# (tests/managed-files/pty-run.py, python3; skipped on Windows). The AI merge
# uses a stub `claude` on PATH; no real AI is called.
# Platform: macOS, Linux (pwsh 7); Windows runs the non-interactive cases.
# Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 12 | Select-Object -Skip 1; exit 0 }

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$lib = Join-Path $root "scripts/aitools-lib.ps1"
$pty = Join-Path $root "tests/managed-files/pty-run.py"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("mf-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
$pwshExe = (Get-Process -Id $PID).Path

$script:pass = 0; $script:fail = 0; $script:skip = 0
$havePty = (-not $IsWindows) -and [bool](Get-Command python3 -ErrorAction SilentlyContinue)
# Get-Command exempt: command-existence check; $havePty is the fallback branch

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++ }
    else {
        Write-Output "FAIL $Name"; $script:fail++
        $outFile = Join-Path $script:C "out"
        if (Test-Path $outFile) {
            (Get-Content $outFile -Tail 25) | ForEach-Object { Write-Output ("      | " + ($_ -replace "`e\[[0-9;]*m", "")) }
        }
    }
}

function Setup-Case([string]$Name) {
    $script:C = Join-Path $tmpRoot $Name
    foreach ($d in @("home", "dest", "repo", "bin", "logs")) { New-Item -ItemType Directory -Path (Join-Path $script:C $d) -Force | Out-Null }
    & git -C (Join-Path $script:C "repo") init -q
    if ($LASTEXITCODE -ne 0) { throw "git init failed in $script:C" }
    Set-Content -Path (Join-Path $script:C "summary") -Value "" -NoNewline
}

function Stub-Claude([string]$Kind) {
    $text = if ($Kind -eq "good") { "# Title`nmerged line" } else { "Sure, here is the merge" }
    $stub = "#!/usr/bin/env bash`ncat > /dev/null`nprintf '%s\n' '$($text -replace "`n", "' '")'`n"
    $path = Join-Path $script:C "bin/claude"
    [IO.File]::WriteAllText($path, $stub)
    & chmod +x $path
}

# Run-Lib <snippet> [input]: dot-source the lib in a child pwsh under the case HOME.
# Terminal for the review-diff colour: TERM=$Term (default xterm); NO_COLOR is
# unset unless -NoColor is given.
function Run-Lib([string]$Snippet, [string]$InputKeys = "", [string]$Term = "xterm", [string]$NoColor = "") {
    $C = $script:C
    $body = @"
. '$lib'
Initialize-Logging "t"
`$C = '$C'
$Snippet
"@
    $snip = Join-Path $C "snippet.ps1"
    [IO.File]::WriteAllText($snip, $body)
    $oldHome = $env:HOME; $oldLog = $env:AITOOLS_LOG_DIR; $oldSum = $env:AITOOLS_SUMMARY_FILE; $oldPath = $env:PATH
    $oldTerm = $env:TERM; $oldNoColor = $env:NO_COLOR
    $env:HOME = Join-Path $C "home"; $env:USERPROFILE = $env:HOME
    $env:AITOOLS_LOG_DIR = Join-Path $C "logs"; $env:AITOOLS_SUMMARY_FILE = Join-Path $C "summary"
    $env:PATH = (Join-Path $C "bin") + [IO.Path]::PathSeparator + $oldPath
    $env:TERM = $Term
    $env:NO_COLOR = if ($NoColor) { $NoColor } else { $null }
    try {
        if ($InputKeys) {
            & python3 $pty --input $InputKeys --log (Join-Path $C "out") -- $pwshExe -NoProfile -File $snip
        } else {
            $null | & $pwshExe -NoProfile -NonInteractive -File $snip *> (Join-Path $C "out")
        }
        Set-Content -Path (Join-Path $C "rc") -Value $LASTEXITCODE
    } finally {
        $env:HOME = $oldHome; $env:AITOOLS_LOG_DIR = $oldLog; $env:AITOOLS_SUMMARY_FILE = $oldSum; $env:PATH = $oldPath
        $env:TERM = $oldTerm; $env:NO_COLOR = $oldNoColor
    }
}

$esc = [string][char]27
function Out { $f = Join-Path $script:C "out"; if (Test-Path $f) { Get-Content $f -Raw } else { "" } }
# Plain: the terminal output as lines, without colour/terminal codes and carriage returns
function Plain { @(((Out) -replace "$esc\[[0-9;?]*[A-Za-z]", "" -replace "$esc[=>]", "" -replace "`r", "") -split "`n") }
function HasLine([string]$Line) { (Plain) -ccontains $Line }

function Result { $f = Join-Path $script:C "result"; if (Test-Path $f) { (Get-Content $f -Raw).Trim() } else { "" } }
function Rc { (Get-Content (Join-Path $script:C "rc") -Raw).Trim() }
function Txt([string]$Rel) { $f = Join-Path $script:C $Rel; if (Test-Path $f) { (Get-Content $f -Raw) -replace '[\r\n]+$', '' } else { $null } }
function Log { $f = Join-Path $script:C "logs/deploy.log"; if (Test-Path $f) { Get-Content $f -Raw } else { "" } }
function JsonCompact([string]$Rel) { & node -e 'console.log(JSON.stringify(JSON.parse(require("fs").readFileSync(process.argv[1]))))' (Join-Path $script:C $Rel) }
function W([string]$Rel, [string]$Text) { [IO.File]::WriteAllText((Join-Path $script:C $Rel), "$Text`n") }

$dmf = '$r = Deploy-ManagedFile -Content ([IO.File]::ReadAllText($src)) -DestPath $dest -ToolName "tool" -ItemName "item" -AdoptPath $adopt; Set-Content -Path "$C/result" -Value $r -NoNewline'

try {
    # --- Text, non-interactive ---
    Setup-Case "created"; W "src.md" "hello"
    Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt=''; $dmf"
    Check "created: missing LOCAL is written" ((Result) -eq "created" -and (Txt "dest/a.md") -eq "hello")
    Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt=''; $dmf"
    Check "verified: LOCAL == SOURCE writes nothing" ((Result) -eq "verified")

    Setup-Case "case-only"; W "src.md" "Hello"; W "dest/a.md" "hello"
    Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt=''; $dmf"
    Check "case-only edit is a difference (case-sensitive compare)" ((Result) -eq "updated" -and (Txt "dest/a.md") -ceq "Hello")

    Setup-Case "overwrite"; W "src.md" "new"; W "dest/a.md" "old"
    Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf"
    Check "non-interactive: SOURCE overwrites LOCAL" ((Result) -eq "updated" -and (Txt "dest/a.md") -eq "new")
    Check "non-interactive: LOCAL backed up, adopt target untouched" ((@(Get-ChildItem "$C/dest" -Filter "a.md.bak.*").Count -ge 1) -and -not (Test-Path "$C/repo/a.md"))
    Check "non-interactive: no review diff, no colour" (-not (Out).Contains("this machine") -and -not (Out).Contains("$esc[31m") -and -not (Out).Contains("$esc[32m"))

    if (-not $IsWindows) {
        Setup-Case "readonly-dir"; W "src.md" "x"; New-Item -ItemType Directory -Path "$C/dest/ro" | Out-Null; & chmod 555 "$C/dest/ro"
        Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/ro/new.md'; `$adopt=''; $dmf; `$r2 = Deploy-ManagedFile -Content 'y' -DestPath '$C/dest/b.md' -ToolName tool -ItemName b; Set-Content -Path '$C/result2' -Value `$r2 -NoNewline"
        Check "write failure: failed, nothing left" ((Result) -eq "failed" -and -not (Test-Path "$C/dest/ro/new.md"))
        Check "write failure: the run continues" ((Txt "result2") -eq "created")
        & chmod 755 "$C/dest/ro"
    }

    Setup-Case "tracker"
    Run-Lib 'Initialize-DeployTracker; Record-DeployOutcome -Outcome failed -ToolName tool -ItemName x.md; Write-DeployTrackerSummary -ToolName tool'
    $sum = Get-Content "$C/summary" -Raw
    Check "tracker: failed -> DETAIL + ERROR row" ($sum -match "DETAIL\|tool\|failed: x.md" -and $sum -match "ERROR\|tool\|1 failed")

    # --- JSON ---
    Setup-Case "json-noninteractive"; W "repo/c.json" '{"a":1,"b":2}'; W "dest/c.json" '{"z":0,"b":3,"a":1}'
    Run-Lib "`$src='$C/repo/c.json'; `$dest='$C/dest/c.json'; `$adopt='$C/repo/c.json'; $dmf"
    Check "json non-interactive: field written, LOCAL-only kept, order kept" ((Result) -eq "updated" -and (JsonCompact "dest/c.json") -eq '{"z":0,"b":2,"a":1}')
    Check "json non-interactive: repo untouched" ((Txt "repo/c.json") -eq '{"a":1,"b":2}')

    Setup-Case "json-invalid"; W "src.json" '{"a":1}'; W "dest/c.json" 'not json'
    Run-Lib "`$src='$C/src.json'; `$dest='$C/dest/c.json'; `$adopt=''; $dmf"
    Check "json: invalid LOCAL -> failed, untouched" ((Result) -eq "failed" -and (Txt "dest/c.json") -eq "not json")

    # --- EOF at a prompt ---
    # Not sent as Ctrl-D on the pty: EOF there is terminal-driver behavior (Ctrl-D on
    # Unix, Ctrl-Z Enter on Windows) and pwsh on Linux does not end ReadLine on \x04.
    # An empty Console.In gives Read-ConsoleChoice the same $null on every platform.
    Setup-Case "eof"
    Run-Lib '[Console]::SetIn([IO.StringReader]::new([string]::Empty)); $r = Read-ConsoleChoice "overwrite"; Set-Content -Path "$C/result" -Value "[$r]" -NoNewline'
    Check "EOF at a prompt: empty choice, warning logged" ((Result) -eq "[]" -and (Log) -match "No input at prompt \(EOF\) -- defaulting to overwrite")

    # --- Interactive (pty) ---
    if ($havePty) {
        Setup-Case "enter"; W "src.md" "new"; W "dest/a.md" "old"
        Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf" "\n"
        Check "empty choice at the menu: overwrite" ((Result) -eq "updated" -and (Txt "dest/a.md") -eq "new")

        Setup-Case "skip"; W "src.md" "new"; W "dest/a.md" "old"
        Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf" "s\n"
        Check "skip: nothing written" ((Result) -eq "skipped" -and (Txt "dest/a.md") -eq "old")

        Setup-Case "adopt"; W "repo/a.md" "source"; W "dest/a.md" "local edit"
        Run-Lib "`$src='$C/repo/a.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf" "a\n"
        Check "adopt: LOCAL kept, copied to the repo" ((Result) -eq "accept & adopt" -and (Txt "repo/a.md") -eq "local edit" -and (Txt "dest/a.md") -eq "local edit")
        Run-Lib "`$src='$C/repo/a.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf"
        Check "adopt: next run verifies" ((Result) -eq "verified")

        Setup-Case "filter"; W "repo/a.md" "TEMPLATE"; W "dest/a.md" "body`nFOOTER"
        Run-Lib "`$f = { param(`$c) (`$c -split ""``n"" | Where-Object { `$_ -notmatch '^FOOTER' }) -join ""``n"" }; `$r = Deploy-ManagedFile -Content 'TEMPLATE' -DestPath '$C/dest/a.md' -ToolName tool -ItemName item -AdoptPath '$C/repo/a.md' -AdoptFilter `$f; Set-Content -Path '$C/result' -Value `$r -NoNewline" "a\n"
        Check "adopt filter: the repo gets the filtered LOCAL" ((Result) -eq "accept & adopt" -and (Txt "repo/a.md") -eq "body")

        Setup-Case "merge"; Stub-Claude "good"; W "repo/a.md" "# Title`nsource line"; W "dest/a.md" "# Title`nlocal line"
        Run-Lib "`$src='$C/repo/a.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf" "m\ny\n"
        Check "merge & adopt: merge in LOCAL and the repo" ((Result) -eq "accept & adopt" -and (Txt "dest/a.md") -match "merged line" -and (Txt "dest/a.md") -eq (Txt "repo/a.md"))
        Run-Lib "`$src='$C/repo/a.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf"
        Check "merge & adopt: next run verifies" ((Result) -eq "verified")

        Setup-Case "merge-reject"; Stub-Claude "good"; W "repo/a.md" "# Title`nsource line"; W "dest/a.md" "# Title`nlocal line"
        Run-Lib "`$src='$C/repo/a.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf" "m\nn\ns\n"
        # The read after the menu returns is not asserted: under this pty harness the
        # console input after the AI spinner job (Start-Job) comes back corrupted
        # (open observation, see the mission report). Asserted: the menu is shown
        # again and the rejected merge is not written.
        $menus = ([regex]::Matches((Get-Content "$C/out" -Raw), [regex]::Escape("choice [o/a/m/s/x]"))).Count
        Check "merge [n]o: back to the menu, merge not written" ($menus -ge 2 -and (Txt "dest/a.md") -notmatch "merged line" -and (Txt "repo/a.md") -match "source line")

        Setup-Case "merge-fail"; Stub-Claude "bad"; W "repo/a.md" "# Title`nsource line"; W "dest/a.md" "# Title`nlocal line"
        Run-Lib "`$src='$C/repo/a.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf" "m\n"
        Check "failed AI merge: failed, nothing written" ((Result) -eq "failed" -and (Txt "dest/a.md") -match "local line" -and (Txt "repo/a.md") -match "source line")

        Setup-Case "merge-restore"; Stub-Claude "good"; W "repo/a.md" "# Title`nsource line"; W "dest/a.md" "# Title`nlocal line"; & chmod 444 "$C/repo/a.md"
        Run-Lib "`$src='$C/repo/a.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf" "m\ny\n"
        Check "adopt-target write failure: LOCAL restored, failed" ((Result) -eq "failed" -and (Txt "dest/a.md") -match "local line")
        & chmod 644 "$C/repo/a.md"

        Setup-Case "abort"; W "src.md" "new"; W "dest/a.md" "old"
        Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt=''; $dmf" "x\n"
        Check "abort: exit 2, error logged, LOCAL unchanged" ((Rc) -eq "2" -and (Log) -match "Aborted by user" -and (Txt "dest/a.md") -eq "old")

        Setup-Case "json-fields"; W "repo/c.json" '{"a":1,"b":2,"c":3}'; W "dest/c.json" '{"a":9,"b":8,"c":7,"z":0}'
        Run-Lib "`$src='$C/repo/c.json'; `$dest='$C/dest/c.json'; `$adopt='$C/repo/c.json'; $dmf" "o\na\ns\na\n"
        Check "json per-field: overwrite/adopt/skip + LOCAL-only adopt" ((JsonCompact "dest/c.json") -eq '{"a":1,"b":8,"c":7,"z":0}' -and (JsonCompact "repo/c.json") -eq '{"a":1,"b":8,"c":3,"z":0}' -and (Result) -eq "accept & adopt")

        # --- Review display: LOCAL -> SOURCE, labelled, coloured (mission DIFF-UX) ---
        Setup-Case "display"; W "repo/a.md" "# Title`nline one`nrepo line`nend"; W "dest/a.md" "# Title`nline one`nmy local line`nend"
        Run-Lib "`$src='$C/repo/a.md'; `$dest='$C/dest/a.md'; `$adopt='$C/repo/a.md'; $dmf" "s\n"
        Check "display: diff is LOCAL -> SOURCE (- this machine, + repo)" ((HasLine "-my local line") -and (HasLine "+repo line") -and -not (HasLine "+ local  my local line"))
        Check "display: headers name both paths, padded" ((HasLine "--- this machine  $C/dest/a.md") -and (HasLine "+++ repo          $C/repo/a.md"))
        $pl = Plain
        $legendAt = [array]::IndexOf($pl, "  red - = only on this machine   green + = only in the repo")
        $headerAt = [array]::IndexOf($pl, "--- this machine  $C/dest/a.md")
        Check "display: legend above the diff" ($legendAt -ge 0 -and $legendAt -lt $headerAt)
        Check "display: menu says what each choice does to the lines" ((HasLine "  [o]verwrite       : this machine gets the green + lines (backup kept)") -and (HasLine "  [a]ccept & adopt  : the repo gets the red - lines (your version) -> $C/repo/a.md") -and (HasLine "  [m]erge & adopt   : AI combines both; written to this machine and $C/repo/a.md") -and (HasLine "  [s]kip            : nothing written; asked again next run") -and (HasLine "  [x]abort          : stop this script (exit 2)"))
        Check "display: red - lines and header, green + lines and header" ((Out).Contains("$esc[31m-my local line$esc[0m") -and (Out).Contains("$esc[32m+repo line$esc[0m") -and (Out).Contains("$esc[31m--- this machine") -and (Out).Contains("$esc[32m+++ repo"))
        Check "display: full diff in the log, plain text" ((Log).Contains("diff a.md: --- this machine  $C/dest/a.md") -and (Log).Contains("diff a.md: -my local line") -and (Log).Contains("diff a.md: +repo line") -and -not (Log).Contains($esc))
        Check "display: choice unchanged (skip)" ((Result) -eq "skipped" -and (Txt "dest/a.md") -match "my local line")

        Setup-Case "display-nocolor"; W "src.md" "new"; W "dest/a.md" "old"
        Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt=''; $dmf" "s\n" -NoColor "1"
        Check "display NO_COLOR: no colour, same lines" (-not (Out).Contains("$esc[31m") -and -not (Out).Contains("$esc[32m") -and (HasLine "-old") -and (HasLine "+new"))
        Check "display, no adopt target: SOURCE header is embedded, menu [o/s/x]" ((HasLine "+++ repo          source (embedded)") -and (HasLine "  [o]verwrite       : this machine gets the green + lines (backup kept)") -and -not (Out).Contains("accept & adopt"))

        Setup-Case "display-dumb"; W "src.md" "new"; W "dest/a.md" "old"
        Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt=''; $dmf" "s\n" -Term "dumb"
        Check "display TERM=dumb: no colour" (-not (Out).Contains("$esc[31m") -and -not (Out).Contains("$esc[32m") -and (HasLine "-old"))

        Setup-Case "display-long"
        W "dest/a.md" ((1..50 | ForEach-Object { "local $_" }) -join "`n"); W "src.md" ((1..50 | ForEach-Object { "repo $_" }) -join "`n")
        Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt=''; $dmf" "s\n"
        # 103 diff lines: 2 headers + 1 hunk header + 50 - + 50 +
        $logDiff = ([regex]::Matches((Log), "diff a\.md: ")).Count
        Check "display >40 lines: first 30 shown, rest in the log" ((HasLine "  ... (73 more lines -- full diff in deploy log)") -and (HasLine "-local 27") -and -not (HasLine "-local 28") -and $logDiff -eq 103 -and (Log).Contains("diff a.md: +repo 50"))

        Setup-Case "display-nogit"; W "src.md" "new"; W "dest/a.md" "old"
        [IO.File]::WriteAllText((Join-Path $C "bin/git"), "#!/usr/bin/env bash`nexit 128`n"); & chmod +x (Join-Path $C "bin/git")
        Run-Lib "`$src='$C/src.md'; `$dest='$C/dest/a.md'; `$adopt=''; $dmf" "s\n"
        Check "display, git diff fails: warning logged, menu still works" ((Log) -match "\[warn\] Review diff unavailable" -and (HasLine "  (diff unavailable -- see deploy log)") -and (Result) -eq "skipped")
    } else {
        Write-Output "SKIP interactive cases (no python3 pty on this platform)"; $script:skip++
    }
} finally {
    if (-not $IsWindows) { & chmod -R u+w $tmpRoot }
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}

Write-Output ""
Write-Output "$($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
