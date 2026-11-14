# test-setup-user-shell.ps1 -- tests for scripts/setup-user-shell.ps1, the aitools
# PATH block and shell integration block in the PowerShell profile.
#
# Safe to re-run: every case uses its own temp profile dir, log dir and summary file,
# removed on exit. Platform: Windows (setup-user-shell.ps1 has a Windows OS guard);
# reported as SKIP elsewhere. Exit 1 if any case fails.
# Covers: blocks added to a new profile; re-run unchanged (no write, no backup);
# user lines around a stale block kept; duplicate blocks collapsed; a #172-style
# corrupted profile repaired as far as is safe + WARN/ACTION with backup choice;
# legacy integration migration (#173); MDM (no aliases.ps1); CRLF, BOM, non-UTF-8;
# a splice that would break the profile refused.
#
# Usage: pwsh -NoProfile -File tests/setup-user-shell/test-setup-user-shell.ps1 [-Help]

param([switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 12
    exit 0
}

$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
$setup = Join-Path $root "scripts" "setup-user-shell.ps1"
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-shelltest-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
$aliases = Join-Path $tmpRoot "aliases.ps1"
[IO.File]::WriteAllText($aliases, "# test aliases`n")
$noAliases = Join-Path $tmpRoot "absent" "aliases.ps1"

$pathStart = "# >>> aitools managed >>>"
$pathEnd = "# <<< aitools managed <<<"
$integStart = "# >>> aitools shell integration >>>"

$script:pass = 0
$script:fail = 0
$script:skip = 0

function Check([string]$Name, [bool]$Ok) {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ } else { Write-Output "FAIL $Name"; $script:fail++ }
}
function Skip([string]$Name, [string]$Why) { Write-Output "SKIP $Name ($Why)"; $script:skip++ }

function Count-Lines([string]$Text, [string]$Line) {
    return ([regex]::Matches($Text, '(?m)^' + [regex]::Escape($Line) + '\r?$')).Count
}

# A profile path in its own directory (backups land beside it).
function New-ProfilePath([string]$Case) {
    $d = Join-Path $tmpRoot "p-$Case"
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    return (Join-Path $d "profile.ps1")
}

# Run setup-user-shell.ps1 on $ProfilePath with an isolated log dir and summary file.
# Returns @{ Rc; Text; ParseErrors; Blocks; Integ; Legacy; Stray; Summary; Backups }.
function Invoke-Setup([string]$Case, [string]$ProfilePath, [string]$AliasesPath = $aliases) {
    $dir = Join-Path $tmpRoot $Case
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $summary = Join-Path $dir "summary.txt"
    if (Test-Path -LiteralPath $summary) { Remove-Item -LiteralPath $summary }
    $env:AITOOLS_PROFILE_PATH = $ProfilePath
    $env:AITOOLS_ALIASES_PATH = $AliasesPath
    $env:AITOOLS_LOG_DIR = Join-Path $dir "logs"
    $env:AITOOLS_SUMMARY_FILE = $summary
    & pwsh -NoProfile -File $setup *> (Join-Path $dir "run.log")
    $rc = $LASTEXITCODE
    $env:AITOOLS_PROFILE_PATH = $null
    $env:AITOOLS_ALIASES_PATH = $null
    $env:AITOOLS_LOG_DIR = $null
    $env:AITOOLS_SUMMARY_FILE = $null
    $text = if (Test-Path -LiteralPath $ProfilePath) { [IO.File]::ReadAllText($ProfilePath) } else { "" }
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errs)
    $pdir = Split-Path $ProfilePath -Parent
    return @{
        Rc          = $rc
        Text        = $text
        ParseErrors = @($errs).Count
        Blocks      = Count-Lines $text $pathStart
        Integ       = Count-Lines $text $integStart
        Legacy      = ([regex]::Matches($text, '(?m)^# (aitools|ai-tooling) shell integration\r?$')).Count
        Stray       = ([regex]::Matches($text, '(?m)^.*_aitoolsLocalBin.*$')).Count
        Summary     = if (Test-Path -LiteralPath $summary) { [IO.File]::ReadAllText($summary) } else { "" }
        Backups     = @(Get-ChildItem -LiteralPath $pdir -File -Filter "profile.ps1.bak.*").Count
    }
}

function Get-ParseErrors([string]$Text) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$null, [ref]$errs)
    return @($errs).Count
}

# The PATH block as the pre-#172 script wrote it (LF lines), and the old buggy splice:
# a .NET replacement string, where "$_" is the whole input (incident #172).
$oldBlock = "$pathStart`n# Owned by aitools (scripts/setup-user-shell.ps1). Edit via the script, not by hand.`n" +
    '$__aitoolsLocalBin = Join-Path $HOME ".local\bin"' + "`n" +
    'if ((Test-Path $__aitoolsLocalBin) -and ($env:PATH -split '';'')[0] -ne $__aitoolsLocalBin) {' + "`n" +
    '    $env:PATH = "$__aitoolsLocalBin;$env:PATH"' + "`n}`n$pathEnd"
$legacyInteg = "# aitools shell integration`n. `"C:\repos\aitools\shared\shell\aliases.ps1`"`n" +
    'function aitools { & "$HOME\.local\bin\aitools.ps1" @args }' + "`n" +
    'function hh { & "$HOME\.local\bin\hh.ps1" @args }' + "`n"
function New-CorruptedProfile {
    $c = "Set-Alias ll Get-ChildItem`n`n$oldBlock`n`n$legacyInteg"
    $pattern = [regex]::Escape($pathStart) + "(?s).*?" + [regex]::Escape($pathEnd) + "(\r?\n)?"
    for ($k = 0; $k -lt 2; $k++) { $c = [regex]::Replace($c, $pattern, $oldBlock + "`n") }
    return $c
}

try {
    if (-not $IsWindows) {
        Skip "setup-user-shell.ps1 cases" "setup-user-shell.ps1 runs on Windows only"
    } else {
        # --- New profile: both blocks added, then unchanged on re-run ---
        $p = New-ProfilePath "new"
        $r1 = Invoke-Setup "new" $p
        Check "new profile: exit 0, OK managed block added + integration added" (($r1.Rc -eq 0) -and ($r1.Summary -match 'OK\|shell\|managed block added') -and ($r1.Summary -match 'OK\|shell\|integration added'))
        Check "new profile: one PATH block, one integration block, no parse errors" (($r1.Blocks -eq 1) -and ($r1.Integ -eq 1) -and ($r1.ParseErrors -eq 0))
        Check "new profile: PATH block first, integration dot-sources the aliases file" (($r1.Text.IndexOf($pathStart) -eq 0) -and ($r1.Text.IndexOf($integStart) -gt 0) -and $r1.Text.Contains(". '$aliases'"))
        Check "new profile: aitools and hh functions written" ($r1.Text.Contains('function aitools { & "$HOME\.local\bin\aitools.ps1" @args }') -and $r1.Text.Contains('function hh { & "$HOME\.local\bin\hh.ps1" @args }'))
        $r2 = Invoke-Setup "new" $p
        $r3 = Invoke-Setup "new" $p
        Check "re-run: exit 0, OK managed block unchanged + integration unchanged" (($r2.Rc -eq 0) -and ($r3.Rc -eq 0) -and ($r2.Summary -match 'OK\|shell\|managed block unchanged') -and ($r2.Summary -match 'OK\|shell\|integration unchanged'))
        Check "re-run: profile byte-identical after the 2nd and 3rd run" (($r2.Text -ceq $r1.Text) -and ($r3.Text -ceq $r1.Text))
        Check "re-run: no write, so no backup taken" ($r3.Backups -eq 0)
        $pathBlock = $r1.Text.Substring(0, $r1.Text.IndexOf($pathEnd) + $pathEnd.Length + 1)

        # --- User lines around a stale block ---
        $p = New-ProfilePath "user"
        [IO.File]::WriteAllText($p, "Set-Alias ll Get-ChildItem`n`n# >>> aitools managed >>>`n`$stale = 1`n# <<< aitools managed <<<`n`nfunction Get-Foo { 'foo' }`n")
        $u1 = Invoke-Setup "user" $p
        $u2 = Invoke-Setup "user" $p
        Check "stale block: replaced by the current block (OK refreshed)" (($u1.Rc -eq 0) -and -not $u1.Text.Contains('$stale') -and $u1.Text.Contains($pathBlock) -and ($u1.Summary -match 'OK\|shell\|managed block refreshed'))
        Check "stale block: user lines before and after kept, in place" ($u1.Text.StartsWith("Set-Alias ll Get-ChildItem`n`n$pathBlock`nfunction Get-Foo { 'foo' }`n"))
        Check "stale block: one block, no parse errors, re-run byte-identical" (($u1.Blocks -eq 1) -and ($u1.ParseErrors -eq 0) -and ($u2.Rc -eq 0) -and ($u2.Text -ceq $u1.Text))
        Check "stale block: one backup taken (first run only)" ($u2.Backups -eq 1)

        # --- Duplicate blocks collapse to one at the first block's position ---
        $p = New-ProfilePath "dup"
        [IO.File]::WriteAllText($p, "# u1`n$oldBlock`n# u2`n$oldBlock`n`n# u3`n$pathStart`n`$x = 1`n$pathEnd`n# u4`n")
        $d = Invoke-Setup "dup" $p
        Check "duplicates: exit 0, OK collapsed 3 blocks to 1" (($d.Rc -eq 0) -and ($d.Summary -match 'OK\|shell\|collapsed 3 blocks to 1'))
        Check "duplicates: one block at the first position, user lines kept in order" (($d.Blocks -eq 1) -and $d.Text.StartsWith("# u1`n$pathBlock# u2`n`n# u3`n# u4`n"))
        Check "duplicates: no WARN (nothing damaged), no parse errors" (($d.Summary -notmatch 'WARN') -and ($d.ParseErrors -eq 0))

        # --- Stray marker lines are ours: removed ---
        $p = New-ProfilePath "orphan"
        [IO.File]::WriteAllText($p, "# a`n$pathEnd`n$oldBlock`n# b`n$pathEnd`n")
        $o = Invoke-Setup "orphan" $p
        Check "stray marker lines: removed, one block, user lines kept" (($o.Rc -eq 0) -and ($o.Blocks -eq 1) -and ((Count-Lines $o.Text $pathEnd) -eq 1) -and $o.Text.StartsWith("# a`n$pathBlock# b`n"))

        # --- #172-style corrupted profile (old buggy splice run twice) ---
        $corrupt = New-CorruptedProfile
        $errsBefore = Get-ParseErrors $corrupt
        Check "fixture: corrupted profile has 84 blocks, parse errors, stray fragments" (((Count-Lines $corrupt $pathStart) -eq 84) -and ($errsBefore -gt 0) -and ($corrupt -match '(?m)^_aitoolsLocalBin'))
        $p = New-ProfilePath "corrupt"
        [IO.File]::WriteAllText($p, $corrupt)
        [IO.File]::WriteAllText("$p.bak.2026-01-01T000000Z", "Set-Alias ll Get-ChildItem`n`n$oldBlock`n")
        [IO.File]::WriteAllText("$p.bak.2026-02-01T000000Z", "$oldBlock`n$oldBlock`n")
        [IO.File]::WriteAllText("$p.bak.2026-03-01T000000Z", "$oldBlock`n_aitoolsLocalBin = Join-Path `$HOME `".local\bin`"`n")
        $c1 = Invoke-Setup "corrupt" $p
        Check "corrupted: exit 0, WARN profile damage left in place" (($c1.Rc -eq 0) -and ($c1.Summary -match 'WARN\|shell\|profile damage left in place'))
        Check "corrupted: exactly one PATH block and one integration block, no legacy block" (($c1.Blocks -eq 1) -and ($c1.Integ -eq 1) -and ($c1.Legacy -eq 0) -and ((Count-Lines $c1.Text $pathEnd) -eq 1))
        Check "corrupted: no more parse errors than before ($($c1.ParseErrors) <= $errsBefore)" ($c1.ParseErrors -le $errsBefore)
        Check "corrupted: user line kept, stray fragments left in place" ($c1.Text.StartsWith("Set-Alias ll Get-ChildItem`n") -and ($c1.Text -match '(?m)^_aitoolsLocalBin'))
        Check "corrupted: ACTION names the newest clean backup (2026-01-01; 02 has 2 blocks, 03 a stray line)" ($c1.Summary -match [regex]::Escape("ACTION||Restore $p from $p.bak.2026-01-01T000000Z"))
        $c2 = Invoke-Setup "corrupt" $p
        Check "corrupted: re-run byte-identical, still WARN + ACTION" (($c2.Rc -eq 0) -and ($c2.Text -ceq $c1.Text) -and ($c2.Summary -match 'WARN\|shell\|profile damage left in place') -and ($c2.Summary -match 'ACTION\|\|Restore '))

        $p = New-ProfilePath "corrupt-nobak"
        [IO.File]::WriteAllText($p, $corrupt)
        $n1 = Invoke-Setup "corrupt-nobak" $p
        Check "corrupted, no clean backup: ACTION says repair by hand" (($n1.Rc -eq 0) -and ($n1.Summary -match [regex]::Escape("ACTION||Repair $p by hand (no clean backup)")))

        # --- Legacy "# aitools shell integration" block (incident #173) ---
        $p = New-ProfilePath "legacy"
        [IO.File]::WriteAllText($p, "$oldBlock`n`n`n# aitools shell integration`n. `"C:\old\aitools\shared\shell\aliases.ps1`"`nfunction aitools { & `"`$HOME\.local\bin\aitools.ps1`" @args }`nfunction hh { & `"`$HOME\.local\bin\hh.ps1`" @args }`nSet-Alias mine Get-Date`n`n# tail`n")
        $l1 = Invoke-Setup "legacy" $p
        Check "legacy: exit 0, OK legacy integration migrated" (($l1.Rc -eq 0) -and ($l1.Summary -match 'OK\|shell\|legacy integration migrated'))
        Check "legacy: user line right after function hh kept (#173)" $l1.Text.Contains("# <<< aitools shell integration <<<`nSet-Alias mine Get-Date`n`n# tail`n")
        Check "legacy: block replaced in place, one blank line above removed" $l1.Text.StartsWith("$pathBlock`n$integStart`n")
        Check "legacy: old lines gone, one integration block, no parse errors" (($l1.Legacy -eq 0) -and ($l1.Integ -eq 1) -and -not $l1.Text.Contains('C:\old\aitools') -and ($l1.ParseErrors -eq 0))
        $l2 = Invoke-Setup "legacy" $p
        Check "legacy: re-run byte-identical, unchanged" (($l2.Text -ceq $l1.Text) -and ($l2.Summary -match 'OK\|shell\|integration unchanged'))

        # --- Legacy "# ai-tooling" block, and two legacy blocks, with CRLF lines ---
        $p = New-ProfilePath "legacy2"
        [IO.File]::WriteAllText($p, "Set-Alias a b`r`n`r`n# ai-tooling shell integration`r`n. `"C:\x\ai-tooling\shared\shell\aliases.ps1`"`r`nfunction hh { & hh.ps1 @args }`r`n`r`n# aitools shell integration`r`n. `"C:\x\aitools\shared\shell\aliases.ps1`"`r`n# keep me`r`n")
        $m1 = Invoke-Setup "legacy2" $p
        Check "two legacy blocks (CRLF): both removed, one integration block at the first" (($m1.Rc -eq 0) -and ($m1.Legacy -eq 0) -and ($m1.Integ -eq 1) -and $m1.Text.StartsWith("Set-Alias a b`r`n$integStart`n"))
        Check "two legacy blocks (CRLF): user lines kept byte for byte" ($m1.Text.Contains("# <<< aitools shell integration <<<`n# keep me`r`n") -and -not $m1.Text.Contains('C:\x\'))

        # --- MDM: aliases.ps1 absent ---
        $p = New-ProfilePath "mdm"
        $mdmBefore = "# mine`n$legacyInteg"
        [IO.File]::WriteAllText($p, $mdmBefore)
        $a1 = Invoke-Setup "mdm" $p $noAliases
        Check "MDM: exit 0, WARN aliases.ps1 not found, OK managed block added" (($a1.Rc -eq 0) -and ($a1.Summary -match 'WARN\|shell\|aliases.ps1 not found') -and ($a1.Summary -match '\|shell\|managed block added'))
        Check "MDM: legacy integration left as is, no integration block written" (($a1.Legacy -eq 1) -and ($a1.Integ -eq 0) -and $a1.Text.StartsWith($mdmBefore))
        $p = New-ProfilePath "mdm2"
        [IO.File]::WriteAllText($p, $r1.Text)
        $a2 = Invoke-Setup "mdm2" $p $noAliases
        Check "MDM: an existing integration block is kept, profile unchanged" (($a2.Rc -eq 0) -and ($a2.Text -ceq $r1.Text) -and ($a2.Backups -eq 0))

        # --- Encoding: BOM kept; a non-UTF-8 profile is not rewritten ---
        $p = New-ProfilePath "bom"
        [IO.File]::WriteAllText($p, "# bom`n", [System.Text.UTF8Encoding]::new($true))
        $b1 = Invoke-Setup "bom" $p
        $bytes = [IO.File]::ReadAllBytes($p)
        Check "BOM: kept after the write" (($b1.Rc -eq 0) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF))
        $p = New-ProfilePath "latin1"
        [IO.File]::WriteAllBytes($p, [byte[]](0x23, 0x20, 0x63, 0x61, 0x66, 0xE9, 0x0A))
        $e1 = Invoke-Setup "latin1" $p
        $after = [IO.File]::ReadAllBytes($p)
        Check "non-UTF-8: exit 1, ERROR row, file unchanged" (($e1.Rc -eq 1) -and ($e1.Summary -match 'ERROR\|shell\|profile not readable as UTF-8') -and ($after.Length -eq 7))

        # --- A splice that would break the profile is refused ---
        # The block is commented out with a <# #> that closes before the end
        # marker: the splice would drop the #> and leave the comment unterminated.
        $p = New-ProfilePath "guard"
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
