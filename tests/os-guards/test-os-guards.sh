#!/usr/bin/env bash
# test-os-guards.sh -- every product script's and test suite's OS guard refuses
# the wrong platform: the macOS/Linux harness. Its Windows twin is
# tests/os-guards/test-os-guards.ps1.
#
# Purpose: prove the platform targeting of plans/ci-platform-targeting.md
# (commander, 2026-11-01: "the os guard should be tested to ensure it works,
# ie, the pwsh scripts meant for windows only should refuse to run"; commander,
# 2026-11-14: "sh scripts and tests should only run on linux/mac and ps1 on
# windows").
#
# The script list comes from the files, not a hand list:
# tests/os-guards/classify-guards.pl classifies every tracked .ps1 and .sh under
# scripts/, shared/ and packaging/ (and extensionless shell scripts there), and
# every test suite tests/<dir>/test-*.sh / test-*.ps1, as one of:
#   win       .ps1 with the Windows guard
#   posix     .sh with the POSIX guard (a test suite also with the
#             ${BASH_VERSINFO[5]:-} case, which a uname shim or an exported
#             OSTYPE cannot fool)
#   weak      a test suite whose POSIX guard lacks that case (FAILS)
#   exempt    no guard, and listed in the "OS guard exemptions" table of
#             .claude/rules/cross-platform.md (hooks, libraries, entry points,
#             cross-platform test suites ...)
#   unexempt  no guard and not listed (FAILS: detection layer)
# On macOS and Linux each win script and suite, run with pwsh -NoProfile
# -NonInteractive -File and no arguments under an isolated HOME, must exit 1,
# print the guard message, and write nothing under HOME except ~/.aitools/logs
# (and pwsh's own startup cache). The Windows harness checks that the posix
# ones refuse Git Bash. The guards' pass side (the script runs on its own
# platform) is covered by the functional suites that run there.
#
# Usage: bash tests/os-guards/test-os-guards.sh [--help]
# Exit: 0 all checks pass, 1 any failure. Without pwsh the refusal checks are
#   reported FAIL under CI (CI=true) and SKIP elsewhere.
# Platform: macOS, Linux; bash 3.2 compatible. Safe to re-run (everything runs
#   under a temp dir that is removed on exit).
set -euo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/os-guards/test-os-guards.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/os-guards/test-os-guards.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if 2 .. /^set -euo/' "$0" | perl -ne 'print unless /^set -euo/' | perl -pe 's/^# ?//'
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
cleanup() { cd / && rm -rf "$WORK"; }
trap cleanup EXIT

case "$(uname -s)" in
    Darwin) PLATFORM=macos ;;
    *) PLATFORM=linux ;;
esac

PASS=0
FAIL=0
SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  skip %s\n' "$1"; }

# --- Classify every product script and test suite ----------------------------
CLASSES="$WORK/classes.tsv"
if ! git -C "$ROOT" ls-files -- scripts shared packaging tests > "$WORK/files.txt"; then
    printf 'FAIL: git ls-files failed in %s\n' "$ROOT"
    exit 1
fi
if ! perl "$ROOT/tests/os-guards/classify-guards.pl" "$ROOT" "$ROOT/.claude/rules/cross-platform.md" "$WORK/files.txt" > "$CLASSES"; then
    printf 'FAIL: classification failed (see the error above)\n'
    exit 1
fi

n_win=$(grep -c '^win	' "$CLASSES" || true)
n_posix=$(grep -c '^posix	' "$CLASSES" || true)
n_exempt=$(grep -c '^exempt	' "$CLASSES" || true)
n_tests=$(grep -c '	tests/' "$CLASSES" || true)
printf '== %s: %s Windows-guarded .ps1, %s POSIX-guarded .sh, %s exempt (%s test suites classified)\n' \
    "$PLATFORM" "$n_win" "$n_posix" "$n_exempt" "$n_tests"

echo "== every unguarded script and suite is in the cross-platform.md exemption table"
if grep -q '^unexempt	' "$CLASSES"; then
    while IFS="$(printf '\t')" read -r _ f; do
        bad "no OS guard and not in the exemption table: $f"
    done < <(grep '^unexempt	' "$CLASSES")
else
    ok "all $n_exempt unguarded scripts and suites are listed exemptions"
fi
echo "== every POSIX-guarded test suite also checks BASH_VERSINFO[5]"
if grep -q '^weak	' "$CLASSES"; then
    while IFS="$(printf '\t')" read -r _ f; do
        bad "test suite guard lacks the \${BASH_VERSINFO[5]:-} case: $f"
    done < <(grep '^weak	' "$CLASSES")
else
    ok "no test suite guard relies on uname alone"
fi
[ "$n_win" -gt 0 ] && ok "found Windows-guarded scripts ($n_win)" || bad "found no Windows-guarded .ps1 (classifier broken?)"
[ "$n_posix" -gt 0 ] && ok "found POSIX-guarded scripts ($n_posix)" || bad "found no POSIX-guarded .sh (classifier broken?)"

# refuse <path> <runner...>: run a script on the wrong platform under a fresh
# HOME; it must exit 1, print the guard message, and write only logs.
refuse() {
    local f="$1"
    shift
    local h="$WORK/home-$(printf '%s' "$f" | tr '/.' '__')"
    local cwd="$WORK/cwd"
    mkdir -p "$h" "$cwd"
    local want="This script is for Windows"
    local rc=0
    (cd "$cwd" && env HOME="$h" "$@" < /dev/null > "$WORK/out.txt" 2>&1) || rc=$?
    # Allowed writes: the script's own logs (it logs its refusal) and pwsh's
    # startup cache (~/.cache/powershell/StartupProfileData-*, written by pwsh
    # itself before any script code runs).
    local stray
    stray=$(cd "$h" && find . -type f ! -path './.aitools/logs/*' ! -path './.cache/powershell/*' | head -n 5)
    if [ "$rc" -eq 1 ] && grep -qF "$want" "$WORK/out.txt" && [ -z "$stray" ]; then
        ok "$f refuses $PLATFORM (exit 1, guard message, only logs written)"
    else
        bad "$f on $PLATFORM: exit $rc (want 1); message $(grep -qF "$want" "$WORK/out.txt" && echo present || echo MISSING); stray files: ${stray:-none}"
        perl -ne 'print "       | $_" if $. <= 8' "$WORK/out.txt"
    fi
}

echo "== Windows-guarded .ps1 scripts and suites refuse $PLATFORM (pwsh)"
if command -v pwsh >/dev/null 2>&1; then
    while IFS="$(printf '\t')" read -r _ f; do
        refuse "$f" pwsh -NoProfile -NonInteractive -File "$ROOT/$f"
    done < <(grep '^win	' "$CLASSES")
elif [ "${CI:-}" = "true" ]; then
    bad "pwsh is not on PATH: the Windows guards cannot be tested on this runner"
else
    skip "pwsh is not on PATH: Windows guard refusal checks not run"
fi

printf '\ntest-os-guards: %d passed, %d failed, %d skipped (%s, bash %s)\n' \
    "$PASS" "$FAIL" "$SKIP" "$PLATFORM" "$BASH_VERSION"
[ "$FAIL" -eq 0 ]
