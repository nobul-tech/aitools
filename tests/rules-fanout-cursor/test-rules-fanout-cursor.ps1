# test-rules-fanout-cursor.ps1 -- tests for step 4 of scripts/setup-user-cursor.ps1:
# the harness rules fan-out ~/.aitools/rules/*.md -> ~/.cursor/rules/*.mdc
# (convert, skip *.bak.* and non-.md, preserve unmanaged files, review on diff),
# driven by the rules manifest: every rule except the retired ones is fanned out
# (commander decision 2026-10-26), and the .mdc of a retired rule is removed when
# the fan-out created it. No manifest: everything fanned out, nothing removed.
# The review menu prompts on a pty and [x]abort exits 2. Also tests
# ConvertTo-CursorRule through tests/rules-fanout-cursor/convert-rule.ps1.
# The Windows harness of this suite; tests/rules-fanout-cursor/test-rules-fanout-cursor.sh
# is the macOS/Linux harness of the same cases for setup-user-cursor.sh.
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs setup-user-cursor.ps1 with native pwsh on Windows only.
# The converter cases compare with the .want texts both converters must give;
# the fan-out cases compare their exit code, ~/.cursor/rules tree and summary
# rows with the committed golden results in tests/rules-fanout-cursor/golden/,
# which the .sh harness checks on macOS/Linux (Test-GoldenMatch in
# tests/lib/platform-lib.ps1). The pty cases need python3 with pywinpty
# (tests/managed-files/pty-run.py).
#
# Safe to re-run: every case runs the real script in a child pwsh under its own
# temp HOME (removed on exit) with stub rg.cmd/agent.cmd on PATH, so no installer
# runs and the real ~/.cursor is never touched. Exit 1 if any check fails.
#
# Usage: pwsh -NoProfile -File tests/rules-fanout-cursor/test-rules-fanout-cursor.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 26 | Select-Object -Skip 1 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/rules-fanout-cursor/test-rules-fanout-cursor.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$ScriptPs1 = [IO.Path]::GetFullPath((Join-Path $root "scripts/setup-user-cursor.ps1"))
$HelperPs1 = [IO.Path]::GetFullPath((Join-Path $root "tests/rules-fanout-cursor/convert-rule.ps1"))
$tmpRoot = New-TestTempRoot "rules-fanout-cursor"
$GoldenDir = Join-Path $root "tests/rules-fanout-cursor/golden"
$GoldenTmp = $tmpRoot
$lang = "ps1"
$Utf8 = [Text.UTF8Encoding]::new($false)

$script:pass = 0; $script:fail = 0; $script:skip = 0
$script:C = $null; $script:H = $null; $script:rc = -1

# --- helpers --------------------------------------------------------------------
# PowerShell names are case-insensitive: $C/$H/$Rules are never reused in lower
# case. Helper names avoid the built-in aliases (ls, md, cat), which take
# precedence over functions. Functions that return lists return them unrolled;
# callers wrap them in @().
function Strip([string]$Text) { ($Text -replace "`e\[[0-9;]*m", "") -replace "`r", "" }
function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
function Lines([string]$Text) {  # the lines of TEXT (a final newline ends the last line)
    if ($Text -eq "") { return }
    $l = $Text -split "`n"
    if ($Text.EndsWith("`n")) { $l = $l[0..($l.Count - 2)] }
    return $l
}
function Put([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $Utf8) }
function Append([string]$Path, [string]$Text) { [IO.File]::AppendAllText($Path, $Text, $Utf8) }
function MkDirs([string[]]$Paths) { foreach ($p in $Paths) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }
function Exists([string]$Path) { Test-Path -LiteralPath $Path }

# Check NAME { condition }: the condition must give exactly one [bool]; an
# exception or any other output is a FAIL (a helper that writes to the output
# stream must not turn a FAIL into a PASS). On FAIL the last 25 lines of the
# case's output are shown, as in the .sh harness.
function Check([string]$Name, [scriptblock]$Cond) {
    $why = ""
    try {
        $res = @(& $Cond)
        $ok = ($res.Count -eq 1 -and $res[0] -is [bool] -and $res[0])
        if ($res.Count -ne 1 -or $res[0] -isnot [bool]) { $why = "condition gave $($res.Count) value(s): $($res -join ', ')" }
    } catch {
        $ok = $false; $why = "condition threw: $($_.Exception.Message)"
    }
    if ($ok) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if ($why) { Write-Output "      | $why" }
    if ($script:C) {
        $out = Join-Path $script:C "out"
        if (Test-Path -LiteralPath $out) {
            @((Strip (ReadText $out)) -split "`n") | Select-Object -Last 25 | ForEach-Object { Write-Output "      | $_" }
        }
    }
}
function Skip([string]$Text) { Write-Output "SKIP $Text"; $script:skip++ }

# Setup-Case NAME: fresh HOME and stub bin (rg, agent: version only, as .cmd
# files native pwsh can run).
function Setup-Case([string]$Name) {
    $script:C = Join-Path $tmpRoot $Name
    $script:H = Join-Path $script:C "home"
    MkDirs @($script:H, (Join-Path $script:C "bin"))
    [IO.File]::WriteAllText((Join-Path $script:C "bin/rg.cmd"), "@echo ripgrep 14.1.0`r`n")
    [IO.File]::WriteAllText((Join-Path $script:C "bin/agent.cmd"), "@echo 2026.05.21-stub`r`n")
    Put (Join-Path $script:C "summary") ""
}

# Manifest LINE...: ~/.aitools/rules/.aitools-rules-manifest (PR #100 contract:
# v1 header, then "<name><TAB><source>" lines); "|" in a LINE stands for the TAB
function Manifest([string[]]$Lines = @()) {
    MkDirs @("$H/.aitools/rules")
    $t = "# aitools rules manifest v1`n"
    foreach ($l in $Lines) { $t += ($l -replace '\|', "`t") + "`n" }
    Put "$H/.aitools/rules/.aitools-rules-manifest" $t
}

# Seed-Rules: a harness rules directory covering every source shape
function Seed-Rules {
    Manifest @("plain.md|shared", "scoped.md|dotprofile")
    MkDirs @("$H/.aitools/rules/subdir")
    Put "$H/.aitools/rules/plain.md" "## Plain rule`n`nAlways loaded.`n"
    Put "$H/.aitools/rules/scoped.md" "---`npaths:`n  - scripts/**`n  - `"shared/**`"`n---`n`n## Scoped rule`n`nBody with a table:`n`n| a | b |`n|---|---|`n"
    Put "$H/.aitools/rules/native.mdc" "---`ndescription: native cursor rule`nalwaysApply: false`n---`nNative body.`n"
    Put "$H/.aitools/rules/notes.txt" "not a rule`n"
    # backups deploy-harness's Deploy-ManagedFile leaves next to updated files
    Put "$H/.aitools/rules/plain.md.bak.2026-10-22T010203Z" "old plain`n"
    Put "$H/.aitools/rules/odd.bak.2026.md" "old odd`n"
    Put "$H/.aitools/rules/.hidden.md" "hidden`n"
    Put "$H/.aitools/rules/subdir/nested.md" "nested`n"
}

# Run-Script [-DryRun] [-Force]: the whole setup-user-cursor.ps1 in a child
# pwsh, non-interactive (stdin at EOF), under the case HOME. AITOOLS_FORCE and
# AITOOLS_DRY_RUN are removed so a value in the runner's environment cannot
# change a case (the .sh harness inherited them; neither is set in CI).
function Run-Script([string[]]$ScriptArgs = @()) {
    $envs = @{
        HOME = $H; USERPROFILE = $H
        AITOOLS_LOG_DIR = (Join-Path $C "logs"); AITOOLS_SUMMARY_FILE = (Join-Path $C "summary")
        PATH = (Join-Path $C "bin") + [IO.Path]::PathSeparator + $env:PATH
        AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null
    }
    $argv = @("-NoProfile", "-NonInteractive", "-File", $ScriptPs1) + $ScriptArgs
    $script:rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList $argv -Environment $envs -OutFile (Join-Path $C "out")
}

# Output, log and summary readers (ANSI colour codes and CRs removed, as the
# .sh harness's strip_cr did for the pwsh output and summary).
function OutText { Strip (ReadText (Join-Path $C "out")) }
function OutMatch([string]$Pattern) { [regex]::IsMatch((OutText), $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline) }
function OutCount([string]$Pattern) { @((Lines (OutText)) | Where-Object { $_ -cmatch $Pattern }).Count }
function SumLines([string]$File = (Join-Path $C "summary")) { Lines ((ReadText $File) -replace "`r", "") }
function SumHas([string]$Line) { @(SumLines) -ccontains $Line }
function SumCount([string]$Line) { @(SumLines | Where-Object { $_ -ceq $Line }).Count }
function SumContains([string]$Text) { [bool](@(SumLines) | Where-Object { $_.Contains($Text) }) }
function SumMatch([string]$Pattern) { [bool](@(SumLines) | Where-Object { $_ -cmatch $Pattern }) }
# Row [FILE]: the last "cursor rules" row that is not DETAIL ("" when none)
function Row([string]$File = (Join-Path $C "summary")) {
    $r1 = @(SumLines $File | Where-Object { $_.Contains("|cursor rules|") -and -not $_.StartsWith("DETAIL") })
    if ($r1.Count) { $r1[-1] } else { "" }
}
# File readers, raw (no CR removed: the converted files are LF on every platform)
function FileHasLine([string]$Path, [string]$Line) { (Exists $Path) -and (@(Lines (ReadText $Path)) -ccontains $Line) }
function FileMatch([string]$Path, [string]$Pattern) { (Exists $Path) -and [regex]::IsMatch((ReadText $Path), $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline) }
function FileContains([string]$Path, [string]$Text) { (Exists $Path) -and (ReadText $Path).Contains($Text) }
function CatText([string]$Path) { (ReadText $Path) -replace "`n+\z", "" }   # as "$(cat FILE)"
function Head([string]$Path, [int]$N) { (@(Lines (ReadText $Path)) | Select-Object -First $N) -join "`n" }
# ListNames DIR: the names in DIR as `ls` lists them (no dot files), ordinal order
function ListNames([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return }
    $n = [string[]]@(Get-ChildItem -LiteralPath $Dir -Force | ForEach-Object { $_.Name } | Where-Object { -not $_.StartsWith(".") })
    [Array]::Sort($n, [StringComparer]::Ordinal)
    return $n
}
function LsAny([string]$Dir, [string]$Pattern) { [bool](@(ListNames -Dir $Dir) | Where-Object { $_ -cmatch $Pattern }) }
# SameBytes A B: as `cmp -s A B` (both files exist, same bytes)
function SameBytes([string]$A, [string]$B) {
    if (-not (Test-Path -LiteralPath $A -PathType Leaf) -or -not (Test-Path -LiteralPath $B -PathType Leaf)) { return $false }
    return ([Convert]::ToHexString([IO.File]::ReadAllBytes($A)) -ceq [Convert]::ToHexString([IO.File]::ReadAllBytes($B)))
}

# Conv IN OUT [NAME]: ConvertTo-CursorRule on file IN, written to OUT, through
# convert-rule.ps1 (the function is loaded from setup-user-cursor.ps1's AST;
# the script body and its guard never run). It is also the fixture generator of
# the fan-out cases. With a NAME the aitools-fanout marker is written.
function Conv([string]$In, [string]$Out, [string]$Name = "") {
    if (Test-Path -LiteralPath $Out) { Remove-Item -LiteralPath $Out -Force }
    $log = Join-Path $tmpRoot "conv-ps.log"
    $argv = @("-NoProfile", "-NonInteractive", "-File", $HelperPs1, $ScriptPs1, $In, $Out)
    if ($Name) { $argv += $Name }   # no empty argument: convert-rule.ps1 defaults it to ""
    $code = Invoke-TestScript -FilePath $pwshExe -OutFile $log -ArgumentList $argv
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $Out -PathType Leaf)) {
        Write-Host "conv: convert-rule.ps1 failed on ${In}:"
        Write-Host (ReadText $log)
    }
}

try {
    # --- converter golden cases (via the script's own function) ------------------
    $Gold = Join-Path $tmpRoot "gold"
    MkDirs @($Gold)
    Put "$Gold/nofm.md" "Body line`n"
    Put "$Gold/nofm.want" "---`nalwaysApply: true`n---`nBody line`n"
    Put "$Gold/paths.md" "---`npaths:`n  - a/**`n  - b/**`n---`nBody`n"
    Put "$Gold/paths.want" "---`nglobs:`n  - **/a/**`n  - **/b/**`nalwaysApply: false`n---`nBody`n"
    Put "$Gold/inline.md" "---`npaths: src/**/*.ts`ndescription: x`n---`nB`n"
    Put "$Gold/inline.want" "---`nglobs:`n  - **/src/**/*.ts`ndescription: x`nalwaysApply: false`n---`nB`n"
    Put "$Gold/native.md" "---`ndescription: keep`nalwaysApply: true`n---`nB`n"
    Put "$Gold/native.want" "---`ndescription: keep`nalwaysApply: true`n---`nB`n"
    Put "$Gold/emptyfm.md" "---`n---`nB`n"
    Put "$Gold/emptyfm.want" "---`nalwaysApply: true`n---`nB`n"
    # A UTF-8 BOM (U+FEFF encodes as EF BB BF) and CRLF line ends
    Put "$Gold/crlf.md" "`u{FEFF}---`r`npaths:`r`n  - x/**`r`n---`r`nB`r`n"
    Put "$Gold/crlf.want" "---`nglobs:`n  - **/x/**`nalwaysApply: false`n---`nB`n"
    # N1: a YAML list at column 0 becomes indented items
    Put "$Gold/col0.md" "---`npaths:`n- scripts/**`n---`nB`n"
    Put "$Gold/col0.want" "---`nglobs:`n  - **/scripts/**`nalwaysApply: false`n---`nB`n"
    # N2: a flow list and a brace pattern become block items (Cursor splits inline values on commas)
    Put "$Gold/flow.md" "---`npaths: [`"a/**`", 'b/**', src/**/*.{ts,tsx}]`n---`nB`n"
    Put "$Gold/flow.want" "---`nglobs:`n  - **/a/**`n  - **/b/**`n  - **/src/**/*.{ts,tsx}`nalwaysApply: false`n---`nB`n"
    Put "$Gold/brace.md" "---`npaths: src/**/*.{ts,tsx}`n---`nB`n"
    Put "$Gold/brace.want" "---`nglobs:`n  - **/src/**/*.{ts,tsx}`nalwaysApply: false`n---`nB`n"
    # Already anchored, absolute, and ./ patterns
    Put "$Gold/keep.md" "---`npaths:`n  - `"**/x`"`n  - /abs/y`n  - ./rel/z`n---`nB`n"
    Put "$Gold/keep.want" "---`nglobs:`n  - **/x`n  - /abs/y`n  - **/rel/z`nalwaysApply: false`n---`nB`n"
    # A YAML comment inside the paths: list does not end it
    Put "$Gold/comment.md" "---`npaths:`n  - a/**`n  # note`n  - b/**`n---`nB`n"
    Put "$Gold/comment.want" "---`nglobs:`n  - **/a/**`n  - **/b/**`nalwaysApply: false`n---`nB`n"
    foreach ($g in @("nofm", "paths", "inline", "native", "emptyfm", "crlf", "col0", "flow", "brace", "keep", "comment")) {
        Conv "$Gold/$g.md" "$Gold/$g.got"
        Check "convert: $g" { SameBytes "$Gold/$g.got" "$Gold/$g.want" }
    }
    # With a rule name the aitools-fanout marker is the line after the frontmatter
    $Mark = '<!-- aitools-fanout: generated by setup-user-cursor from ~/.aitools/rules/'
    Conv "$Gold/paths.md" "$Gold/paths.named.got" "paths.md"
    Put "$Gold/paths.named.want" "---`nglobs:`n  - **/a/**`n  - **/b/**`nalwaysApply: false`n---`n${Mark}paths.md; edit that rule, not this file -->`nBody`n"
    Check "convert: marker after frontmatter" { SameBytes "$Gold/paths.named.got" "$Gold/paths.named.want" }
    Conv "$Gold/nofm.md" "$Gold/nofm.named.got" "nofm.md"
    Put "$Gold/nofm.named.want" "---`nalwaysApply: true`n---`n${Mark}nofm.md; edit that rule, not this file -->`nBody line`n"
    Check "convert: marker without source frontmatter" { SameBytes "$Gold/nofm.named.got" "$Gold/nofm.named.want" }

    # --- resolution: converted globs match a repo file as Cursor resolves them ----
    # Model of the IDE matcher (Cursor 3.13.10 cursor-agent-exec main.js, aL/rL): a
    # relative glob of ~/.cursor/rules/x.mdc is matched against the file path
    # relative to the directory owning .cursor/rules, i.e. $HOME. Glob subset:
    # **/, **, *, ?, {a,b}. The un-anchored form is checked too, to show the model
    # reproduces the defect the anchoring fixes. Port of the .sh harness's perl
    # glob_match (perl is not on a native pwsh PATH everywhere): the same token
    # rules, quotemeta -> [regex]::Escape, \A...\z anchors; perl's split drops
    # trailing empty fields, so does this.
    function GlobMatch([string]$Glob, [string]$Path) {
        $g1 = $Glob; $re = [Text.StringBuilder]::new()
        while ($g1.Length) {
            if ($g1.StartsWith("**/")) { [void]$re.Append("(?:.*/)?"); $g1 = $g1.Substring(3) }
            elseif ($g1.StartsWith("**")) { [void]$re.Append(".*"); $g1 = $g1.Substring(2) }
            elseif ($g1.StartsWith("*")) { [void]$re.Append("[^/]*"); $g1 = $g1.Substring(1) }
            elseif ($g1.StartsWith("?")) { [void]$re.Append("[^/]"); $g1 = $g1.Substring(1) }
            elseif (($m1 = [regex]::Match($g1, '\A\{([^}]*)\}')).Success) {
                $alts = [Collections.Generic.List[string]]::new([string[]]($m1.Groups[1].Value -split ","))
                while ($alts.Count -and $alts[$alts.Count - 1] -eq "") { $alts.RemoveAt($alts.Count - 1) }
                [void]$re.Append("(?:" + (($alts | ForEach-Object { [regex]::Escape($_) }) -join "|") + ")")
                $g1 = $g1.Substring($m1.Length)
            } else { [void]$re.Append([regex]::Escape($g1.Substring(0, 1))); $g1 = $g1.Substring(1) }
        }
        return [regex]::IsMatch($Path, "\A" + $re.ToString() + "\z")
    }
    function NoMatch([string]$Glob, [string]$Path) { (GlobMatch $Glob $Path) -eq $false }  # a model error throws: FAIL
    Check "resolve: **/scripts/** matches repos/aitools/scripts/a.sh" { GlobMatch '**/scripts/**' 'repos/aitools/scripts/a.sh' }
    Check "resolve: un-anchored scripts/** does not (the defect)" { NoMatch 'scripts/**' 'repos/aitools/scripts/a.sh' }
    Check "resolve: un-anchored scripts/** matches only ~/scripts (model sanity)" { GlobMatch 'scripts/**' 'scripts/a.sh' }
    Check "resolve: **/src/**/*.{ts,tsx} matches repos/x/src/a/b.tsx" { GlobMatch '**/src/**/*.{ts,tsx}' 'repos/x/src/a/b.tsx' }
    Check "resolve: **/CLAUDE.md matches repos/aitools/CLAUDE.md" { GlobMatch '**/CLAUDE.md' 'repos/aitools/CLAUDE.md' }
    # Every glob the converter emits for the repo's own path-scoped rules resolves
    $repoRules = [string[]]@(Get-ChildItem -LiteralPath (Join-Path $root ".claude/rules") -Filter "*.md" -File | ForEach-Object { $_.Name })
    [Array]::Sort($repoRules, [StringComparer]::Ordinal)
    $repoMdc = @()
    foreach ($rf in $repoRules) {
        $src = Join-Path $root ".claude/rules/$rf"
        if (-not [regex]::IsMatch((ReadText $src), '^paths:', [Text.RegularExpressions.RegexOptions]::Multiline)) { continue }
        Conv $src "$Gold/repo-$rf.mdc"
        $repoMdc += "$Gold/repo-$rf.mdc"
    }
    # Frontmatter only (between the first two --- lines): bodies have bullet lists too
    $resolveBad = @(); $resolveCount = 0
    foreach ($f in $repoMdc) {
        $in = $false; $first = $true
        foreach ($ln in (Lines (ReadText $f))) {
            if ($first) { $in = $ln.StartsWith("---"); $first = $false; continue }
            if ($in -and $ln.StartsWith("---")) { $in = $false }
            if ($in -and ($m2 = [regex]::Match($ln, '\A  - (.*)\z')).Success) {
                $resolveCount++
                if ($m2.Groups[1].Value -notmatch '\A(?:\*\*/|/)') { $resolveBad += "${f}: $($m2.Groups[1].Value)" }
            }
        }
    }
    Check "resolve: the repo's path-scoped rules produce globs (count $resolveCount)" { $resolveCount -gt 0 }
    Check "resolve: every repo paths: glob is anchored (**/ or absolute)" { $resolveBad.Count -eq 0 }
    Check "resolve: config-file-safety scripts/** resolves in a repo under HOME" { (FileHasLine "$Gold/repo-config-file-safety.md.mdc" '  - **/scripts/**') -and (GlobMatch '**/scripts/**' 'repos/aitools/scripts/setup-x.sh') }

    # --- case: missing ~/.aitools/rules -> info + OK n/a, nothing created ----------
    Setup-Case missing
    Run-Script
    Check "missing: exit 0" { $rc -eq 0 }
    Check "missing: OK n/a row" { SumHas 'OK|cursor rules|n/a (no harness rules)' }
    Check "missing: no ~/.cursor/rules" { -not (Exists "$H/.cursor/rules") }
    Check "missing: info log" { OutMatch 'No harness rules at' }

    # --- case: ~/.aitools/rules with only an empty manifest -> OK n/a --------------
    Setup-Case empty
    Manifest
    Run-Script
    Check "empty: exit 0" { $rc -eq 0 }
    Check "empty: OK n/a row" { SumHas 'OK|cursor rules|n/a (no harness rules)' }
    Check "empty: manifest not logged" { -not (OutMatch 'aitools-rules-manifest') }

    # --- case: first run, rerun, edited target, -Force -----------------------------
    Setup-Case fanout
    Seed-Rules
    MkDirs @("$H/.cursor/rules")
    Put "$H/.cursor/rules/mine.mdc" "---`nalwaysApply: true`n---`nmine`n"
    $Rules = "$H/.cursor/rules"
    Run-Script
    Check "first: exit 0" { $rc -eq 0 }
    Check "first: plain.md -> plain.mdc (alwaysApply true)" { (Head "$Rules/plain.mdc" 3) -ceq "---`nalwaysApply: true`n---" }
    Check "first: scoped.md -> anchored globs list, alwaysApply false" { (FileHasLine "$Rules/scoped.mdc" 'globs:') -and (FileHasLine "$Rules/scoped.mdc" '  - **/scripts/**') -and (FileHasLine "$Rules/scoped.mdc" '  - **/shared/**') -and (FileHasLine "$Rules/scoped.mdc" 'alwaysApply: false') -and -not (FileMatch "$Rules/scoped.mdc" '^paths:') }
    Check "first: scoped body kept (table ---)" { FileHasLine "$Rules/scoped.mdc" '|---|---|' }
    Check "first: native.mdc source not fanned out (contract: *.md only)" { -not (Exists "$Rules/native.mdc") -and (OutMatch 'Ignoring non-rule file in harness rules: native.mdc') }
    Check "first: notes.txt not fanned out" { -not (Exists "$Rules/notes.txt") -and (OutMatch 'Ignoring non-rule file in harness rules: notes.txt') }
    Check "first: *.bak.* backups skipped" { -not (LsAny $Rules '^plain\.md\.bak\.') -and -not (Exists "$Rules/odd.bak.2026.mdc") -and -not (OutMatch 'odd.bak') }
    Check "first: no .md left in target" { -not (Exists "$Rules/plain.md") -and -not (Exists "$Rules/scoped.md") }
    Check "first: hidden file not deployed" { -not (Exists "$Rules/.hidden.mdc") -and -not (Exists "$Rules/.hidden.md") }
    Check "first: subdirectory not deployed" { -not (Exists "$Rules/subdir") -and (OutMatch 'Ignoring non-rule file in harness rules: subdir') }
    Check "first: user rule preserved" { ((CatText "$Rules/mine.mdc") -ceq "---`nalwaysApply: true`n---`nmine") -and (OutMatch 'Preserved unmanaged rule: mine.mdc') }
    Check "first: OK row 2 added" { SumHas 'OK|cursor rules|2 added' }

    Run-Script
    Check "rerun: exit 0" { $rc -eq 0 }
    Check "rerun: OK row 2 verified" { SumHas 'OK|cursor rules|2 verified' }
    Check "rerun: no backups (nothing written)" { -not (LsAny $Rules '\.bak\.') }

    Append "$Rules/plain.mdc" "local edit`n"
    Run-Script
    Check "edited: exit 0" { $rc -eq 0 }
    Check "edited: non-interactive overwrite" { OutMatch 'plain.mdc -- overwriting \(non-interactive\)' }
    Check "edited: source content restored" { -not (FileMatch "$Rules/plain.mdc" 'local edit') }
    Check "edited: backup kept, not loadable by Cursor" { (LsAny $Rules '^plain\.mdc\.bak\.') -and -not [bool](@(ListNames -Dir $Rules) | Where-Object { $_ -cmatch '\.bak\.' -and $_ -cmatch '\.mdc$' }) }
    Check "edited: row reports 1 updated" { (Row) -cmatch '\|cursor rules\|1 updated, 1 verified' }
    Check "edited: backup not reported as preserved" { -not (OutMatch 'Preserved unmanaged rule: plain.mdc.bak') }

    Append "$Rules/scoped.mdc" "local edit 2`n"
    Run-Script @("-Force")
    Check "force: exit 0" { $rc -eq 0 }
    Check "force: overwrite (-Force)" { (OutText).Contains('scoped.mdc -- overwriting (-Force)') }
    Check "force: source content restored" { -not (FileMatch "$Rules/scoped.mdc" 'local edit 2') }

    # --- case: an x.mdc next to x.md is not a second source (contract: *.md only) -
    Setup-Case mdcnext
    Manifest @("dup.md|shared")
    Put "$H/.aitools/rules/dup.md" "from md`n"
    Put "$H/.aitools/rules/dup.mdc" "---`nalwaysApply: true`n---`nfrom mdc`n"
    Run-Script
    Check "mdcnext: exit 0" { $rc -eq 0 }
    Check "mdcnext: dup.mdc deployed from dup.md" { FileMatch "$H/.cursor/rules/dup.mdc" 'from md' }
    Check "mdcnext: OK row 1 added" { SumHas 'OK|cursor rules|1 added' }

    # --- case: names differing only in case (Foo.md, foo.md) are one target -------
    # Possible only on a case-sensitive file system (Linux); NTFS holds one file.
    Setup-Case dupcase
    Manifest @("Foo.md|shared")
    Put "$H/.aitools/rules/Foo.md" "upper`n"
    Put "$H/.aitools/rules/foo.md" "lower`n"
    if (@(ListNames -Dir "$H/.aitools/rules").Count -lt 2) {
        Skip "dupcase (case-insensitive file system holds one file)"
    } else {
        Run-Script
        Check "dupcase: exit 1" { $rc -eq 1 }
        Check "dupcase: duplicate reported" { OutMatch 'Skipped duplicate: foo\.md -> foo\.mdc' }
        Check "dupcase: Foo.md deployed (ordinal order)" { (Test-Path -LiteralPath "$H/.cursor/rules/Foo.mdc" -PathType Leaf) -and -not (Exists "$H/.cursor/rules/foo.mdc") }
        Check "dupcase: ERROR row" { SumHas 'ERROR|cursor rules|1 failed' }
    }

    # --- dangling symlinks and chmod 000: not ported to this harness ---------------
    # The .sh harness's Windows run skipped these cases (Git Bash cannot make a
    # dangling native link; chmod 000 does not block reads on NTFS), and so does
    # this one, with the same SKIP lines: a dangling native symlink needs
    # administrator rights or Developer Mode, and an unreadable file needs a deny
    # ACL; neither has been verified on Windows yet (plans/ci-platform-targeting.md
    # follow-up "Windows symlink / chmod / read-only coverage").
    Skip "broken (no dangling symlinks here)"
    Skip "unreadable (chmod 000 does not block reads in this environment)"

    # --- case: --- inside a frontmatter value -> warning (Cursor would misparse) ---
    Setup-Case descdash
    Manifest @("dd.md|shared")
    Put "$H/.aitools/rules/dd.md" "---`ndescription: before --- after`npaths:`n  - x/**`n---`nBody`n"
    Run-Script
    Check "descdash: exit 0 (warning only)" { $rc -eq 0 }
    Check "descdash: misparse warned" { OutMatch 'dd.mdc: Cursor would not see alwaysApply' }
    Check "descdash: row promoted to WARN" { SumHas 'WARN|cursor rules|1 added' }

    # --- case: dry run -> nothing written ------------------------------------------
    Setup-Case dry
    Seed-Rules
    Run-Script @("-DryRun")
    Check "dry: exit 0" { $rc -eq 0 }
    Check "dry: no ~/.cursor/rules files" { -not (Exists "$H/.cursor/rules/plain.mdc") }
    Check "dry: would-create logged" { OutMatch 'Would create: plain.mdc' }
    Check "dry: dry-run row" { SumContains '|cursor rules|dry run (no files written)' }

    # --- case: dry run with a failure -> ERROR row (a dangling symlink; see above) -
    Skip "drydup (no dangling symlinks here)"

    # --- manifest cases ---------------------------------------------------------
    # Commander decision 2026-10-26 (RECONCILE Q3, reverses PR #110's filter):
    # Cursor gets every rule the manifest does not retire; the .mdc of a retired
    # rule is removed when the fan-out created it. Each case seeds $C/home and runs
    # the whole script once; the parity check compares the exit code, the
    # resulting ~/.cursor/rules tree and the "cursor rules" / ACTION summary rows
    # with the golden result the .sh (macOS/Linux) and .ps1 (Windows) must both give.

    # TreeSig DIR: one line per file under DIR, "<path> <md5>", backup time stamps
    # normalized (.bak.TS), ordinal order (the .sh's perl File::Find + sort).
    # Nothing when DIR is not a directory.
    function TreeSig([string]$Dir) {
        if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return }
        $base = [IO.Path]::GetFullPath($Dir).TrimEnd('\', '/')
        $sig = [string[]]@(Get-ChildItem -LiteralPath $base -Recurse -File -Force | ForEach-Object {
            $rel = $_.FullName.Substring($base.Length + 1) -replace '\\', '/'
            $rel = $rel -creplace '\.bak\.[0-9TZ-]+\z', '.bak.TS'
            $md5 = [Convert]::ToHexString([Security.Cryptography.MD5]::HashData([IO.File]::ReadAllBytes($_.FullName))).ToLowerInvariant()
            "$rel $md5"
        })
        [Array]::Sort($sig, [StringComparer]::Ordinal)
        return $sig
    }
    # ParityRows FILE: the "cursor rules" and ACTION rows, without DETAIL verified
    function ParityRows([string]$File) {
        @(SumLines $File | Where-Object { $_ -cmatch '^(ACTION\||[A-Z]+\|cursor rules\|)' -and $_ -cnotmatch '^DETAIL\|cursor rules\|verified' })
    }
    # Parity CASE: this run's exit code, ~/.cursor/rules tree and summary rows
    # equal the golden result tests/rules-fanout-cursor/golden/CASE.result
    function Parity([string]$Case) {
        $t = "exit code: $rc`n# ~/.cursor/rules (path md5)`n"
        foreach ($l in (TreeSig "$C/home/.cursor/rules")) { $t += "$l`n" }
        $t += "# summary rows`n"
        foreach ($l in (ParityRows (Join-Path $C "summary"))) { $t += "$l`n" }
        Put (Join-Path $C "$Case.result") $t
        Check "parity: ${Case}: exit code, ~/.cursor/rules and summary rows match golden (sh and ps share it)" { Test-GoldenMatch "$Case.result" (Join-Path $C "$Case.result") }
    }

    # A: every source fanned out (aitools too), retired pruned, user files kept
    Setup-Case users
    Manifest @("d.md|dotprofile", "gone.md|retired", "old.md|retired", "p.md|aitools", "q.md|aitools", "s.md|shared", "u.md|aitools")
    Put "$H/.aitools/rules/s.md" "## Shared rule`n"
    Put "$H/.aitools/rules/d.md" "## Dotprofile rule`n"
    Put "$H/.aitools/rules/p.md" "---`npaths:`n  - scripts/**`n---`n## Project rule`n"
    Put "$H/.aitools/rules/q.md" "## Project rule q`n"
    Put "$H/.aitools/rules/u.md" "## Project rule u`n"
    Put "$H/.aitools/rules/s.md.bak.2026-10-22T010203Z" "old shared`n"
    MkDirs @("$H/.cursor/rules")
    # p.mdc as PR #110 left it: removed (an aitools rule), its backup kept
    Conv "$H/.aitools/rules/p.md" "$H/.cursor/rules/p.mdc.bak.2026-10-23T010203Z"
    # q.mdc as this fan-out deploys it (with the marker): verified
    Conv "$H/.aitools/rules/q.md" "$H/.cursor/rules/q.mdc" "q.md"
    # gone.mdc as this fan-out deploys it: with the marker (its source is gone)
    Put "$C/gone-src.md" "## Gone rule`n"
    Conv "$C/gone-src.md" "$H/.cursor/rules/gone.mdc" "gone.md"
    Put "$H/.cursor/rules/u.mdc" "---`nalwaysApply: true`n---`nmy own u`n"
    Put "$H/.cursor/rules/old.mdc" "---`nalwaysApply: true`n---`nmy own old`n"
    Put "$H/.cursor/rules/mine.mdc" "---`nalwaysApply: true`n---`nmine`n"
    $Rules = "$H/.cursor/rules"
    Run-Script
    Check "users: exit 0" { $rc -eq 0 }
    Check "users: shared, dotprofile and aitools rules fanned out with the marker" { (FileContains "$Rules/s.mdc" "${Mark}s.md;") -and (FileContains "$Rules/d.mdc" "${Mark}d.md;") -and (FileContains "$Rules/p.mdc" "${Mark}p.md;") -and (FileContains "$Rules/u.mdc" "${Mark}u.md;") }
    Check "users: aitools rule PR #110 pruned is re-added" { (SumHas 'DETAIL|cursor rules|added: p.mdc') -and (FileHasLine "$Rules/p.mdc" '  - **/scripts/**') }
    Check "users: aitools rule already fanned out is verified" { -not (SumMatch '\|cursor rules\|.*: q.mdc') -and (FileContains "$Rules/q.mdc" "${Mark}q.md;") }
    Check "users: row 3 added, 1 updated, 1 removed, 1 verified (WARN: a kept file still loads)" { SumHas 'WARN|cursor rules|3 added, 1 updated, 1 removed, 1 verified' }
    Check "users: ACTION row lists the kept retired file" { SumHas 'ACTION||Cursor still loads retired rules in ~/.cursor/rules: old.mdc -- delete them unless you wrote them' }
    Check "users: retired rule with the marker removed, backup kept" { -not (Exists "$Rules/gone.mdc") -and (LsAny $Rules '^gone\.mdc\.bak\.') -and (OutMatch 'Removed gone.mdc \(retired rule; aitools-fanout marker') }
    Check "users: removal is a tracker DETAIL row" { SumHas 'DETAIL|cursor rules|removed: gone.mdc' }
    Check "users: user file at an aitools rule's name now the fan-out's (backup kept)" { (FileContains "$Rules/u.mdc" "${Mark}u.md;") -and (LsAny $Rules '^u\.mdc\.bak\.') -and (SumHas 'DETAIL|cursor rules|updated: u.mdc') }
    Check "users: user file with a retired rule's name kept" { (FileMatch "$Rules/old.mdc" 'my own old') -and (OutMatch 'Kept old.mdc: the rules manifest retires old.md') }
    Check "users: unrelated user rule kept" { (FileMatch "$Rules/mine.mdc" 'mine') -and (OutMatch 'Preserved unmanaged rule: mine.mdc') }
    Check "users: retired names logged as not fanned out only when present" { -not (OutMatch 'Not fanned out: gone.md') }
    Check "users: *.bak.* source skipped silently" { -not (LsAny $Rules '^s\.md\.bak') -and -not (OutMatch 's.md.bak') }
    Check "users: manifest ignored silently" { -not (OutMatch 'aitools-rules-manifest') -and -not (Exists "$Rules/.aitools-rules-manifest") }
    Parity users
    $baks = @(ListNames -Dir $Rules | Where-Object { $_ -cmatch '\.bak\.' }).Count
    Run-Script
    Check "users rerun: row 5 verified" { SumHas 'WARN|cursor rules|5 verified' }
    Check "users rerun: nothing removed, no new backups" { -not (OutMatch '^Removed|\] Removed') -and (@(ListNames -Dir $Rules | Where-Object { $_ -cmatch '\.bak\.' }).Count -eq $baks) }

    # B: no manifest -> every rule fanned out, none removed, info log (Claude parity)
    Setup-Case nomanifest
    MkDirs @("$H/.aitools/rules", "$H/.cursor/rules")
    Put "$H/.aitools/rules/s.md" "## Shared rule`n"
    Put "$H/.aitools/rules/p.md" "## Project rule`n"
    # p.mdc as PR #87 deployed it (no marker): updated to the marker form
    Conv "$H/.aitools/rules/p.md" "$H/.cursor/rules/p.mdc"
    Run-Script
    Check "nomanifest: exit 0" { $rc -eq 0 }
    Check "nomanifest: info log" { OutMatch '\[info\] No rules manifest at .* -- every rule fanned out, none removed' }
    # The row is WARN only because p.mdc was overwritten non-interactively (a warn)
    Check "nomanifest: no manifest WARN, no ACTION; row 1 added, 1 updated" { -not (OutMatch '\[warn\] No rules manifest') -and -not (SumMatch '^ACTION') -and (SumHas 'WARN|cursor rules|1 added, 1 updated') -and (OutMatch 'p.mdc -- overwriting \(non-interactive\)') }
    Check "nomanifest: both rules fanned out with the marker" { (FileContains "$H/.cursor/rules/s.mdc" "${Mark}s.md;") -and (FileContains "$H/.cursor/rules/p.mdc" "${Mark}p.md;") }
    Parity nomanifest

    # C: another first line -> every rule fanned out + WARN log + ACTION
    Setup-Case badheader
    MkDirs @("$H/.aitools/rules")
    Put "$H/.aitools/rules/.aitools-rules-manifest" "# aitools rules manifest v2`ns.md`tretired`n"
    Put "$H/.aitools/rules/s.md" "## Shared rule`n"
    Run-Script
    Check "badheader: exit 0" { $rc -eq 0 }
    Check "badheader: warned, with the ACTION's instruction" { OutMatch '\[warn\] Rules manifest .*the first line is not.* -- Run aitools to rebuild ~/.aitools/rules and its manifest' }
    Check "badheader: ACTION row" { SumHas 'ACTION||Run aitools to rebuild ~/.aitools/rules and its manifest' }
    Check "badheader: fanned out (its retired line not read), row WARN 1 added" { (Test-Path -LiteralPath "$H/.cursor/rules/s.mdc" -PathType Leaf) -and (SumHas 'WARN|cursor rules|1 added') }
    Parity badheader

    # C2: an unreadable manifest (a directory at its path) -> ERROR row, the
    # fan-out continues, the manifest counted as a failed item
    Setup-Case badmanifest
    MkDirs @("$H/.aitools/rules/.aitools-rules-manifest")
    Put "$H/.aitools/rules/s.md" "## Shared rule`n"
    Run-Script
    Check "badmanifest: exit 1" { $rc -eq 1 }
    Check "badmanifest: ERROR row cannot read rules manifest" { SumHas 'ERROR|cursor rules|cannot read rules manifest' }
    Check "badmanifest: fan-out continued" { (Test-Path -LiteralPath "$H/.cursor/rules/s.mdc" -PathType Leaf) -and (SumHas 'DETAIL|cursor rules|added: s.mdc') }
    Check "badmanifest: manifest counted failed, final row ERROR 1 failed" { (SumHas 'DETAIL|cursor rules|failed: .aitools-rules-manifest') -and ((Row) -ceq 'ERROR|cursor rules|1 failed') }
    Parity badmanifest

    # D: invalid lines ignored with a warning; case-insensitive names
    Setup-Case invalid
    Manifest @("Lower.md|shared", "LOWER.md|aitools", "../x.md|shared", "y.txt|shared", "z.md|bogus", "w.bak.1.md|shared", "nosource.md")
    Put "$H/.aitools/rules/lower.md" "## Lower`n"
    Run-Script
    Check "invalid: exit 0" { $rc -eq 0 }
    Check "invalid: 6 lines ignored with a warning" { ((OutCount 'line ignored') -eq 6) -and (OutMatch 'line ignored: ../x.md<TAB>shared') }
    Check "invalid: name matched case-insensitively" { (Test-Path -LiteralPath "$H/.cursor/rules/lower.mdc" -PathType Leaf) -and -not (OutMatch 'Not fanned out: Lower.md is in the rules manifest') }
    Check "invalid: WARN row" { SumHas 'WARN|cursor rules|1 added' }
    Check "invalid: one ACTION row to rebuild the manifest" { (SumCount 'ACTION||Run aitools to rebuild ~/.aitools/rules and its manifest') -eq 1 }
    Parity invalid

    # D2: an upper-case .MD extension is a rule (rule_name_kind is case-insensitive).
    # No manifest here: the lib's manifest reader takes *.md names case-sensitively
    # (a "Up.MD" line is ignored as invalid), so a listed Up.MD would add a warning.
    Setup-Case upper
    MkDirs @("$H/.aitools/rules")
    Put "$H/.aitools/rules/Up.MD" "## Upper ext`n"
    Run-Script
    Check "upper: exit 0" { $rc -eq 0 }
    # NTFS is case-insensitive: the name is compared as listed (ordinal), so a
    # wrong-case Up.mdc on disk cannot pass as the .sh's [ -f ] would not on Linux
    Check "upper: Up.MD -> Up.mdc" { (@(ListNames -Dir "$H/.cursor/rules") -ccontains 'Up.mdc') -and (FileContains "$H/.cursor/rules/Up.mdc" "${Mark}Up.MD;") -and (SumHas 'OK|cursor rules|1 added') }
    Parity upper

    # E: only a retired rule -> row reports the removal (#87 file, matched through
    # the backup deploy-harness left when it retired the rule)
    function Seed-OnlyRemove {
        Manifest @("p.md|retired")
        Put "$H/.aitools/rules/p.md.bak.2026-10-22T010203Z" "## Project rule`n"
        MkDirs @("$H/.cursor/rules")
        Conv "$H/.aitools/rules/p.md.bak.2026-10-22T010203Z" "$H/.cursor/rules/p.mdc"
    }
    Setup-Case onlyremove
    Seed-OnlyRemove
    Run-Script
    Check "onlyremove: exit 0" { $rc -eq 0 }
    Check "onlyremove: OK row 1 removed" { SumHas 'OK|cursor rules|1 removed' }
    Check "onlyremove: p.mdc removed, backup with the same text kept" { -not (Exists "$H/.cursor/rules/p.mdc") -and (LsAny "$H/.cursor/rules" '^p\.mdc\.bak\.') -and (OutMatch 'Removed p.mdc \(retired rule; same content as the conversion of p.md.bak.2026-10-22T010203Z; backup kept\)') }
    Parity onlyremove

    # E1: an aitools rule is no longer pruned (PR #110 removed it; FD-2)
    Setup-Case aitools
    Manifest @("p.md|aitools")
    Put "$H/.aitools/rules/p.md" "## Project rule`n"
    MkDirs @("$H/.cursor/rules")
    Conv "$H/.aitools/rules/p.md" "$H/.cursor/rules/p.mdc" "p.md"
    Run-Script
    Check "aitools: exit 0" { $rc -eq 0 }
    Check "aitools: p.mdc kept and verified, nothing removed" { (Test-Path -LiteralPath "$H/.cursor/rules/p.mdc" -PathType Leaf) -and (SumHas 'OK|cursor rules|1 verified') -and -not (LsAny "$H/.cursor/rules" '\.bak\.') }
    Parity aitools

    # E2: a name with [ ] is backed up before removal (Backup-File -LiteralPath)
    Setup-Case bracket
    Manifest @("br[1].md|retired")
    MkDirs @("$H/.cursor/rules")
    Put "$C/br-src.md" "## Bracket rule`n"
    Conv "$C/br-src.md" "$H/.cursor/rules/br[1].mdc" "br[1].md"
    Run-Script
    Check "bracket: exit 0" { $rc -eq 0 }
    Check "bracket: removed with a backup" { -not (Exists "$H/.cursor/rules/br[1].mdc") -and [bool](@(ListNames -Dir "$H/.cursor/rules") | Where-Object { $_.Contains('br[1].mdc.bak.') }) -and (SumHas 'OK|cursor rules|1 removed') }
    Parity bracket

    # E3 (review finding 1): #87 files of rules edited before they were retired
    # are recognised through the backups deploy-harness left beside the harness copy
    Setup-Case edited
    Manifest @("e.md|retired", "r.md|retired")
    MkDirs @("$H/.cursor/rules")
    Put "$H/.aitools/rules/e.md.bak.2026-10-21T010203Z" "## Edited rule, old text`n"
    Put "$H/.aitools/rules/e.md.bak.2026-10-22T010203Z" "## Edited rule, new text`n"
    Put "$H/.aitools/rules/r.md.bak.2026-10-22T010203Z" "## Retired rule`n"
    Conv "$H/.aitools/rules/e.md.bak.2026-10-21T010203Z" "$H/.cursor/rules/e.mdc"
    Conv "$H/.aitools/rules/r.md.bak.2026-10-22T010203Z" "$H/.cursor/rules/r.mdc"
    Run-Script
    Check "edited: exit 0" { $rc -eq 0 }
    Check "edited: old copy of an edited retired rule removed" { -not (Exists "$H/.cursor/rules/e.mdc") -and (OutMatch 'Removed e.mdc \(retired rule.*e.md.bak.2026-10-21T010203Z') }
    Check "edited: old copy of a retired rule removed" { -not (Exists "$H/.cursor/rules/r.mdc") }
    Check "edited: OK row 2 removed" { SumHas 'OK|cursor rules|2 removed' }
    Parity edited

    # E4 (review finding 3): marker text after a body --- line is not the marker
    Setup-Case bodymark
    Manifest @("p.md|retired")
    Put "$H/.aitools/rules/p.md" "## Project rule`n"
    MkDirs @("$H/.cursor/rules")
    Put "$H/.cursor/rules/p.mdc" "---`nalwaysApply: true`n---`nmine`n---`n${Mark}p.md; edit that rule, not this file -->`n"
    Run-Script
    Check "bodymark: exit 0" { $rc -eq 0 }
    Check "bodymark: retired harness copy not fanned out" { OutMatch 'Not fanned out: p.md \(retired in the rules manifest\)' }
    Check "bodymark: user file kept" { (FileMatch "$H/.cursor/rules/p.mdc" '^mine') -and (OutMatch 'Kept p.mdc') }
    Check "bodymark: WARN row (nothing to deploy) and ACTION" { (SumHas 'WARN|cursor rules|n/a (nothing to deploy)') -and (SumHas 'ACTION||Cursor still loads retired rules in ~/.cursor/rules: p.mdc -- delete them unless you wrote them') }
    Parity bodymark

    # E5 (review finding 4): a manifest ending in a lone CR -- both scripts reject
    # the line; the rule is still fanned out (only retired names are withheld)
    Setup-Case lonecr
    MkDirs @("$H/.aitools/rules")
    Put "$H/.aitools/rules/.aitools-rules-manifest" "# aitools rules manifest v1`na.md`tshared`nb.md`tretired`r"
    Put "$H/.aitools/rules/a.md" "## a`n"
    Put "$H/.aitools/rules/b.md" "## b`n"
    Run-Script
    Check "lonecr: last line ignored with a warning (b.md not retired)" { (OutMatch 'line ignored: b.md<TAB>retired') -and (Test-Path -LiteralPath "$H/.cursor/rules/b.mdc" -PathType Leaf) }
    Check "lonecr: WARN row 2 added" { SumHas 'WARN|cursor rules|2 added' }
    Parity lonecr

    # F: dry run -> removal only logged
    Setup-Case dryprune
    Seed-OnlyRemove
    Run-Script @("-DryRun")
    Check "dryprune: exit 0" { $rc -eq 0 }
    Check "dryprune: would-remove logged" { OutMatch 'Would back up and remove p.mdc \(retired rule' }
    Check "dryprune: p.mdc still there, no backup" { (@(ListNames -Dir "$H/.cursor/rules") -join "`n") -ceq 'p.mdc' }
    Parity dryprune

    # G: a listed rule with no file -> warning
    Setup-Case missingsrc
    Manifest @("s.md|shared", "t.md|aitools")
    Put "$H/.aitools/rules/s.md" "## Shared rule`n"
    Run-Script
    Check "missingsrc: exit 0" { $rc -eq 0 }
    Check "missingsrc: warned" { OutMatch 'Not fanned out: t.md is in the rules manifest but not in' }
    Check "missingsrc: WARN row 1 added" { SumHas 'WARN|cursor rules|1 added' }
    Check "missingsrc: ACTION row to rebuild the manifest" { SumHas 'ACTION||Run aitools to rebuild ~/.aitools/rules and its manifest' }
    Parity missingsrc

    # G2: a rule the manifest does not list is fanned out too (Claude parity, FAN-PLAN D1)
    Setup-Case unlisted
    Manifest @("s.md|shared")
    Put "$H/.aitools/rules/s.md" "## Shared rule`n"
    Put "$H/.aitools/rules/extra.md" "## A rule the manifest does not list`n"
    Run-Script
    Check "unlisted: exit 0, both fanned out" { ($rc -eq 0) -and (Test-Path -LiteralPath "$H/.cursor/rules/extra.mdc" -PathType Leaf) -and (SumHas 'OK|cursor rules|2 added') }
    Parity unlisted

    # H: something that is not a directory at ~/.cursor/rules -> ERROR row
    Setup-Case nocreate
    Manifest @("s.md|shared")
    Put "$H/.aitools/rules/s.md" "## Shared rule`n"
    MkDirs @("$H/.cursor")
    Put "$H/.cursor/rules" "a file`n"
    Run-Script
    Check "nocreate: exit 1, ERROR row" { ($rc -eq 1) -and ((Row) -ceq 'ERROR|cursor rules|cannot create rules dir') }
    Check "nocreate: the file in the way kept" { FileHasLine "$H/.cursor/rules" 'a file' }
    Parity nocreate

    # H1 (audit B1): a dangling symlink at a target name -- not ported (see above)
    Skip "dangtarget (no dangling symlinks here)"

    # H2 (review 3): a retired name is looked up case-insensitively in ~/.cursor/rules
    # and reported under its on-disk name (Gone.md in the manifest, gone.mdc on disk)
    Setup-Case caseretired
    Manifest @("Gone.md|retired")
    MkDirs @("$H/.cursor/rules")
    Put "$C/gone-src.md" "## Gone rule`n"
    Conv "$C/gone-src.md" "$H/.cursor/rules/gone.mdc" "gone.md"
    Run-Script
    Check "caseretired: removed under its on-disk name" { ($rc -eq 0) -and -not (Exists "$H/.cursor/rules/gone.mdc") -and (SumHas 'DETAIL|cursor rules|removed: gone.mdc') -and (SumHas 'OK|cursor rules|1 removed') }
    Parity caseretired

    # H3 (audit B3): an unreadable source rule -- not ported (chmod 000; see above)
    Skip "unreadsrc (chmod 000 does not block reads in this environment)"

    # --- pty: the review menu prompts and [x]abort exits 2 ------------------------
    # tests/managed-files/pty-run.py runs the whole .ps1 in a child pwsh on a
    # ConPTY (pywinpty), so the script sees a terminal and prompts.
    $Pty = Join-Path $root "tests/managed-files/pty-run.py"
    $py = Get-Command python3 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $havePty = [bool]$py -and (Test-Path -LiteralPath $Pty -PathType Leaf)
    if ($havePty) {
        # Windows pty = pywinpty (ConPTY); a failed import means "not installed"
        $probe = Join-Path $tmpRoot "winpty-probe.log"
        $havePty = (Invoke-TestScript -FilePath $py.Source -ArgumentList @("-c", "import winpty") -OutFile $probe) -eq 0
    }
    # Run-Pty INPUT: the whole .ps1 on a pty under $C/home; keystrokes INPUT
    # (backslash escapes decoded by pty-run.py)
    function Run-Pty([string]$Keys) {
        Put (Join-Path $C "summary-$lang") ""
        $envs = @{
            HOME = $H; USERPROFILE = $H
            AITOOLS_LOG_DIR = (Join-Path $C "logs-$lang"); AITOOLS_SUMMARY_FILE = (Join-Path $C "summary-$lang")
            PATH = (Join-Path $C "bin") + [IO.Path]::PathSeparator + $env:PATH
            AITOOLS_FORCE = $null; AITOOLS_DRY_RUN = $null
        }
        $argv = @($Pty, "--input", $Keys, "--log", (Join-Path $C "pty-$lang.out"), "--", $pwshExe, "-NoProfile", "-File", $ScriptPs1)
        $script:ptyRc = Invoke-TestScript -FilePath $py.Source -ArgumentList $argv -Environment $envs -OutFile (Join-Path $C "pty-run-$lang.log")
    }
    if ($havePty) {
        Setup-Case pty
        Manifest @("s.md|shared", "t.md|aitools")
        Put "$H/.aitools/rules/s.md" "## Shared rule`n"
        Put "$H/.aitools/rules/t.md" "## Project rule`n"
        MkDirs @("$H/.cursor/rules")
        Conv "$H/.aitools/rules/s.md" "$H/.cursor/rules/s.mdc" "s.md"
        Append "$H/.cursor/rules/s.mdc" "my edit`n"
        Conv "$H/.aitools/rules/t.md" "$H/.cursor/rules/t.mdc" "t.md"
        $PtyRules = "$H/.cursor/rules"
        Run-Pty 's\n'
        Check "pty ${lang}: the review menu prompted" { (ReadText (Join-Path $C "pty-$lang.out")).Contains('[s]kip') }
        Check "pty ${lang}: [s]kip keeps the local edit, row WARN 1 skipped" { (FileHasLine "$PtyRules/s.mdc" 'my edit') -and ((Row (Join-Path $C "summary-$lang")) -ceq 'WARN|cursor rules|1 skipped (user review)') }
        Run-Pty 'x\n'
        Check "pty ${lang}: [x]abort exits 2, no cursor rules row, local file kept" { ($ptyRc -eq 2) -and ((Row (Join-Path $C "summary-$lang")) -eq "") -and (FileHasLine "$PtyRules/s.mdc" 'my edit') }
    } else {
        Skip "pty review menu and abort (python3 not found; on Windows also pywinpty)"
    }
} finally {
    Remove-TestTempRoot $tmpRoot
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped (windows: {3} scripts)" -f $script:pass, $script:fail, $script:skip, $lang)
if ($script:fail -ne 0) { exit 1 }
exit 0
