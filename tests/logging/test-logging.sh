#!/usr/bin/env bash
# test-logging.sh -- unit tests for the shared logging framework (scripts/aitools-lib.sh),
# check-lib.sh's checks.log / checks.jsonl writers, and the bash entry point (scripts/aitools).
#
# Safe to re-run: every case runs in its own temp HOME / log dir, removed on exit.
# Platform: macOS, Linux, Windows (Git Bash). Exit 1 if any case fails.
# Spec: .claude/rules/script-standards.md (log line format, levels, counters,
# end-of-run summary), reference/logging.md (location, rotation, fail-safe writes),
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

# Fail-safe log writes (reference/logging.md section 5): a failed log write is
# swallowed. Under set -euo pipefail the script goes on, the console lines still
# print, the counters still count, and no shell error message appears.
# run_unwritable <case> <log dir>: every log helper, then the counters
run_unwritable() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home"
    env HOME="$C/home" AITOOLS_LOG_DIR="$2" bash -c "set -euo pipefail; source '$LIB'; logging_init t; log info-line; log_detail detail-line; log_warn warn-line; log_error error-line; log_ok ok-line; _ai_log ai-line; echo \"COUNTS=\$ERRORS/\$WARNINGS\"; echo REACHED-END" > "$C/out" 2>&1
    echo $? > "$C/rc"
}
unwritable_checks() {  # <what>
    check "lib: $1 -- set -e run goes on (exit 0)" "[ \"\$(cat '$C/rc')\" = 0 ] && grep -q REACHED-END '$C/out'"
    check "lib: $1 -- console lines still printed" \
        "grep -q '\[info\] info-line' '$C/out' && grep -q '\[warn\] warn-line' '$C/out' && grep -q '\[error\] error-line' '$C/out' && grep -q '\[ok\] ok-line' '$C/out'"
    check "lib: $1 -- log_error/log_warn still count" "grep -q 'COUNTS=1/1' '$C/out'"
    check "lib: $1 -- no shell error, detail and AI lines stay off the console" \
        "! grep -Eq 'Is a directory|Permission denied|cannot create|No such file|detail-line|ai-line' '$C/out'"
}

# deploy.log is a directory (cannot be opened for writing on any platform)
mkdir -p "$TMP_ROOT/logdir-is-dir/logs/deploy.log"
run_unwritable logdir-is-dir "$TMP_ROOT/logdir-is-dir/logs"
unwritable_checks "deploy.log is a directory"

# deploy.log without write permission (root ignores the mode: the write then works,
# and the checks still hold)
mkdir -p "$TMP_ROOT/no-write/logs"; : > "$TMP_ROOT/no-write/logs/deploy.log"
chmod 000 "$TMP_ROOT/no-write/logs/deploy.log"
run_unwritable no-write "$TMP_ROOT/no-write/logs"
chmod 644 "$TMP_ROOT/no-write/logs/deploy.log"
unwritable_checks "deploy.log not writable (chmod 000)"

# The log directory cannot be created (its parent is a file)
: > "$TMP_ROOT/not-a-dir"
run_unwritable no-dir "$TMP_ROOT/not-a-dir/logs"
unwritable_checks "log dir cannot be created"

# ---------------------------------------------------------------------------
# scripts/check-lib.sh -- checks.log / checks.jsonl writers (incident #174)
# ---------------------------------------------------------------------------
# The same fail-safe contract for the check scripts' own log files: under
# set -euo pipefail a checks.log / checks.jsonl that cannot be written (or a log
# dir that cannot be created) ends nothing, every step line still prints and
# every step counter still counts. A writable pair still gets every line.
CHECK_LIB="$ROOT/scripts/check-lib.sh"
# run_checks <case> <log dir>: check_log_init, one step of each kind, print_summary
run_checks() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home"
    env HOME="$C/home" AITOOLS_LOG_DIR="$2" bash -c "set -euo pipefail; source '$CHECK_LIB'; check_log_init probe; step_pass 1 pass-step; step_fail 2 fail-step 'a \"quoted\" detail'; step_warn 3 warn-step; step_skip 4 skip-step; print_summary; echo \"COUNTS=\$PASS_COUNT/\$FAIL_COUNT/\$WARN_COUNT/\$SKIP_COUNT\"; echo REACHED-END" > "$C/out" 2>&1
    echo $? > "$C/rc"
}
check_run_checks() {  # <what>
    check "check-lib: $1 -- set -e run goes on (exit 0)" "[ \"\$(cat '$C/rc')\" = 0 ] && grep -q REACHED-END '$C/out'"
    check "check-lib: $1 -- step lines still printed" \
        "grep -q 'pass-step.*\[PASS\]' '$C/out' && grep -q 'fail-step.*\[FAIL\]' '$C/out' && grep -q 'warn-step.*\[WARN\]' '$C/out' && grep -q 'skip-step.*\[SKIP\]' '$C/out' && grep -q 'SUMMARY: 1 PASS, 1 SKIP, 1 WARN, 1 FAIL' '$C/out'"
    check "check-lib: $1 -- step counters still count" "grep -q 'COUNTS=1/1/1/1' '$C/out'"
    check "check-lib: $1 -- no shell error on the console" \
        "! grep -Eq 'Is a directory|Permission denied|cannot create|Not a directory|No such file' '$C/out'"
}

# Writable: every line reaches checks.log, every checks.jsonl line is one JSON object
run_checks checks-written "$TMP_ROOT/checks-written/logs"
check_run_checks "writable"
check "check-lib: writable -- checks.log has run start, the 4 steps and the summary" \
    "[ \"\$(grep -cE 'RUN START|pass-step|fail-step.*a \"quoted\" detail|warn-step|skip-step|=== SUMMARY: 1 PASS, 1 SKIP, 1 WARN, 1 FAIL' '$TMP_ROOT/checks-written/logs/checks.log')\" = 6 ]"
check "check-lib: writable -- checks.jsonl has 6 records, each valid JSON" \
    "perl -MJSON::PP -ne 'BEGIN { \$n = 0; \$bad = 0 } s/\\r?\\n\\z//; \$n++; \$bad++ unless eval { decode_json(\$_); 1 }; END { exit((\$n == 6 && !\$bad) ? 0 : 1) }' '$TMP_ROOT/checks-written/logs/checks.jsonl'"

# checks.log and checks.jsonl are directories
mkdir -p "$TMP_ROOT/checks-dir/logs/checks.log" "$TMP_ROOT/checks-dir/logs/checks.jsonl"
run_checks checks-dir "$TMP_ROOT/checks-dir/logs"
check_run_checks "checks.log/.jsonl are directories"

# checks.log and checks.jsonl without write permission (root ignores the mode:
# the writes then work, and the checks still hold)
mkdir -p "$TMP_ROOT/checks-nowrite/logs"
: > "$TMP_ROOT/checks-nowrite/logs/checks.log"; : > "$TMP_ROOT/checks-nowrite/logs/checks.jsonl"
chmod 000 "$TMP_ROOT/checks-nowrite/logs/checks.log" "$TMP_ROOT/checks-nowrite/logs/checks.jsonl"
run_checks checks-nowrite "$TMP_ROOT/checks-nowrite/logs"
chmod 644 "$TMP_ROOT/checks-nowrite/logs/checks.log" "$TMP_ROOT/checks-nowrite/logs/checks.jsonl"
check_run_checks "checks.log/.jsonl not writable (chmod 000)"

# The log directory cannot be created (its parent is a file)
: > "$TMP_ROOT/checks-notadir"
run_checks checks-nodir "$TMP_ROOT/checks-notadir/logs"
check_run_checks "log dir cannot be created"

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
