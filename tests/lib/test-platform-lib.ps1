# test-platform-lib.ps1 -- tests for tests/lib/platform-lib.ps1, the helpers every
# Windows (.ps1) suite harness uses: golden normalization and lookup
# (the twin of golden_match in tests/lib/platform-lib.sh), Invoke-TestScript,
# ConvertTo-MsysPath, Resolve-TestGitBash and the temp root.
#
# Safe to re-run: works in its own temp directory (removed on exit); writes no
# golden file. Platform: Windows, pwsh 7 (the helpers are for the Windows
# harnesses; commander 2026-11-14: "ps1 on windows"). Exit 1 if any case fails.
#
# Usage: pwsh -NoProfile -File tests/lib/test-platform-lib.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 10 | Select-Object -Skip 1 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. The macOS/Linux golden helper is tested through the .sh suites that use it.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$script:pass = 0; $script:fail = 0; $script:skip = 0

function Check([string]$Name, [bool]$Cond, [string]$Detail = "") {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++ }
    else { Write-Output "FAIL $Name"; $script:fail++; if ($Detail) { Write-Output "      | $Detail" } }
}
function Skip([string]$Name) { Write-Output "SKIP $Name"; $script:skip++ }

$work = New-TestTempRoot "platform-lib"
try {
    # --- temp root ---
    Check "temp root: exists and is empty" ((Test-Path -LiteralPath $work -PathType Container) -and -not (Get-ChildItem -LiteralPath $work -Force))
    Check "temp root: no 8.3 short component" ($work -notmatch '~')

    # --- ConvertTo-GoldenText ---
    $t = 'C:\T\r1'
    $g = { param($s) ConvertTo-GoldenText $s $t }
    Check "normalize: CR removed" ((& $g "a`r`nb`r`n") -ceq "a`nb`n")
    Check "normalize: native form, rest to slashes" ((& $g 'x C:\T\r1\a\b.txt y') -ceq 'x <TMP>/a/b.txt y')
    Check "normalize: mixed form" ((& $g 'x C:/T/r1/a/b y') -ceq 'x <TMP>/a/b y')
    Check "normalize: MSYS form" ((& $g 'x /c/T/r1/a\b y') -ceq 'x <TMP>/a/b y')
    Check "normalize: drive and name case ignored" ((& $g 'c:\t\R1\a') -ceq '<TMP>/a')
    Check "normalize: rest ends at | and quote" ((& $g 'OK|C:\T\r1\a\b|"C:\T\r1\c\d"') -ceq 'OK|<TMP>/a/b|"<TMP>/c/d"')
    Check "normalize: other paths untouched" ((& $g 'D:\other\x C:\T\r2\y') -ceq 'D:\other\x C:\T\r2\y')
    Check "normalize: trailing separator on the root ignored" ((ConvertTo-GoldenText 'C:\T\r1\a' 'C:\T\r1\') -ceq '<TMP>/a')
    Check "normalize: no root, CR only" ((ConvertTo-GoldenText "C:\T\r1\a`r`n" "") -ceq "C:\T\r1\a`n")

    # --- Test-GoldenMatch ---
    $GoldenDir = Join-Path $work "golden"
    $GoldenTmp = Join-Path $work "tmp"
    New-Item -ItemType Directory -Path $GoldenDir, $GoldenTmp | Out-Null
    [IO.File]::WriteAllText((Join-Path $GoldenDir "one.rows"), "OK|a|<TMP>/x/y`n")
    [IO.File]::WriteAllText((Join-Path $GoldenDir "two.rows"), "OK|generic`n")
    [IO.File]::WriteAllText((Join-Path $GoldenDir "two.rows.windows"), "OK|windows`n")
    $res = Join-Path $work "result"
    [IO.File]::WriteAllText($res, "OK|a|$GoldenTmp\x\y`r`n")
    $r = @(Test-GoldenMatch "one.rows" $res)
    Check "golden: match after normalization returns one `$true" ($r.Count -eq 1 -and $r[0] -eq $true) "got: $($r -join ',')"
    [IO.File]::WriteAllText($res, "OK|a|$GoldenTmp\x\z`n")
    $r = @(Test-GoldenMatch "one.rows" $res 6>$null)
    Check "golden: mismatch returns one `$false (diagnostics on the host stream)" ($r.Count -eq 1 -and $r[0] -eq $false) "got: $($r -join ',')"
    [IO.File]::WriteAllText($res, "OK|windows`n")
    Check "golden: NAME.windows wins over NAME" ((Test-GoldenMatch "two.rows" $res) -eq $true)
    [IO.File]::WriteAllText($res, "OK|generic`n")
    Check "golden: NAME not used when NAME.windows exists" ((Test-GoldenMatch "two.rows" $res 6>$null) -eq $false)
    Check "golden: missing golden file fails" ((Test-GoldenMatch "absent.rows" $res 6>$null) -eq $false)
    Check "golden: missing result file fails" ((Test-GoldenMatch "one.rows" (Join-Path $work "absent") 6>$null) -eq $false)
    Check "golden: case matters" ((& { [IO.File]::WriteAllText($res, "ok|a|$GoldenTmp\x\y`n"); Test-GoldenMatch "one.rows" $res 6>$null }) -eq $false)
    $before = [IO.File]::ReadAllText((Join-Path $GoldenDir "one.rows"))
    $env:AITOOLS_TEST_UPDATE_GOLDEN = "1"
    try { $r = Test-GoldenMatch "one.rows" $res 6>$null } finally { $env:AITOOLS_TEST_UPDATE_GOLDEN = $null }
    Check "golden: update mode refused on Windows, golden unchanged" ($r -eq $false -and [IO.File]::ReadAllText((Join-Path $GoldenDir "one.rows")) -ceq $before)
    $GoldenDir = $null
    Check "golden: unset GoldenDir fails" ((Test-GoldenMatch "one.rows" $res 6>$null) -eq $false)

    # --- Invoke-TestScript ---
    $out = Join-Path $work "out.txt"
    $env:AIT_PLATFORM_LIB_PROBE = "parent"
    $child = Join-Path $work "child.ps1"
    [IO.File]::WriteAllText($child, @'
Write-Output "probe=$env:AIT_PLATFORM_LIB_PROBE"
Write-Output "removed=[$env:AIT_PLATFORM_LIB_GONE]"
[Console]::Error.WriteLine("to-stderr")
$in = [Console]::In.ReadToEnd()
Write-Output "stdin-length=$($in.Length)"
Write-Output "cwd=$((Get-Location).Path)"
exit 7
'@)
    $env:AIT_PLATFORM_LIB_GONE = "still-here"
    $rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $child) `
        -Environment @{ AIT_PLATFORM_LIB_PROBE = "child"; AIT_PLATFORM_LIB_GONE = $null } -OutFile $out -WorkingDirectory $work
    $o = [IO.File]::ReadAllText($out)
    Check "invoke: exit code returned" ($rc -eq 7) "rc=$rc"
    Check "invoke: variable set in the child" ($o.Contains("probe=child"))
    Check "invoke: `$null removes a variable in the child" ($o.Contains("removed=[]"))
    Check "invoke: stderr captured" ($o.Contains("to-stderr"))
    Check "invoke: stdin at EOF" ($o.Contains("stdin-length=0"))
    Check "invoke: working directory" ($o.Contains("cwd=$work"))
    Check "invoke: parent variables restored" ($env:AIT_PLATFORM_LIB_PROBE -eq "parent" -and $env:AIT_PLATFORM_LIB_GONE -eq "still-here")
    $env:AIT_PLATFORM_LIB_PROBE = $null; $env:AIT_PLATFORM_LIB_GONE = $null

    # --- ConvertTo-MsysPath ---
    Check "msys path: drive" ((ConvertTo-MsysPath 'C:\Users\a b\x') -ceq '/c/Users/a b/x')
    Check "msys path: mixed form" ((ConvertTo-MsysPath 'D:/a/b') -ceq '/d/a/b')

    # --- Resolve-TestGitBash ---
    $gb = Resolve-TestGitBash
    if (-not $gb) {
        Skip "git bash: Git for Windows not installed"
    } else {
        $refused = ($env:SystemRoot -and $gb.StartsWith($env:SystemRoot, [StringComparison]::OrdinalIgnoreCase)) -or ($gb -match 'WindowsApps')
        Check "git bash: a bash.exe outside SystemRoot and WindowsApps" (($gb -match '\\bash\.exe$') -and -not $refused) $gb
        # OSTYPE is msys in a Git Bash terminal, cygwin when bin\bash.exe is started
        # from a native program (seen 2026-11-14, Git for Windows 2.56).
        $o = & $gb -c 'printf "%s %s" "$OSTYPE" "$(uname -s)"'
        Check "git bash: it is MSYS bash (OSTYPE, uname)" ($o -match '^(msys|cygwin)\S* (MINGW|MSYS|CYGWIN)') "got: $o"
    }
} finally {
    Remove-TestTempRoot $work
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped" -f $script:pass, $script:fail, $script:skip)
if ($script:fail -ne 0) { exit 1 }
exit 0
