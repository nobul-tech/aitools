# test-fanout-lib.ps1 -- tests for the fan-out helpers in scripts/aitools-lib.ps1
# (plans/skills-and-rules-fanout.md section 3.3, batch FO-1): the deploy tracker's
# "removed" outcome and unknown outcomes (counted as failed), Get-RuleNameKind,
# Get-SkillNameKind, Read-HarnessManifest (rules and skills: ok, header-bad, BOM,
# CRLF, invalid lines, duplicates, unknown kind), a guard that setup-user-cursor
# has no copy of the reader or list helpers, Test-FanoutTextEqual,
# Test-FanoutDirMatches (match, extra or missing file, *.bak.* ignored, empty
# dir) and Backup-Dir.
# The Windows harness of this suite; tests/fanout-lib/test-fanout-lib.sh is the
# macOS/Linux harness of the same cases for scripts/aitools-lib.sh.
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# one driver (a child pwsh) dot-sources aitools-lib.ps1 under an isolated HOME
# and log dir and runs the whole case list; every result must equal the
# expectation. Parity with aitools-lib.sh is checked against the committed
# golden results in tests/fanout-lib/golden/ (Test-GoldenMatch in
# tests/lib/platform-lib.ps1), one file per fixture group. Only the base group
# runs on Windows: the symlinks, fifos, special and unread groups are skipped
# (reasons printed; see the Skips section below).
#
# Safe to re-run: everything lives in a temp dir removed on exit; the real HOME
# is never read or written. Exit 1 if any check fails.
#
# Usage: pwsh -NoProfile -File tests/fanout-lib/test-fanout-lib.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 25 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/fanout-lib/test-fanout-lib.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$WORK = New-TestTempRoot "fanout-lib"
$GoldenDir = Join-Path $root "tests/fanout-lib/golden"
$GoldenTmp = $WORK
$S = "ps"   # the driver tag: check names and the fixtures' "@" copy (bd/ps)

$script:pass = 0; $script:fail = 0; $script:skip = 0
# Output lines as the .sh prints them ("  ok   NAME", "  FAIL NAME")
function Ok([string]$Name) { $script:pass++; Write-Output "  ok   $Name" }
function Bad([string]$Name) { $script:fail++; Write-Output "  FAIL $Name" }

# Fixture writers: W writes TEXT as bytes, one byte per char (Latin1), so
# [char]0xEF etc. give the exact bytes the .sh writes with printf '\xEF'.
function New-Dir([string]$Path) { [IO.Directory]::CreateDirectory($Path) | Out-Null }
function W([string]$Path, [string]$Text) {
    New-Dir ([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllBytes($Path, [Text.Encoding]::Latin1.GetBytes($Text))
}

try {
    $F = Join-Path $WORK "fix"   # fixtures; case arguments are paths relative to it
    New-Dir $F

    # -----------------------------------------------------------------------
    # Fixtures (the base group's, byte for byte as the .sh writes them)
    # -----------------------------------------------------------------------
    # Mf FILE HEADER LINE...: a manifest; "|" in a LINE stands for the TAB
    function Mf([string]$File, [string]$Header, [string[]]$Lines = @()) {
        $t = "$Header`n"
        foreach ($l in $Lines) { $t += ($l -replace '\|', "`t") + "`n" }
        W (Join-Path $F $File) $t
    }
    $RH = "# aitools rules manifest v1"
    $SH = "# aitools skills manifest v1"
    $bom = [string][char]0xEF + [char]0xBB + [char]0xBF

    Mf "r-ok" $RH @("a.md|shared", "b.md|aitools", "c.md|dotprofile", "d.md|retired")
    Mf "r-headerbad" "# aitools rules manifest v2" @("a.md|shared")
    Mf "r-skillshead" $SH @("a.md|shared")
    Mf "r-headeronly" $RH
    Mf "r-invalid" $RH @("noext|shared", "sub/x.md|shared", 'back\x.md|shared', "y.bak.2.md|shared",
        "z.md|bogus", "w.md", "v.md|shared|extra", "", "u.md|shared", "U.md|dotprofile", "|shared",
        ".hidden.md|shared", "my-skill|shared")
    W (Join-Path $F "r-bom") "$bom# aitools rules manifest v1`na.md`tshared`n"
    W (Join-Path $F "r-crlf") "# aitools rules manifest v1`r`na.md`tshared`r`nb.md`taitools`r`ne.md`tshared`r"
    W (Join-Path $F "r-nolf") "# aitools rules manifest v1"
    W (Join-Path $F "r-crnolf") "# aitools rules manifest v1`r"
    W (Join-Path $F "r-empty") ""
    New-Dir (Join-Path $F "r-dir")

    Mf "s-ok" $SH @("my-skill|shared", "Other|aitools", "third|dotprofile", "gone|retired")
    Mf "s-ruleshead" $RH @("my-skill|shared")
    Mf "s-invalid" $SH @(".hidden|shared", "a/b|shared", 'a\b|shared', "x.bak.1|shared", "dup|shared",
        "DUP|aitools", "ok.md|shared", "q|nope", "My Skill|dotprofile", "|shared")
    W (Join-Path $F "s-bomcrlf") "$bom# aitools skills manifest v1`r`nmy-skill`tshared`r`n"

    # text_equal fixtures
    $T = Join-Path $F "t"
    W "$T/a-lf" "a`n"
    W "$T/a-crlf2" "a`r`n`n"
    W "$T/a-none" "a"
    W "$T/b" "b`n"
    W "$T/ab-crlf" "a`r`nb`n"
    W "$T/ab-lf" "a`nb`n"
    W "$T/empty" ""
    W "$T/nl" "`n"
    W "$T/bin1" ([string][char]0xFF + [char]0xFE + [char]0xC3 + [char]0xA9 + "`n")
    W "$T/bin2" ([string][char]0xFF + [char]0xFE + [char]0xC3 + [char]0xA9)
    New-Dir "$T/dir"

    # dir_matches fixtures: d/<case>/T (the deployed copy) and d/<case>/C (harness copy)
    function Skill([string]$Dir) {  # a small skill tree
        New-Dir "$Dir/sub/deep"
        W "$Dir/SKILL.md" "---`nname: s`n---`nBody`n"
        W "$Dir/sub/x.txt" "x`n"
        W "$Dir/sub/deep/y.sh" "y`n"
    }
    $D = Join-Path $F "d"
    Skill "$D/match/T"; Skill "$D/match/C"
    W "$D/match/C/SKILL.md.crlf" "---`r`nname: s`r`n---`r`nBody`r`n`r`n"   # not under T: ignored
    W "$D/match/C/SKILL.md" "---`nname: s`n---`nBody`r`n`n"              # trailing CR/LF differ only
    Skill "$D/extra/T"; Skill "$D/extra/C"; W "$D/extra/T/mine.md" "user`n"
    Skill "$D/candextra/T"; Skill "$D/candextra/C"; W "$D/candextra/C/new.md" "new`n"
    Skill "$D/differ/T"; Skill "$D/differ/C"; W "$D/differ/T/sub/deep/y.sh" "y2`n"
    Skill "$D/innercr/T"; Skill "$D/innercr/C"; W "$D/innercr/T/sub/x.txt" "x`r`ny`n"; W "$D/innercr/C/sub/x.txt" "x`ny`n"
    Skill "$D/bak/T"; Skill "$D/bak/C"
    W "$D/bak/T/SKILL.md.bak.2026-10-26T010203Z" "old`n"
    W "$D/bak/T/sub/X.BAK.1" "old`n"
    New-Dir "$D/empty/T"; New-Dir "$D/empty/C"
    New-Dir "$D/onlybak/T"; New-Dir "$D/onlybak/C"; W "$D/onlybak/T/SKILL.md.bak.1" "old`n"
    New-Dir "$D/emptysub/T/sub"; New-Dir "$D/emptysub/C"
    Skill "$D/hidden/T"; Skill "$D/hidden/C"; W "$D/hidden/T/.DS_Store" "ds`n"
    Skill "$D/candmissing/T"
    Skill "$D/canddir/T"; Skill "$D/canddir/C"; [IO.File]::Delete("$D/canddir/C/sub/x.txt"); New-Dir "$D/canddir/C/sub/x.txt"
    W "$D/targetfile/T" "f`n"; Skill "$D/targetfile/C"
    Skill "$D/targetmissing/C"

    # backup_dir fixtures, in this driver's copy bd/ps (the run backs them up)
    $B = Join-Path $F "bd/$S"
    New-Dir "$B/plain/rules"; New-Dir "$B/nomd/d"; New-Dir "$B/missing"; New-Dir "$B/mdcase/upper"
    W "$B/plain/rules/a.md" "a`n"
    W "$B/mdcase/upper/X.MD" "u`n"   # the *.md count ignores case
    W "$B/nomd/d/x.txt" "x`n"

    # -----------------------------------------------------------------------
    # Skips: the fixture groups Windows cannot build (the .sh harness skipped
    # the same groups, with the same counts, when it ran on Windows in Git Bash)
    # -----------------------------------------------------------------------
    # symlinks (7): creating a symlink needs Developer Mode or an elevated
    #   process on Windows (CreateSymbolicLink: "A required privilege is not held
    #   by the client", seen 2026-11-14 on a non-elevated session). The group has
    #   never run on Windows; enabling it is the follow-up named in PR #139.
    # fifos (2): NTFS has no FIFOs (named pipes live in \\.\pipe\, not in a
    #   directory tree).
    # special (1): Windows refuses * ? in file names ("The filename, directory
    #   name, or volume label syntax is incorrect").
    # unread (10): chmod 000 has no NTFS meaning; an ACL-based equivalent is new
    #   fixture design (the PR #139 follow-up), not a port.
    $script:skip += 7; Write-Output "  skip symlink cases (Windows: making symlinks needs Developer Mode or an elevated process)"
    $script:skip += 2; Write-Output "  skip FIFO cases (Windows: NTFS has no FIFOs)"
    $script:skip += 1; Write-Output "  skip backup_dir special-name case (* ? not allowed in names here)"
    $script:skip += 10; Write-Output "  skip unreadable cases (Windows: chmod 000 has no NTFS equivalent here)"

    # -----------------------------------------------------------------------
    # Cases: id <TAB> expected <TAB> call <TAB> arg1 [<TAB> arg2]; no empty fields.
    # Manifest results: lines joined with " ;; ", rule lines first, TAB shown as ^,
    # CR as <CR>, "(none)" for no line, "fail" when the reader fails or throws.
    # The same list as the .sh's base group, in the same order (sh_ cases kept so
    # the case file is the .sh's; the driver and the checks skip them).
    # -----------------------------------------------------------------------
    $caseList = New-Object System.Collections.Generic.List[object]
    function Case([string]$Id, [string]$Want, [string]$Call, [string]$A1, [string]$A2 = "") {
        $caseList.Add([pscustomobject]@{ Id = $Id; Want = $Want; Call = $Call; A1 = $A1; A2 = $A2; Group = "base" })
    }
    # deploy tracker ("pairs" outcome:item, comma separated)
    Case 't-removed' 'DETAIL|t|removed: a.md ;; OK|t|1 removed ;; text=1 removed ;; errors=0' 'tracker' 'removed:a.md'
    Case 't-unknown' 'DETAIL|t|failed: b.md ;; ERROR|t|1 failed ;; text=1 failed ;; errors=1' 'tracker' 'bogus:b.md'
    Case 't-blank' 'DETAIL|t|failed: x.md ;; ERROR|t|1 failed ;; text=1 failed ;; errors=1' 'tracker' ':x.md'
    Case 't-mix' 'DETAIL|t|added: a.md ;; DETAIL|t|removed: b.md ;; DETAIL|t|failed: d.md ;; ERROR|t|1 failed ;; text=1 added, 1 removed, 1 verified, 1 failed ;; errors=1' 'tracker' 'added:a.md,removed:b.md,verified:c.md,bogus:d.md,preserved:e.md'
    Case 't-order' 'DETAIL|t|accept & adopt: a.md ;; DETAIL|t|removed: b.md ;; DETAIL|t|updated: d.md ;; DETAIL|t|added: e.md ;; OK|t|1 added, 1 updated, 1 accepted, 1 removed, 1 verified ;; text=1 added, 1 updated, 1 accepted, 1 removed, 1 verified ;; errors=0' 'tracker' 'accept & adopt:a.md,removed:b.md,verified:c.md,updated:d.md,created:e.md'
    Case 't-skip' 'DETAIL|t|removed: a.md ;; DETAIL|t|skipped: b.md ;; WARN|t|1 skipped (user review) ;; text=1 removed ;; errors=0' 'tracker' 'removed:a.md,skipped:b.md'
    # every count 0 (only preserved / skipped items): the text is "n/a (nothing to deploy)", never "verified"
    Case 't-preserved' 'OK|t|n/a (nothing to deploy) ;; text=n/a (nothing to deploy) ;; errors=0' 'tracker' 'preserved:a.md'
    Case 't-skiponly' 'DETAIL|t|skipped: a.md ;; WARN|t|1 skipped (user review) ;; text=n/a (nothing to deploy) ;; errors=0' 'tracker' 'skipped:a.md'
    # outcomes are matched case-sensitively in both shells
    Case 't-case' 'DETAIL|t|failed: x.md ;; DETAIL|t|failed: y.md ;; DETAIL|t|failed: z.md ;; ERROR|t|3 failed ;; text=3 failed ;; errors=3' 'tracker' 'Removed:x.md,Added:y.md,CREATED:z.md'
    # name kinds: NAME RULE-KIND SKILL-KIND
    foreach ($spec in @("a.md rule skill", "A.MD rule skill", ".hidden.md hidden hidden", ".aitools-skills-manifest hidden hidden",
                        "x.md.bak.2026-10-22T010203Z backup backup", "X.MD.BAK.1 backup backup", "odd.bak.2026.md backup backup",
                        "Skill.Bak.1 backup backup", "skill.bak other skill", "notes.txt other skill", "my-skill other skill",
                        "My_Skill-2 other skill")) {
        $w = $spec -split ' '
        Case "rk-$($w[0])" $w[1] 'rkind' $w[0]
        Case "sk-$($w[0])" $w[2] 'skind' $w[0]
    }
    # manifests
    Case 'm-r-ok' 'rule^a.md^shared ;; rule^b.md^aitools ;; rule^c.md^dotprofile ;; rule^d.md^retired' 'manifest' 'r-ok' 'rules'
    Case 'm-r-headerbad' 'header-bad' 'manifest' 'r-headerbad' 'rules'
    Case 'm-r-skillshead' 'header-bad' 'manifest' 'r-skillshead' 'rules'
    Case 'm-r-headeronly' '(none)' 'manifest' 'r-headeronly' 'rules'
    Case 'm-r-invalid' 'rule^u.md^shared ;; rule^.hidden.md^shared ;; invalid^noext<TAB>shared ;; invalid^sub/x.md<TAB>shared ;; invalid^back\x.md<TAB>shared ;; invalid^y.bak.2.md<TAB>shared ;; invalid^z.md<TAB>bogus ;; invalid^w.md ;; invalid^v.md<TAB>shared<TAB>extra ;; invalid^U.md<TAB>dotprofile ;; invalid^<TAB>shared ;; invalid^my-skill<TAB>shared' 'manifest' 'r-invalid' 'rules'
    Case 'm-r-bom' 'rule^a.md^shared' 'manifest' 'r-bom' 'rules'
    Case 'm-r-crlf' 'rule^a.md^shared ;; rule^b.md^aitools ;; invalid^e.md<TAB>shared<CR>' 'manifest' 'r-crlf' 'rules'
    Case 'm-r-nolf' '(none)' 'manifest' 'r-nolf' 'rules'
    Case 'm-r-crnolf' 'header-bad' 'manifest' 'r-crnolf' 'rules'
    Case 'm-r-empty' 'header-bad' 'manifest' 'r-empty' 'rules'
    Case 'm-r-dir' 'fail' 'manifest' 'r-dir' 'rules'
    Case 'm-r-missing' 'fail' 'manifest' 'r-missing' 'rules'
    Case 'm-s-ok' 'rule^my-skill^shared ;; rule^Other^aitools ;; rule^third^dotprofile ;; rule^gone^retired' 'manifest' 's-ok' 'skills'
    Case 'm-s-ruleshead' 'header-bad' 'manifest' 's-ruleshead' 'skills'
    Case 'm-s-invalid' 'rule^dup^shared ;; rule^ok.md^shared ;; rule^My Skill^dotprofile ;; invalid^.hidden<TAB>shared ;; invalid^a/b<TAB>shared ;; invalid^a\b<TAB>shared ;; invalid^x.bak.1<TAB>shared ;; invalid^DUP<TAB>aitools ;; invalid^q<TAB>nope ;; invalid^<TAB>shared' 'manifest' 's-invalid' 'skills'
    Case 'm-s-bomcrlf' 'rule^my-skill^shared' 'manifest' 's-bomcrlf' 'skills'
    Case 'm-s-rulesfile' 'header-bad' 'manifest' 'r-ok' 'skills'
    Case 'm-kind-caps' 'fail' 'manifest' 'r-ok' 'Rules'
    Case 'm-kind-bogus' 'fail' 'manifest' 'r-ok' 'bogus'
    # read_harness_manifest exit codes (bash only: PowerShell throws)
    Case 'mrc-ok' 'rc=0' 'sh_mrc' 'r-ok' 'rules'
    Case 'mrc-headerbad' 'rc=0' 'sh_mrc' 'r-headerbad' 'rules'
    Case 'mrc-missing' 'rc=1' 'sh_mrc' 'r-missing' 'rules'
    Case 'mrc-dir' 'rc=1' 'sh_mrc' 'r-dir' 'rules'
    Case 'mrc-kind' 'rc=2' 'sh_mrc' 'r-ok' 'Rules'
    # text equality
    Case 'te-trailing' 'rc=0' 'teq' 't/a-lf' 't/a-crlf2'
    Case 'te-nonl' 'rc=0' 'teq' 't/a-none' 't/a-lf'
    Case 'te-differ' 'rc=1' 'teq' 't/a-lf' 't/b'
    Case 'te-innercr' 'rc=1' 'teq' 't/ab-crlf' 't/ab-lf'
    Case 'te-emptynl' 'rc=0' 'teq' 't/empty' 't/nl'
    Case 'te-bytes' 'rc=0' 'teq' 't/bin1' 't/bin2'
    Case 'te-missing' 'rc=2' 'teq' 't/a-lf' 't/nope'
    Case 'te-missing1' 'rc=2' 'teq' 't/nope' 't/a-lf'
    Case 'te-dir' 'rc=2' 'teq' 't/dir' 't/a-lf'
    Case 'te-emptyarg' 'rc=2' 'teq' '-' 't/a-lf'
    # perl itself fails (bash only)
    Case 'te-perlfail' 'rc=2' 'sh_teqperl' 't/a-lf' 't/b'
    # directory match
    Case 'dm-match' 'rc=0' 'dmatch' 'd/match/T' 'd/match/C'
    Case 'dm-extra' 'rc=1' 'dmatch' 'd/extra/T' 'd/extra/C'
    Case 'dm-candextra' 'rc=0' 'dmatch' 'd/candextra/T' 'd/candextra/C'
    Case 'dm-differ' 'rc=1' 'dmatch' 'd/differ/T' 'd/differ/C'
    Case 'dm-innercr' 'rc=1' 'dmatch' 'd/innercr/T' 'd/innercr/C'
    Case 'dm-bak' 'rc=0' 'dmatch' 'd/bak/T' 'd/bak/C'
    Case 'dm-empty' 'rc=1' 'dmatch' 'd/empty/T' 'd/empty/C'
    Case 'dm-onlybak' 'rc=1' 'dmatch' 'd/onlybak/T' 'd/onlybak/C'
    Case 'dm-emptysub' 'rc=1' 'dmatch' 'd/emptysub/T' 'd/emptysub/C'
    Case 'dm-hidden' 'rc=1' 'dmatch' 'd/hidden/T' 'd/hidden/C'
    Case 'dm-candmissing' 'rc=1' 'dmatch' 'd/candmissing/T' 'd/candmissing/C'
    Case 'dm-canddir' 'rc=1' 'dmatch' 'd/canddir/T' 'd/canddir/C'
    Case 'dm-targetfile' 'rc=1' 'dmatch' 'd/targetfile/T' 'd/targetfile/C'
    Case 'dm-targetmissing' 'rc=1' 'dmatch' 'd/targetmissing/T' 'd/targetmissing/C'
    Case 'dm-emptytarget' 'rc=1' 'dmatch' '-' 'd/match/C'
    Case 'dm-emptycand' 'rc=1' 'dmatch' 'd/match/T' '-'
    # Backup-Dir ("@" is the driver's own fixture copy); <TS> is this run's stamp
    Case 'bd-plain' 'ok=true reason=- path=rules.bak.<TS> copied=yes siblings=rules,rules.bak.<TS>' 'bdir' 'bd/@/plain/rules'
    Case 'bd-nomd' 'ok=false reason=no top-level *.md path=- copied=no siblings=d' 'bdir' 'bd/@/nomd/d'
    Case 'bd-missing' 'ok=false reason=no directory path=- copied=no siblings=(none)' 'bdir' 'bd/@/missing/nope'
    Case 'bd-mdcase' 'ok=true reason=- path=upper.bak.<TS> copied=yes siblings=upper,upper.bak.<TS>' 'bdir' 'bd/@/mdcase/upper'

    $CASES = Join-Path $WORK "cases"
    $caseText = ($caseList | ForEach-Object {
        $line = "$($_.Id)`t$($_.Want)`t$($_.Call)`t$($_.A1)"
        if ($_.A2) { $line += "`t$($_.A2)" }
        $line
    }) -join "`n"
    [IO.File]::WriteAllText($CASES, $caseText + "`n", [Text.UTF8Encoding]::new($false))

    # setup-user-cursor's own copies of the manifest reader and list helpers were
    # deleted in FO-5 (it uses the lib's, FAN-PLAN F1): fail if one comes back.
    # Lines split on LF only, as grep reads them (a CRLF line keeps its CR, which
    # these start-anchored patterns never reach).
    function Test-AnyLine([string]$Path, [string]$Pattern) {
        foreach ($l in ([IO.File]::ReadAllText($Path) -split "`n")) { if ($l -cmatch $Pattern) { return $true } }
        return $false
    }
    if ((Test-AnyLine (Join-Path $root "scripts/setup-user-cursor.sh") '^(read_rules_manifest|lower_name|in_list)\(\)') -or
        (Test-AnyLine (Join-Path $root "scripts/setup-user-cursor.ps1") '^function Read-RulesManifest\b|^\$rulesManifestHeader =')) {
        Bad "setup-user-cursor defines its own manifest reader or list helpers again (use the lib's, FAN-PLAN F1)"
    } else {
        Ok "setup-user-cursor uses the lib's manifest reader and list helpers (no copies)"
    }

    # -----------------------------------------------------------------------
    # Driver: dot-source the lib, run every case, write "<id><TAB><result>" lines
    # (moved unchanged from the .sh harness, where it ran under Git Bash)
    # -----------------------------------------------------------------------
    $drive = Join-Path $WORK "drive.ps1"
    [IO.File]::WriteAllText($drive, @'
# Dot-source the lib, run every case from $env:CASES, write "<id><TAB><result>" lines to $env:OUT
$ErrorActionPreference = "Stop"
. (Join-Path $env:REPO "scripts/aitools-lib.ps1")
Initialize-Logging "test-fanout-lib"
$F = $env:F
$results = New-Object System.Collections.Generic.List[string]
function Format-Manifest($r) {
    if ($r.Status -eq "header-bad") { return "header-bad" }
    $a = @()
    foreach ($x in $r.Rules) { $a += "rule^$($x.Name)^$($x.Source)" }
    foreach ($x in $r.Invalid) { $a += "invalid^$x" }
    $a = @($a | ForEach-Object { $_ -replace "`r", "<CR>" })
    if ($a.Count -eq 0) { return "(none)" }
    return ($a -join " ;; ")
}
function Resolve-Fx([string]$Rel) {  # "-" is the empty string, "@" this shell's copy (ps)
    if ($Rel -eq "-") { return "" }
    return (Join-Path $F $Rel).Replace("@", "ps")
}
function Get-Names([string]$Dir) {  # sorted top-level names, comma-joined (as names_of in drive.sh)
    if (-not [IO.Directory]::Exists($Dir)) { return "" }
    [string[]]$n = @([IO.Directory]::GetFileSystemEntries($Dir) | ForEach-Object { [IO.Path]::GetFileName($_) })
    [Array]::Sort($n, [StringComparer]::Ordinal)
    return ($n -join ",")
}
function Get-EntryType([string]$Path) {  # link | dir | file:<first line> | missing (as entry_type in drive.sh)
    $info = [IO.FileInfo]::new($Path)
    if ($null -ne $info.LinkTarget) { return "link" }
    if ([IO.Directory]::Exists($Path)) { return "dir" }
    if ([IO.File]::Exists($Path)) { return "file:" + (([IO.File]::ReadAllText($Path) -split "`n")[0]) }
    return "missing"
}
function Invoke-Reader([scriptblock]$Read) {
    try { return Format-Manifest (& $Read) } catch { LogDetail "reader threw: $_"; return "fail" }
}
foreach ($line in [IO.File]::ReadAllLines($env:CASES)) {
    if ($line.StartsWith("#")) { continue }   # a "#group" line
    $fields = $line -split "`t"   # (not $f: PowerShell names are case-insensitive, $F is the fixtures dir)
    $id = $fields[0]; $call = $fields[2]
    $a1 = if ($fields.Count -gt 3) { $fields[3] } else { "" }
    $a2 = if ($fields.Count -gt 4) { $fields[4] } else { "" }
    if ($call.StartsWith("sh_")) { continue }   # bash-only case (ps_ cases run only here)
    switch -CaseSensitive ($call) {
        "tracker" {
            $env:AITOOLS_SUMMARY_FILE = Join-Path $env:WORK "sum-ps-$id"
            [IO.File]::WriteAllText($env:AITOOLS_SUMMARY_FILE, "")
            $e0 = $script:errors
            Initialize-DeployTracker
            foreach ($pair in ($a1 -split ",")) {
                $c = $pair.IndexOf(":")
                Record-DeployOutcome -Outcome $pair.Substring(0, $c) -ToolName "t" -ItemName $pair.Substring($c + 1)
            }
            Write-DeployTrackerSummary -ToolName "t"
            $rows = @([IO.File]::ReadAllLines($env:AITOOLS_SUMMARY_FILE)) -join " ;; "
            $res = "$rows ;; text=$($script:deployTrackerText) ;; errors=$($script:errors - $e0)"
        }
        "rkind" { $res = Get-RuleNameKind $a1 }
        "skind" { $res = Get-SkillNameKind $a1 }
        "manifest" { $p = Join-Path $F $a1; $k = $a2; $res = Invoke-Reader { Read-HarnessManifest -Path $p -Kind $k } }
        "teq" { $res = "rc=" + (Test-FanoutTextEqual (Resolve-Fx $a1) (Resolve-Fx $a2)) }
        "dmatch" { $res = "rc=" + (Test-FanoutDirMatches (Resolve-Fx $a1) (Resolve-Fx $a2)) }
        { $_ -ceq "dmf" -or $_ -ceq "dmfdry" } {
            $p = Resolve-Fx $a1
            $DryRun = ($call -ceq "dmfdry")
            $r = Deploy-ManagedFile -Content "new" -DestPath $p -ToolName "t" -ItemName ([IO.Path]::GetFileName($p)) 6>$null
            $DryRun = $false
            $lt = [IO.FileInfo]::new($p).LinkTarget
            $tgt = if ($null -eq $lt) { "notlink" }
                   elseif (-not (Test-Path -LiteralPath $lt)) { "target=absent" }
                   else { "target=" + ([IO.File]::ReadAllText($lt) -replace '\n\z', '') }
            $res = "result=$r $tgt"
        }
        "ps_bdirlink" {
            $p = Resolve-Fx $a1
            Backup-Dir -DirPath $p
            $b = $script:BackupDirPath
            $x = if ([IO.File]::Exists([IO.Path]::Combine($b, "sub", "x.txt"))) { "yes" } else { "no" }
            $ok = if ($script:BackupDirOk) { "true" } else { "false" }
            $res = "ok=$ok l.md=$(Get-EntryType ([IO.Path]::Combine($b, 'l.md'))) sub=$(Get-EntryType ([IO.Path]::Combine($b, 'sub'))) sub/x.txt=$x"
        }
        "bdir" {
            $p = Resolve-Fx $a1
            Backup-Dir -DirPath $p
            $copied = "no"   # yes: the copy holds the same top-level names as the source
            if ($script:BackupDirOk) {
                $srcNames = Get-Names $p; $bakNames = Get-Names $script:BackupDirPath
                if ($srcNames -and $srcNames -ceq $bakNames) { $copied = "yes" }
            }
            $bp = if ($script:BackupDirPath) { [IO.Path]::GetFileName($script:BackupDirPath) } else { "-" }
            try {
                [string[]]$sib = @([IO.Directory]::GetFileSystemEntries([IO.Path]::GetDirectoryName($p)) | ForEach-Object { [IO.Path]::GetFileName($_) })
                [Array]::Sort($sib, [StringComparer]::Ordinal)
                $sibText = if ($sib.Count -gt 0) { $sib -join "," } else { "(none)" }
            } catch {
                LogDetail "driver: cannot list the parent of ${p}: $_"
                $sibText = "cannot list"
            }
            $reason = if ($script:BackupDirReason) { $script:BackupDirReason } else { "-" }
            $ok = if ($script:BackupDirOk) { "true" } else { "false" }
            $res = "ok=$ok reason=$reason path=$bp copied=$copied siblings=$sibText" -replace '(?!2020)[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z', '<TS>'
        }
        default { $res = "unknown call $call" }
    }
    $results.Add("$id`t$res")
}
[IO.File]::WriteAllText($env:OUT, (($results -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
'@, [Text.UTF8Encoding]::new($false))

    # -----------------------------------------------------------------------
    # Run the driver in a child pwsh under an isolated HOME (USERPROFILE too:
    # pwsh's $HOME follows it), stdin at EOF
    # -----------------------------------------------------------------------
    $h = Join-Path $WORK "home-$S"
    New-Dir $h
    $OUT = Join-Path $WORK "out-$S"
    $console = Join-Path $WORK "console-$S"
    $envs = @{
        HOME = $h; USERPROFILE = $h
        AITOOLS_LOG_DIR = (Join-Path $WORK "logs-$S"); AITOOLS_SUMMARY_FILE = (Join-Path $WORK "sum-$S")
        REPO = $root; CASES = $CASES; F = $F; WORK = $WORK; OUT = $OUT
    }
    $rc = Invoke-TestScript -FilePath $pwshExe -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $drive) -Environment $envs -OutFile $console
    if ($rc -ne 0 -or -not (Test-Path -LiteralPath $OUT) -or (Get-Item -LiteralPath $OUT).Length -eq 0) {
        Bad "$S driver ran (exit $rc)"
        if (Test-Path -LiteralPath $console) {
            @(([IO.File]::ReadAllText($console) -replace "`e\[[0-9;]*m", "" -replace "`r", "") -split "`n") |
                Select-Object -Last 25 | ForEach-Object { Write-Output "      | $_" }
        }
    }

    # The driver's results: id -> result (the first line of each id)
    $got = @{}
    if (Test-Path -LiteralPath $OUT) {
        foreach ($l in ([IO.File]::ReadAllText($OUT) -split "`n")) {
            $l = $l -replace "`r\z", ""
            $tab = $l.IndexOf("`t")
            if ($tab -lt 0) { continue }
            $i = $l.Substring(0, $tab)
            if (-not $got.ContainsKey($i)) { $got[$i] = $l.Substring($tab + 1) }
        }
    }

    # Every case of this driver must give its expectation. The results of the
    # cases both drivers run (no sh_ / ps_ prefix) are collected per fixture group
    # and compared with the golden file the .sh driver must also give.
    $parity = [ordered]@{}
    foreach ($c in $caseList) {
        if ($c.Call.StartsWith("sh_")) { continue }   # bash-only case
        $shared = -not $c.Call.StartsWith("ps_")
        $r = if ($got.ContainsKey($c.Id)) { $got[$c.Id] } else { "(no result)" }
        if ($r -ceq $c.Want) {
            Ok "$S $($c.Id)"
        } else {
            Bad "$S $($c.Id)"
            Write-Output "      want: $($c.Want)"
            Write-Output "      got:  $r"
        }
        if ($shared) {
            if (-not $parity.Contains($c.Group)) { $parity[$c.Group] = New-Object System.Text.StringBuilder }
            [void]$parity[$c.Group].Append("$($c.Id)`t$r`n")
        }
    }
    foreach ($g in $parity.Keys) {
        $pf = Join-Path $WORK "parity-$g.results"
        [IO.File]::WriteAllText($pf, $parity[$g].ToString(), [Text.UTF8Encoding]::new($false))
        if (Test-GoldenMatch "parity-$g.results" $pf) {
            Ok "parity $g group: results match golden (sh and ps share it)"
        } else {
            Bad "parity $g group: results match golden (sh and ps share it)"
        }
    }

    # LogLines: this driver's deploy.log split on LF only (as perl and grep read
    # it). LogText: each line with its first CR removed and \ turned into /, as
    # the .sh's logtext did for the pwsh driver's native paths. NF: the fixture
    # path in that / form.
    $LOG = Join-Path $WORK "logs-$S/deploy.log"
    $logLines = @()
    if (Test-Path -LiteralPath $LOG -PathType Leaf) {
        $logLines = @([IO.File]::ReadAllText($LOG) -split "`n")
        if ($logLines.Count -gt 0 -and $logLines[-1] -eq "") { $logLines = @($logLines | Select-Object -SkipLast 1) }
    }
    $logText = @($logLines | ForEach-Object { ([regex]'\r').Replace($_, "", 1) -replace '\\', '/' })
    $NF = $F -replace '\\', '/'

    # The unknown outcome is logged with its name (any file in the log dir)
    $unknownLogged = $false
    $logDir = Join-Path $WORK "logs-$S"
    if (Test-Path -LiteralPath $logDir) {
        foreach ($lf in (Get-ChildItem -LiteralPath $logDir -Recurse -File)) {
            if ([IO.File]::ReadAllText($lf.FullName).Contains('unknown outcome "bogus" for b.md (t) -- counted as failed')) { $unknownLogged = $true; break }
        }
    }
    if ($unknownLogged) { Ok "$S unknown outcome logged" } else { Bad "$S unknown outcome logged" }

    # Every deploy.log line keeps the [timestamp] [script] [level] format (a
    # multi-line reason is one log line per entry). A missing deploy.log fails
    # here (the .sh's perl passed on an unreadable file; the other log checks
    # failed then).
    $fmt = '\A\[[0-9]{4}-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z\] \[test-fanout-lib\] \[(?:info|ok|warn|error|detail)\] '
    $badLines = @($logLines | Where-Object { $_ -cnotmatch $fmt })
    if (-not (Test-Path -LiteralPath $LOG -PathType Leaf)) {
        Bad "$S deploy.log: lines without the log line format"
        Write-Output "      | no deploy.log at $LOG"
    } elseif ($badLines.Count -eq 0) {
        Ok "$S deploy.log: every line has the log line format"
    } else {
        Bad "$S deploy.log: lines without the log line format"
        $badLines | Select-Object -First 5 | ForEach-Object { Write-Output "      | $_" }
    }

    # Logged TEXT DESC: a detail line containing TEXT in this driver's log
    function Logged([string]$Text, [string]$Desc) {
        $needle = "[detail] $Text"
        if (@($logText | Where-Object { $_.Contains($needle) }).Count -gt 0) {
            Ok "$S detail log: $Desc"
        } else {
            Bad "$S detail log: $Desc (no line with: $Text)"
        }
    }
    Logged "Test-FanoutTextEqual: cannot read $NF/t/nope: " "Test-FanoutTextEqual names the missing file and why"
    Logged "Test-FanoutTextEqual: cannot read $NF/t/dir: is a directory" "Test-FanoutTextEqual: a directory"
    Logged "Backup-Dir: $NF/bd/ps/nomd/d: not backed up (no top-level *.md file)" "Backup-Dir skip rule"
    Logged "Backup-Dir: $NF/bd/ps/missing/nope: not backed up (no directory)" "Backup-Dir: no directory"
} finally {
    Remove-TestTempRoot $WORK
}

Write-Output ""
Write-Output ("{0} passed, {1} failed, {2} skipped" -f $script:pass, $script:fail, $script:skip)
if ($script:fail -ne 0) { exit 1 }
exit 0
