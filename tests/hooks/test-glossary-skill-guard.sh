#!/usr/bin/env bash
# test-glossary-skill-guard.sh -- tests for shared/hooks/glossary-skill-guard.sh
# (PreToolUse, matcher Read|Grep; advisory, never blocks).
#
# Covers: Read of glossary.json / glossary.md and Grep with a glossary path
# print one valid JSON object whose hookSpecificOutput has hookEventName
# "PreToolUse" (required by Claude Code; its absence made every reminder a
# non-blocking validation error) and an additionalContext naming /glossary;
# exit 0 and no stderr. Other paths, empty and malformed input: silent, exit 0.
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible. Safe to re-run.
# Usage: bash tests/hooks/test-glossary-skill-guard.sh
#        AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/test-glossary-skill-guard.sh

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook-test-lib.sh"

HOOK="${TEST_HOOK_OVERRIDE:-$HOOKS/glossary-skill-guard.sh}"  # override: run against another copy

COMMON="\"session_id\":\"s1\",\"cwd\":\"$NOGIT\",\"hook_event_name\":\"PreToolUse\""

echo "== glossary targets: reminder reaches Claude =="
for case_ in "Read|file_path|/x/registries/glossary.json" "Read|file_path|/x/reference/glossary.md" "Grep|path|/x/registries/glossary.json"; do
    tool="${case_%%|*}"
    rest="${case_#*|}"
    key="${rest%%|*}"
    target="${rest#*|}"
    printf '{%s,"tool_name":"%s","tool_input":{"%s":"%s","pattern":"term"}}' "$COMMON" "$tool" "$key" "$target" > "$WORK/p.json"
    run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
    check "$tool $target: exit 0" [ "$RC" -eq 0 ]
    check "$tool $target: valid PreToolUse additionalContext naming /glossary" ctx_has PreToolUse "/glossary skill"
    check "$tool $target: no stderr" [ -z "$ERR" ]
done

echo "== other targets and bad input: silent =="
printf '{%s,"tool_name":"Read","tool_input":{"file_path":"/x/registries/tool-ops.json"}}' "$COMMON" > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "other file: exit 0, no output" quiet0
: > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "empty input: exit 0, no output" quiet0
printf '{"tool_input":{"file_path":' > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "malformed input: exit 0, no output" quiet0

finish_tests "test-glossary-skill-guard"
