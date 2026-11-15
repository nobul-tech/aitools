# mutate.ps1 -- run tests/aitools-entry/test-console-mode-guard.ps1 against mutated
# copies of the worktree's lib / entry (temp tree; the worktree is not touched).
# Writes mutate.log in this scratch dir.
$ErrorActionPreference = "Stop"
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$sc = Join-Path $wt ".scratch\session-M3b-C1"
$base = "e8ebd07"
$iso = Join-Path $sc "iso-home"
New-Item -ItemType Directory -Force -Path $iso, (Join-Path $iso "logs") | Out-Null
$env:HOME = $iso; $env:USERPROFILE = $iso; $env:AITOOLS_LOG_DIR = Join-Path $iso "logs"

$origLib = Join-Path $sc "origin-aitools-lib.ps1"
$origEntry = Join-Path $sc "origin-aitools.ps1"
& cmd /c "git -C `"$wt`" show ${base}:scripts/aitools-lib.ps1 > `"$origLib`""
if ($LASTEXITCODE -ne 0) { throw "git show lib failed" }
& cmd /c "git -C `"$wt`" show ${base}:scripts/aitools.ps1 > `"$origEntry`""
if ($LASTEXITCODE -ne 0) { throw "git show entry failed" }

$libText = [IO.File]::ReadAllText((Join-Path $wt "scripts\aitools-lib.ps1"))
$entryText = [IO.File]::ReadAllText((Join-Path $wt "scripts\aitools.ps1"))
$testText = [IO.File]::ReadAllText((Join-Path $wt "tests\aitools-entry\test-console-mode-guard.ps1"))

function Replace-Once([string]$Text, [string]$Old, [string]$New) {
    $i = $Text.IndexOf($Old)
    if ($i -lt 0) { throw "mutation anchor not found: $Old" }
    if ($Text.IndexOf($Old, $i + 1) -ge 0) { throw "mutation anchor not unique: $Old" }
    return $Text.Substring(0, $i) + $New + $Text.Substring($i + $Old.Length)
}

$mutations = [ordered]@{
    "M0-none (control)"                         = @{ Lib = $libText; Entry = $entryText }
    "M1-no-finally-restore"                     = @{ Lib = (Replace-Once $libText '            $rc = [AitConsoleInput]::Set($saved)' '            $rc = 0'); Entry = $entryText }
    "M2-no-EnterCooked (Get instead)"           = @{ Lib = (Replace-Once $libText '        $saved = [AitConsoleInput]::EnterCooked()' '        $saved = [AitConsoleInput]::Get()'); Entry = $entryText }
    "M3-EnterCooked-without-echo"               = @{ Lib = (Replace-Once $libText '(m | ProcessedInput | LineInput | EchoInput) & ~VirtualTerminalInput' '(m | ProcessedInput | LineInput) & ~VirtualTerminalInput'); Entry = $entryText }
    "M4-compiles-with-redirected-stdin"         = @{ Lib = (Replace-Once $libText "    if ([Console]::IsInputRedirected) { return `$false }`r`n    if ('AitConsoleInput'" "    if ('AitConsoleInput'"); Entry = $entryText }
    "M5-read-outside-try"                       = @{ Lib = (Replace-Once $libText "    try {`r`n        `$line = [Console]::ReadLine()`r`n    } finally {" "    `$line = [Console]::ReadLine()`r`n    try { } finally {"); Entry = $entryText }
    "M6-entry-keeps-own-copies (origin entry)"  = @{ Lib = $libText; Entry = [IO.File]::ReadAllText($origEntry) }
    "M7-before: origin lib + origin entry"      = @{ Lib = [IO.File]::ReadAllText($origLib); Entry = [IO.File]::ReadAllText($origEntry) }
    "M8-before: origin lib + new entry"         = @{ Lib = [IO.File]::ReadAllText($origLib); Entry = $entryText }
}

$report = @()
$n = 0
foreach ($k in $mutations.Keys) {
    $n++
    $tree = Join-Path ([IO.Path]::GetTempPath()) ("m3bc1-mut-$n-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $tree "scripts"), (Join-Path $tree "tests\aitools-entry") | Out-Null
    $enc = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText((Join-Path $tree "scripts\aitools-lib.ps1"), $mutations[$k].Lib, $enc)
    [IO.File]::WriteAllText((Join-Path $tree "scripts\aitools.ps1"), $mutations[$k].Entry, $enc)
    [IO.File]::WriteAllText((Join-Path $tree "tests\aitools-entry\test-console-mode-guard.ps1"), $testText, $enc)
    $out = & pwsh -NoProfile -File (Join-Path $tree "tests\aitools-entry\test-console-mode-guard.ps1") 2>&1 | Out-String
    $rc = $LASTEXITCODE
    $fails = @($out -split "`r?`n" | Where-Object { $_ -like "FAIL *" })
    $total = ($out -split "`r?`n" | Where-Object { $_ -like "---- *" }) -join ""
    $report += "=== $k : exit=$rc $total"
    foreach ($f in $fails) { $report += "    $(if ($f.Length -gt 220) { $f.Substring(0, 220) + '...' } else { $f })" }
    Remove-Item -Recurse -Force $tree
}
$text = ($report -join "`n") + "`n"
[IO.File]::WriteAllText((Join-Path $sc "mutate.log"), $text)
$text
