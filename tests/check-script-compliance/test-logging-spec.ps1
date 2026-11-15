# test-logging-spec.ps1 -- tests for check-script-compliance.ps1 steps 3, 12,
# 13 and 14, the checks of reference/logging.md section 8 (plan
# summary-warn-reporting, step I2):
#   step 13  the summary rules: rule 1 write_summary / Write-Summary never
#            change the category; rule 2 every write_error / Write-AitError
#            passes a non-empty reason; rule 3 the relay changes no parent
#            warning count; rule 4 legacy write_summary WARN / ERROR calls are
#            reported while $StrictSummary is $false and FAIL when it is $true
#   step 14  log writers outside aitools-lib (logging.md 8.1); the 8.1
#            exceptions are never listed
#   step 12  with $StrictSummary on, only OK, DETAIL and ACTION
#   step 3   an exit 1 after Write-AitError / Write-AitWarn / Write-AitAction
#            is covered
#
# Platform targeting (commander, 2026-11-14: "sh scripts and tests should only
# run on linux/mac and ps1 on windows"): this harness runs on Windows only and
# tests the .ps1 twin, scripts/check-script-compliance.ps1, with native pwsh.
# No case runs bash. Its twin, tests/check-script-compliance/test-logging-spec.sh,
# runs the same cases on macOS and Linux against the .sh twin.
#
# Cases (the same as the .sh harness):
#   P   parity     the perl program embedded in check-script-compliance.ps1 is
#                  the same text (CR removed) as the one in the .sh twin; both
#                  twins have the switch off
#   L1  old lib    the promotion and the relay increment in synthetic
#                  libraries: rule 1 and rule 3 FAIL, each line listed
#   L2  new lib    rules 1-4 ok, step 13 and step 14 PASS
#   L3  missing    a missing relay_child_log / Write-Summary: FAIL "not found"
#   R2  reasons    write_error / Write-AitError with and without a reason
#   R4  legacy     write_summary WARN / ERROR and Write-Summary "WARN" /
#                  'error' listed, OK / DETAIL / ACTION / comments / mentions not;
#                  WARN with the switch off, FAIL with it on
#   W   writers    each writer kind listed; look-alikes and the 8.1 exceptions
#                  not; WARN with the switch off, FAIL with it on
#   E   end to end the copied check-script-compliance.ps1 with a planted
#                  scripts/setup-zz.ps1: step 3, then steps 12, 13 and 14 with
#                  the switch off and on
# The program runs from the text this harness extracts from the .ps1 twin
# (here-string $logSpecProg), through perl, the way the twin runs it. The
# planted .ps1 files keep this file's CRLF line ends, the planted .sh files get
# LF, as a Windows checkout has them.
#
# TEST_KEEP_TMP=1 keeps the temp dir (its path is printed). Safe to re-run:
# writes only to a temp dir, removed on exit; the copied check runs with HOME,
# USERPROFILE and AITOOLS_LOG_DIR inside it. Needs perl on PATH (a managed tool;
# without it every case that runs the program FAILs). Exit 1 if any case fails.
# Platform: Windows, pwsh 7 (CI: windows job); refuses macOS and Linux.
# Usage: pwsh -NoProfile -File tests/check-script-compliance/test-logging-spec.ps1 [-Help]

param([switch]$Help)
if ($Help) { Get-Content $PSCommandPath -TotalCount 48 | ForEach-Object { $_ -replace '^# ?', '' }; exit 0 }

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/check-script-compliance/test-logging-spec.sh with bash.")
    exit 1
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root "tests/lib/platform-lib.ps1")
$pwshExe = (Get-Process -Id $PID).Path
$tmpRoot = New-TestTempRoot "logging-spec"
$keepTmp = ($env:TEST_KEEP_TMP -eq "1")
if ($keepTmp) { Write-Output "temp dir kept: $tmpRoot" }
$outFile = Join-Path $tmpRoot "out"
$utf8 = [Text.UTF8Encoding]::new($false)
$script:pass = 0; $script:fail = 0; $script:skip = 0

function ReadText([string]$Path) { if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::ReadAllText($Path) } else { "" } }
function WriteText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $utf8) }
# WriteSh PATH TEXT: a planted .sh file, LF line ends; WritePs PATH TEXT: CRLF
function WriteSh([string]$Path, [string]$Text) { WriteText $Path (($Text -replace "`r", "") + "`n") }
function WritePs([string]$Path, [string]$Text) { WriteText $Path ((($Text -replace "`r", "") -replace "`n", "`r`n") + "`r`n") }

function Check([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Output "PASS $Name"; $script:pass++; return }
    Write-Output "FAIL $Name"; $script:fail++
    if (Test-Path -LiteralPath $outFile -PathType Leaf) {
        $lines = @(((ReadText $outFile) -replace "`e\[[0-9;]*m", "" -replace "`r", "") -split "`n")
        $lines | Select-Object -Last 15 | ForEach-Object { Write-Output "      | $_" }
    }
}

# LineOf TAG PATH: the line number of the line that ends in "# TAG" ("" if none)
function LineOf([string]$Tag, [string]$Path) {
    $lines = @(((ReadText $Path) -replace "`r", "") -split "`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('#[ ]' + [regex]::Escape($Tag) + '[ \t]*$')) { return [string]($i + 1) }
    }
    return ""
}
# Has TEXT PATH: the file contains TEXT (literal)
function Has([string]$Text, [string]$Path) { return (ReadText $Path).Contains($Text) }
# Listed SITE PATH: the site (file:line or file:line(kind)) appears as a whole word
function Listed([string]$Site, [string]$Path) {
    return [regex]::IsMatch((ReadText $Path), '(?<![\w/.-])' + [regex]::Escape($Site) + '(?![0-9])')
}
# ResultOf PATH: the word of the program's RESULT line
function ResultOf([string]$Path) {
    $m = [regex]::Match((ReadText $Path), '(?m)^RESULT\t(PASS|WARN|FAIL)\t')
    if ($m.Success) { return $m.Groups[1].Value }
    return ""
}

try {
    # --- Case P: the program is the same in both twins ----------------------------
    $shTwin = Join-Path $root "scripts/check-script-compliance.sh"
    $psTwin = Join-Path $root "scripts/check-script-compliance.ps1"
    # Extract TEXT START END: the lines strictly between the line matching START
    # and the next line matching END, CR removed
    function Extract([string]$Text, [string]$Start, [string]$End) {
        $out = [Text.StringBuilder]::new()
        $in = $false
        foreach ($l in (($Text -replace "`r", "") -split "`n")) {
            if ($in -and $l -match $End) { break }
            if ($in) { [void]$out.Append($l + "`n") }
            if (-not $in -and $l -match $Start) { $in = $true }
        }
        return $out.ToString()
    }
    $progSh = Extract (ReadText $shTwin) "<<'LOGSPEC_PERL' \|\| true$" '^LOGSPEC_PERL$'
    $progPs = Extract (ReadText $psTwin) "^\`$logSpecProg = @'$" "^'@$"
    $prog = Join-Path $tmpRoot "logspec.pl"
    WriteText $prog $progPs
    Check "P: the .sh twin embeds the program" ($progSh.Length -gt 0)
    Check "P: the .ps1 twin embeds the program" ($progPs.Length -gt 0)
    Check "P: the program is the same text in both twins" ($progSh -ceq $progPs)
    Check "P: the .sh twin has STRICT_SUMMARY=false" ([regex]::IsMatch((ReadText $shTwin), '(?m)^STRICT_SUMMARY=false\r?$'))
    Check "P: the .ps1 twin has `$StrictSummary = `$false" ([regex]::IsMatch((ReadText $psTwin), '(?m)^\$StrictSummary = \$false\r?$'))
    $havePerl = [bool](Get-Command perl -ErrorAction SilentlyContinue)
    Check "P: perl is on PATH" $havePerl

    # Prog ROOT MODE STRICT: run the program; output -> $outFile
    function Prog([string]$R, [string]$Mode, [string]$Strict) {
        $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        try { $o = @(& perl $prog $Mode $Strict $R 2>&1 | ForEach-Object { "$_" }); $rc = $LASTEXITCODE } finally { $ErrorActionPreference = $prev }
        WriteText $outFile (($o -join "`n") + "`n")
        if ($rc -ne 0) { Write-Output "INFO program exit $rc ($R $Mode $Strict)" }
    }

    # --- Synthetic libraries --------------------------------------------------------
    function LibOld([string]$R) {
        New-Item -ItemType Directory -Force -Path (Join-Path $R "scripts") | Out-Null
        WriteSh (Join-Path $R "scripts/aitools-lib.sh") @'
#!/usr/bin/env bash
write_summary() {
    if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then
        local cat="$1"
        if [ "$cat" = "OK" ] && [ "${WARNINGS:-0}" -gt 0 ]; then  # O1
            cat="WARN"  # O2
        fi
        printf '%s|%s|%s\n' "$cat" "$2" "$3" >> "$AITOOLS_SUMMARY_FILE"
    fi
}
_aitlib_relay_line() {
    case "$3" in
        warn)  AITLIB_CHILD_WARNINGS=$((AITLIB_CHILD_WARNINGS + 1)); WARNINGS=$((WARNINGS + 1)) ;;  # O3
    esac
}
relay_child_log() { AITLIB_CHILD_WARNINGS=0; }
run_child_relayed() {
    AITLIB_CHILD_RC=0
}
'@
        WritePs (Join-Path $R "scripts/aitools-lib.ps1") @'
function Write-Summary($cat, $tool, $detail) {
    if ($env:AITOOLS_SUMMARY_FILE) {
        if ($cat -eq "OK" -and $script:warnings -gt 0) {  # O1
            $cat = "WARN"  # O2
        }
        [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, "${cat}|${tool}|${detail}`n")
    }
}
function Send-AitLibChildLine($Record) {
    if ($level -ceq "warn") { $script:AitLibChildWarnings++; $script:warnings++ }  # O3
}
function Send-ChildLog([object[]]$Lines) { $script:AitLibChildWarnings = 0 }
function Invoke-ChildRelayed([string]$AitLibLabel) {
    return 0
}
'@
    }
    function LibNew([string]$R) {
        New-Item -ItemType Directory -Force -Path (Join-Path $R "scripts") | Out-Null
        WriteSh (Join-Path $R "scripts/aitools-lib.sh") @'
#!/usr/bin/env bash
log_warn()  { log "$1" "warn"; WARNINGS=$((WARNINGS + 1)); }
write_summary() {
    # written as given: never reads WARNINGS, never sets cat="WARN"
    if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then
        printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$AITOOLS_SUMMARY_FILE"
    fi
}
_aitlib_relay_line() {
    case "$3" in
        warn)  AITLIB_CHILD_WARNINGS=$((AITLIB_CHILD_WARNINGS + 1)) ;;
    esac
}
relay_child_log() { AITLIB_CHILD_WARNINGS=0; }
run_child_relayed() {
    if [ "$WARNINGS" -gt 0 ]; then :; fi
    AITLIB_CHILD_RC=0
}
'@
        WritePs (Join-Path $R "scripts/aitools-lib.ps1") @'
function LogWarn($msg)  { Log $msg "warn"; $script:warnings++ }
function Write-Summary($cat, $tool, $detail) {
    <# written as given: no $script:warnings, no $cat = "WARN" #>
    if ($env:AITOOLS_SUMMARY_FILE) {
        [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, "${cat}|${tool}|${detail}`n")
    }
}
function Send-AitLibChildLine($Record) {
    if ($level -ceq "warn") { $script:AitLibChildWarnings++ }
}
function Send-ChildLog([object[]]$Lines) { $script:AitLibChildWarnings = 0 }
function Invoke-ChildRelayed([string]$AitLibLabel) {
    if ($script:warnings -gt 0) { }
    return 0
}
'@
    }
    # RemoveLines PATH REGEX: drop the matching lines, keeping the file's line ends
    function RemoveLines([string]$Path, [string]$Re) {
        $t = ReadText $Path
        $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
        $kept = @(($t -replace "`r", "").TrimEnd("`n") -split "`n" | Where-Object { $_ -notmatch $Re })
        WriteText $Path (($kept -join $nl) + $nl)
    }

    # --- Case L: rules 1 and 3 on the library -------------------------------------
    $R = Join-Path $tmpRoot "l1"
    LibOld $R
    Prog $R summary false
    Check "L1: old library: step 13 is FAIL" ((ResultOf $outFile) -eq "FAIL")
    Check "L1: rule 1 FAIL is reported" (Has "rule 1 FAIL, write_summary changes the category" $outFile)
    foreach ($t in @("O1", "O2")) {
        $k = if ($t -eq "O2") { "sets the category" } else { "reads the count" }
        foreach ($f in @("aitools-lib.sh", "aitools-lib.ps1")) {
            $n = LineOf $t (Join-Path $R "scripts/$f")
            Check "L1 ${t}: scripts/${f}:$n($k) is listed" ($n -and (Listed "scripts/${f}:$n($k)" $outFile))
        }
    }
    Check "L1: rule 3 FAIL is reported" (Has "rule 3 FAIL, the relay changes the parent warning count" $outFile)
    $n = LineOf "O3" (Join-Path $R "scripts/aitools-lib.sh")
    Check "L1 O3: scripts/aitools-lib.sh:$n(_aitlib_relay_line) is listed" ($n -and (Listed "scripts/aitools-lib.sh:$n(_aitlib_relay_line)" $outFile))
    $n = LineOf "O3" (Join-Path $R "scripts/aitools-lib.ps1")
    Check "L1 O3: scripts/aitools-lib.ps1:$n(send-aitlibchildline) is listed" ($n -and (Listed "scripts/aitools-lib.ps1:$n(send-aitlibchildline)" $outFile))

    $R = Join-Path $tmpRoot "l2"
    LibNew $R
    Prog $R summary false
    Check "L2: new library, no other script: step 13 is PASS" ((ResultOf $outFile) -eq "PASS")
    Check "L2: rules 1 to 4 ok" (Has "rule 1 ok; rule 2 ok (0 write_error call(s)); rule 3 ok; rule 4 ok (no legacy WARN/ERROR call)" $outFile)
    Prog $R writers false
    Check "L2: step 14 is PASS (the library is not listed)" ((ResultOf $outFile) -eq "PASS")
    Prog $R writers true
    Check "L2: step 14 is PASS with STRICT true" ((ResultOf $outFile) -eq "PASS")

    $R = Join-Path $tmpRoot "l3"
    LibNew $R
    RemoveLines (Join-Path $R "scripts/aitools-lib.sh") '^relay_child_log\(\)'
    $t = ReadText (Join-Path $R "scripts/aitools-lib.ps1")
    WriteText (Join-Path $R "scripts/aitools-lib.ps1") ([regex]::Replace($t, '(?s)function Write-Summary.*?\r?\n\}\r?\n', ''))
    Prog $R summary false
    Check "L3: step 13 is FAIL" ((ResultOf $outFile) -eq "FAIL")
    Check "L3: rule 3 names the missing relay" (Has "scripts/aitools-lib.sh: relay_child_log not found" $outFile)
    Check "L3: rule 1 names the missing Write-Summary" (Has "scripts/aitools-lib.ps1: write-summary not found" $outFile)

    # --- Case R2: rule 2, a reason for every write_error -----------------------------
    $R = Join-Path $tmpRoot "r2"
    LibNew $R
    $zzSh = Join-Path $R "scripts/setup-zz.sh"
    $zzPs = Join-Path $R "scripts/setup-zz.ps1"
    WriteSh $zzSh @'
#!/usr/bin/env bash
write_error "pandoc" "brew install failed" "$(error_reason "$out" "$rc")"  # G1
write_error "t" "what" "$reason"  # G2
write_error "t" \
    "what" "$reason"  # G3
if ! cmd; then write_error "t" "what failed" "$(error_reason "$o" 1)"; fi  # G4
write_error "$@"  # G5
log "call write_error t w later"  # I1
command -v write_error >/dev/null  # I2
write_error "t" "what" ""  # B1
write_error "t" "what" ''  # B2
write_error "t" "what"  # B3
if true; then write_error t w; fi  # B4
x=1; write_error "t" "w" "" 2>/dev/null  # B5
case "$x" in 1) write_error t w "" ;; esac  # B6
echo '    write_error "t" "w" ""'  # B7
'@
    WritePs $zzPs @'
Write-AitError "pandoc" "brew install failed" (Get-AitErrorReason -Output $out -ExitCode $rc)  # G1
Write-AitError -Tool "t" -What "w" -Reason $r  # G2
Write-AitError "t" "w" "$($_.Exception.Message)"  # G3
Write-AitError -Tool t "w" $r  # G4
Write-AitError @splat  # G5
LogDetail "Write-AitError t w is not a call"  # I1
Write-AitError "t" "w" ""  # B1
Write-AitError "t" "w"  # B2
Write-AitError -Tool t -What w -Reason ''  # B3
write-aiterror t w $null  # B4
if ($x) { Write-AitError "t" "w" -Reason:"" }  # B5
'@
    Prog $R summary false
    Check "R2: step 13 is FAIL" ((ResultOf $outFile) -eq "FAIL")
    Check "R2: rule 2 FAIL is reported" (Has "rule 2 FAIL, write_error without a reason" $outFile)
    foreach ($t in @("B1", "B2", "B5", "B6", "B7")) {
        $n = LineOf $t $zzSh
        Check "R2 sh ${t}: scripts/setup-zz.sh:$n(empty reason) is listed" ($n -and (Listed "scripts/setup-zz.sh:$n(empty reason)" $outFile))
    }
    foreach ($t in @("B3", "B4")) {
        $n = LineOf $t $zzSh
        Check "R2 sh ${t}: scripts/setup-zz.sh:$n(no reason) is listed" ($n -and (Listed "scripts/setup-zz.sh:$n(no reason)" $outFile))
    }
    foreach ($t in @("G1", "G2", "G3", "G4", "G5", "I1", "I2")) {
        $n = LineOf $t $zzSh
        Check "R2 sh ${t}: scripts/setup-zz.sh:$n is not listed" ($n -and -not (Listed "scripts/setup-zz.sh:$n" $outFile))
    }
    $n = [int](LineOf "G3" $zzSh) - 1
    Check "R2 sh G3: the continued call's first line scripts/setup-zz.sh:$n is not listed" (-not (Listed "scripts/setup-zz.sh:$n" $outFile))
    foreach ($t in @("B1", "B3", "B4", "B5")) {
        $n = LineOf $t $zzPs
        Check "R2 ps1 ${t}: scripts/setup-zz.ps1:$n(empty reason) is listed" ($n -and (Listed "scripts/setup-zz.ps1:$n(empty reason)" $outFile))
    }
    $n = LineOf "B2" $zzPs
    Check "R2 ps1 B2: scripts/setup-zz.ps1:$n(no reason) is listed" ($n -and (Listed "scripts/setup-zz.ps1:$n(no reason)" $outFile))
    foreach ($t in @("G1", "G2", "G3", "G4", "G5", "I1")) {
        $n = LineOf $t $zzPs
        Check "R2 ps1 ${t}: scripts/setup-zz.ps1:$n is not listed" ($n -and -not (Listed "scripts/setup-zz.ps1:$n" $outFile))
    }
    RemoveLines $zzSh '# B[0-9]$'
    RemoveLines $zzPs '# B[0-9]$'
    Prog $R summary false
    Check "R2 good only: step 13 is PASS" ((ResultOf $outFile) -eq "PASS")
    Check "R2 good only: rule 2 ok (10 write_error call(s))" (Has "rule 2 ok (10 write_error call(s))" $outFile)

    # --- Case R4: rule 4, legacy write_summary WARN / ERROR ---------------------------
    $R = Join-Path $tmpRoot "r4"
    LibNew $R
    $libSh = Join-Path $R "scripts/aitools-lib.sh"
    WriteText $libSh ((ReadText $libSh) + "zz_lib() {`n    write_summary ERROR `"`$1`" `"`$3`"  # L1`n}`n")
    $zzSh = Join-Path $R "scripts/setup-zz.sh"
    $zzPs = Join-Path $R "scripts/setup-zz.ps1"
    WriteSh $zzSh @'
#!/usr/bin/env bash
write_summary WARN "t" "x"  # W1
write_summary "ERROR" "t" "x"  # W2
if true; then write_summary ERROR t x; fi  # W3
case 1 in 1) write_summary WARN t x ;; esac  # W4
echo '    write_summary ERROR "t" "x"'  # W5
    Write-Summary "ERROR" "t" "x"  # W6
write_summary OK "t" "v1"  # N1
write_summary DETAIL "t" "x"  # N2
write_summary ACTION "" "do x"  # N3
log "write_summary WARN is retired"  # N4
# write_summary WARN t x  # N5
'@
    WritePs $zzPs @'
Write-Summary "WARN" "t" "x"  # W1
write-summary 'error' t x  # W2
Write-Summary "OK" "t" "v"  # N1
<# Write-Summary "WARN" t x #>  # N2
'@
    Prog $R list-legacy false
    foreach ($tc in @("W1:WARN", "W2:ERROR", "W3:ERROR", "W4:WARN", "W5:ERROR", "W6:ERROR")) {
        $t, $c = $tc -split ':'
        $n = LineOf $t $zzSh
        Check "R4 sh ${t}: scripts/setup-zz.sh:$n($c) is listed" ($n -and (Listed "scripts/setup-zz.sh:$n($c)" $outFile))
    }
    foreach ($t in @("N1", "N2", "N3", "N4", "N5")) {
        $n = LineOf $t $zzSh
        Check "R4 sh ${t}: scripts/setup-zz.sh:$n is not listed" ($n -and -not (Listed "scripts/setup-zz.sh:$n" $outFile))
    }
    foreach ($tc in @("W1:WARN", "W2:ERROR")) {
        $t, $c = $tc -split ':'
        $n = LineOf $t $zzPs
        Check "R4 ps1 ${t}: scripts/setup-zz.ps1:$n($c) is listed" ($n -and (Listed "scripts/setup-zz.ps1:$n($c)" $outFile))
    }
    foreach ($t in @("N1", "N2")) {
        $n = LineOf $t $zzPs
        Check "R4 ps1 ${t}: scripts/setup-zz.ps1:$n is not listed" ($n -and -not (Listed "scripts/setup-zz.ps1:$n" $outFile))
    }
    $n = LineOf "L1" $libSh
    Check "R4 L1: the library's own call scripts/aitools-lib.sh:$n(ERROR) is listed" ($n -and (Listed "scripts/aitools-lib.sh:$n(ERROR)" $outFile))
    Prog $R summary false
    Check "R4: STRICT false: step 13 is WARN" ((ResultOf $outFile) -eq "WARN")
    Check "R4: STRICT false: 9 calls reported, per file" (Has "rule 4 reported, 9 legacy write_summary WARN/ERROR call(s), a FAIL once STRICT_SUMMARY is on: scripts/aitools-lib.sh(1) scripts/setup-zz.ps1(2) scripts/setup-zz.sh(6)" $outFile)
    Prog $R summary true
    Check "R4: STRICT true: step 13 is FAIL" ((ResultOf $outFile) -eq "FAIL")
    Check "R4: STRICT true: rule 4 FAIL, 9 calls" (Has "rule 4 FAIL, 9 legacy write_summary WARN/ERROR call(s): " $outFile)

    # --- Case W: step 14, log writers outside the library -----------------------------
    $R = Join-Path $tmpRoot "w"
    LibNew $R
    $S = Join-Path $R "scripts"
    New-Item -ItemType Directory -Force -Path (Join-Path $S "githooks") | Out-Null
    $zzSh = Join-Path $S "setup-zz.sh"
    $zzPs = Join-Path $S "setup-zz.ps1"
    WriteSh $zzSh @'
#!/usr/bin/env bash
log() { printf '%s\n' "$1"; }  # F1
blog_warn() { printf '%s\n' "$1" >&2; }  # F2
function log_step { :; }  # F3
printf 'x\n' >> "$LOG_FILE"  # A1
cmd >>"$AITOOLS_SUMMARY_FILE"  # A2
printf 'x\n' | tee -a "$LOG_DIR/extra.log"  # A3
echo x >> "$HOME/.aitools/logs/deploy.jsonl"  # A4
_aitlib_log_append "$x" "$LOG_FILE"  # R1
jsonl_record "$ts" "s" "info" "m"  # R2
if [ -n "${CLAUDE_CODE_REMOTE:-}" ]; then :; fi  # C1
login() { :; }  # N1
ui_log_lines() { :; }  # N2
printf 'x\n' >> "$HOME/.bashrc"  # N3
log "appending >> $LOG_FILE"  # N4
# printf x >> "$LOG_FILE"  # N5
log "x"  # N6
'@
    WritePs $zzPs @'
function LogWarn($m) { Write-Host $m }  # F1
function script:Log($m) { }  # F2
Add-Content -Path $logFile -Value "x"  # A1
"x" | Out-File -FilePath $env:AITOOLS_SUMMARY_FILE -Append  # A2
[IO.File]::AppendAllText($LOG_FILE, "x")  # A3
$out >> "$logDir\deploy.log"  # A4
Add-AitLibLogText $line  # R1
Write-JsonlRecord $ts $n $l $m  # R2
if ($env:CLAUDE_CODE_REMOTE) { }  # C1
function Login-Thing { }  # N1
Add-Content -Path $profilePath -Value "x"  # N2
LogDetail "Add-Content -Path $logFile"  # N3
Out-File -FilePath $logFile  # N4
<# Add-Content -Path $logFile #>  # N5
'@
    WriteSh (Join-Path $S "zz-entry") "#!/usr/bin/env bash`necho x >> `"`$LOG_FILE`"  # X1"
    WriteSh (Join-Path $S "zz-tool") "#!/usr/bin/env python3`nprint(1) >> `"`$LOG_FILE`"  # X2"
    WriteSh (Join-Path $S "githooks/pre-commit") "#!/bin/sh`necho x >> `"`$LOG_FILE`"  # X3"
    foreach ($f in @("bootstrap.sh", "hh.sh", "relay-outbound-prompt.sh", "check-lib.sh", "check-zz.sh")) {
        WriteSh (Join-Path $S $f) "#!/usr/bin/env bash`nprintf x >> `"`$LOG_FILE`"  # EX`nlog() { :; }  # EX2"
    }
    foreach ($f in @("bootstrap.ps1", "hh.ps1", "check-lib.ps1", "check-zz.ps1")) {
        WritePs (Join-Path $S $f) "Add-Content -Path `$logFile -Value x  # EX`nfunction Log(`$m) { }  # EX2"
    }
    WritePs (Join-Path $S "relay-outbound-prompt.ps1") "Add-Content -Path `$logFile -Value x  # RO"
    $bd = Join-Path $S "build-deploy.sh"
    WriteSh $bd @'
#!/usr/bin/env bash
cat <<'BLOCK'
    if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then printf 'ERROR|harness files|script truncated\n' >> "$AITOOLS_SUMMARY_FILE"; fi  # E1
    printf 'ERROR|other|x\n' >> "$AITOOLS_SUMMARY_FILE"  # E2
    Add-Content -Path $logFile -Value "x"  # E3
BLOCK
'@
    Prog $R list-writers false
    foreach ($tk in @("F1:log-func", "F2:log-func", "F3:log-func", "A1:log-append", "A2:log-append", "A3:log-append", "A4:log-append", "R1:raw-primitive", "R2:raw-primitive", "C1:ccr-read")) {
        $t, $k = $tk -split ':'
        $n = LineOf $t $zzSh
        Check "W sh ${t}: scripts/setup-zz.sh:$n($k) is listed" ($n -and (Listed "scripts/setup-zz.sh:$n($k)" $outFile))
    }
    foreach ($t in @("N1", "N2", "N3", "N4", "N5", "N6")) {
        $n = LineOf $t $zzSh
        Check "W sh ${t}: scripts/setup-zz.sh:$n is not listed" ($n -and -not (Listed "scripts/setup-zz.sh:$n" $outFile))
    }
    foreach ($tk in @("F1:log-func", "F2:log-func", "A1:log-append", "A2:log-append", "A3:log-append", "A4:log-append", "R1:raw-primitive", "R2:raw-primitive", "C1:ccr-read")) {
        $t, $k = $tk -split ':'
        $n = LineOf $t $zzPs
        Check "W ps1 ${t}: scripts/setup-zz.ps1:$n($k) is listed" ($n -and (Listed "scripts/setup-zz.ps1:$n($k)" $outFile))
    }
    foreach ($t in @("N1", "N2", "N3", "N4", "N5")) {
        $n = LineOf $t $zzPs
        Check "W ps1 ${t}: scripts/setup-zz.ps1:$n is not listed" ($n -and -not (Listed "scripts/setup-zz.ps1:$n" $outFile))
    }
    Check "W X1: an extensionless bash file is scanned (scripts/zz-entry:2(log-append))" (Listed "scripts/zz-entry:2(log-append)" $outFile)
    Check "W X2: an extensionless python file is not" (-not (Has "scripts/zz-tool" $outFile))
    Check "W X3: scripts/githooks/ is scanned (scripts/githooks/pre-commit:2(log-append))" (Listed "scripts/githooks/pre-commit:2(log-append)" $outFile)
    foreach ($f in @("bootstrap.sh", "hh.sh", "relay-outbound-prompt.sh", "check-lib.sh", "check-zz.sh", "bootstrap.ps1", "hh.ps1", "check-lib.ps1", "check-zz.ps1", "aitools-lib.sh", "aitools-lib.ps1")) {
        Check "W 8.1: scripts/$f is not listed" (-not (Has "scripts/${f}:" $outFile))
    }
    Check "W 8.1: scripts/relay-outbound-prompt.ps1 is in scope (listed)" (Listed "scripts/relay-outbound-prompt.ps1:1(log-append)" $outFile)
    $n = LineOf "E1" $bd
    Check "W 8.1 E1: build-deploy.sh's truncation guard line $n is not listed" ($n -and -not (Listed "scripts/build-deploy.sh:$n" $outFile))
    $n = LineOf "E2" $bd
    Check "W E2: another build-deploy.sh append scripts/build-deploy.sh:$n(log-append) is listed" ($n -and (Listed "scripts/build-deploy.sh:$n(log-append)" $outFile))
    $n = LineOf "E3" $bd
    Check "W E3: generated PowerShell in build-deploy.sh, scripts/build-deploy.sh:$n(log-append), is listed" ($n -and (Listed "scripts/build-deploy.sh:$n(log-append)" $outFile))
    Prog $R writers false
    Check "W: STRICT false: step 14 is WARN" ((ResultOf $outFile) -eq "WARN")
    Check "W: STRICT false: the detail says it is reported" (Has "reported until STRICT_SUMMARY is on" $outFile)
    Prog $R writers true
    Check "W: STRICT true: step 14 is FAIL" ((ResultOf $outFile) -eq "FAIL")

    # --- Case E: the copied check, end to end -----------------------------------------
    $fix = Join-Path $tmpRoot "repo"
    New-Item -ItemType Directory -Force -Path $fix | Out-Null
    Copy-Item -Recurse -Path (Join-Path $root "scripts") -Destination (Join-Path $fix "scripts")
    $zz = Join-Path $fix "scripts/setup-zz.ps1"
    $fill = (1..11 | ForEach-Object { '$a = 1' }) -join "`n"
    WritePs $zz ("Write-AitError `"t`" `"w`" `$r  # X1`nexit 1  # X1E`nWrite-Summary `"WARN`" `"t`" `"x`"  # X2`n" + $fill + "`nexit 1  # X3")
    $copy = Join-Path $fix "scripts/check-script-compliance.ps1"
    # RunCheck LABEL: the copied check in a child pwsh; output -> $outFile, the
    # step lines (colour codes removed) in $script:stepLines
    function RunCheck([string]$Label) {
        $home2 = Join-Path $tmpRoot "home-$Label"
        New-Item -ItemType Directory -Force -Path $home2 | Out-Null
        $saved = @{}
        $envs = @{ HOME = $home2; USERPROFILE = $home2; AITOOLS_LOG_DIR = (Join-Path $home2 "logs"); AITOOLS_SUMMARY_FILE = $null; AITOOLS_USER_REPO_PATH = $null; AITOOLS_PROFILE_FILE = $null; AITOOLS_MACHINE_ALIAS = $null }
        foreach ($k in @($envs.Keys)) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $envs[$k]) }
        $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        try {
            $o = @(& $pwshExe -NoProfile -File $copy 2>&1 | ForEach-Object { "$_" })
            $rc = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $prev
            foreach ($k in @($saved.Keys)) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
        }
        WriteText $outFile (($o -join "`n") + "`n")
        $script:stepLines = @{}
        foreach ($l in (((ReadText $outFile) -replace "`e\[[0-9;]*m", "" -replace "`r", "") -split "`n")) {
            if ($l -match '^\s*(\d+)\.\s') { $script:stepLines[$Matches[1]] = $l }
        }
        Write-Output "INFO ${Label}: check exit $rc; step 13: $(StepResult '13'); step 14: $(StepResult '14')"
    }
    function StepLine([string]$N) { if ($script:stepLines.ContainsKey($N)) { return $script:stepLines[$N] } else { return "" } }
    function StepResult([string]$N) {
        $m = [regex]::Match((StepLine $N), '\[(PASS|FAIL|WARN|SKIP)\]')
        if ($m.Success) { return $m.Groups[1].Value }
        return ""
    }
    function InLine([string]$Site, [string]$N) { return [regex]::IsMatch((StepLine $N), '(?<![\w/.-])' + [regex]::Escape($Site) + '(?![0-9])') }

    RunCheck "off"
    $x1e = LineOf "X1E" $zz; $x2 = LineOf "X2" $zz; $x3 = LineOf "X3" $zz
    Check "E step 3: the exit 1 after Write-AitError (setup-zz.ps1:$x1e) is not listed" (-not (InLine "setup-zz.ps1:$x1e" "3"))
    Check "E step 3: the uncovered exit 1 (setup-zz.ps1:$x3) is listed" (InLine "setup-zz.ps1:$x3" "3")
    Check "E STRICT false: step 12 does not list Write-Summary WARN (setup-zz.ps1:$x2)" ((StepLine "12") -and -not (InLine "setup-zz.ps1:$x2" "12"))
    Check "E STRICT false: step 13 is there, with rule 4 counting setup-zz.ps1" ((StepLine "13").Contains("scripts/setup-zz.ps1(1)"))
    $s14Off = StepResult "14"
    Check "E STRICT false: step 14 is PASS or WARN (it is $s14Off)" ($s14Off -eq "PASS" -or $s14Off -eq "WARN")

    $t = ReadText $copy
    WriteText $copy ([regex]::Replace($t, '(?m)^\$StrictSummary = \$false', '$StrictSummary = $true'))
    RunCheck "on"
    Check "E STRICT true: step 12 is FAIL and lists setup-zz.ps1:$x2(WARN)" ((StepResult "12") -eq "FAIL" -and (InLine "setup-zz.ps1:$x2(WARN)" "12"))
    Check "E STRICT true: step 13 is FAIL with rule 4 FAIL" ((StepResult "13") -eq "FAIL" -and (StepLine "13").Contains("rule 4 FAIL, "))
    if ($s14Off -eq "WARN") {
        Check "E STRICT true: step 14 is FAIL (it was WARN)" ((StepResult "14") -eq "FAIL")
    } else {
        Check "E STRICT true: step 14 is PASS (it was PASS)" ((StepResult "14") -eq "PASS")
    }
} finally {
    if (-not $keepTmp) { Remove-TestTempRoot $tmpRoot }
}

Write-Output ""
Write-Output "$($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
if ($script:fail -gt 0) { exit 1 }
exit 0
