# eol-check.ps1 -- count bare-LF lines and non-ASCII chars in the touched files
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input"
foreach ($f in @("scripts\aitools-lib.ps1", "scripts\aitools.ps1", "tests\aitools-entry\test-console-mode-guard.ps1")) {
    $b = [IO.File]::ReadAllBytes((Join-Path $wt $f))
    $lf = 0; $bare = 0
    for ($i = 0; $i -lt $b.Length; $i++) { if ($b[$i] -eq 10) { $lf++; if ($i -eq 0 -or $b[$i - 1] -ne 13) { $bare++ } } }
    $t = [IO.File]::ReadAllText((Join-Path $wt $f))
    $nonAscii = ([regex]::Matches($t, '[^\x00-\x7F]')).Count
    "$f lines=$lf bareLF=$bare nonASCII=$nonAscii"
}
# Non-ASCII in the lines this change added
$diff = & git -C $wt diff -U0 -- scripts/aitools-lib.ps1 scripts/aitools.ps1 tests/aitools-entry/test-console-mode-guard.ps1
$added = @($diff | Where-Object { $_ -match '^\+[^+]' -and $_ -match '[^\x00-\x7F]' })
"added lines with non-ASCII: $($added.Count)"
$added
