#!/usr/bin/env bash
# test-logging-spec.sh -- tests for check-script-compliance.sh steps 3, 12, 13
# and 14, the checks of reference/logging.md section 8 (plan
# summary-warn-reporting, step I2):
#   step 13  the summary rules: rule 1 write_summary / Write-Summary never
#            change the category; rule 2 every write_error / Write-AitError
#            passes a non-empty reason; rule 3 the relay changes no parent
#            warning count; rule 4 legacy write_summary WARN / ERROR calls are
#            reported while STRICT_SUMMARY is false and FAIL when it is true
#   step 14  log writers outside aitools-lib (logging.md 8.1): logging
#            functions defined outside the library, appends to a log or the
#            run summary file, calls of the library's raw writers, direct
#            CLAUDE_CODE_REMOTE reads; the 8.1 exceptions are never listed
#   step 12  with STRICT_SUMMARY true, only OK, DETAIL and ACTION
#   step 3   an exit 1 after write_error / write_warn / write_action is covered
#
# Steps 13 and 14 run one perl program that both twins embed. Case P checks
# that the program in check-script-compliance.sh and the one in
# check-script-compliance.ps1 are the same text (CR removed) and that both
# twins have the switch off. Cases L, R2, R4 and W run that program on small
# synthetic repo roots under the temp dir (synthetic libraries, planted
# scripts). Case E copies this checkout's scripts/ into a temp repo root,
# plants scripts/setup-zz.sh, and runs the copied check twice: as it is
# (STRICT_SUMMARY=false) and with the copy switched to true.
#
# Cases:
#   P   parity     the program text is identical in the two twins; both have
#                  STRICT_SUMMARY / $StrictSummary off
#   L1  old lib    the promotion (write_summary reads WARNINGS, sets cat=WARN;
#                  Write-Summary reads $script:warnings, sets $cat = "WARN")
#                  and the relay's WARNINGS=... / $script:warnings++: step 13
#                  FAIL, rule 1 lists the four lines, rule 3 the two
#   L2  new lib    no promotion, the relay counts only the child: rules 1 and
#                  3 ok (comments that name the counters are ignored; reading
#                  WARNINGS in a relay and changing it in log_warn are not
#                  listed); no other script: step 13 PASS and step 14 PASS
#   L3  missing    a library without relay_child_log, one without
#                  write_summary: rule 3 / rule 1 FAIL "not found"
#   R2  reasons    write_error / Write-AitError calls with a reason (captured
#                  error_reason, a variable, a continued line, named and mixed
#                  parameters, "$@" and @splat not judged) are not listed;
#                  "" / '' / $null / no third argument / -Reason:"" are, as
#                  (empty reason) or (no reason); quoted mentions are not
#                  calls; a call in an echo'd generated line is; a good-only
#                  root reports "rule 2 ok (10 write_error call(s))"
#   R4  legacy     write_summary WARN / ERROR (quoted or not, in an if, a case
#                  arm, an echo'd generated line, the PowerShell code a bash
#                  generator writes, the library) and Write-Summary "WARN" /
#                  'error' are listed; OK, DETAIL, ACTION, comments, <# #>
#                  blocks and quoted mentions are not; STRICT false: WARN
#                  "rule 4 reported, 9"; STRICT true: FAIL "rule 4 FAIL, 9"
#   W   writers    each planted writer is listed with its kind (log-func,
#                  log-append, raw-primitive, ccr-read) in .sh, .ps1, an
#                  extensionless bash file and scripts/githooks/; the look-alikes
#                  are not; the 8.1 exceptions are not (the library, check-lib,
#                  the check scripts, bootstrap.*, hh.*,
#                  relay-outbound-prompt.sh, build-deploy.sh's truncation guard
#                  line), while relay-outbound-prompt.ps1 and another
#                  build-deploy.sh append are; STRICT false: WARN, true: FAIL
#   E   end to end the copied check: step 3 does not list the exit 1 after
#                  write_error and lists the uncovered one; with STRICT false
#                  step 12 accepts WARN and step 14 is not FAIL; with STRICT
#                  true step 12 FAILs on write_summary WARN, step 13 FAILs
#                  (rule 4), and step 14 is FAIL when it was WARN, PASS when it
#                  was PASS
#
# AITOOLS_TEST_BASH runs the copied check with another bash (macOS /bin/bash
# 3.2). TEST_KEEP_TMP=1 keeps the temp dir. Nothing outside the temp dir
# (removed on exit) is written; the copied check runs with HOME and
# AITOOLS_LOG_DIR inside it. Safe to re-run. Needs perl. Exit 1 if any case
# fails.
# Platform: macOS and Linux (bash 5, and /bin/bash 3.2 on macOS); CI: macos
# and linux jobs. Windows refuses it (OS guard, exit 1): its twin
# tests/check-script-compliance/test-logging-spec.ps1 runs there.
# Usage: bash tests/check-script-compliance/test-logging-spec.sh [--help]

set -euo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/check-script-compliance/test-logging-spec.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/check-script-compliance/test-logging-spec.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne '$stop = 1 if $. > 1 && !/^#/; print if $. > 1 && !$stop' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TB="${AITOOLS_TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
if [ "${TEST_KEEP_TMP:-}" = 1 ]; then
    printf 'temp dir kept: %s\n' "$TMP_ROOT"
else
    trap 'rm -rf "$TMP_ROOT"' EXIT
fi

PASS=0
FAIL=0
SKIP=0
OUT="$TMP_ROOT/out"

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -f "$OUT" ]; then
            # The last 25 lines of the last output, colour codes removed
            perl -ne 's/\e\[[0-9;]*m//g; push @l, "      | $_"; shift @l if @l > 25; END { print @l }' "$OUT"
        fi
    fi
}

# line_of <tag> <file>: the line number of the line that ends in "# <tag>"
line_of() {
    LS_TAG="$1" perl -ne 'print "$.\n" if /#[ ]\Q$ENV{LS_TAG}\E[ \t]*$/' "$2"
}

# has <text> <file>: 0 when the file contains the text (a literal string)
has() {
    LS_TEXT="$1" perl -ne '$f = 1 if index($_, $ENV{LS_TEXT}) >= 0; END { exit($f ? 0 : 1) }' "$2"
}

# listed <site> <file>: 0 when the site (file:line, or file:line(kind)) is in
# the file as a whole word (never a prefix of file:line0 or a longer path)
listed() {
    LS_SITE="$1" perl -ne '$f = 1 if /(?<![\w\/.-])\Q$ENV{LS_SITE}\E(?![0-9])/; END { exit($f ? 0 : 1) }' "$2"
}

# result_of <file>: the result word of the program's RESULT line
result_of() {
    perl -ne 'print $1 if /^RESULT\t(PASS|WARN|FAIL)\t/' "$1"
}

# --- Case P: the program is the same in both twins ------------------------------
SH_TWIN="$ROOT/scripts/check-script-compliance.sh"
PS_TWIN="$ROOT/scripts/check-script-compliance.ps1"
PROG="$TMP_ROOT/logspec.pl"
perl -ne 's/\r$//; if (/^LOGSPEC_PERL$/) { $in = 0 } print if $in; $in = 1 if /<<\x27LOGSPEC_PERL\x27 [|][|] true$/' "$SH_TWIN" > "$PROG"
perl -ne 's/\r$//; if (/^\x27@$/) { $in = 0 } print if $in; $in = 1 if /^\$logSpecProg = @\x27$/' "$PS_TWIN" > "$TMP_ROOT/logspec-ps1.pl"
check "P: the .sh twin embeds the program" "[ -s '$PROG' ]"
check "P: the .ps1 twin embeds the program" "[ -s '$TMP_ROOT/logspec-ps1.pl' ]"
check "P: the program is the same text in both twins" "cmp -s '$PROG' '$TMP_ROOT/logspec-ps1.pl'"
check "P: the .sh twin has STRICT_SUMMARY=false" "perl -ne '\$f = 1 if /^STRICT_SUMMARY=false\r?\$/; END { exit(\$f ? 0 : 1) }' '$SH_TWIN'"
check "P: the .ps1 twin has \$StrictSummary = \$false" "perl -ne '\$f = 1 if /^\\\$StrictSummary = \\\$false\r?\$/; END { exit(\$f ? 0 : 1) }' '$PS_TWIN'"

# prog <root> <mode> <strict>: run the program; output -> $OUT
prog() {
    local rc=0
    perl "$PROG" "$2" "$3" "$1" > "$OUT" 2>&1 || rc=$?
    if [ "$rc" -ne 0 ]; then printf 'INFO program exit %d (%s %s %s)\n' "$rc" "$1" "$2" "$3"; fi
}

# --- Synthetic libraries --------------------------------------------------------
# lib_old <root> / lib_new <root>: scripts/aitools-lib.sh and .ps1 with the
# promotion and the relay increment (old), or without them (new)
lib_old() {
    mkdir -p "$1/scripts"
    cat > "$1/scripts/aitools-lib.sh" <<'LIB_OLD_SH'
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
LIB_OLD_SH
    cat > "$1/scripts/aitools-lib.ps1" <<'LIB_OLD_PS1'
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
LIB_OLD_PS1
}
lib_new() {
    mkdir -p "$1/scripts"
    cat > "$1/scripts/aitools-lib.sh" <<'LIB_NEW_SH'
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
LIB_NEW_SH
    cat > "$1/scripts/aitools-lib.ps1" <<'LIB_NEW_PS1'
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
LIB_NEW_PS1
}

# --- Case L: rules 1 and 3 on the library ---------------------------------------
R="$TMP_ROOT/l1"
lib_old "$R"
prog "$R" summary false
check "L1: old library: step 13 is FAIL" "[ \"\$(result_of '$OUT')\" = FAIL ]"
check "L1: rule 1 FAIL is reported" "has 'rule 1 FAIL, write_summary changes the category' '$OUT'"
for t in O1 O2; do
    n=$(line_of "$t" "$R/scripts/aitools-lib.sh")
    k="reads the count"; [ "$t" = O2 ] && k="sets the category"
    check "L1 $t: scripts/aitools-lib.sh:$n($k) is listed" "[ -n '$n' ] && listed 'scripts/aitools-lib.sh:$n($k)' '$OUT'"
    n=$(line_of "$t" "$R/scripts/aitools-lib.ps1")
    check "L1 $t: scripts/aitools-lib.ps1:$n($k) is listed" "[ -n '$n' ] && listed 'scripts/aitools-lib.ps1:$n($k)' '$OUT'"
done
check "L1: rule 3 FAIL is reported" "has 'rule 3 FAIL, the relay changes the parent warning count' '$OUT'"
n=$(line_of O3 "$R/scripts/aitools-lib.sh")
check "L1 O3: scripts/aitools-lib.sh:$n(_aitlib_relay_line) is listed" "[ -n '$n' ] && listed 'scripts/aitools-lib.sh:$n(_aitlib_relay_line)' '$OUT'"
n=$(line_of O3 "$R/scripts/aitools-lib.ps1")
check "L1 O3: scripts/aitools-lib.ps1:$n(send-aitlibchildline) is listed" "[ -n '$n' ] && listed 'scripts/aitools-lib.ps1:$n(send-aitlibchildline)' '$OUT'"

R="$TMP_ROOT/l2"
lib_new "$R"
prog "$R" summary false
check "L2: new library, no other script: step 13 is PASS" "[ \"\$(result_of '$OUT')\" = PASS ]"
check "L2: rules 1 to 4 ok" "has 'rule 1 ok; rule 2 ok (0 write_error call(s)); rule 3 ok; rule 4 ok (no legacy WARN/ERROR call)' '$OUT'"
prog "$R" writers false
check "L2: step 14 is PASS (the library is not listed)" "[ \"\$(result_of '$OUT')\" = PASS ]"
prog "$R" writers true
check "L2: step 14 is PASS with STRICT true" "[ \"\$(result_of '$OUT')\" = PASS ]"

R="$TMP_ROOT/l3"
lib_new "$R"
perl -i -ne 'print unless /^relay_child_log\(\)/' "$R/scripts/aitools-lib.sh"
perl -0777 -i -pe 's/function Write-Summary.*?\n\}\n//s' "$R/scripts/aitools-lib.ps1"
prog "$R" summary false
check "L3: step 13 is FAIL" "[ \"\$(result_of '$OUT')\" = FAIL ]"
check "L3: rule 3 names the missing relay" "has 'scripts/aitools-lib.sh: relay_child_log not found' '$OUT'"
check "L3: rule 1 names the missing Write-Summary" "has 'scripts/aitools-lib.ps1: write-summary not found' '$OUT'"

# --- Case R2: rule 2, a reason for every write_error -------------------------------
R="$TMP_ROOT/r2"
lib_new "$R"
cat > "$R/scripts/setup-zz.sh" <<'R2_SH'
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
R2_SH
cat > "$R/scripts/setup-zz.ps1" <<'R2_PS1'
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
R2_PS1
prog "$R" summary false
check "R2: step 13 is FAIL" "[ \"\$(result_of '$OUT')\" = FAIL ]"
check "R2: rule 2 FAIL is reported" "has 'rule 2 FAIL, write_error without a reason' '$OUT'"
for t in B1 B2 B5 B6 B7; do
    n=$(line_of "$t" "$R/scripts/setup-zz.sh")
    check "R2 sh $t: scripts/setup-zz.sh:$n(empty reason) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.sh:$n(empty reason)' '$OUT'"
done
for t in B3 B4; do
    n=$(line_of "$t" "$R/scripts/setup-zz.sh")
    check "R2 sh $t: scripts/setup-zz.sh:$n(no reason) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.sh:$n(no reason)' '$OUT'"
done
for t in G1 G2 G3 G4 G5 I1 I2; do
    n=$(line_of "$t" "$R/scripts/setup-zz.sh")
    check "R2 sh $t: scripts/setup-zz.sh:$n is not listed" "[ -n '$n' ] && ! listed 'scripts/setup-zz.sh:$n' '$OUT'"
done
n=$(line_of G3 "$R/scripts/setup-zz.sh")
n=$((n - 1))
check "R2 sh G3: the continued call's first line scripts/setup-zz.sh:$n is not listed" "! listed 'scripts/setup-zz.sh:$n' '$OUT'"
for t in B1 B3 B4 B5; do
    n=$(line_of "$t" "$R/scripts/setup-zz.ps1")
    check "R2 ps1 $t: scripts/setup-zz.ps1:$n(empty reason) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.ps1:$n(empty reason)' '$OUT'"
done
n=$(line_of B2 "$R/scripts/setup-zz.ps1")
check "R2 ps1 B2: scripts/setup-zz.ps1:$n(no reason) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.ps1:$n(no reason)' '$OUT'"
for t in G1 G2 G3 G4 G5 I1; do
    n=$(line_of "$t" "$R/scripts/setup-zz.ps1")
    check "R2 ps1 $t: scripts/setup-zz.ps1:$n is not listed" "[ -n '$n' ] && ! listed 'scripts/setup-zz.ps1:$n' '$OUT'"
done
# The good calls alone
perl -i -ne 'print unless /# B[0-9]$/' "$R/scripts/setup-zz.sh" "$R/scripts/setup-zz.ps1"
prog "$R" summary false
check "R2 good only: step 13 is PASS" "[ \"\$(result_of '$OUT')\" = PASS ]"
check "R2 good only: rule 2 ok (10 write_error call(s))" "has 'rule 2 ok (10 write_error call(s))' '$OUT'"

# --- Case R4: rule 4, legacy write_summary WARN / ERROR ------------------------------
R="$TMP_ROOT/r4"
lib_new "$R"
cat >> "$R/scripts/aitools-lib.sh" <<'R4_LIB'
zz_lib() {
    write_summary ERROR "$1" "$3"  # L1
}
R4_LIB
cat > "$R/scripts/setup-zz.sh" <<'R4_SH'
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
R4_SH
cat > "$R/scripts/setup-zz.ps1" <<'R4_PS1'
Write-Summary "WARN" "t" "x"  # W1
write-summary 'error' t x  # W2
Write-Summary "OK" "t" "v"  # N1
<# Write-Summary "WARN" t x #>  # N2
R4_PS1
prog "$R" list-legacy false
for t in W1 W3 W4; do
    n=$(line_of "$t" "$R/scripts/setup-zz.sh")
    c=WARN; [ "$t" = W3 ] && c=ERROR
    check "R4 sh $t: scripts/setup-zz.sh:$n($c) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.sh:$n($c)' '$OUT'"
done
for t in W2 W5 W6; do
    n=$(line_of "$t" "$R/scripts/setup-zz.sh")
    check "R4 sh $t: scripts/setup-zz.sh:$n(ERROR) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.sh:$n(ERROR)' '$OUT'"
done
for t in N1 N2 N3 N4 N5; do
    n=$(line_of "$t" "$R/scripts/setup-zz.sh")
    check "R4 sh $t: scripts/setup-zz.sh:$n is not listed" "[ -n '$n' ] && ! listed 'scripts/setup-zz.sh:$n' '$OUT'"
done
n=$(line_of W1 "$R/scripts/setup-zz.ps1")
check "R4 ps1 W1: scripts/setup-zz.ps1:$n(WARN) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.ps1:$n(WARN)' '$OUT'"
n=$(line_of W2 "$R/scripts/setup-zz.ps1")
check "R4 ps1 W2: scripts/setup-zz.ps1:$n(ERROR) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.ps1:$n(ERROR)' '$OUT'"
for t in N1 N2; do
    n=$(line_of "$t" "$R/scripts/setup-zz.ps1")
    check "R4 ps1 $t: scripts/setup-zz.ps1:$n is not listed" "[ -n '$n' ] && ! listed 'scripts/setup-zz.ps1:$n' '$OUT'"
done
n=$(line_of L1 "$R/scripts/aitools-lib.sh")
check "R4 L1: the library's own call scripts/aitools-lib.sh:$n(ERROR) is listed" "[ -n '$n' ] && listed 'scripts/aitools-lib.sh:$n(ERROR)' '$OUT'"
prog "$R" summary false
check "R4: STRICT false: step 13 is WARN" "[ \"\$(result_of '$OUT')\" = WARN ]"
check "R4: STRICT false: 9 calls reported, per file" \
    "has 'rule 4 reported, 9 legacy write_summary WARN/ERROR call(s), a FAIL once STRICT_SUMMARY is on: scripts/aitools-lib.sh(1) scripts/setup-zz.ps1(2) scripts/setup-zz.sh(6)' '$OUT'"
prog "$R" summary true
check "R4: STRICT true: step 13 is FAIL" "[ \"\$(result_of '$OUT')\" = FAIL ]"
check "R4: STRICT true: rule 4 FAIL, 9 calls" "has 'rule 4 FAIL, 9 legacy write_summary WARN/ERROR call(s): ' '$OUT'"

# --- Case W: step 14, log writers outside the library ----------------------------
R="$TMP_ROOT/w"
lib_new "$R"
mkdir -p "$R/scripts/githooks"
cat > "$R/scripts/setup-zz.sh" <<'W_SH'
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
W_SH
cat > "$R/scripts/setup-zz.ps1" <<'W_PS1'
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
W_PS1
printf '#!/usr/bin/env bash\necho x >> "$LOG_FILE"  # X1\n' > "$R/scripts/zz-entry"
printf '#!/usr/bin/env python3\nprint(1) >> "$LOG_FILE"  # X2\n' > "$R/scripts/zz-tool"
printf '#!/bin/sh\necho x >> "$LOG_FILE"  # X3\n' > "$R/scripts/githooks/pre-commit"
for f in bootstrap.sh hh.sh relay-outbound-prompt.sh check-lib.sh check-zz.sh; do
    printf '#!/usr/bin/env bash\nprintf x >> "$LOG_FILE"  # EX\nlog() { :; }  # EX2\n' > "$R/scripts/$f"
done
for f in bootstrap.ps1 hh.ps1 check-lib.ps1 check-zz.ps1; do
    printf 'Add-Content -Path $logFile -Value x  # EX\nfunction Log($m) { }  # EX2\n' > "$R/scripts/$f"
done
printf 'Add-Content -Path $logFile -Value x  # RO\n' > "$R/scripts/relay-outbound-prompt.ps1"
cat > "$R/scripts/build-deploy.sh" <<'W_BD'
#!/usr/bin/env bash
cat <<'BLOCK'
    if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then printf 'ERROR|harness files|script truncated\n' >> "$AITOOLS_SUMMARY_FILE"; fi  # E1
    printf 'ERROR|other|x\n' >> "$AITOOLS_SUMMARY_FILE"  # E2
    Add-Content -Path $logFile -Value "x"  # E3
BLOCK
W_BD
prog "$R" list-writers false
for tk in F1:log-func F2:log-func F3:log-func A1:log-append A2:log-append A3:log-append A4:log-append R1:raw-primitive R2:raw-primitive C1:ccr-read; do
    t="${tk%%:*}"; k="${tk#*:}"
    n=$(line_of "$t" "$R/scripts/setup-zz.sh")
    check "W sh $t: scripts/setup-zz.sh:$n($k) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.sh:$n($k)' '$OUT'"
done
for t in N1 N2 N3 N4 N5 N6; do
    n=$(line_of "$t" "$R/scripts/setup-zz.sh")
    check "W sh $t: scripts/setup-zz.sh:$n is not listed" "[ -n '$n' ] && ! listed 'scripts/setup-zz.sh:$n' '$OUT'"
done
for tk in F1:log-func F2:log-func A1:log-append A2:log-append A3:log-append A4:log-append R1:raw-primitive R2:raw-primitive C1:ccr-read; do
    t="${tk%%:*}"; k="${tk#*:}"
    n=$(line_of "$t" "$R/scripts/setup-zz.ps1")
    check "W ps1 $t: scripts/setup-zz.ps1:$n($k) is listed" "[ -n '$n' ] && listed 'scripts/setup-zz.ps1:$n($k)' '$OUT'"
done
for t in N1 N2 N3 N4 N5; do
    n=$(line_of "$t" "$R/scripts/setup-zz.ps1")
    check "W ps1 $t: scripts/setup-zz.ps1:$n is not listed" "[ -n '$n' ] && ! listed 'scripts/setup-zz.ps1:$n' '$OUT'"
done
check "W X1: an extensionless bash file is scanned (scripts/zz-entry:2(log-append))" "listed 'scripts/zz-entry:2(log-append)' '$OUT'"
check "W X2: an extensionless python file is not" "! has 'scripts/zz-tool' '$OUT'"
check "W X3: scripts/githooks/ is scanned (scripts/githooks/pre-commit:2(log-append))" "listed 'scripts/githooks/pre-commit:2(log-append)' '$OUT'"
for f in bootstrap.sh hh.sh relay-outbound-prompt.sh check-lib.sh check-zz.sh bootstrap.ps1 hh.ps1 check-lib.ps1 check-zz.ps1 aitools-lib.sh aitools-lib.ps1; do
    check "W 8.1: scripts/$f is not listed" "! has 'scripts/$f:' '$OUT'"
done
check "W 8.1: scripts/relay-outbound-prompt.ps1 is in scope (listed)" "listed 'scripts/relay-outbound-prompt.ps1:1(log-append)' '$OUT'"
n=$(line_of E1 "$R/scripts/build-deploy.sh")
check "W 8.1 E1: build-deploy.sh's truncation guard line $n is not listed" "[ -n '$n' ] && ! listed 'scripts/build-deploy.sh:$n' '$OUT'"
n=$(line_of E2 "$R/scripts/build-deploy.sh")
check "W E2: another build-deploy.sh append scripts/build-deploy.sh:$n(log-append) is listed" "[ -n '$n' ] && listed 'scripts/build-deploy.sh:$n(log-append)' '$OUT'"
n=$(line_of E3 "$R/scripts/build-deploy.sh")
check "W E3: generated PowerShell in build-deploy.sh, scripts/build-deploy.sh:$n(log-append), is listed" "[ -n '$n' ] && listed 'scripts/build-deploy.sh:$n(log-append)' '$OUT'"
prog "$R" writers false
check "W: STRICT false: step 14 is WARN" "[ \"\$(result_of '$OUT')\" = WARN ]"
check "W: STRICT false: the detail says it is reported" "has 'reported until STRICT_SUMMARY is on' '$OUT'"
prog "$R" writers true
check "W: STRICT true: step 14 is FAIL" "[ \"\$(result_of '$OUT')\" = FAIL ]"

# --- Case E: the copied check, end to end -----------------------------------------
FIX="$TMP_ROOT/repo"
mkdir -p "$FIX"
cp -R "$ROOT/scripts" "$FIX/scripts"
cat > "$FIX/scripts/setup-zz.sh" <<'E_SH'
#!/usr/bin/env bash
set -euo pipefail
r=x
write_error "t" "w" "$r"  # X1
exit 1  # X1E
write_summary WARN "t" "x"  # X2
true
true
true
true
true
true
true
true
true
true
true
exit 1  # X3
E_SH

# run_check <label>: the copied check under a temp HOME and log dir; output ->
# $OUT, its step <n> line (colour codes removed) -> $TMP_ROOT/step<n>-<label>
run_check() {
    local label="$1" rc=0 s
    mkdir -p "$TMP_ROOT/home-$label"
    env -u AITOOLS_SUMMARY_FILE -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS \
        HOME="$TMP_ROOT/home-$label" AITOOLS_LOG_DIR="$TMP_ROOT/home-$label/logs" \
        "$TB" "$FIX/scripts/check-script-compliance.sh" < /dev/null > "$OUT" 2>&1 || rc=$?
    for s in 3 12 13 14; do
        LS_N="$s" perl -ne 's/\e\[[0-9;]*m//g; print if /^\s*\Q$ENV{LS_N}\E\.\s/' "$OUT" > "$TMP_ROOT/step$s-$label"
    done
    printf 'INFO %s: check exit %d; step 13: %s; step 14: %s\n' "$label" "$rc" \
        "$(step_result "$TMP_ROOT/step13-$label")" "$(step_result "$TMP_ROOT/step14-$label")"
}
# step_result <file>: the [PASS] / [WARN] / [FAIL] / [SKIP] word of a step line
step_result() {
    perl -ne 'print $1 if /\[(PASS|FAIL|WARN|SKIP)\]/' "$1"
}

run_check off
X1E=$(line_of X1E "$FIX/scripts/setup-zz.sh")
X2=$(line_of X2 "$FIX/scripts/setup-zz.sh")
X3=$(line_of X3 "$FIX/scripts/setup-zz.sh")
check "E step 3: the exit 1 after write_error (setup-zz.sh:$X1E) is not listed" "! listed 'setup-zz.sh:$X1E' '$TMP_ROOT/step3-off'"
check "E step 3: the uncovered exit 1 (setup-zz.sh:$X3) is listed" "listed 'setup-zz.sh:$X3' '$TMP_ROOT/step3-off'"
check "E STRICT false: step 12 does not list write_summary WARN (setup-zz.sh:$X2)" "[ -s '$TMP_ROOT/step12-off' ] && ! listed 'setup-zz.sh:$X2' '$TMP_ROOT/step12-off'"
check "E STRICT false: step 13 is there, with rule 4 counting setup-zz.sh" "has 'scripts/setup-zz.sh(1)' '$TMP_ROOT/step13-off'"
S14_OFF=$(step_result "$TMP_ROOT/step14-off")
check "E STRICT false: step 14 is PASS or WARN (it is $S14_OFF)" "[ '$S14_OFF' = PASS ] || [ '$S14_OFF' = WARN ]"

perl -i -pe 's/^STRICT_SUMMARY=false$/STRICT_SUMMARY=true/' "$FIX/scripts/check-script-compliance.sh"
run_check on
check "E STRICT true: step 12 is FAIL and lists setup-zz.sh:$X2(WARN)" "[ \"\$(step_result '$TMP_ROOT/step12-on')\" = FAIL ] && listed 'setup-zz.sh:$X2(WARN)' '$TMP_ROOT/step12-on'"
check "E STRICT true: step 13 is FAIL with rule 4 FAIL" "[ \"\$(step_result '$TMP_ROOT/step13-on')\" = FAIL ] && has 'rule 4 FAIL, ' '$TMP_ROOT/step13-on'"
if [ "$S14_OFF" = WARN ]; then
    check "E STRICT true: step 14 is FAIL (it was WARN)" "[ \"\$(step_result '$TMP_ROOT/step14-on')\" = FAIL ]"
else
    check "E STRICT true: step 14 is PASS (it was PASS)" "[ \"\$(step_result '$TMP_ROOT/step14-on')\" = PASS ]"
fi

# --- A program that cannot read a file is a FAIL, never a pass --------------------
R="$TMP_ROOT/unreadable"
lib_new "$R"
printf '#!/usr/bin/env bash\n:\n' > "$R/scripts/setup-zz.sh"
chmod 000 "$R/scripts/setup-zz.sh"
if [ -r "$R/scripts/setup-zz.sh" ]; then
    printf 'SKIP U: chmod 000 does not stop this user from reading (root)\n'; SKIP=$((SKIP + 1))
else
    rc=0
    perl "$PROG" writers false "$R" > "$OUT" 2>&1 || rc=$?
    check "U: an unreadable script ends the program with a non-zero exit (exit $rc)" "[ $rc -ne 0 ] && has 'logspec: cannot read scripts/setup-zz.sh' '$OUT'"
fi
chmod 644 "$R/scripts/setup-zz.sh"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
