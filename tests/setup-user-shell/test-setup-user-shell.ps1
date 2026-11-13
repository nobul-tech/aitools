# test-setup-user-shell.ps1 -- tests for scripts/setup-user-shell.ps1, the aitools
# managed PATH block in the PowerShell profile.
#
# Safe to re-run: every case uses its own temp profile, log dir and summary file,
# removed on exit. Platform: Windows (setup-user-shell.ps1 has a Windows OS guard);
# reported as SKIP elsewhere. Exit 1 if any case fails.
# Covers: block added to a new profile; refresh byte-stable across re-runs (it once
# multiplied the profile on every run); user lines around a stale block kept; a
# splice that would break the profile refused.
#
# Usage: pwsh -NoProfile -File tests/setup-user-shell/test-setup-user-shell.ps1 [-Help]

param([switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 10
    exit 0
}

$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
$setup = Join-Path $root "scripts" "setup-user-shell.ps1"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-shelltest-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

$script:pass = 0
$script:fail = 0
$script:skip = 0

function Check([string]$Name, [bool]$Ok) {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ } else { Write-Output "FAIL $Name"; $script:fail++ }
}
function Skip([string]$Name, [string]$Why) { Write-Output "SKIP $Name ($Why)"; $script:skip++ }

# Run setup-user-shell.ps1 on $ProfilePath with an isolated log dir and summary file.
# Returns @{ Rc; Text; ParseErrors; Blocks; Summary } for the profile after the run.
function Invoke-Setup([string]$Case, [string]$ProfilePath) {
    $dir = Join-Path $tmpRoot $Case
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $summary = Join-Path $dir "summary.txt"
    if (Test-Path -LiteralPath $summary) { Remove-Item -LiteralPath $summary }
    $env:AITOOLS_PROFILE_PATH = $ProfilePath
    $env:AITOOLS_LOG_DIR = Join-Path $dir "logs"
    $env:AITOOLS_SUMMARY_FILE = $summary
    & pwsh -NoProfile -File $setup *> (Join-Path $dir "run.log")
    $rc = $LASTEXITCODE
    $env:AITOOLS_PROFILE_PATH = $null
    $env:AITOOLS_LOG_DIR = $null
    $env:AITOOLS_SUMMARY_FILE = $null
    $text = if (Test-Path -LiteralPath $ProfilePath) { [IO.File]::ReadAllText($ProfilePath) } else { "" }
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errs)
    return @{
        Rc          = $rc
        Text        = $text
        ParseErrors = @($errs).Count
        Blocks      = ([regex]::Matches($text, [regex]::Escape("# >>> aitools managed >>>"))).Count
        Summary     = if (Test-Path -LiteralPath $summary) { [IO.File]::ReadAllText($summary) } else { "" }
    }
}

try {
    if (-not $IsWindows) {
        Skip "setup-user-shell.ps1 cases" "setup-user-shell.ps1 runs on Windows only"
    } else {
        # --- New profile: block appended, then refreshed in place ---
        $p = Join-Path $tmpRoot "new.ps1"
        $r1 = Invoke-Setup "new" $p
        Check "new profile: block added (exit 0, OK added)" (($r1.Rc -eq 0) -and ($r1.Summary -match 'OK\|shell\|managed block added'))
        Check "new profile: one block, no parse errors" (($r1.Blocks -eq 1) -and ($r1.ParseErrors -eq 0))
        $r2 = Invoke-Setup "new" $p
        $r3 = Invoke-Setup "new" $p
        Check "re-run: refreshed (exit 0, OK refreshed)" (($r2.Rc -eq 0) -and ($r3.Rc -eq 0) -and ($r2.Summary -match 'OK\|shell\|managed block refreshed'))
        Check "re-run: profile byte-identical after the 2nd and 3rd run" (($r2.Text -ceq $r1.Text) -and ($r3.Text -ceq $r1.Text))
        Check "re-run: one block, no parse errors" (($r3.Blocks -eq 1) -and ($r3.ParseErrors -eq 0))

        # --- User lines around a stale block ---
        $p = Join-Path $tmpRoot "user.ps1"
        [IO.File]::WriteAllText($p, "Set-Alias ll Get-ChildItem`n`n# >>> aitools managed >>>`n`$stale = 1`n# <<< aitools managed <<<`n`nfunction Get-Foo { 'foo' }`n")
        $u1 = Invoke-Setup "user" $p
        $u2 = Invoke-Setup "user" $p
        Check "stale block: replaced by the current block" (($u1.Rc -eq 0) -and -not $u1.Text.Contains('$stale') -and $u1.Text.Contains($r1.Text))
        Check "stale block: user lines before and after kept" ($u1.Text.StartsWith("Set-Alias ll Get-ChildItem`n`n") -and $u1.Text.EndsWith("`nfunction Get-Foo { 'foo' }`n"))
        Check "stale block: one block, no parse errors, re-run byte-identical" (($u1.Blocks -eq 1) -and ($u1.ParseErrors -eq 0) -and ($u2.Rc -eq 0) -and ($u2.Text -ceq $u1.Text))

        # --- A splice that would break the profile is refused ---
        # The block is commented out with a <# #> that closes before the end
        # marker: the splice would drop the #> and leave the comment unterminated.
        $p = Join-Path $tmpRoot "guard.ps1"
        $before = "<#`n# >>> aitools managed >>>`n`$old = 1`n#>`n# <<< aitools managed <<<`n"
        [IO.File]::WriteAllText($p, $before)
        $g = Invoke-Setup "guard" $p
        Check "breaking splice: exit 1, ERROR row" (($g.Rc -eq 1) -and ($g.Summary -match 'ERROR\|shell\|managed block splice failed parse check'))
        Check "breaking splice: profile left unchanged" ($g.Text -ceq $before)
    }
} finally {
    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot }
}

Write-Output "---- $($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
