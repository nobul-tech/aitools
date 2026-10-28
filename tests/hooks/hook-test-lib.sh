#!/usr/bin/env bash
# hook-test-lib.sh -- shared helpers for tests/hooks/test-*.sh (sourced, not run).
#
# Provides: REPO, HOOKS, WORK (temp dir, removed on exit), TEST_HOME (an
# isolated HOME under WORK), NOGIT (a cwd that is not a git repo, so hooks
# write no telemetry into a real session dir), BASH_BIN (AITOOLS_TEST_BASH,
# default bash), PYBIN (python3 or python with json + sqlite3, "" if none),
# ok / bad / skip counters, run_hook, json_ctx, finish_tests.
# Hooks always run with HOME=TEST_HOME: they write ~/.aitools/logs and
# ~/.claude/hooks/logs, which must never be the real ones.
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS="$REPO/shared/hooks"
WORK="$(mktemp -d)"
_hook_test_cleanup() { cd / && rm -rf "$WORK"; }
trap _hook_test_cleanup EXIT
TEST_HOME="$WORK/home"
NOGIT="$WORK/nogit"
mkdir -p "$TEST_HOME" "$NOGIT"
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"

# Same interpreter choice as the hooks: python3, else python. A python that
# cannot import json + sqlite3 (e.g. the Windows Store alias) counts as none.
PYBIN=""
for _py in python3 python; do
    if command -v "$_py" >/dev/null 2>&1; then
        if "$_py" -c "import json, sqlite3" >/dev/null 2>&1; then
            PYBIN="$_py"
        fi
        break
    fi
done

PASS=0
FAIL=0
SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  {  # on failure, also show the last hook run's exit code and output
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$1"
    printf '       last run: rc=%s stdout=%.300s\n' "$RC" "$OUT"
    printf '       stderr=%.300s\n' "$ERR"
}
skip() { SKIP=$((SKIP + 1)); printf '  skip %s\n' "$1"; }
check() {  # check <description> <command...>: ok if the command succeeds
    local d="$1"
    shift
    if "$@"; then ok "$d"; else bad "$d"; fi
}

OUT=""
ERR=""
RC=0
# run_hook <hook file> <payload file> <cwd> [VAR=value ...]
#   -> RC (exit code), OUT (stdout), ERR (stderr). HOME is TEST_HOME unless
#   a HOME=... assignment is passed.
run_hook() {
    local hook="$1" payload="$2" dir="$3"
    shift 3
    RC=0
    (cd "$dir" && env HOME="$TEST_HOME" "$@" "$BASH_BIN" "$hook" \
        < "$payload" > "$WORK/out.txt" 2> "$WORK/err.txt") || RC=$?
    OUT="$(cat "$WORK/out.txt")"
    ERR="$(cat "$WORK/err.txt")"
}

# json_ctx <event>: OUT must be exactly one JSON object whose
# hookSpecificOutput.hookEventName is <event>. Writes additionalContext (or
# permissionDecisionReason when there is no additionalContext) to
# $WORK/ctx.txt. Returns 0 on success, 1 on failure, 2 when no JSON parser
# is available (the caller skips).
json_ctx() {
    local event="$1"
    if [ -n "$PYBIN" ]; then
        printf '%s' "$OUT" | "$PYBIN" -c '
import json, sys
event = sys.argv[1]
try:
    obj = json.loads(sys.stdin.read())
except ValueError:
    sys.exit(1)
if not isinstance(obj, dict):
    sys.exit(1)
h = obj.get("hookSpecificOutput")
if not isinstance(h, dict) or h.get("hookEventName") != event:
    sys.exit(1)
v = h.get("additionalContext", h.get("permissionDecisionReason", ""))
sys.stdout.write(v if isinstance(v, str) else "")
' "$event" > "$WORK/ctx.txt"
        return $?
    fi
    if perl -MJSON::PP -e 1 >/dev/null 2>&1; then
        printf '%s' "$OUT" | perl -MJSON::PP -0777 -e '
            my $j = eval { JSON::PP->new->utf8(0)->decode(<STDIN>) } or exit 1;
            ref $j eq "HASH" or exit 1;
            my $h = $j->{hookSpecificOutput} or exit 1;
            exit 1 unless ($h->{hookEventName} // "") eq $ARGV[0];
            print $h->{additionalContext} // $h->{permissionDecisionReason} // "";
        ' "$event" > "$WORK/ctx.txt"
        return $?
    fi
    return 2
}

# ctx_is <event> <expected text>: json_ctx passes and the context equals the text
ctx_is() {
    local rc=0
    json_ctx "$1" || rc=$?
    if [ "$rc" -eq 2 ]; then
        return 0  # no JSON parser on this machine: covered by other platforms
    fi
    [ "$rc" -eq 0 ] && [ "$(cat "$WORK/ctx.txt")" = "$2" ]
}

# ctx_has <event> <substring>: json_ctx passes and the context contains it
ctx_has() {
    local rc=0
    json_ctx "$1" || rc=$?
    if [ "$rc" -eq 2 ]; then
        return 0
    fi
    [ "$rc" -eq 0 ] && case "$(cat "$WORK/ctx.txt")" in *"$2"*) true ;; *) false ;; esac
}

# native_path <path>: the path as Claude Code would send it in a payload.
# On Windows Git Bash that is a Windows path (mixed form C:/..., JSON-safe):
# a native program such as Windows Python cannot open an MSYS /tmp/... path.
native_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        printf '%s' "$1"
    fi
}

contains() { case "$1" in *"$2"*) true ;; *) false ;; esac; }
quiet0() { [ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ -z "$ERR" ]; }  # exit 0, no output

finish_tests() {
    printf '\n%s: %d passed, %d failed, %d skipped (bash: %s)\n' \
        "$1" "$PASS" "$FAIL" "$SKIP" "$("$BASH_BIN" -c 'echo $BASH_VERSION')"
    [ "$FAIL" -eq 0 ]
}
