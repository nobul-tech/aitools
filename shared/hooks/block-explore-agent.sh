#!/usr/bin/env bash
# block-explore-agent.sh — Claude Code PreToolUse hook
# Blocks operator-disabled subagent types (Explore) and redirects to
# general-purpose. Mirrors block-claude-code-guide.sh.
#
# Hook contract:
#   - Fires on PreToolUse for the Agent tool
#   - Receives JSON on stdin (tool_input.subagent_type, etc.)
#   - Exit 0 with no output = allow (all non-blocked agent types)
#   - Exit 0 with JSON stdout = deny with corrective context
#
# Operator policy: research/search delegation goes through general-purpose, not
# the built-in Explore agent. Extend BLOCKED_TYPES (space-separated) to disable
# more agent types.

set -euo pipefail

# --- Blocked subagent types (operator policy; space-separated, exact match) ---
BLOCKED_TYPES="Explore"

# --- Telemetry: JSONL event emission ---
_SESSION_DIR=""
_cs_file="$(git rev-parse --show-toplevel 2>/dev/null || echo "")/.scratch/.current-session"
if [ -f "$_cs_file" ]; then
    _SESSION_DIR=$(cat "$_cs_file" 2>/dev/null || true)
fi

emit_hook_event() {
    local event_type="$1" detail_json="$2"
    [ -n "$_SESSION_DIR" ] || return 0
    printf '{"t":"%s","type":"%s","src":"bea","d":%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$event_type" "$detail_json" \
        >> "$_SESSION_DIR/events.jsonl" 2>/dev/null || true
}

INPUT=$(cat)

# Extract subagent_type from tool_input using bash regex (no jq dependency)
SUBAGENT_TYPE=""
pattern='"subagent_type"[[:space:]]*:[[:space:]]*"([^"]*)"'
if [[ "$INPUT" =~ $pattern ]]; then
    SUBAGENT_TYPE="${BASH_REMATCH[1]}"
fi

# Deny if the requested type is on the blocklist (exact match).
for blocked in $BLOCKED_TYPES; do
    if [ "$SUBAGENT_TYPE" = "$blocked" ]; then
        emit_hook_event "hook_block" "{\"blocked\":\"$SUBAGENT_TYPE\"}"
        # permissionDecisionReason is shown to Claude (not the user) on deny,
        # so it doubles as the corrective redirect.
        cat <<HOOKJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "The '$SUBAGENT_TYPE' subagent is DISABLED in this harness by operator policy. Use subagent_type 'general-purpose' instead for read-only research, search, and multi-file exploration. DO NOT retry this call with '$SUBAGENT_TYPE'."
  }
}
HOOKJSON
        exit 0
    fi
done

exit 0
