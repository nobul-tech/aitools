#!/usr/bin/env bash
# standing-order-guard.sh — Claude Code PreToolUse hook
# Enforces standing orders by inspecting tool calls before execution.
#
# Currently enforces:
#   SO #1: Dedicated tools for file ops (Read/Edit/Write/Grep/Glob, not Bash)
#   SO #4: Scratch files for complex bash (no long inline commands)
#
# Hook contract:
#   - Receives JSON on stdin (tool_name, tool_input.command, etc.)
#   - Exit 0 = allow
#   - Exit 2 = block (stderr becomes Claude's feedback)
#   - Must never crash or hang (would break Claude Code)
#
# Rollout mode:
#   MODE="observe"  — log what would be blocked, always exit 0
#   MODE="enforce"  — block violations (exit 2)
#   See .claude/rules/hook-rollout.md for the observe-then-enforce practice.
#
# Design decisions:
#   - Pure-bash JSON parsing (jq not guaranteed in hook environment)
#   - Conservative matching: only flag clear violations, allow ambiguous cases
#   - Helpful feedback: tell Claude which tool to use instead
#   - Pipeline exemption: cat/head/tail in pipelines (cmd | ...) are allowed
#     because the Read tool cannot pipe output into other commands

set -euo pipefail

# --- Mode and logging ---
MODE="observe"  # observe = log only, enforce = block

LOG_DIR="$HOME/.claude/hooks/logs"
LOG_FILE="$LOG_DIR/standing-order-guard.log"

# violation() — dispatch based on MODE
# In enforce mode: write message to stderr, exit 2 (block)
# In observe mode: append to log file, exit 0 (allow)
violation() {
    local message="$1"
    if [ "$MODE" = "enforce" ]; then
        echo "$message" >&2
        exit 2
    else
        mkdir -p "$LOG_DIR"
        printf '%s [WOULD-BLOCK] %s | cmd: %s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$message" "$COMMAND" \
            >> "$LOG_FILE"
        exit 0
    fi
}

INPUT=$(cat)

# --- Pure-bash JSON field extraction ---
# Same pattern as session-archive.sh. Handles simple top-level string values.
json_field() {
    local json="$1" key="$2"
    printf '%s' "$json" \
        | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -1 \
        | sed 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"//' \
        | sed 's/"$//'
}

# Extract tool_input.command — it's nested, so we need the command field
# from within tool_input. Since our JSON parser is simple, we can grep for
# the "command" key directly (it appears at the tool_input level).
COMMAND=$(json_field "$INPUT" "command")

# If no command found (shouldn't happen for Bash tool), allow
if [ -z "$COMMAND" ]; then
    exit 0
fi

# --- SO #4: Scratch files for complex bash ---
# In JSON, newlines in strings are escaped as \n (literal two-char sequence).
# Count occurrences by measuring string length before/after removing \n sequences.
# This avoids grep exit-code issues with set -euo pipefail when no matches exist.
STRIPPED=$(printf '%s' "$COMMAND" | sed 's/\\n//g')
CMD_LEN=${#COMMAND}
STRIPPED_LEN=${#STRIPPED}
NEWLINE_COUNT=$(( (CMD_LEN - STRIPPED_LEN) / 2 ))
# 5+ lines (4+ newlines) = too complex for inline. Write a temp file instead.
if [ "$NEWLINE_COUNT" -ge 4 ]; then
    LINE_COUNT=$((NEWLINE_COUNT + 1))
    violation "SO #4 violation: This command is ~${LINE_COUNT} lines long. Write it to a temp .sh or .ps1 file using the Write tool, execute with Bash, then clean up. Standing order: never inline long commands in the Bash tool."
fi

# --- SO #1: Dedicated tools for file operations ---
# Pattern: command starts with a file-op utility that has a dedicated tool.
# We check the first token of the command (before any arguments).
FIRST_TOKEN=$(printf '%s' "$COMMAND" | head -1 | awk '{print $1}')

# Allowlist: commands that look like file ops but are legitimate shell use.
# pwsh wrapping, git operations, npm/node, etc. are always OK.
case "$FIRST_TOKEN" in
    pwsh|powershell|git|npm|node|python*|pip*|cargo|rustup|brew|winget|choco)
        exit 0
        ;;
esac

# Check for standalone file-reading commands (should use Read tool)
# Allow in pipelines (cmd | ...) — Read tool can't pipe output into other commands.
case "$FIRST_TOKEN" in
    cat)
        case "$COMMAND" in
            *\|*) ;;  # Pipeline — legitimate shell use
            *) violation "SO #1 violation: Use the Read tool instead of 'cat' to read files. The Read tool provides line numbers and handles large files better." ;;
        esac
        ;;
    head)
        case "$COMMAND" in
            *\|*) ;;
            *) violation "SO #1 violation: Use the Read tool with offset/limit parameters instead of 'head'. Example: Read with limit=20 for the first 20 lines." ;;
        esac
        ;;
    tail)
        case "$COMMAND" in
            *\|*) ;;
            *) violation "SO #1 violation: Use the Read tool with offset parameter instead of 'tail'. Example: Read with offset=100 to start from line 100." ;;
        esac
        ;;
esac

# Check for standalone file-search commands (should use Grep tool)
case "$FIRST_TOKEN" in
    grep|rg|egrep|fgrep)
        violation "SO #1 violation: Use the Grep tool instead of '$FIRST_TOKEN' to search file contents. The Grep tool supports regex, file filtering, and multiple output modes."
        ;;
esac

# Check for file-finding commands (should use Glob tool)
case "$FIRST_TOKEN" in
    find)
        violation "SO #1 violation: Use the Glob tool instead of 'find' to locate files. Example: Glob with pattern '**/*.sh' instead of 'find . -name \"*.sh\"'."
        ;;
    ls)
        # ls is borderline -- block when clearly used to list directory contents
        # for exploration (should use Glob or Bash 'ls' for quick checks).
        # Allow: ls is commonly used for quick verification before mkdir, etc.
        # Decision: allow ls, it's a gray area and commonly used in workflows.
        exit 0
        ;;
esac

# Check for file-editing commands (should use Edit tool)
case "$FIRST_TOKEN" in
    sed)
        violation "SO #1 violation: Use the Edit tool instead of 'sed' to modify files. For non-trivial string manipulation, use Perl (standing order #5)."
        ;;
    awk)
        violation "SO #1 violation: Use the Read tool instead of 'awk' to process files. For string manipulation, use Perl (standing order #5)."
        ;;
esac

# Check for file-writing patterns (should use Write tool)
# These are harder to detect by first token alone. Check the full first line
# for redirection patterns that indicate file creation.
FIRST_LINE=$(printf '%s' "$COMMAND" | head -1)
case "$FIRST_LINE" in
    echo*\>*|printf*\>*)
        # echo/printf redirecting to a file
        violation "SO #1 violation: Use the Write tool instead of echo/printf redirection to create files. The Write tool handles encoding and permissions correctly."
        ;;
esac

# All checks passed — allow the command
exit 0
