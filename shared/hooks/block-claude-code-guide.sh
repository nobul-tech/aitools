#!/usr/bin/env bash
# block-claude-code-guide.sh — Claude Code PreToolUse hook
# Blocks the built-in claude-code-guide subagent (Haiku model) and
# injects corrective harness context so the agent can proceed with
# accurate information without needing the subagent.
#
# Hook contract:
#   - Fires on PreToolUse for the Agent tool
#   - Receives JSON on stdin (tool_input.subagent_type, etc.)
#   - Exit 0 with no output = allow (all other agent types)
#   - Exit 0 with JSON stdout = deny with corrective context
#
# See: https://github.com/anthropics/claude-code/issues/34730

set -euo pipefail

INPUT=$(cat)

# Extract subagent_type from tool_input using bash regex (no jq dependency)
SUBAGENT_TYPE=""
pattern='"subagent_type"[[:space:]]*:[[:space:]]*"([^"]*)"'
if [[ "$INPUT" =~ $pattern ]]; then
    SUBAGENT_TYPE="${BASH_REMATCH[1]}"
fi

if [ "$SUBAGENT_TYPE" = "claude-code-guide" ]; then
    # Return JSON deny with corrective context.
    # permissionDecisionReason is shown to Claude (not the user) on deny,
    # so it serves as injected harness knowledge.
    cat <<'HOOKJSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "claude-code-guide subagent is DENIED. It is a Haiku-based built-in that returns inaccurate schema information — it caused a production incident where all hooks were disabled (issue #34730). DO NOT retry this call.\n\nFor Claude Code documentation (hooks, settings, permissions, subagents, MCP), use the chrome-devtools skill to navigate to the .md pages at code.claude.com/docs/en/*.md and read the rendered content. Key pages:\n  - Hooks: code.claude.com/docs/en/hooks.md\n  - Permissions: code.claude.com/docs/en/permissions.md\n  - Sub-agents: code.claude.com/docs/en/sub-agents.md\n  - Settings: code.claude.com/docs/en/settings.md\n  - MCP: code.claude.com/docs/en/mcp.md\n\nQuick reference — hook type schemas:\n  type: \"command\" requires: command (string, shell command to execute)\n  type: \"prompt\"  requires: prompt (string, static LLM prompt text)\n  type: \"http\"    requires: url (string, endpoint URL)\n  type: \"agent\"   requires: prompt (string, task for subagent)\n\nNever mix these — a command-type hook with a prompt field or a prompt-type hook with a command field will break settings.json validation and disable ALL hooks."
  }
}
HOOKJSON
    exit 0
fi

exit 0
