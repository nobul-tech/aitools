#!/usr/bin/env bash
# probe-wrapper.sh -- logic probe of read_menu_choice (scratch copy, /dev/tty
# replaced by stderr) with a stub read_tty_choice that reads lines from fd 3.
set -euo pipefail
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$S/../../scripts/aitools-lib.sh"
export AITOOLS_LOG_DIR="$S/probe-logs"; rm -rf "$AITOOLS_LOG_DIR"
source "$LIB"
logging_init probe
perl -pe 's{> /dev/tty}{>&2}g' "$S/wrapper.sh" > "$S/wrapper-probe.tmp"
source "$S/wrapper-probe.tmp"
# Stub: same contract as read_tty_choice (EOF -> log_warn + ""), input from fd 3
read_tty_choice() {
    local __var="$1" __default_desc="$2" __line=""
    if ! IFS= read -r __line <&3; then
        log_warn "No input at prompt (EOF) -- defaulting to $__default_desc"
        __line=""
    fi
    printf -v "$__var" '%s' "$__line"
}
run() {  # name, input (printf format), valid, default
    local name="$1" input="$2" valid="$3" def="$4" ans=""
    printf "$input" > "$S/in.tmp"
    exec 3< "$S/in.tmp"
    read_menu_choice ans "$valid" "$def" "the default" "$name" "  choice: " 2> "$S/err.tmp"
    exec 3<&-
    printf '%-10s -> [%s]  hints=%s\n' "$name" "$ans" "$(grep -c 'please type one of' "$S/err.tmp" || true)"
}
run reask   '\n\nskip\nq\no\n'   "o a m s x" o
run upper   '  S \n'             "o a m s x" o
run eof     ''                   "o a m s x" o
run eofafter '\nfoo\n'           "o s x" o
run yesword 'Yes\n'              "y yes n no" n
run nums    '3\n0\n2\n'          "1 2 n s" s
run crlf    'a\r\n'              "o a s x" o
perl -e 'print "junk\n" x 60' > "$S/in.tmp"; exec 3< "$S/in.tmp"
ans=""; read_menu_choice ans "o s x" o "overwrite" guard "  > " 2> "$S/err.tmp"; exec 3<&-
printf '%-10s -> [%s]  hints=%s\n' guard "$ans" "$(grep -c 'please type one of' "$S/err.tmp" || true)"
echo "--- log ---"
grep -E 'menu answer|No valid|EOF' "$AITOOLS_LOG_DIR/deploy.log" | perl -pe 's/^\[[^]]+\] //'
echo "WARNINGS=$WARNINGS"
