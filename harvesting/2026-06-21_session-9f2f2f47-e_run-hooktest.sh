#!/usr/bin/env bash
# Throwaway test runner for standing-order-guard.sh after fixes.
set -uo pipefail
HOOK="/Users/new-jose/repos/aitools/shared/hooks/standing-order-guard.sh"
DIR="/Users/new-jose/repos/aitools/.scratch/session-9f2f2f47-e"

run() {  # label  expected_exit  json_file
    local label="$1" want="$2" file="$3" out rc
    out="$(bash "$HOOK" < "$DIR/$file" 2>&1)"; rc=$?
    if [ "$rc" = "$want" ]; then echo "PASS [$label] exit=$rc"; else echo "FAIL [$label] exit=$rc want=$want :: $out"; fi
}

# --- inline JSON fixtures written on the fly ---
printf '%s\n' '{"tool_name":"Bash","tool_input":{"command":"git status"}}'        > "$DIR/f-clean.json"
printf '%s\n' '{"tool_name":"Bash","tool_input":{"command":"echo hi | wc -l"}}'   > "$DIR/f-pipe.json"
printf '%s\n' '{"tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ x.txt"}}' > "$DIR/f-sed.json"
printf '%s\n' '{"tool_name":"Bash","tool_input":{"command":"echo data > out.txt"}}'  > "$DIR/f-redir.json"

echo "=== THE REPORTED BUG: multi-line with quotes ==="
run "ml-quotes (block:scratch)"   2 ml-quotes.json
run "ml-noquotes (block:scratch)" 2 ml-noquotes.json

echo "=== no new false positives ==="
run "git -m with && in quotes (allow)" 0 ml-gitquotes.json
run "clean git status (allow)"         0 f-clean.json
run "pipeline (allow)"                 0 f-pipe.json

echo "=== resurrected dead-code checks ==="
run "sed (block)"            2 f-sed.json
run "echo redirect (block)"  2 f-redir.json
