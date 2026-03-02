#!/usr/bin/env bash
# standing-order-guard.sh — Claude Code PreToolUse hook
# Enforces standing orders by inspecting tool calls before execution.
#
# Currently enforces:
#   USO: Dedicated tools for file ops (Read/Edit/Write/Grep/Glob, not Bash)
#   USO: Scratch files for complex scripting (no long inline commands)
#   USO: Simple Bash commands only (no &&, ||, ;, $(...), backticks, globs in rm)
#
# Hook contract:
#   - Receives JSON on stdin (tool_name, tool_input.command, etc.)
#   - Exit 0 = allow
#   - Exit 2 = block (stderr becomes Claude's feedback)
#   - Must never crash or hang (would break Claude Code)
#
# Rollout mode (per-check):
#   MODE_AND="enforce"      — && : zero false positives confirmed, blocking
#   MODE_SUBSHELL="enforce" — $(): zero false positives confirmed, blocking
#   MODE_REST="observe"     — ||, ;, backticks: false positives exist or low sample count
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
MODE_AND="enforce"      # &&  — zero false positives confirmed; blocking
MODE_SUBSHELL="enforce" # $() — zero false positives confirmed; blocking
MODE_REST="observe"     # ||, ;, backticks — false positives or low sample; observe only

LOG_DIR="$HOME/.claude/hooks/logs"
LOG_FILE="$LOG_DIR/standing-order-guard.log"

# Ensure log directory exists once (not per-violation)
if [ "$MODE" = "observe" ]; then
    mkdir -p "$LOG_DIR"
fi

# violation() — dispatch based on per-check mode
# $1: message  $2: mode variable value (enforce or observe; defaults to MODE_REST)
# In enforce mode: write message to stderr, exit 2 (block)
# In observe mode: append to log file, exit 0 (allow)
violation() {
    local message="$1"
    local mode="${2:-$MODE_REST}"
    if [ "$mode" = "enforce" ]; then
        echo "$message" >&2
        exit 2
    else
        printf '%s [WOULD-BLOCK] %s | cmd: %s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$message" "$COMMAND" \
            >> "$LOG_FILE"
        exit 0
    fi
}

INPUT=$(cat)

# --- Pure-bash JSON field extraction ---
# Same pattern as session-archive.sh. Handles simple top-level string values.
# Uses bash regex (zero external process forks) since this is a hot-path hook.
json_field() {
    local json="$1" key="$2"
    local pattern="\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
    if [[ "$json" =~ $pattern ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

# Extract tool_input.command — it's nested, so we need the command field
# from within tool_input. Since our JSON parser is simple, we can grep for
# the "command" key directly (it appears at the tool_input level).
COMMAND=$(json_field "$INPUT" "command")

# If no command found (shouldn't happen for Bash tool), allow
if [ -z "$COMMAND" ]; then
    exit 0
fi

# --- USO: Scratch files for complex scripting ---
# In JSON, newlines in strings are escaped as \n (literal two-char sequence).
# Count occurrences by measuring string length before/after removing \n sequences.
# This avoids grep exit-code issues with set -euo pipefail when no matches exist.
STRIPPED="${COMMAND//\\n/}"
CMD_LEN=${#COMMAND}
STRIPPED_LEN=${#STRIPPED}
NEWLINE_COUNT=$(( (CMD_LEN - STRIPPED_LEN) / 2 ))
# 5+ lines (4+ newlines) = too complex for inline. Write a temp file instead.
if [ "$NEWLINE_COUNT" -ge 4 ]; then
    LINE_COUNT=$((NEWLINE_COUNT + 1))
    violation "USO: Scratch files --: This command is ~${LINE_COUNT} lines long. Write it to a temp .sh or .ps1 file using the Write tool, execute with Bash, then clean up. USO: never inline long commands in the Bash tool."
fi

# --- USO: Simple Bash commands only ---
# Block compound operators and command substitution that trigger permission prompts.
# Pipelines (|) are explicitly OK per the USO.
# Checked before the first-token allowlist because compound commands like
# `git tag && git push` have `git` as first token and would exit early.
# Known gap: $(...) after quoted segments (e.g., git commit -m "$(...)") is
# invisible due to json_field truncation at \". Mitigated by the USO itself
# (use git commit -F) and by CC's permission system (which prompts anyway).
case "$COMMAND" in
    *'&&'*) violation "USO: Simple Bash commands only --: Don't use '&&' to chain commands. Make separate Bash tool calls instead. For git in another repo, use 'git -C /path' instead of 'cd /path && git'." "$MODE_AND" ;;
    *'||'*) violation "USO: Simple Bash commands only --: Don't use '||' to chain commands. Make separate Bash tool calls instead." "$MODE_REST" ;;
    *';'*)
        # Exempt ; inside scripting-language arguments: pwsh -Command '...;...' and perl -e '...;...'
        # The ; is a language-internal statement separator, not a shell command separator.
        case "$COMMAND" in
            pwsh\ *|powershell\ *|'perl -e'*|'perl -E'*) ;;
            *) violation "USO: Simple Bash commands only --: Don't use ';' to chain commands. Make separate Bash tool calls instead." "$MODE_REST" ;;
        esac
        ;;
    *'$('*) violation "USO: Simple Bash commands only --: Don't use '\$(...)' command substitution. For commit messages, write to a temp file with Write and use 'git commit -F'. For other values, compute in a prior step." "$MODE_SUBSHELL" ;;
    *'`'*)  violation "USO: Simple Bash commands only --: Don't use backtick command substitution. For commit messages, write to a temp file with Write and use 'git commit -F'. For other values, compute in a prior step." "$MODE_REST" ;;
esac

# --- USO: Dedicated tools for file operations ---
# Pattern: command starts with a file-op utility that has a dedicated tool.
# We check the first token of the command (before any arguments).
read -r FIRST_TOKEN _ <<< "$COMMAND"

# Allowlist: commands that look like file ops but are legitimate shell use.
# pwsh wrapping, git operations, npm/node, etc. are always OK.
case "$FIRST_TOKEN" in
    pwsh|powershell|git|npm|node|python*|pip*|cargo|rustup|brew|winget|choco)
        exit 0
        ;;
esac

# --- USO: Simple Bash commands only (glob in destructive operations) ---
# Glob patterns in rm can expand unexpectedly. Write a cleanup script instead.
case "$FIRST_TOKEN" in
    rm)
        case "$COMMAND" in
            *'*'*|*'?'*)
                violation "USO: Simple Bash commands only --: Don't use glob patterns (*, ?) with 'rm'. Write a cleanup script listing the specific files, execute it, then clean up the script."
                ;;
        esac
        ;;
esac

# Check for standalone file-reading commands (should use Read tool)
# Allow in pipelines (cmd | ...) — Read tool can't pipe output into other commands.
case "$FIRST_TOKEN" in
    cat)
        case "$COMMAND" in
            *\|*) ;;  # Pipeline — legitimate shell use
            *) violation "USO: Dedicated tools --: Use the Read tool instead of 'cat' to read files. The Read tool provides line numbers and handles large files better." ;;
        esac
        ;;
    head)
        case "$COMMAND" in
            *\|*) ;;
            *) violation "USO: Dedicated tools --: Use the Read tool with offset/limit parameters instead of 'head'. Example: Read with limit=20 for the first 20 lines." ;;
        esac
        ;;
    tail)
        case "$COMMAND" in
            *\|*) ;;
            *) violation "USO: Dedicated tools --: Use the Read tool with offset parameter instead of 'tail'. Example: Read with offset=100 to start from line 100." ;;
        esac
        ;;
esac

# Check for standalone file-search commands (should use Grep tool)
case "$FIRST_TOKEN" in
    grep|rg|egrep|fgrep)
        violation "USO: Dedicated tools --: Use the Grep tool instead of '$FIRST_TOKEN' to search file contents. The Grep tool supports regex, file filtering, and multiple output modes."
        ;;
esac

# Check for file-finding commands (should use Glob tool)
case "$FIRST_TOKEN" in
    find)
        violation "USO: Dedicated tools --: Use the Glob tool instead of 'find' to locate files. Example: Glob with pattern '**/*.sh' instead of 'find . -name \"*.sh\"'."
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
        violation "USO: Dedicated tools --: Use the Edit tool instead of 'sed' to modify files. For non-trivial string manipulation, use Perl (USO: Perl for string manipulation)."
        ;;
    awk)
        violation "USO: Dedicated tools --: Use the Read tool instead of 'awk' to process files. For string manipulation, use Perl (USO: Perl for string manipulation)."
        ;;
esac

# Check for file-writing patterns (should use Write tool)
# These are harder to detect by first token alone. Check the full first line
# for redirection patterns that indicate file creation.
FIRST_LINE=$(printf '%s' "$COMMAND" | head -1)
case "$FIRST_LINE" in
    echo*\>*|printf*\>*)
        # echo/printf redirecting to a file
        violation "USO: Dedicated tools --: Use the Write tool instead of echo/printf redirection to create files. The Write tool handles encoding and permissions correctly."
        ;;
esac

# All checks passed — allow the command
exit 0
