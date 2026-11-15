#!/usr/bin/env bash
# test-step7-grepq.sh -- tests for check-script-compliance.sh step 7 ("Grep
# pipefail safety"): a pipeline that ends in a reader that exits before its
# input ends -- grep -q (or --quiet / --silent), grep -l / -L, grep -m N
# (--max-count), head, a perl -n / -p program that runs exit or last -- in a
# bash file that runs under pipefail FAILS the step with file:line(reader) for
# each site, in scripts/, shared/hooks/ and tests/; the fixed forms pass. Why:
# such a reader stops reading, the writer then gets SIGPIPE (exit 141) or an
# EPIPE write error, and under pipefail the pipeline fails, so a condition can
# be false although the reader found what it wanted (CI runs 43640967140 and
# 43642017937; PR #164; reference/script-standards-detail.md "Pipelines into
# grep -q under pipefail").
#
# Isolation: the cases copy this checkout's scripts/, shared/hooks/*.sh,
# tests/lib/platform-lib.sh and this suite into a temp repo root (the check
# takes REPO_ROOT from its own location, so the copied check scans the copy),
# plant files under the copy's scripts/ and tests/, and run the copied check
# with HOME and AITOOLS_LOG_DIR inside the temp dir. Nothing outside the temp
# dir (removed on exit) is written; the real HOME and the real repo are never
# written. Only step 7 is asserted (other steps may FAIL in the copy).
#
# Cases:
#   A  planted    scripts/zz-planted-grepq.sh (set -euo pipefail) with sixteen
#                 bad pipelines: grep -q in an if condition, in $(...) before
#                 && and ||, after if !, with --quiet, with -i -q, and on a
#                 continued line that starts with the pipe (A1-A6); head -n 1,
#                 head -3 (A7, A8); grep -m 1, grep --max-count=1 (A9, A10);
#                 grep -l, grep -L (A11, A12); perl `print, exit`, perl `last`
#                 (A13, A14); a pattern glued to -q (grep -q"a") and a quoted
#                 option (grep "-q" a), both missed before (A15, A16). Step 7
#                 is FAIL, its detail names the count and the reason, and each
#                 planted line is listed as scripts/zz-planted-grepq.sh:<n>(<reader>)
#   B  ignored    in the same run: a comment line, grep -q reading a file,
#                 grep -q after ||, grep ... >/dev/null, grep -c, a file
#                 without pipefail (B1-B6); and the false-positive edge cases
#                 of PR #168 review note 4: grep -- -q, grep -e -q (B7, B8);
#                 perl with exit only in END { }, perl -0777 with exit, head
#                 reading a file, a perl -p with no exit (B9-B12): none listed
#   C  fixed      the sixteen bad lines in the fixed forms (grep ... >/dev/null;
#                 sed -n '1p' / '1,3p'; grep ... | sed -n '1p'; perl
#                 `next if $done; ...` and `END { exit(...) }`): step 7 is not
#                 FAIL and none of them is listed (this also needs the copied
#                 tree to have no flagged site of its own: the step 7 line is
#                 shown on failure)
#   E  tests/     in the planted run: tests/zz-planted/test-zz.sh (pipefail)
#                 with grep -q and head (E1, E2) is listed; a tests/ file
#                 without pipefail (E3) is not; tests/lib/platform-lib.sh, a
#                 library the suites source, with head appended (E4) is listed
#                 although it does not set pipefail itself; this suite's own
#                 copy (it plants the bad forms on purpose) is never listed
#                 (E5). In the fixed run E1, E2 and E4 in the fixed form are
#                 not listed
#   D  mechanism  under pipefail, 20 runs each of seq 1 300000 piped to
#                 grep -x 1 >/dev/null, sed -n '1p', perl `next if $done`,
#                 and perl `END { exit }` all exit 0 (each reads its input to
#                 the end); then, for the CI log only (a race, not asserted),
#                 how many of 20 runs piped to grep -qx 1 and to head -n 1 exit
#                 non-zero, and with which status; and the host grep's version
#
# AITOOLS_TEST_BASH runs the copied check with another bash (macOS /bin/bash
# 3.2); case D runs in the bash that runs this suite (CI starts it with the
# same bash). TEST_KEEP_TMP=1 keeps the temp dir. Safe to re-run. Needs perl
# and seq (case D is skipped without seq). Exit 1 if any case fails.
# Platform: Linux (bash 5), macOS (bash 5 and /bin/bash 3.2); CI: linux and
# macos jobs. Windows refuses it (OS guard, exit 1): the .sh check it tests
# refuses Windows too, and it has no Windows twin.
# Usage: bash tests/check-script-compliance/test-step7-grepq.sh [--help]

set -euo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. It has no Windows twin: the CI linux and macos jobs run it.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. It has no Windows twin: the CI linux and macos jobs run it.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'exit 0 if $. > 1 && !/^#/; print if $. > 1' "$0"
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
S7_RESULT=""

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -f "$TMP_ROOT/out" ]; then
            # The last 25 lines of the check's output, colour codes removed
            perl -ne 's/\e\[[0-9;]*m//g; push @l, "      | $_"; shift @l if @l > 25; END { print @l }' "$TMP_ROOT/out"
        fi
    fi
}

# line_of <tag> <file>: the line number of the line that ends in "# <tag>"
line_of() {
    S7_TAG="$1" perl -ne 'print "$.\n" if /#[ ]\Q$ENV{S7_TAG}\E[ \t]*$/' "$2"
}

# listed <site> <step7 file>: 0 when that site (file:line, or file:line(reader))
# is in the step 7 line (matched as a whole word, never as a prefix of
# file:line0 or a longer path)
listed() {
    S7_SITE="$1" perl -ne '$f = 1 if /(?<!\S)\Q$ENV{S7_SITE}\E(?![0-9])/; END { exit($f ? 0 : 1) }' "$2"
}

# --- Fixture -------------------------------------------------------------------
# A temp repo root with this checkout's scripts/, shared/hooks/*.sh,
# tests/lib/platform-lib.sh and this suite
FIX="$TMP_ROOT/repo"
mkdir -p "$FIX/shared/hooks" "$FIX/tests/lib" "$FIX/tests/check-script-compliance" "$FIX/tests/zz-planted"
cp -R "$ROOT/scripts" "$FIX/scripts"
for h in "$ROOT"/shared/hooks/*.sh; do
    if [ -f "$h" ]; then cp "$h" "$FIX/shared/hooks/"; fi
done
cp "$ROOT/tests/lib/platform-lib.sh" "$FIX/tests/lib/platform-lib.sh"
cp "$ROOT/tests/check-script-compliance/test-step7-grepq.sh" "$FIX/tests/check-script-compliance/test-step7-grepq.sh"
P="scripts/zz-planted-grepq.sh"
NOPF="scripts/zz-planted-nopf.sh"
TZ="tests/zz-planted/test-zz.sh"
TZN="tests/zz-planted/test-zz-nopf.sh"
LIB="tests/lib/platform-lib.sh"
SELF="tests/check-script-compliance/test-step7-grepq.sh"

# The reader each A line plants, in A1..A16 order
A_KINDS="grep-q grep-q grep-q grep-q grep-q grep-q head head grep-m grep-m grep-l grep-l perl-exit perl-exit grep-q grep-q"

# plant_bad: the bad pipelines (A1-A16, E1, E2, E4) and the lines step 7 must
# ignore (B1-B12, E3)
plant_bad() {
    cat > "$FIX/$P" <<'PLANTED_A'
#!/usr/bin/env bash
# zz-planted-grepq.sh -- planted by tests/check-script-compliance/test-step7-grepq.sh
set -euo pipefail
x=abc
f=/dev/null
if echo "$x" | grep -q a; then :; fi  # A1
r=$(printf '%s\n' "$x" | grep -qi a && echo y || echo n)  # A2
if ! printf '%s' "$x" | grep -qxF a; then :; fi  # A3
echo "$x" | grep --quiet a  # A4
echo "$x" | grep -i -q a  # A5
echo "$x" \
    | grep -q a  # A6
v=$(printf '%s\n' "$x" | head -n 1)  # A7
printf '%s\n' "$x" | head -3 >/dev/null  # A8
echo "$x" | grep -m 1 a  # A9
echo "$x" | grep --max-count=1 a  # A10
echo "$x" | grep -l a  # A11
echo "$x" | grep -L b  # A12
v=$(printf '%s\n' "$x" | perl -ne 'print, exit if /a/')  # A13
printf '%s\n' "$x" | perl -ne 'last if /a/; print'  # A14
echo "$x" | grep -q"a"  # A15
echo "$x" | grep "-q" a  # A16
# echo x | grep -q a  # B1
grep -q a "$f"  # B2
true || grep -q a "$f"  # B3
echo "$x" | grep a >/dev/null  # B4
echo "$x" | grep -c a  # B5
echo "$x" | grep -- -q  # B7
echo "$x" | grep -e -q  # B8
printf '%s\n' "$x" | perl -ne '$f = 1 if /a/; END { exit($f ? 0 : 1) }'  # B9
printf '%s' "$x" | perl -0777 -ne 'exit(/a/ ? 0 : 1)'  # B10
head -n 1 "$f"  # B11
printf '%s\n' "$x" | perl -pe 's/a/b/'  # B12
echo "$r $v"
PLANTED_A
    cat > "$FIX/$TZ" <<'PLANTED_E'
#!/usr/bin/env bash
# test-zz.sh -- planted by tests/check-script-compliance/test-step7-grepq.sh
set -uo pipefail
x=abc
check "e1" "echo '$x' | grep -q a"  # E1
v=$(printf '%s\n' "$x" | head -n 1)  # E2
echo "$v"
PLANTED_E
    cp "$ROOT/$LIB" "$FIX/$LIB"
    printf '%s\n' 'zz_first() { printf "%s\n" "$1" | head -n 1; }  # E4' >> "$FIX/$LIB"
}

# plant_fixed: A1-A16 rewritten to the fixed forms (C1-C16), E1, E2, E4 fixed;
# the B lines unchanged
plant_fixed() {
    cat > "$FIX/$P" <<'PLANTED_C'
#!/usr/bin/env bash
# zz-planted-grepq.sh -- planted by tests/check-script-compliance/test-step7-grepq.sh
set -euo pipefail
x=abc
f=/dev/null
if echo "$x" | grep a >/dev/null; then :; fi  # C1
r=$(printf '%s\n' "$x" | grep -i a >/dev/null && echo y || echo n)  # C2
if ! printf '%s' "$x" | grep -xF a >/dev/null; then :; fi  # C3
echo "$x" | grep a >/dev/null  # C4
echo "$x" | grep -i a >/dev/null  # C5
echo "$x" \
    | grep a >/dev/null  # C6
v=$(printf '%s\n' "$x" | sed -n '1p')  # C7
printf '%s\n' "$x" | sed -n '1,3p' >/dev/null  # C8
echo "$x" | grep a | sed -n '1p'  # C9
echo "$x" | grep a | sed -n '1p'  # C10
echo "$x" | grep a >/dev/null  # C11
! echo "$x" | grep b >/dev/null  # C12
v=$(printf '%s\n' "$x" | perl -ne 'next if $done; if (/a/) { print; $done = 1 }')  # C13
printf '%s\n' "$x" | perl -ne '$stop = 1 if /a/; print unless $stop'  # C14
echo "$x" | grep a >/dev/null  # C15
echo "$x" | grep a >/dev/null  # C16
# echo x | grep -q a  # B1
grep -q a "$f"  # B2
true || grep -q a "$f"  # B3
echo "$x" | grep a >/dev/null  # B4
echo "$x" | grep -c a  # B5
echo "$x" | grep -- -q  # B7
echo "$x" | grep -e -q  # B8
printf '%s\n' "$x" | perl -ne '$f = 1 if /a/; END { exit($f ? 0 : 1) }'  # B9
printf '%s' "$x" | perl -0777 -ne 'exit(/a/ ? 0 : 1)'  # B10
head -n 1 "$f"  # B11
printf '%s\n' "$x" | perl -pe 's/a/b/'  # B12
echo "$r $v"
PLANTED_C
    cat > "$FIX/$TZ" <<'PLANTED_EF'
#!/usr/bin/env bash
# test-zz.sh -- planted by tests/check-script-compliance/test-step7-grepq.sh
set -uo pipefail
x=abc
check "e1" "echo '$x' | grep a >/dev/null"  # E1
v=$(printf '%s\n' "$x" | sed -n '1p')  # E2
echo "$v"
PLANTED_EF
    cp "$ROOT/$LIB" "$FIX/$LIB"
    printf '%s\n' 'zz_first() { printf "%s\n" "$1" | sed -n "1p"; }  # E4' >> "$FIX/$LIB"
}

# Files without pipefail: not in step 7's qualified set (B6, E3)
cat > "$FIX/$NOPF" <<'PLANTED_NOPF'
#!/usr/bin/env bash
# zz-planted-nopf.sh -- planted by tests/check-script-compliance/test-step7-grepq.sh
set -eu
echo x | grep -q a  # B6
PLANTED_NOPF
cat > "$FIX/$TZN" <<'PLANTED_TZN'
#!/usr/bin/env bash
# test-zz-nopf.sh -- planted by tests/check-script-compliance/test-step7-grepq.sh
set -eu
echo x | head -n 1  # E3
PLANTED_TZN

# run_check <label>: the copied check under a temp HOME and log dir; its output
# -> $TMP_ROOT/out, its step 7 line (colour codes removed) -> $TMP_ROOT/step7-<label>,
# the step 7 result word -> S7_RESULT (empty when there is no step 7 line)
run_check() {
    local label="$1" rc=0
    mkdir -p "$TMP_ROOT/home-$label"
    env -u AITOOLS_SUMMARY_FILE -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS \
        HOME="$TMP_ROOT/home-$label" AITOOLS_LOG_DIR="$TMP_ROOT/home-$label/logs" \
        "$TB" "$FIX/scripts/check-script-compliance.sh" < /dev/null > "$TMP_ROOT/out" 2>&1 || rc=$?
    perl -ne 's/\e\[[0-9;]*m//g; print if /^\s*7\.\s+Grep pipefail safety\s/' "$TMP_ROOT/out" > "$TMP_ROOT/step7-$label"
    S7_RESULT=$(perl -ne 'print $1 if /\[(PASS|FAIL|WARN|SKIP)\]/' "$TMP_ROOT/step7-$label")
    printf 'INFO %s: check exit %d, step 7 result: %s\n' "$label" "$rc" "${S7_RESULT:-none}"
}

# --- Cases A, B and E: planted bad pipelines -----------------------------------
plant_bad
run_check planted
S7P="$TMP_ROOT/step7-planted"
check "A: step 7 is FAIL" "[ \"\$S7_RESULT\" = FAIL ]"
check "A: the detail names the count and the reason" \
    "perl -ne '\$f = 1 if /\\[FAIL\\] [0-9]+ pipeline\\(s\\) end in a reader that exits early \\(grep -q \\/ -l \\/ -m, head, perl exit\\) under pipefail: /; END { exit(\$f ? 0 : 1) }' '$S7P'"
i=0
for kind in $A_KINDS; do
    i=$((i + 1))
    t="A$i"
    n=$(line_of "$t" "$FIX/$P")
    check "A $t: listed as $P:$n($kind)" "[ -n '$n' ] && listed '$P:$n($kind)' '$S7P'"
done
for t in B1 B2 B3 B4 B5 B7 B8 B9 B10 B11 B12; do
    n=$(line_of "$t" "$FIX/$P")
    check "B $t: $P:$n is not listed" "[ -n '$n' ] && ! listed '$P:$n' '$S7P'"
done
n=$(line_of B6 "$FIX/$NOPF")
check "B B6: $NOPF:$n (no pipefail) is not listed" "[ -n '$n' ] && ! listed '$NOPF:$n' '$S7P'"
n=$(line_of E1 "$FIX/$TZ")
check "E E1: $TZ:$n(grep-q) is listed (tests/ is scanned)" "[ -n '$n' ] && listed '$TZ:$n(grep-q)' '$S7P'"
n=$(line_of E2 "$FIX/$TZ")
check "E E2: $TZ:$n(head) is listed" "[ -n '$n' ] && listed '$TZ:$n(head)' '$S7P'"
n=$(line_of E3 "$FIX/$TZN")
check "E E3: $TZN:$n (no pipefail) is not listed" "[ -n '$n' ] && ! listed '$TZN:$n' '$S7P'"
n=$(line_of E4 "$FIX/$LIB")
check "E E4: $LIB:$n(head) is listed (a library the suites source)" "[ -n '$n' ] && listed '$LIB:$n(head)' '$S7P'"
check "E E5: no line of $SELF is listed (it plants the bad forms)" \
    "S7_SELF='$SELF:' perl -ne '\$f = 1 if index(\$_, \$ENV{S7_SELF}) >= 0; END { exit(\$f ? 1 : 0) }' '$S7P'"

# --- Cases C and E: the fixed forms ---------------------------------------------
plant_fixed
run_check fixed
S7C="$TMP_ROOT/step7-fixed"
check "C: step 7 is not FAIL (result: ${S7_RESULT:-none})" "[ -n \"\$S7_RESULT\" ] && [ \"\$S7_RESULT\" != FAIL ]"
i=0
while [ "$i" -lt 16 ]; do
    i=$((i + 1))
    t="C$i"
    n=$(line_of "$t" "$FIX/$P")
    check "C $t: $P:$n is not listed" "[ -n '$n' ] && ! listed '$P:$n' '$S7C'"
done
for t in E1 E2; do
    n=$(line_of "$t" "$FIX/$TZ")
    check "E fixed $t: $TZ:$n is not listed" "[ -n '$n' ] && ! listed '$TZ:$n' '$S7C'"
done
n=$(line_of E4 "$FIX/$LIB")
check "E fixed E4: $LIB:$n is not listed" "[ -n '$n' ] && ! listed '$LIB:$n' '$S7C'"

# --- Case D: the mechanism on the host grep, sed and perl -----------------------
rm -f "$TMP_ROOT/out"
# d_runs <label> <command>: 20 runs of the command under pipefail; sets D_BAD
# (runs that exited non-zero) and D_CODES (their statuses)
d_runs() {
    local i=0 rc
    D_BAD=0
    D_CODES=""
    while [ "$i" -lt 20 ]; do
        rc=0
        eval "$1" || rc=$?
        if [ "$rc" -ne 0 ]; then D_BAD=$((D_BAD + 1)); D_CODES="$D_CODES $rc"; fi
        i=$((i + 1))
    done
}
if ! command -v seq >/dev/null 2>&1; then
    printf 'SKIP D: seq not installed\n'; SKIP=$((SKIP + 1))
else
    gv=$(grep --version 2>&1) || gv="unknown (grep --version failed)"
    gv1=""
    IFS= read -r gv1 <<< "$gv"
    printf 'INFO D: host grep: %s\n' "$gv1"
    printf 'INFO D: bash %s\n' "$BASH_VERSION"
    d_runs 'seq 1 300000 | grep -x 1 >/dev/null'
    check "D: 20 of 20 runs of seq 1 300000, piped to grep -x 1 >/dev/null under pipefail, exit 0 (non-zero runs: $D_BAD, statuses:${D_CODES:- none})" \
        "[ $D_BAD -eq 0 ]"
    d_runs "seq 1 300000 | sed -n '1p' >/dev/null"
    check "D: 20 of 20 runs of seq 1 300000, piped to sed -n '1p', exit 0 (non-zero runs: $D_BAD, statuses:${D_CODES:- none})" \
        "[ $D_BAD -eq 0 ]"
    d_runs "seq 1 300000 | perl -ne 'next if \$done; if (/^1\$/) { print; \$done = 1 }' >/dev/null"
    check "D: 20 of 20 runs of seq 1 300000, piped to perl next-if-done, exit 0 (non-zero runs: $D_BAD, statuses:${D_CODES:- none})" \
        "[ $D_BAD -eq 0 ]"
    d_runs "seq 1 300000 | perl -ne '\$f = 1 if /^1\$/; END { exit(\$f ? 0 : 1) }'"
    check "D: 20 of 20 runs of seq 1 300000, piped to perl END { exit }, exit 0 (non-zero runs: $D_BAD, statuses:${D_CODES:- none})" \
        "[ $D_BAD -eq 0 ]"
    d_runs 'seq 1 300000 | grep -qx 1'
    printf 'INFO D: race, not asserted: %d of 20 runs of seq 1 300000, piped to grep -qx 1 under pipefail, exited non-zero (statuses:%s)\n' \
        "$D_BAD" "${D_CODES:- none}"
    d_runs 'seq 1 300000 | head -n 1 >/dev/null'
    printf 'INFO D: race, not asserted: %d of 20 runs of seq 1 300000, piped to head -n 1 under pipefail, exited non-zero (statuses:%s)\n' \
        "$D_BAD" "${D_CODES:- none}"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
