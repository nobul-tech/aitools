#!/usr/bin/env bash
# glossary-skill-guard.sh — Detection layer for governed data access
# Fires on Read/Grep of glossary files, reminds agent to use /glossary skill
# Part of the governed data access framework.
# See reference/framework-governed-data-access.md
#
# Hook contract:
#   - PreToolUse hook, matcher: Read|Grep
#   - Never blocks: exit 0 always
#   - Glossary target: stdout {"hookSpecificOutput":{"hookEventName":
#     "PreToolUse","additionalContext":"..."}} (reaches Claude next to the
#     tool result); any other target: no output
# Platform: macOS + Linux + Windows Git Bash (bash 3.2 compatible)

set -euo pipefail

# --- Telemetry: JSONL event emission ---
_SESSION_DIR=""
_cs_file="$(git rev-parse --show-toplevel 2>/dev/null || echo "")/.scratch/.current-session"
if [ -f "$_cs_file" ]; then
    _SESSION_DIR=$(cat "$_cs_file" 2>/dev/null || true)
fi

emit_hook_event() {
    local event_type="$1" detail_json="$2"
    [ -n "$_SESSION_DIR" ] || return 0
    printf '{"t":"%s","type":"%s","src":"gsg","d":%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$event_type" "$detail_json" \
        >> "$_SESSION_DIR/events.jsonl" 2>/dev/null || true
}

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | perl -ne 'print $1 if /"file_path"\s*:\s*"([^"]*)"/')
PATTERN_PATH=$(echo "$INPUT" | perl -ne 'print $1 if /"path"\s*:\s*"([^"]*)"/')

TARGET="${FILE_PATH:-$PATTERN_PATH}"

case "$TARGET" in
    *glossary.json|*glossary.md)
        emit_hook_event "hook_warn" "{\"target\":\"$(basename "$TARGET")\"}"
        # hookSpecificOutput JSON goes to stdout (structured hook response).
        # hookEventName is required: without it Claude Code rejects the JSON
        # ("hookSpecificOutput is missing required field hookEventName", a
        # non-blocking error) and the reminder never reaches Claude -- all 7
        # transcript records of this hook up to 2026-10-28 were that error.
        echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"You are reading glossary files directly. Use /glossary skill instead — it provides the governed process for checking definitions, adding terms, and resolving ambiguities. Reading the file bypasses that process."}}'
        ;;
esac
exit 0
