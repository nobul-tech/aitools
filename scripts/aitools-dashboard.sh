#!/usr/bin/env bash
# aitools-dashboard.sh -- Mission control dashboard lifecycle management (macOS/Linux)
# Safe to re-run. Manages the live dashboard server for running estimates.
#
# Usage:
#   bash scripts/aitools-dashboard.sh [OPTIONS]
#
# Options:
#   --background        Start server in background (for hooks)
#   --stop              Stop the running server
#   --status            Show server status
#   --snapshot          Generate static HTML snapshot
#   --port PORT         Custom port (default: 8411)
#   --estimate PATH     Explicit estimate path (default: auto-detect)
#
# Called by: aitools dashboard (entry point dispatch)
# Called by: SessionStart hook (dashboard-serve.sh) via aitools dashboard --background
# See: reference/tool-registry.md (Python managed tool)

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "aitools-dashboard"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use aitools-dashboard.ps1 instead."
        exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
PORT=8411
ESTIMATE=""
ACTION="start"      # start | stop | status | snapshot
BACKGROUND=false
OPEN_BROWSER=false
PROJECT_ROOT=""

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --background)   BACKGROUND=true; shift ;;
        --stop)         ACTION="stop"; shift ;;
        --status)       ACTION="status"; shift ;;
        --snapshot)     ACTION="snapshot"; shift ;;
        --open)         OPEN_BROWSER=true; shift ;;
        --port)
            shift
            if [[ $# -eq 0 ]]; then
                log_error "--port requires a value"
                exit 1
            fi
            PORT="$1"; shift ;;
        --estimate)
            shift
            if [[ $# -eq 0 ]]; then
                log_error "--estimate requires a path"
                exit 1
            fi
            ESTIMATE="$1"; shift ;;
        --project-root)
            shift
            if [[ $# -eq 0 ]]; then
                log_error "--project-root requires a path"
                exit 1
            fi
            PROJECT_ROOT="$1"; shift ;;
        *)
            log_error "unknown option '$1'"
            exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve project root
# ---------------------------------------------------------------------------
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi

# ---------------------------------------------------------------------------
# PID file location
# ---------------------------------------------------------------------------
PID_DIR="$PROJECT_ROOT/.aitools"
mkdir -p "$PID_DIR" 2>/dev/null || PID_DIR="/tmp"
PID_FILE="$PID_DIR/.dashboard-pid"

# ---------------------------------------------------------------------------
# Find python3
# ---------------------------------------------------------------------------
find_python() {
    if command -v python3 >/dev/null 2>&1; then
        printf 'python3'
    elif command -v python >/dev/null 2>&1; then
        printf 'python'
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Find the generator script
# ---------------------------------------------------------------------------
find_generator() {
    local repo_path=""
    repo_path=$(read_config_key "$HOME/.aitools/config.json" "repoPath" 2>/dev/null || true)
    repo_path="${repo_path:-$HOME/repos/aitools}"

    if [ -f "$repo_path/scripts/generate-dashboard.py" ]; then
        printf '%s' "$repo_path/scripts/generate-dashboard.py"
    elif [ -f "$PROJECT_ROOT/scripts/generate-dashboard.py" ]; then
        printf '%s' "$PROJECT_ROOT/scripts/generate-dashboard.py"
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Auto-detect running estimate
# ---------------------------------------------------------------------------
find_estimate() {
    # 1. Check .aitools/channel/ for tracked running estimate
    if [ -f "$PROJECT_ROOT/.aitools/channel/running-estimate.json" ]; then
        printf '%s' "$PROJECT_ROOT/.aitools/channel/running-estimate.json"
        return 0
    fi

    # 2. Check session-specific channel dirs
    if [ -d "$PROJECT_ROOT/.aitools/channel/" ]; then
        local dir est
        for dir in "$PROJECT_ROOT"/.aitools/channel/session-*/; do
            [ -d "$dir" ] || continue
            for est in "$dir"/*running-estimate*.json; do
                [ -f "$est" ] || continue
                printf '%s' "$est"
                return 0
            done
        done
    fi

    # 3. Check .scratch/ for session estimates (most recently modified)
    if [ -d "$PROJECT_ROOT/.scratch" ]; then
        local best=""
        local dir est
        for dir in "$PROJECT_ROOT"/.scratch/session-*/; do
            [ -d "$dir" ] || continue
            for est in "$dir"/*running-estimate*.json; do
                [ -f "$est" ] || continue
                if [ -z "$best" ]; then
                    best="$est"
                elif [ "$est" -nt "$best" ]; then
                    best="$est"
                fi
            done
        done
        if [ -n "$best" ]; then
            printf '%s' "$best"
            return 0
        fi
    fi

    # 4. Check .aitools/scratch/ (workspace namespace)
    if [ -d "$PROJECT_ROOT/.aitools/scratch" ]; then
        local best=""
        local dir est
        for dir in "$PROJECT_ROOT"/.aitools/scratch/session-*/; do
            [ -d "$dir" ] || continue
            for est in "$dir"/*running-estimate*.json; do
                [ -f "$est" ] || continue
                if [ -z "$best" ]; then
                    best="$est"
                elif [ "$est" -nt "$best" ]; then
                    best="$est"
                fi
            done
        done
        if [ -n "$best" ]; then
            printf '%s' "$best"
            return 0
        fi
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Check if server is running
# ---------------------------------------------------------------------------
is_server_running() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            printf '%s' "$pid"
            return 0
        fi
        # Stale PID file -- clean up
        rm -f "$PID_FILE"
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Check if port is in use
# ---------------------------------------------------------------------------
is_port_in_use() {
    local port="$1"
    if command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1
    elif command -v ss >/dev/null 2>&1; then
        ss -tlnp 2>/dev/null | grep -q ":${port} " 2>/dev/null
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# ACTION: status
# ---------------------------------------------------------------------------
if [ "$ACTION" = "status" ]; then
    if pid=$(is_server_running); then
        log_ok "Dashboard server running (PID $pid) on port $PORT"
        log "URL: http://localhost:$PORT/"
        if [ -f "$PID_FILE" ]; then
            log "PID file: $PID_FILE"
        fi
    else
        log "Dashboard server is not running"
        if is_port_in_use "$PORT"; then
            log_warn "Port $PORT is in use by another process"
        fi
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# ACTION: stop
# ---------------------------------------------------------------------------
if [ "$ACTION" = "stop" ]; then
    if pid=$(is_server_running); then
        kill "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
        log_ok "Dashboard server stopped (PID $pid)"
    else
        log "Dashboard server is not running"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# ACTION: snapshot
# ---------------------------------------------------------------------------
if [ "$ACTION" = "snapshot" ]; then
    PYTHON=$(find_python) || {
        log_error "python3 not found -- install Python to use the dashboard"
        write_summary ERROR "dashboard" "python3 not found"
        exit 1
    }

    GENERATOR=$(find_generator) || {
        log_error "generate-dashboard.py not found"
        write_summary ERROR "dashboard" "generator not found"
        exit 1
    }

    if [ -z "$ESTIMATE" ]; then
        ESTIMATE=$(find_estimate) || {
            log_error "no running estimate found"
            write_summary WARN "dashboard" "no estimate found"
            exit 1
        }
    fi

    log "Generating static dashboard snapshot..."
    local_args=("--estimate" "$ESTIMATE")
    if [ "$OPEN_BROWSER" = true ]; then
        local_args+=("--open")
    fi

    if "$PYTHON" "$GENERATOR" "${local_args[@]}"; then
        log_ok "Dashboard snapshot generated"
        write_summary OK "dashboard" "snapshot generated"
    else
        log_error "Dashboard generation failed"
        write_summary ERROR "dashboard" "generation failed"
        exit 1
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# ACTION: start (default)
# ---------------------------------------------------------------------------

# Check if already running
if pid=$(is_server_running); then
    log "Dashboard server already running (PID $pid)"
    if ! $BACKGROUND; then
        log "URL: http://localhost:$PORT/"
    fi
    write_summary OK "dashboard" "http://localhost:$PORT/ (already running)"
    exit 0
fi

# Check if port is in use by something else
if is_port_in_use "$PORT"; then
    log_warn "Port $PORT is already in use by another process"
    write_summary WARN "dashboard" "port $PORT in use"
    exit 1
fi

# Find dependencies
PYTHON=$(find_python) || {
    log_error "python3 not found -- install Python to use the dashboard"
    write_summary ERROR "dashboard" "python3 not found"
    exit 1
}

GENERATOR=$(find_generator) || {
    log_error "generate-dashboard.py not found"
    write_summary ERROR "dashboard" "generator not found"
    exit 1
}

# Resolve estimate path
if [ -z "$ESTIMATE" ]; then
    ESTIMATE=$(find_estimate) || {
        if $BACKGROUND; then
            # Background mode: no estimate is not an error, just skip
            exit 0
        fi
        log_error "no running estimate found"
        log "Create a running estimate in .aitools/channel/running-estimate.json or .scratch/session-*/running-estimate*.json"
        write_summary WARN "dashboard" "no estimate found"
        exit 1
    }
fi

log "Starting dashboard server on port $PORT..."
log "Estimate: $ESTIMATE"

if $BACKGROUND; then
    # Background mode: nohup + disown for hook usage
    nohup "$PYTHON" "$GENERATOR" --estimate "$ESTIMATE" --serve --port "$PORT" \
        >/dev/null 2>&1 &
    SERVER_PID=$!
    disown "$SERVER_PID" 2>/dev/null || true

    # Write PID for cleanup
    printf '%d' "$SERVER_PID" > "$PID_FILE"

    # Brief pause to let the server bind
    sleep 0.3

    # Verify server started
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        log_ok "Dashboard server started in background (PID $SERVER_PID)"
        log "URL: http://localhost:$PORT/"
        write_summary OK "dashboard" "http://localhost:$PORT/"
    else
        rm -f "$PID_FILE"
        log_error "Dashboard server failed to start"
        write_summary ERROR "dashboard" "failed to start"
        exit 1
    fi
else
    # Foreground mode: server runs until Ctrl+C
    # Write PID for status/stop commands
    printf '%d' "$$" > "$PID_FILE"

    # Trap to clean up PID file on exit
    cleanup() {
        rm -f "$PID_FILE"
    }
    trap cleanup EXIT

    local_args=("--estimate" "$ESTIMATE" "--serve" "--port" "$PORT")
    if [ "$OPEN_BROWSER" = true ]; then
        local_args+=("--open")
    fi

    write_summary OK "dashboard" "http://localhost:$PORT/"
    "$PYTHON" "$GENERATOR" "${local_args[@]}"
fi
