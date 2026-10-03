#!/usr/bin/env bash
# test-logging.sh -- unit tests for the shared logging framework (scripts/aitools-lib.sh)
# and for the bash entry point's use of it (scripts/aitools).
#
# Safe to re-run: every case runs in its own temp HOME / log dir, removed on exit.
# Platform: macOS, Linux, Windows (Git Bash). Exit 1 if any case fails.
# Spec: .claude/rules/script-standards.md (log line format, levels, counters,
# end-of-run summary), reference/logging.md (location, rotation),
# reference/script-standards-detail.md "Logging overrides".
#
# Usage: bash tests/logging/test-logging.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    sed -n '2,12p' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/scripts/aitools-lib.sh"
ENTRY="$ROOT/scripts/aitools"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
ESC=$(printf '\033')
TS_RE='\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\]'

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
    fi
}

# run_lib <case> <snippet>: source the lib in a fresh bash with an isolated log dir.
# Console output -> $C/out, the log -> $C/logs/deploy.log, rc -> $C/rc.
run_lib() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home"
    env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="${SUMMARY:-}" \
        bash -c "set -uo pipefail; source '$LIB'; logging_init t; $2" > "$C/out" 2>&1
    echo $? > "$C/rc"
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || : > "$LOG"
}

# ---------------------------------------------------------------------------
# aitools-lib.sh
# ---------------------------------------------------------------------------

run_lib format 'log "hello world"'
check "lib: log line format [ts] [script] [level] message" \
    "grep -Eq '^${TS_RE} \[t\] \[info\] hello world\$' '$LOG'"
check "lib: log file is AITOOLS_LOG_DIR/deploy.log" "[ -s '$C/logs/deploy.log' ]"

run_lib levels 'log_ok a; log_warn b; log_error c; log d info'
check "lib: levels ok/warn/error/info recorded" \
    "grep -q '\[ok\] a' '$LOG' && grep -q '\[warn\] b' '$LOG' && grep -q '\[error\] c' '$LOG' && grep -q '\[info\] d' '$LOG'"
check "lib: log file has no ANSI codes" "! grep -q '$ESC' '$LOG'"
check "lib: warn is yellow on the console" "grep -q '${ESC}\[33m.*\[warn\] b' '$C/out'"
check "lib: error is red on the console" "grep -q '${ESC}\[31m.*\[error\] c' '$C/out'"
check "lib: info is plain on the console" "grep -Eq '^${TS_RE} \[t\] \[info\] d\$' '$C/out'"

run_lib detail 'log_detail "secret diff line"'
check "lib: log_detail writes the log" "grep -q '\[detail\] secret diff line' '$LOG'"
check "lib: log_detail stays off the console" "! grep -q 'secret diff line' '$C/out'"

run_lib counters 'log_error x; log_error y; log_warn z; echo "COUNTS=$ERRORS/$WARNINGS"'
check "lib: log_error/log_warn increment ERRORS/WARNINGS" "grep -q 'COUNTS=2/1' '$C/out'"

run_lib reset 'log_error x; logging_init t2; echo "COUNTS=$ERRORS/$WARNINGS"'
check "lib: logging_init resets the counters" "grep -q 'COUNTS=0/0' '$C/out'"

SUMMARY="" run_lib nosummary 'write_summary ERROR tool detail; echo "RC=$?"'
check "lib: write_summary is a no-op without AITOOLS_SUMMARY_FILE" "grep -q 'RC=0' '$C/out'"

SUMMARY="$TMP_ROOT/summary.txt" run_lib summary 'write_summary ERROR tool "it failed"; write_summary OK tool2 v1'
check "lib: write_summary writes CAT|tool|detail" "grep -qx 'ERROR|tool|it failed' '$TMP_ROOT/summary.txt'"
check "lib: write_summary OK stays OK with no warnings" "grep -qx 'OK|tool2|v1' '$TMP_ROOT/summary.txt'"

SUMMARY="$TMP_ROOT/summary2.txt" run_lib promote 'log_warn w; write_summary OK tool v1'
check "lib: write_summary promotes OK to WARN after a warning" "grep -qx 'WARN|tool|v1' '$TMP_ROOT/summary2.txt'"

C="$TMP_ROOT/rotate"; mkdir -p "$C/logs"
head -c 5242880 /dev/zero | tr '\0' 'x' > "$C/logs/deploy.log"
# Console output is irrelevant here; the check below inspects the rotated files.
env HOME="$C" AITOOLS_LOG_DIR="$C/logs" bash -c "source '$LIB'; logging_init t; log after" > /dev/null 2>&1
check "lib: logging_init rotates a 5 MB log to deploy.log.1" \
    "[ -f '$C/logs/deploy.log.1' ] && grep -q '\[info\] after' '$C/logs/deploy.log' && [ \$(wc -c < '$C/logs/deploy.log') -lt 1000 ]"

# ---------------------------------------------------------------------------
# scripts/aitools (entry point) -- uses the lib's logging, defines none of its own
# ---------------------------------------------------------------------------

check "entry: defines no log functions (uses aitools-lib)" \
    "! grep -Eq '^[[:space:]]*(log|log_ok|log_warn|log_error|log_detail)\(\)' '$ENTRY'"

# fake_repo <case> [with-lib]: HOME with config.json -> a repo dir holding the lib.
fake_repo() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home/.aitools" "$C/repo/.git" "$C/repo/scripts"
    if [ "${2:-}" = "with-lib" ]; then cp "$LIB" "$C/repo/scripts/"; fi
    printf '{"version":2,"repoPath":"%s"}\n' "$C/repo" > "$C/home/.aitools/config.json"
}
run_entry() {  # args... (uses $C from fake_repo)
    env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" bash "$ENTRY" "$@" < /dev/null > "$C/out" 2> "$C/err"
    echo $? > "$C/rc"
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || { mkdir -p "$C/logs"; : > "$LOG"; }
}

fake_repo unknown with-lib
run_entry --bogus-flag
check "entry: unknown argument exits 1" "[ \"\$(cat '$C/rc')\" = 1 ]"
check "entry: unknown argument written to deploy.log" \
    "grep -Eq '^${TS_RE} \[aitools\] \[error\] unknown argument .--bogus-flag.' '$LOG'"
check "entry: unknown argument shown in the lib's console format (not a bare 'error:')" \
    "grep -Eq '${TS_RE} \[aitools\] \[error\] unknown argument' '$C/out' && ! grep -q '^error: unknown argument' '$C/err'"

fake_repo prelib with-lib
mkdir -p "$C/home/.config/ai-tooling"
run_entry --bogus-flag
check "entry: warnings found before the lib loads are logged after it loads" \
    "grep -q '\[aitools\] \[warn\] both .*ai-tooling.* exist' '$LOG'"

fake_repo nolib
run_entry --bogus-flag
check "entry: missing aitools-lib exits 1" "[ \"\$(cat '$C/rc')\" = 1 ]"
check "entry: missing aitools-lib names the path on stderr" "grep -q 'aitools-lib.sh not found at $C/repo/scripts' '$C/err'"

fake_repo version
rm -rf "$C/repo"
run_entry --version
check "entry: --version answers without the repo" \
    "[ \"\$(cat '$C/rc')\" = 0 ] && grep -q '^aitools ' '$C/out' && grep -q 'repo: not found' '$C/out'"

printf -- '---- %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
