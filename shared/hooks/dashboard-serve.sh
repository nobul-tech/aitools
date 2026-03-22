#!/usr/bin/env bash
# dashboard-serve.sh -- Claude Code SessionStart hook
# Delegates to `aitools dashboard --background` for dashboard lifecycle.
#
# The CLI owns estimation discovery, PID management, port detection, and
# server launch. This hook is a thin dispatcher that extracts project
# root from the hook input and delegates.
#
# Hook contract:
#   - SessionStart hook, command type
#   - stdout is added as context for Claude
#   - Must be fast (<100ms for detection; server starts async)
#   - Must never crash or hang (silent exit on errors)

set -euo pipefail

# Read hook input from stdin (contains session_id, cwd, etc.)
INPUT=$(cat)

# Extract cwd from hook input
cwd=""
if [[ "$INPUT" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    cwd="${BASH_REMATCH[1]}"
fi

# Find project root
PROJECT_ROOT=""
if [ -n "$cwd" ]; then
    PROJECT_ROOT=$(cd "$cwd" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
else
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi

# Find aitools CLI
AITOOLS=""
if command -v aitools >/dev/null 2>&1; then
    AITOOLS="aitools"
elif [ -f "$HOME/.local/bin/aitools" ]; then
    AITOOLS="$HOME/.local/bin/aitools"
fi

if [ -n "$AITOOLS" ]; then
    # Delegate to CLI -- it handles everything
    cd "$PROJECT_ROOT" 2>/dev/null || true
    "$AITOOLS" dashboard --background --project-root "$PROJECT_ROOT" 2>/dev/null || true
else
    # Fallback: direct launch if aitools CLI not installed
    # This preserves functionality during initial setup before first `aitools install`
    PYTHON=""
    if command -v python3 >/dev/null 2>&1; then
        PYTHON="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON="python"
    fi
    [ -n "$PYTHON" ] || exit 0

    GENERATOR=""
    if [ -f "$HOME/repos/aitools/scripts/generate-dashboard.py" ]; then
        GENERATOR="$HOME/repos/aitools/scripts/generate-dashboard.py"
    elif [ -f "$PROJECT_ROOT/scripts/generate-dashboard.py" ]; then
        GENERATOR="$PROJECT_ROOT/scripts/generate-dashboard.py"
    fi
    [ -n "$GENERATOR" ] || exit 0

    # Find estimate (simplified -- CLI has full search logic)
    ESTIMATE=""
    if [ -f "$PROJECT_ROOT/.aitools/channel/running-estimate.json" ]; then
        ESTIMATE="$PROJECT_ROOT/.aitools/channel/running-estimate.json"
    fi
    if [ -z "$ESTIMATE" ] && [ -d "$PROJECT_ROOT/.scratch" ]; then
        for dir in "$PROJECT_ROOT"/.scratch/session-*/; do
            [ -d "$dir" ] || continue
            for est in "$dir"/*running-estimate*.json; do
                [ -f "$est" ] || continue
                ESTIMATE="$est"
                break 2
            done
        done
    fi
    [ -n "$ESTIMATE" ] || exit 0

    PORT=8411
    PID_DIR="$PROJECT_ROOT/.aitools"
    mkdir -p "$PID_DIR" 2>/dev/null || PID_DIR="/tmp"
    PID_FILE="$PID_DIR/.dashboard-pid"

    # Check if already running
    if [ -f "$PID_FILE" ]; then
        old_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            printf 'Dashboard: http://localhost:%d/\n' "$PORT"
            exit 0
        fi
        rm -f "$PID_FILE"
    fi

    nohup "$PYTHON" "$GENERATOR" --estimate "$ESTIMATE" --serve --port "$PORT" \
        >/dev/null 2>&1 &
    SERVER_PID=$!
    disown "$SERVER_PID" 2>/dev/null || true
    printf '%d' "$SERVER_PID" > "$PID_FILE"
    sleep 0.3
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        printf 'Dashboard: http://localhost:%d/\n' "$PORT"
    else
        rm -f "$PID_FILE"
    fi
fi

exit 0
