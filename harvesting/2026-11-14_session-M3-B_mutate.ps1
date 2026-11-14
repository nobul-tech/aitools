# Mutation check: the new test must FAIL on each broken variant of aitools.ps1.
$ErrorActionPreference = "Stop"
$wt = "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile"
$base = Join-Path $PSScriptRoot "mut"
$src = Get-Content -LiteralPath (Join-Path $wt "scripts\aitools.ps1") -Raw
$orig = (& git -C $wt show "941e64a:scripts/aitools.ps1") -join "`n"
$mutants = [ordered]@{
    "origin-main"   = $orig
    "no-null-stdin" = $src.Replace('$buildResult = $null | & $bashExe', '$buildResult = & $bashExe')
    "no-restore"    = $src.Replace('    $null = Restore-ConsoleInputMode $consoleInMode "build-deploy"' + "`r`n", '').Replace('    $null = Restore-ConsoleInputMode $consoleInMode "build-deploy"' + "`n", '')
    "no-save"       = $src.Replace('$consoleInMode = Save-ConsoleInputMode', '$consoleInMode = $null')
    "unmodified"    = $src
}
foreach ($k in $mutants.Keys) {
    $root = Join-Path $base $k
    New-Item -ItemType Directory -Force -Path (Join-Path $root "scripts"), (Join-Path $root "tests\aitools-entry") | Out-Null
    if ($k -ne "unmodified" -and $mutants[$k] -eq $src) { "MUTANT $k did not change the file -- mutation broken"; continue }
    [IO.File]::WriteAllText((Join-Path $root "scripts\aitools.ps1"), $mutants[$k])
    Copy-Item (Join-Path $wt "scripts\aitools-lib.ps1") (Join-Path $root "scripts\aitools-lib.ps1") -Force
    Copy-Item (Join-Path $wt "tests\aitools-entry\test-console-mode-guard.ps1") (Join-Path $root "tests\aitools-entry\") -Force
    $out = & pwsh -NoProfile -File (Join-Path $root "tests\aitools-entry\test-console-mode-guard.ps1") 2>&1 | Out-String
    $rc = $LASTEXITCODE
    $fails = @($out -split "`r?`n" | Where-Object { $_ -match '^FAIL ' })
    "=== $k : exit $rc, $($fails.Count) FAIL line(s)"
    $fails | ForEach-Object { "    $_" }
    ($out -split "`r?`n" | Where-Object { $_ -match '^---- ' })
}
