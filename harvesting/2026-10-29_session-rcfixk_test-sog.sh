#!/usr/bin/env bash
# test-sog.sh -- smoke/violation tests for a standing-order-guard.sh copy
# (hook-rollout.md "Pre-deploy verification"). Usage: test-sog.sh <hook> [bash]
set -uo pipefail
HOOK="$1"
BASH_BIN="${2:-bash}"
H="$(mktemp -d)"
W="$(mktemp -d)"
PASS=0
FAIL=0
LOG="$H/.aitools/logs/standing-order-guard.log"
t() {  # name, command-json-string, want-rc, want-log (yes|no)
    rm -f "$LOG"
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$2" > "$W/in.json"
    ( cd "$W" && HOME="$H" "$BASH_BIN" "$HOOK" < "$W/in.json" > "$W/out" 2> "$W/err" )
    rc=$?
    if [ -f "$LOG" ]; then lg=yes; else lg=no; fi
    if [ "$rc" = "$3" ] && [ "$lg" = "$4" ]; then
        PASS=$((PASS + 1)); printf 'PASS %s (rc=%s log=%s)\n' "$1" "$rc" "$lg"
    else
        FAIL=$((FAIL + 1)); printf 'FAIL %s (rc=%s want %s, log=%s want %s) err=%s\n' "$1" "$rc" "$3" "$lg" "$4" "$(tr '\n' ' ' < "$W/err")"
    fi
}
t "clean: git status" 'git status' 0 no
t "violation: &&" 'git status && git log' 2 no
t "line 1 cat still blocked" 'cat f\\nls' 2 no
t "line 1 sed -n two-line still blocked" 'sed -n 1p f\\nls' 2 no
t "single-line echo redirect blocked" 'echo hi > f' 2 no
t "later sed -i: observe logs, allows" 'ls\\nsed -i s/a/b/ f' 0 yes
t "later rm glob after git: observe logs" 'git status\\nrm -f *.tmp' 0 yes
t "later cat in pipeline: no log" 'ls\\ncat f | grep x' 0 no
t "later awk: observe logs" 'ls -la\\nawk 1 f' 0 yes
t "later printf redirect: observe logs" 'ls\\nprintf x > f' 0 yes
t "two plain lines: no log" 'ls\\nls -la' 0 no
t "three lines, sed on line 3: logs" 'ls\\nls\\nsed s/a/b/ f' 0 yes
t "4 lines still scratch-blocked" 'a\\nb\\nc\\nd' 2 no
if [ -n "${ENFORCE_COPY:-}" ]; then
    HOOK="$ENFORCE_COPY"
    t "MODE_LATER=enforce: later sed -i blocked" 'ls\\nsed -i s/a/b/ f' 2 no
    t "MODE_LATER=enforce: later rm glob after git blocked" 'git status\\nrm -f *.tmp' 2 no
    t "MODE_LATER=enforce: later cat pipeline allowed" 'ls\\ncat f | grep x' 0 no
fi
printf '%s: %d passed, %d failed\n' "$BASH_BIN" "$PASS" "$FAIL"
