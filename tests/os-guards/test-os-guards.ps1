# test-os-guards.ps1 -- every product script's and test suite's OS guard refuses
# the wrong platform: the Windows harness. Its macOS/Linux twin is
# tests/os-guards/test-os-guards.sh; both use one classifier,
# tests/os-guards/classify-guards.pl (perl is cross-platform; commander
# 2026-11-14: "build-deploy.sh and all perl/python scripts").
#
# Commander, 2026-11-14: "sh scripts and tests should only run on linux/mac and
# ps1 on windows". On Windows this harness checks that every tracked script and
# test suite is guarded or listed in the "OS guard exemptions" table of
# .claude/rules/cross-platform.md, that every POSIX-guarded test suite also has
# the ${BASH_VERSINFO[5]:-} case (a uname shim or an exported OSTYPE cannot fool
# it), and that every POSIX-guarded .sh, run with Git Bash under an isolated
# HOME, exits 1, prints "This script is for macOS/Linux" and writes nothing
# under HOME except ~/.aitools/logs.
#
# Safe to re-run: everything runs under a temp dir removed on exit; the scripts
# under test stop at their guard. Exit 1 if any check fails. Needs Git for
# Windows (bash.exe; its perl when no perl is on PATH).
#
# Usage: pwsh -NoProfile -File tests/os-guards/test-os-guards.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 20 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/os-guards/test-os-guards.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$script:pass = 0; $script:fail = 0; $script:skip = 0
function Ok([string]$m) { $script:pass++; Write-Output "  ok   $m" }
function Bad([string]$m) { $script:fail++; Write-Output "  FAIL $m" }

$work = New-TestTempRoot "os-guards"
try {
    $gitBash = Resolve-TestGitBash
    if (-not $gitBash) {
        Bad "Git for Windows bash.exe not found: the POSIX guards cannot be tested"
        throw "no Git Bash"
    }
    # perl: the one on PATH, else Git for Windows' own (Git\usr\bin\perl.exe).
    $perl = (Get-Command perl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $perl) {
        $gitPerl = Join-Path (Split-Path -Parent (Split-Path -Parent $gitBash)) "usr\bin\perl.exe"
        if (Test-Path -LiteralPath $gitPerl -PathType Leaf) { $perl = $gitPerl }
    }
    if (-not $perl) {
        Bad "perl not found (PATH, Git for Windows usr\bin): cannot classify"
        throw "no perl"
    }

    # --- Classify every product script and test suite ---
    $files = Join-Path $work "files.txt"
    $lsOut = & git -C $root ls-files -- scripts shared packaging tests
    if ($LASTEXITCODE -ne 0) { Bad "git ls-files failed in $root"; throw "git ls-files" }
    [IO.File]::WriteAllText($files, (($lsOut | Where-Object { $_ }) -join "`n") + "`n")
    $classes = Join-Path $work "classes.tsv"
    $errFile = Join-Path $work "classify.err"
    $rcClass = Invoke-TestScript -FilePath $perl -ArgumentList @((Join-Path $root "tests/os-guards/classify-guards.pl"), $root, (Join-Path $root ".claude/rules/cross-platform.md"), $files) -OutFile $classes -Environment @{ PERLIO = ":perlio" }
    if ($rcClass -ne 0) {
        Bad "classification failed (exit $rcClass)"
        Get-Content -LiteralPath $classes | ForEach-Object { Write-Output "       | $_" }
        throw "classify"
    }
    $rows = @([IO.File]::ReadAllText($classes) -replace "`r", "" -split "`n" | Where-Object { $_ } | ForEach-Object { , ($_ -split "`t") })
    $byKind = @{}
    foreach ($r in $rows) { if (-not $byKind.ContainsKey($r[0])) { $byKind[$r[0]] = @() }; $byKind[$r[0]] += , $r[1] }
    $count = { param($k) if ($byKind.ContainsKey($k)) { $byKind[$k].Count } else { 0 } }
    $nTests = @($rows | Where-Object { $_[1] -like 'tests/*' }).Count
    Write-Output ("== windows: {0} Windows-guarded .ps1, {1} POSIX-guarded .sh, {2} exempt ({3} test suites classified)" -f (& $count 'win'), (& $count 'posix'), (& $count 'exempt'), $nTests)

    Write-Output "== every unguarded script and suite is in the cross-platform.md exemption table"
    if ((& $count 'unexempt') -gt 0) {
        foreach ($f in $byKind['unexempt']) { Bad "no OS guard and not in the exemption table: $f" }
    } else { Ok ("all {0} unguarded scripts and suites are listed exemptions" -f (& $count 'exempt')) }
    Write-Output "== every POSIX-guarded test suite also checks BASH_VERSINFO[5]"
    if ((& $count 'weak') -gt 0) {
        foreach ($f in $byKind['weak']) { Bad "test suite guard lacks the `${BASH_VERSINFO[5]:-} case: $f" }
    } else { Ok "no test suite guard relies on uname alone" }
    if ((& $count 'win') -gt 0) { Ok ("found Windows-guarded scripts ({0})" -f (& $count 'win')) } else { Bad "found no Windows-guarded .ps1 (classifier broken?)" }
    if ((& $count 'posix') -gt 0) { Ok ("found POSIX-guarded scripts ({0})" -f (& $count 'posix')) } else { Bad "found no POSIX-guarded .sh (classifier broken?)" }

    # --- Every POSIX-guarded .sh refuses Git Bash ---
    Write-Output "== POSIX-guarded .sh scripts and suites refuse Windows (Git Bash)"
    $want = "This script is for macOS/Linux"
    $cwd = Join-Path $work "cwd"
    New-Item -ItemType Directory -Path $cwd | Out-Null
    $out = Join-Path $work "out.txt"
    foreach ($f in @($byKind['posix'])) {
        if (-not $f) { continue }
        $h = Join-Path $work ("home-" + ($f -replace '[/.]', '_'))
        New-Item -ItemType Directory -Path $h | Out-Null
        $rc = Invoke-TestScript -FilePath $gitBash -ArgumentList @((ConvertTo-MsysPath (Join-Path $root $f))) `
            -Environment @{ HOME = $h; USERPROFILE = $h } -OutFile $out -WorkingDirectory $cwd
        $text = if (Test-Path -LiteralPath $out) { [IO.File]::ReadAllText($out) } else { "" }
        $logs = Join-Path $h ".aitools\logs"
        $stray = @(Get-ChildItem -LiteralPath $h -Recurse -File -Force | Where-Object { -not $_.FullName.StartsWith($logs + "\", [StringComparison]::OrdinalIgnoreCase) } |
            Select-Object -First 5 | ForEach-Object { $_.FullName.Substring($h.Length + 1) })
        if ($rc -eq 1 -and $text.Contains($want) -and $stray.Count -eq 0) {
            Ok "$f refuses windows (exit 1, guard message, only logs written)"
        } else {
            $msg = if ($text.Contains($want)) { "present" } else { "MISSING" }
            $s = if ($stray.Count) { $stray -join ", " } else { "none" }
            Bad "$f on windows: exit $rc (want 1); message $msg; stray files: $s"
            @($text -split "`n") | Select-Object -First 8 | ForEach-Object { Write-Output "       | $_" }
        }
    }
} catch {
    if ($script:fail -eq 0) { Bad "unexpected error: $($_.Exception.Message)" }
} finally {
    Remove-TestTempRoot $work
}

Write-Output ""
Write-Output ("test-os-guards: {0} passed, {1} failed, {2} skipped (windows, pwsh {3})" -f $script:pass, $script:fail, $script:skip, $PSVersionTable.PSVersion)
if ($script:fail -ne 0) { exit 1 }
exit 0
