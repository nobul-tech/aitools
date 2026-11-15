#!/usr/bin/env bash
# test-step7-grepq.sh -- tests for check-script-compliance.sh step 7 ("Grep
# pipefail safety"): a pipeline that ends in grep -q (or --quiet / --silent)
# in a bash file that runs under pipefail FAILS the step with file:line for
# each site, and the fixed form (the same grep without q, stdout to /dev/null)
# passes. Why: grep -q exits at its first match without reading the rest of
# its input, the writer then gets SIGPIPE (exit 141), and under pipefail the
# pipeline returns 141, so a grep -q condition can be false although the
# pattern matched (CI runs 43640967140 and 43642017937; PR #164).
#
# Isolation: the cases copy this checkout's scripts/ and shared/hooks/*.sh into
# a temp repo root (the check takes REPO_ROOT from its own location, so the
# copied check scans the copy), plant files under the copy's scripts/, and run
# the copied check with HOME and AITOOLS_LOG_DIR inside the temp dir. Nothing
# outside the temp dir (removed on exit) is written; the real HOME and the real
# repo are never written. Only step 7 is asserted (other steps may FAIL in the
# copy).
#
# Cases:
#   A  planted    scripts/zz-planted-grepq.sh (set -euo pipefail) with six bad
#                 pipelines: in an if condition, in $(...) before && and ||,
#                 after if !, with --quiet, with -i -q, and a continued line
#                 that starts with the pipe. Step 7 is FAIL, its detail names
#                 the count and the reason, and each planted line is listed as
#                 scripts/zz-planted-grepq.sh:<n>
#   B  ignored    in the same run: a comment line, grep -q reading a file, grep
#                 -q after ||, a pipe to grep ... >/dev/null, a pipe to grep -c,
#                 and scripts/zz-planted-nopf.sh (no pipefail) with a pipe to
#                 grep -q: none of their file:line is listed
#   C  fixed      the six bad lines rewritten to the fixed form (same flags
#                 without q, stdout to /dev/null): step 7 is not FAIL and none
#                 of them is listed (this also needs the copied tree to have no
#                 flagged site of its own: the step 7 line is shown on failure)
#   D  mechanism  under pipefail, 20 runs of seq 1 300000 piped to
#                 grep -x 1 >/dev/null all exit 0 (the host grep, GNU or BSD,
#                 reads its input to the end when it has no -q and stdout is
#                 /dev/null); then, for the CI log only (a race, not asserted),
#                 how many of 20 runs piped to grep -qx 1 exit non-zero, and
#                 with which status; and the host grep's version line
#
# AITOOLS_TEST_BASH runs the copied check with another bash (macOS /bin/bash
# 3.2); case D runs in the bash that runs this suite (CI starts it with the
# same bash). TEST_KEEP_TMP=1 keeps the temp dir. Safe to re-run. Needs perl
# and seq (case D is skipped without seq). Exit 1 if any case fails.
# Platform: Linux (bash 5), macOS (bash 5 and /bin/bash 3.2); CI: linux and
# macos jobs. On Windows the .sh check refuses to run (OS guard), so the suite
# reports SKIP and exits 0.
# Usage: bash tests/check-script-compliance/test-step7-grepq.sh [--help]

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'exit 0 if $. > 1 && !/^#/; print if $. > 1' "$0"
    exit 0
fi

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'SKIP all cases: check-script-compliance.sh refuses Windows (OS guard); CI runs this suite on macOS and Linux\n'
        printf '\n0 passed, 0 failed, 1 skipped\n'
        exit 0 ;;
esac

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

# listed <file:line> <step7 file>: 0 when that site is in the step 7 line
# (a whole token: not a prefix of file:line0 or a longer path)
listed() {
    S7_SITE="$1" perl -ne '$f = 1 if /(?<!\S)\Q$ENV{S7_SITE}\E(?![0-9])/; END { exit($f ? 0 : 1) }' "$2"
}

# --- Fixture -------------------------------------------------------------------
# A temp repo root with this checkout's scripts/ and shared/hooks/*.sh
FIX="$TMP_ROOT/repo"
mkdir -p "$FIX/shared/hooks"
cp -R "$ROOT/scripts" "$FIX/scripts"
for h in "$ROOT"/shared/hooks/*.sh; do
    if [ -f "$h" ]; then cp "$h" "$FIX/shared/hooks/"; fi
done
P="scripts/zz-planted-grepq.sh"
NOPF="scripts/zz-planted-nopf.sh"

# plant_bad: the six bad pipelines (A1-A6) and the lines step 7 must ignore (B1-B5)
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
# echo x | grep -q a  # B1
grep -q a "$f"  # B2
true || grep -q a "$f"  # B3
echo "$x" | grep a >/dev/null  # B4
echo "$x" | grep -c a  # B5
echo "$r"
PLANTED_A
}

# plant_fixed: A1-A6 rewritten to the fixed form (C1-C6), B1-B5 unchanged
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
# echo x | grep -q a  # B1
grep -q a "$f"  # B2
true || grep -q a "$f"  # B3
echo "$x" | grep a >/dev/null  # B4
echo "$x" | grep -c a  # B5
echo "$r"
PLANTED_C
}

# A file without pipefail: not in step 7's qualified set (B6)
cat > "$FIX/$NOPF" <<'PLANTED_NOPF'
#!/usr/bin/env bash
# zz-planted-nopf.sh -- planted by tests/check-script-compliance/test-step7-grepq.sh
set -eu
echo x | grep -q a  # B6
PLANTED_NOPF

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

# --- Cases A and B: planted bad pipelines --------------------------------------
plant_bad
run_check planted
S7P="$TMP_ROOT/step7-planted"
check "A: step 7 is FAIL" "[ \"\$S7_RESULT\" = FAIL ]"
check "A: the detail names the count and the reason" \
    "perl -ne '\$f = 1 if /\\[FAIL\\] [0-9]+ pipeline\\(s\\) end in grep -q under pipefail: /; END { exit(\$f ? 0 : 1) }' '$S7P'"
for t in A1 A2 A3 A4 A5 A6; do
    n=$(line_of "$t" "$FIX/$P")
    check "A $t: listed as $P:$n" "[ -n '$n' ] && listed '$P:$n' '$S7P'"
done
for t in B1 B2 B3 B4 B5; do
    n=$(line_of "$t" "$FIX/$P")
    check "B $t: $P:$n is not listed" "[ -n '$n' ] && ! listed '$P:$n' '$S7P'"
done
n=$(line_of B6 "$FIX/$NOPF")
check "B B6: $NOPF:$n (no pipefail) is not listed" "[ -n '$n' ] && ! listed '$NOPF:$n' '$S7P'"

# --- Case C: the fixed form ----------------------------------------------------
plant_fixed
run_check fixed
S7C="$TMP_ROOT/step7-fixed"
check "C: step 7 is not FAIL (result: ${S7_RESULT:-none})" "[ -n \"\$S7_RESULT\" ] && [ \"\$S7_RESULT\" != FAIL ]"
for t in C1 C2 C3 C4 C5 C6; do
    n=$(line_of "$t" "$FIX/$P")
    check "C $t: $P:$n is not listed" "[ -n '$n' ] && ! listed '$P:$n' '$S7C'"
done

# --- Case D: the mechanism on the host grep ------------------------------------
rm -f "$TMP_ROOT/out"
if ! command -v seq >/dev/null 2>&1; then
    printf 'SKIP D: seq not installed\n'; SKIP=$((SKIP + 1))
else
    gv=$(grep --version 2>&1) || gv="unknown (grep --version failed)"
    gv1=""
    IFS= read -r gv1 <<< "$gv"
    printf 'INFO D: host grep: %s\n' "$gv1"
    printf 'INFO D: bash %s\n' "$BASH_VERSION"
    d_bad=0
    d_codes=""
    i=0
    while [ "$i" -lt 20 ]; do
        rc=0
        seq 1 300000 | grep -x 1 >/dev/null || rc=$?
        if [ "$rc" -ne 0 ]; then d_bad=$((d_bad + 1)); d_codes="$d_codes $rc"; fi
        i=$((i + 1))
    done
    check "D: 20 of 20 runs of seq 1 300000, piped to grep -x 1 >/dev/null under pipefail, exit 0 (non-zero runs: $d_bad, statuses:${d_codes:- none})" \
        "[ $d_bad -eq 0 ]"
    q_bad=0
    q_codes=""
    i=0
    while [ "$i" -lt 20 ]; do
        rc=0
        seq 1 300000 | grep -qx 1 || rc=$?
        if [ "$rc" -ne 0 ]; then q_bad=$((q_bad + 1)); q_codes="$q_codes $rc"; fi
        i=$((i + 1))
    done
    printf 'INFO D: race, not asserted: %d of 20 runs of seq 1 300000, piped to grep -qx 1 under pipefail, exited non-zero (statuses:%s)\n' \
        "$q_bad" "${q_codes:- none}"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
