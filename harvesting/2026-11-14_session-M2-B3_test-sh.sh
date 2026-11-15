#!/usr/bin/env bash
# Functional check of the re-ask loops in relay-outbound-prompt.sh and aliases.sh.
# Sources the REAL files and feeds answers through files on stdin.
set -uo pipefail
wt=/c/Users/jdpal/repos/aitools/.claude/worktrees/menus-reask
sd="$wt/.scratch/session-M2-B3"
# shellcheck source=/dev/null
source "$wt/scripts/relay-outbound-prompt.sh"
# shellcheck source=/dev/null
source "$wt/shared/shell/aliases.sh"

run_relay() { # name, input (printf format)
    printf "$2" > "$sd/in.tmp"
    local rc=0 out
    out=$(_relay_outbound_choice < "$sd/in.tmp") || rc=$?
    printf '=== relay %s: rc=%s\n%s\n' "$1" "$rc" "$out"
}
run_confirm() {
    printf "$2" > "$sd/in.tmp"
    local rc=0 out
    out=$(_aitools_confirm "Overwrite? [y/n] " < "$sd/in.tmp") || rc=$?
    printf '=== confirm %s: rc=%s\n%s\n' "$1" "$rc" "$out"
}

run_relay "empty-then-c" '\nc\n'
run_relay "word-then-Quit" 'foo\n  Quit  \n'
run_relay "s" 'S\n'
run_relay "show" 'show\n'
run_relay "continue-crlf" 'continue\r\n'
run_relay "prefix-no-longer-matches" 'qq\nsx\nc\n'
run_relay "eof-immediate" ''
run_relay "empty-then-eof" '\n'
run_relay "partial-valid-at-eof" 'q'
yes x | head -n 60 > "$sd/in.tmp"
rc=0; out=$(_relay_outbound_choice < "$sd/in.tmp") || rc=$?
printf '=== relay 60-junk: rc=%s hints=%s last=%s\n' "$rc" \
    "$(printf '%s\n' "$out" | grep -c 'please type one of')" "$(printf '%s\n' "$out" | tail -n 1)"

run_confirm "empty-then-y" '\ny\n'
run_confirm "YES" '  YES \n'
run_confirm "maybe-then-no" 'maybe\nno\n'
run_confirm "N" 'N\n'
run_confirm "eof-immediate" ''
run_confirm "empty-then-eof" '\n'
yes x | head -n 60 > "$sd/in.tmp"
rc=0; out=$(_aitools_confirm "Overwrite? [y/n] " < "$sd/in.tmp") || rc=$?
printf '=== confirm 60-junk: rc=%s hints=%s last=%s\n' "$rc" \
    "$(printf '%s\n' "$out" | grep -c 'please type one of')" "$(printf '%s\n' "$out" | tail -n 1)"

# cc end to end with a stub claude, in an empty dir
mkdir -p "$sd/ccdir"
claude() { printf 'STUB claude %s\n' "$*"; }
( cd "$sd/ccdir" || exit 1; printf '\ny\n' | cc --foo )
( cd "$sd/ccdir" || exit 1; printf 'n\n' | cc --bar )
