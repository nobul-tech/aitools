#!/usr/bin/env bash
# test-relay-outbound.sh -- the [RELAY] prompt scripts on macOS/Linux: the OS
# guards of scripts/relay-outbound-prompt.sh and .ps1.
#
# What it checks:
#   - relay-outbound-prompt.sh loads on macOS/Linux: sourced, it returns 0, prints
#     nothing and defines relay_outbound_prompt and _relay_outbound_choice; run
#     directly on a clean repo it exits 0 and prints nothing.
#   - The prompt still works below the guard: with CI set and an uncommitted
#     relay.md it prints the one-line [RELAY] hint on stderr and returns 0;
#     AITOOLS_SKIP_RELAY_PROMPT=1 returns 0 with no output.
#   - Its guard has the canonical POSIX form the OS guard classifier reads
#     (tests/os-guards), comes before the first function, writes the structured
#     line itself and returns 1 when sourced (exit 1 when run).
#   - relay-outbound-prompt.ps1 refuses macOS/Linux (pwsh, isolated HOME): run,
#     it exits 1 with "[<UTC>] [relay-outbound-prompt] [error] This script is for
#     Windows ..." on stderr and writes nothing but pwsh's own cache; dot-sourced
#     by a calling script, the guard's exit 1 ends only the guarded file: the
#     caller goes on with $LASTEXITCODE 1 and neither function defined, so a
#     caller under $ErrorActionPreference Stop (hh.ps1) ends nonzero at the call.
# The Windows side (the .ps1 loads, the .sh refuses, scripts/aitools forwards
# before it could source the .sh) is tests/relay-outbound/test-relay-outbound.ps1.
#
# Usage: bash tests/relay-outbound/test-relay-outbound.sh [--help]
# Safe to re-run: everything is written under a temp dir, removed on exit.
# Platform: macOS/Linux only (OS guard below); bash 3.2 compatible. Without pwsh
#   the .ps1 cases FAIL under CI (CI=true) and SKIP elsewhere. Exit 1 if any case fails.
set -uo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/relay-outbound/test-relay-outbound.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/relay-outbound/test-relay-outbound.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 27' "$0" | perl -pe 's/^# ?//'
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELAY_SH="$ROOT/scripts/relay-outbound-prompt.sh"
RELAY_PS1="$ROOT/scripts/relay-outbound-prompt.ps1"
# The bash that runs the relay script (macOS CI: /bin/bash 3.2 via AITOOLS_TEST_BASH)
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
WORK="$(mktemp -d)"
cleanup() { cd / && rm -rf "$WORK"; }
trap cleanup EXIT

PASS=0
FAIL=0
SKIP=0
ok()   { PASS=$((PASS + 1)); printf 'PASS %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf 'FAIL %s%s\n' "$1" "${2:+ -- $2}"; }
skip() { SKIP=$((SKIP + 1)); printf 'SKIP %s (%s)\n' "$1" "$2"; }
check() { if [ "$2" = 0 ]; then ok "$1"; else bad "$1" "${3:-}"; fi; }

# --- The .sh guard: form and place (classifier regex of tests/os-guards) -----
rc=0
perl -0777 -ne 'exit(/MINGW\*\|MSYS\*\|CYGWIN\*\)[^;]{0,300}?This script is for macOS\/Linux[^;]{0,200}?exit 1/s ? 0 : 1)' "$RELAY_SH" || rc=$?
check "sh guard: canonical POSIX form (classifier regex)" "$rc"
rc=0
perl -0777 -ne 'my $g = index($_, "MINGW*|MSYS*|CYGWIN*)"); my $f = index($_, "relay_outbound_prompt() {"); exit(($g > 0 && $f > $g) ? 0 : 1)' "$RELAY_SH" || rc=$?
check "sh guard: before the first function" "$rc"
rc=0
perl -0777 -ne 'exit(/printf \x27\[%s\] \[relay-outbound-prompt\] \[error\] This script is for macOS\/Linux\.[^\n]*"\$\(date -u \+%Y-%m-%dT%H:%M:%SZ\)" >&2\n\s+\[ "\$\{BASH_SOURCE\[0\]\}" = "\$0" \] \|\| return 1\n\s+exit 1 ;;/ ? 0 : 1)' "$RELAY_SH" || rc=$?
check "sh guard: structured UTC line on stderr, return 1 when sourced, exit 1 when run" "$rc"

# --- The .sh loads and works on macOS/Linux ----------------------------------
out=$("$BASH_BIN" -c 'source "$1"; rc=$?; type relay_outbound_prompt >/dev/null 2>&1 && d1=yes || d1=no; type _relay_outbound_choice >/dev/null 2>&1 && d2=yes || d2=no; printf "rc=%s defined=%s,%s\n" "$rc" "$d1" "$d2"' _ "$RELAY_SH" 2>"$WORK/src.err")
check "sh sourced: returns 0 and defines both functions" "$([ "$out" = "rc=0 defined=yes,yes" ] && echo 0 || echo 1)" "got: $out"
check "sh sourced: nothing on stderr" "$([ ! -s "$WORK/src.err" ] && echo 0 || echo 1)" "$(head -c 300 "$WORK/src.err")"

# A clean git repo with a committed relay.md and no origin: nothing to report
REPO="$WORK/repo"
mkdir -p "$REPO/.aitools/channel"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.invalid
git -C "$REPO" config user.name t
printf 'relay\n' > "$REPO/.aitools/channel/relay.md"
git -C "$REPO" add .aitools/channel/relay.md
git -C "$REPO" commit -q -m init
rc=0
out=$(env -u CI -u AITOOLS_SKIP_RELAY_PROMPT "$BASH_BIN" "$RELAY_SH" "$REPO" 2>&1 < /dev/null) || rc=$?
check "sh run: clean repo, exit 0" "$rc" "rc=$rc"
check "sh run: clean repo, prints nothing" "$([ -z "$out" ] && echo 0 || echo 1)" "$out"

# An uncommitted relay.md under CI: the one-line hint, return 0
printf 'more\n' >> "$REPO/.aitools/channel/relay.md"
rc=0
out=$(env -u AITOOLS_SKIP_RELAY_PROMPT -u RELAY_PROMPT_FORCE CI=true "$BASH_BIN" "$RELAY_SH" "$REPO" 2>&1 < /dev/null) || rc=$?
check "sh run: dirty relay under CI, exit 0" "$rc" "rc=$rc"
case "$out" in
    *"[RELAY]"*"uncommitted relay"*) rc=0 ;;
    *) rc=1 ;;
esac
check "sh run: dirty relay under CI, [RELAY] hint" "$rc" "$out"
rc=0
out=$(AITOOLS_SKIP_RELAY_PROMPT=1 CI=true "$BASH_BIN" "$RELAY_SH" "$REPO" 2>&1 < /dev/null) || rc=$?
check "sh run: AITOOLS_SKIP_RELAY_PROMPT=1, exit 0 and no output" "$([ "$rc" = 0 ] && [ -z "$out" ] && echo 0 || echo 1)" "rc=$rc out=$out"

# --- The .ps1 refuses macOS/Linux (pwsh) --------------------------------------
if ! command -v pwsh >/dev/null 2>&1; then
    if [ "${CI:-}" = "true" ]; then
        bad "ps1 refuses $(uname -s) (run and dot-sourced)" "pwsh is not on PATH"
    else
        skip "ps1 refuses $(uname -s) (run and dot-sourced)" "pwsh is not on PATH"
    fi
else
    H1="$WORK/home-run"
    mkdir -p "$H1"
    rc=0
    (cd "$WORK" && env HOME="$H1" pwsh -NoProfile -NonInteractive -File "$RELAY_PS1" < /dev/null > "$WORK/ps1.out" 2> "$WORK/ps1.err") || rc=$?
    check "ps1 run on $(uname -s): exit 1" "$([ "$rc" = 1 ] && echo 0 || echo 1)" "rc=$rc"
    check "ps1 run: structured guard line on stderr" \
        "$(grep -Eq '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\] \[relay-outbound-prompt\] \[error\] This script is for Windows\. On macOS/Linux, use relay-outbound-prompt\.sh' "$WORK/ps1.err" && echo 0 || echo 1)" "$(head -c 300 "$WORK/ps1.err")"
    check "ps1 run: nothing on stdout" "$([ ! -s "$WORK/ps1.out" ] && echo 0 || echo 1)" "$(head -c 300 "$WORK/ps1.out")"
    stray=$(cd "$H1" && find . -type f ! -path './.cache/powershell/*' | head -n 5)
    check "ps1 run: writes nothing under HOME but pwsh's cache" "$([ -z "$stray" ] && echo 0 || echo 1)" "$stray"

    # Dot-sourced, `exit 1` ends only the guarded file: the caller goes on with
    # $LASTEXITCODE 1 and neither function defined
    CALLER="$WORK/caller.ps1"
    printf '. "%s"\n"after: lastexit=" + $LASTEXITCODE + " defined=" + [bool](Get-Command Invoke-RelayOutboundPrompt -ErrorAction SilentlyContinue) + "," + [bool](Get-Command Read-RelayOutboundChoice -ErrorAction SilentlyContinue)\nexit 0\n' "$RELAY_PS1" > "$CALLER"
    rc=0
    (cd "$WORK" && env HOME="$H1" pwsh -NoProfile -NonInteractive -File "$CALLER" < /dev/null > "$WORK/caller.out" 2> "$WORK/caller.err") || rc=$?
    got=$(perl -ne 's/\r//; print if /^after: /' "$WORK/caller.out")
    check "ps1 dot-sourced on $(uname -s): \$LASTEXITCODE 1, no function defined" "$([ "$got" = "after: lastexit=1 defined=False,False" ] && echo 0 || echo 1)" "rc=$rc got=$got"
    check "ps1 dot-sourced: structured guard line on stderr" "$(grep -Fq '[relay-outbound-prompt] [error] This script is for Windows' "$WORK/caller.err" && echo 0 || echo 1)" "$(head -c 300 "$WORK/caller.err")"

    # A caller that then calls the prompt under $ErrorActionPreference Stop (as
    # hh.ps1 does) ends with a nonzero exit before its next line
    CALLER2="$WORK/caller-stop.ps1"
    printf '$ErrorActionPreference = "Stop"\n. "%s"\n$null = Invoke-RelayOutboundPrompt -RepoPath "."\n"after the prompt"\nexit 0\n' "$RELAY_PS1" > "$CALLER2"
    rc=0
    (cd "$WORK" && env HOME="$H1" pwsh -NoProfile -NonInteractive -File "$CALLER2" < /dev/null > "$WORK/caller2.out" 2> "$WORK/caller2.err") || rc=$?
    check "ps1 dot-sourced, caller under Stop: nonzero exit" "$([ "$rc" != 0 ] && echo 0 || echo 1)" "rc=$rc"
    check "ps1 dot-sourced, caller under Stop: nothing after the call runs" "$(grep -Fq 'after the prompt' "$WORK/caller2.out" && echo 1 || echo 0)" "$(head -c 300 "$WORK/caller2.out")"
fi

printf -- '---- %d passed, %d failed, %d skipped (%s, bash %s)\n' "$PASS" "$FAIL" "$SKIP" "$(uname -s)" "$BASH_VERSION"
[ "$FAIL" -eq 0 ]
