#!/usr/bin/env bash
# test-cli.sh -- CLI tests for scripts/build-package.sh (v1.0 scaffolding)
#
# Runs build-package.sh from this repo under an isolated HOME, log directory,
# summary file and --out, all in a temp directory removed on exit. The real
# HOME is never touched; nothing is staged or built (the build steps are stubs).
# Cases: --help, unknown option, bad and missing --version, bad --ref,
# all --dry-run (n/a rows for the kinds this host cannot build, a plan for the
# kind it can, nothing written to --out), AITOOLS_DRY_RUN=1, an explicit kind
# this host cannot build, stage without --dry-run (not-implemented ERROR), and
# a standalone run whose own panel shows every per-step row (tool names
# "build <step>", one per step: show_summary keeps one row per tool name).
# Exit codes asserted: 0 or 1, never 2 (2 means a user abort, D-TS13).
# Bash: $TEST_BASH (default: bash on PATH; e.g. TEST_BASH=/bin/bash for 3.2).
# Platform: macOS, Linux, Windows Git Bash. Exit 1 if any case fails.
#
# Usage: bash tests/build-package/test-cli.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'next if $. == 1; last unless /^#/; print' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/build-package.sh"
BASH_BIN="${TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "${C:-}" ] && [ -f "$C/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/out" | tail -n 30
        fi
    fi
}

# run_bp NAME ARGS...: run build-package.sh in case directory $C (rc, out, summary, log).
run_bp() {
    C="$TMP_ROOT/$1"; shift
    mkdir -p "$C/home"
    : > "$C/summary"
    env -u AITOOLS_DRY_RUN -u AITOOLS_FORCE -u AITOOLS_ENVIRONMENT HOME="$C/home" \
        AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" ${EXTRA_ENV:-} \
        "$BASH_BIN" "$SCRIPT" "$@" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || : > "$LOG"
}

rc() { cat "$C/rc"; }
row() { grep -qxF "$1" "$C/summary"; }      # exact summary row
has_out() { grep -qF -- "$1" "$C/out"; }    # console substring
has_log() { grep -qF -- "$1" "$LOG"; }      # log substring

case "$(uname -s)" in
    Darwin*)              HOST=macos;   NATIVE=pkg ;;
    Linux*)               HOST=linux;   NATIVE=deb ;;
    MINGW*|MSYS*|CYGWIN*) HOST=windows; NATIVE=intune ;;
    *)                    HOST=unknown; NATIVE="" ;;
esac
printf 'host: %s (native kind: %s), bash: %s\n' "$HOST" "${NATIVE:-none}" "$("$BASH_BIN" -c 'echo $BASH_VERSION')"

# --- --help ---
run_bp help --help
check "--help exits 0" '[ "$(rc)" = 0 ]'
check "--help prints the usage" 'has_out "Usage: build-package.sh <command> [options]"'
check "--help writes no summary row" '[ ! -s "$C/summary" ]'

# --- unknown option ---
run_bp unknown all --version 1.2.3 --bogus
check "unknown option exits 1" '[ "$(rc)" = 1 ]'
check "unknown option is logged as an error" 'has_log "[error] Unknown option: --bogus"'
check "unknown option prints the usage" 'has_out "Usage: build-package.sh"'
check "unknown option: ERROR row" 'row "ERROR|build-package|bad arguments"'
# (argument errors use "build-package"; every step row is "build <step>")

# --- bad / missing --version ---
run_bp badver pkg --version 1.2
check "--version 1.2 exits 1" '[ "$(rc)" = 1 ]'
check "--version 1.2 is reported" 'has_log "--version '"'"'1.2'"'"' is not X.Y.Z"'
run_bp vprefix deb --version v1.2.3
check "--version v1.2.3 exits 1" '[ "$(rc)" = 1 ]'
run_bp nover intune --dry-run
check "missing --version for intune exits 1" '[ "$(rc)" = 1 ]'
check "missing --version is reported" 'has_log "--version <X.Y.Z> is required for '"'"'intune'"'"'"'

# --- bad --ref ---
run_bp badref stage --dry-run --ref no-such-ref-xyz
check "bad --ref exits 1" '[ "$(rc)" = 1 ]'
check "bad --ref is reported" 'has_log "--ref '"'"'no-such-ref-xyz'"'"' is not a commit"'

# --- no command ---
run_bp nocmd --dry-run
check "no command exits 1" '[ "$(rc)" = 1 ]'

# --- all --dry-run ---
run_bp alldry all --dry-run --version 1.2.3 --out "$TMP_ROOT/alldry/outdir"
check "all --dry-run exits 0" '[ "$(rc)" = 0 ]'
check "all --dry-run: no ERROR row" '! grep -q "^ERROR|" "$C/summary"'
check "all --dry-run: stage plan logged" 'has_log "[DRY RUN] stage: 2. git archive"'
check "all --dry-run: dry-run row" 'grep -q "^OK|build dry-run|stage" "$C/summary"'
check "all --dry-run: --out not created" '[ ! -e "$TMP_ROOT/alldry/outdir" ]'
for kind in pkg intune deb; do
    if [ "$kind" = "$NATIVE" ]; then
        # Native kind: a plan when the tool is present, else an n/a row.
        check "all --dry-run: $kind planned or n/a" \
            'has_log "[DRY RUN] $kind: 1." || row "OK|build $kind|n/a ($HOST)"'
    else
        check "all --dry-run: $kind n/a ($HOST)" 'row "OK|build $kind|n/a ($HOST)"'
    fi
done

# --- standalone panel: every per-step row is shown (show_summary keeps one row per tool name) ---
# No AITOOLS_SUMMARY_FILE from the caller, so the script renders its own panel.
C="$TMP_ROOT/panel"; mkdir -p "$C/home"
env -u AITOOLS_DRY_RUN -u AITOOLS_FORCE -u AITOOLS_ENVIRONMENT -u AITOOLS_SUMMARY_FILE HOME="$C/home" \
    AITOOLS_LOG_DIR="$C/logs" "$BASH_BIN" "$SCRIPT" all --dry-run --version 1.2.3 < /dev/null > "$C/out" 2>&1
echo $? > "$C/rc"
perl -pe 's/\e\[[0-9;]*m//g' "$C/out" > "$C/panel"
in_panel() { grep -qE -- "^ +\[ok\] +$1 +$2\$" "$C/panel"; }   # TOOL DETAIL-REGEX
check "standalone panel exits 0" '[ "$(rc)" = 0 ]'
check "standalone panel: dry-run row" 'in_panel "build dry-run" "stage.*"'
for kind in pkg intune deb; do
    if [ "$kind" != "$NATIVE" ]; then
        check "standalone panel: $kind n/a row" 'in_panel "build $kind" "n/a \\($HOST\\)"'
    fi
done

# --- AITOOLS_DRY_RUN=1 equals --dry-run ---
EXTRA_ENV="AITOOLS_DRY_RUN=1" run_bp envdry stage
check "AITOOLS_DRY_RUN=1 stage exits 0" '[ "$(rc)" = 0 ]'
check "AITOOLS_DRY_RUN=1 logs the plan" 'has_log "[DRY RUN] stage: 1."'

# --- explicit kind this host cannot build ---
case "$HOST" in
    macos)   FOREIGN=deb ;;
    *)       FOREIGN=pkg ;;
esac
run_bp foreign "$FOREIGN" --dry-run --version 1.2.3
check "$FOREIGN on $HOST exits 1" '[ "$(rc)" = 1 ]'
check "$FOREIGN on $HOST: ERROR row" 'row "ERROR|build $FOREIGN|cannot build ($HOST)"'

# --- stage without --dry-run: not implemented ---
run_bp stage stage --out "$TMP_ROOT/stage/outdir"
check "stage exits 1" '[ "$(rc)" = 1 ]'
check "stage: not-implemented error logged" 'has_log "[error] stage: not implemented in v1.0 scaffolding (batch B2"'
check "stage: ERROR row" 'row "ERROR|build stage|not implemented"'
check "stage: --out not created" '[ ! -e "$TMP_ROOT/stage/outdir" ]'

# --- never exit 2 ---
NEVER2=true
for d in "$TMP_ROOT"/*/; do
    if [ -f "$d/rc" ] && [ "$(cat "$d/rc")" = 2 ]; then NEVER2=false; fi
done
C=""
check "no case exited 2" '$NEVER2'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
