# eol-check.ps1 -- line endings and non-ASCII in the touched files and in the added lines;
# git diff --stat / --summary; git status. Output to stdout.
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
$files = @("scripts\aitools-lib.ps1", "tests\aitools-entry\test-console-mode-guard.ps1", "reference\cross-platform-detail.md")
foreach ($f in $files) {
    $b = [IO.File]::ReadAllBytes((Join-Path $wt $f))
    $lf = 0; $bare = 0
    for ($i = 0; $i -lt $b.Length; $i++) { if ($b[$i] -eq 10) { $lf++; if ($i -eq 0 -or $b[$i - 1] -ne 13) { $bare++ } } }
    $head = & git -C $wt show "HEAD:$($f -replace '\\', '/')" | Out-String
    $t = [IO.File]::ReadAllText((Join-Path $wt $f))
    $nonAscii = ([regex]::Matches($t, '[^\x00-\x7F]')).Count
    "$f lines=$lf bareLF=$bare crlf=$($lf - $bare) nonASCII(file)=$nonAscii"
}
"--- index eol (git ls-files --eol)"
& git -C $wt ls-files --eol -- scripts/aitools-lib.ps1 tests/aitools-entry/test-console-mode-guard.ps1 reference/cross-platform-detail.md
"--- added lines with non-ASCII"
$diff = & git -C $wt diff -U0 -- scripts/aitools-lib.ps1 tests/aitools-entry/test-console-mode-guard.ps1 reference/cross-platform-detail.md
$added = @($diff | Where-Object { $_ -match '^\+[^+]' })
$na = @($added | Where-Object { $_ -match '[^\x00-\x7F]' })
"added lines: $($added.Count); with non-ASCII: $($na.Count)"
$na
"--- git diff --stat"
& git -C $wt diff --stat
"--- git diff --summary (mode changes would show here)"
& git -C $wt diff --summary
"--- git status --short"
& git -C $wt status --short
