#!/usr/bin/env bash
# aitools-dashboard.sh -- Mission control dashboard lifecycle management (macOS/Linux)
# Safe to re-run. Manages the live dashboard server for running estimates.
#
# Usage:
#   bash scripts/aitools-dashboard.sh [OPTIONS]
#
# Options:
#   --background        Start server in background (for hooks)
#   --stop              Stop running server(s)
#     --port PORT         Stop specific port only
#     --all               Stop all instances
#   --status            Show all running instances with health
#   --health-check      Liveness + data quality check for all instances
#   --snapshot          Generate static HTML snapshot
#   --port PORT         Custom port (default: 8411)
#   --estimate PATH     Explicit estimate path (default: auto-detect)
#
# Multi-instance: PID files stored in ~/.aitools/dashboard-pids/<port>.pid
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
ACTION="start"      # start | stop | status | snapshot | health-check
BACKGROUND=false
OPEN_BROWSER=false
PROJECT_ROOT=""
STOP_ALL=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --background)   BACKGROUND=true; shift ;;
        --stop)         ACTION="stop"; shift ;;
        --status)       ACTION="status"; shift ;;
        --health-check) ACTION="health-check"; shift ;;
        --snapshot)     ACTION="snapshot"; shift ;;
        --open)         OPEN_BROWSER=true; shift ;;
        --all)          STOP_ALL=true; shift ;;
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
# PID registry directory (multi-instance)
# ---------------------------------------------------------------------------
PID_REGISTRY_DIR="$HOME/.aitools/dashboard-pids"
mkdir -p "$PID_REGISTRY_DIR" 2>/dev/null || true

# Legacy PID file location (for migration)
LEGACY_PID_DIR="$PROJECT_ROOT/.aitools"
LEGACY_PID_FILE="$LEGACY_PID_DIR/.dashboard-pid"

# ---------------------------------------------------------------------------
# Expected fields for health checks (shared with generate-dashboard.py)
# ---------------------------------------------------------------------------
EXPECTED_TOP_FIELDS="delegationLog findings openThreads"
EXPECTED_SITUATION_FIELDS="decisions assumptions deviations facts"

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
# PID registry helpers (multi-instance)
# ---------------------------------------------------------------------------

# Get PID file path for a specific port
pid_file_for_port() {
    local port="$1"
    printf '%s/%s.pid' "$PID_REGISTRY_DIR" "$port"
}

# Check if a specific port's server is running; prints PID if so
is_port_server_running() {
    local port="$1"
    local pf
    pf=$(pid_file_for_port "$port")
    if [ -f "$pf" ]; then
        local pid
        pid=$(cat "$pf" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            printf '%s' "$pid"
            return 0
        fi
        # Stale PID file -- clean up
        rm -f "$pf"
    fi
    return 1
}

# Migrate legacy single PID file to registry (one-time)
migrate_legacy_pid() {
    if [ -f "$LEGACY_PID_FILE" ]; then
        local pid
        pid=$(cat "$LEGACY_PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            # Legacy server is running -- migrate its PID to the registry
            # We assume default port 8411 for legacy instances
            local new_pf
            new_pf=$(pid_file_for_port "8411")
            if [ ! -f "$new_pf" ]; then
                cp "$LEGACY_PID_FILE" "$new_pf"
                log "Migrated legacy PID $pid to port registry (8411)"
            fi
        fi
        rm -f "$LEGACY_PID_FILE"
    fi
}

# List all running instances. Prints: port pid (one per line)
list_running_instances() {
    local found=false
    for pf in "$PID_REGISTRY_DIR"/*.pid; do
        [ -f "$pf" ] || continue
        local port_name pid
        port_name=$(basename "$pf" .pid)
        pid=$(cat "$pf" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            printf '%s %s\n' "$port_name" "$pid"
            found=true
        else
            # Stale PID file -- clean up
            rm -f "$pf"
        fi
    done
    if [ "$found" = false ]; then
        return 1
    fi
    return 0
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
# Health check helper: check one instance
# ---------------------------------------------------------------------------
check_instance_health() {
    local port="$1"
    local pid="$2"
    local healthy=true
    local details=""

    # 1. HTTP liveness check
    local http_status=""
    if command -v curl >/dev/null 2>&1; then
        http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/" 2>/dev/null || echo "000")
    else
        # No curl -- skip HTTP check, just verify process is alive
        http_status="skip"
    fi

    if [ "$http_status" = "skip" ]; then
        details="no curl available, process alive (PID $pid)"
    elif [ "$http_status" != "200" ]; then
        healthy=false
        details="HTTP $http_status (expected 200)"
    fi

    # 2. Data quality check: read the estimate the dashboard is serving
    # Try the API endpoint first
    local estimate_json=""
    if command -v curl >/dev/null 2>&1; then
        estimate_json=$(curl -s "http://localhost:${port}/api/estimate" 2>/dev/null || echo "")
    fi

    if [ -n "$estimate_json" ]; then
        # Use python to check fields (available since we need it for the dashboard)
        local python_cmd=""
        python_cmd=$(find_python 2>/dev/null || echo "")
        if [ -n "$python_cmd" ]; then
            local check_result=""
            check_result=$("$python_cmd" -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
except:
    print('PARSE_ERROR')
    sys.exit(0)
missing = []
for f in ['delegationLog', 'findings', 'openThreads']:
    if f not in d:
        missing.append(f)
sit = d.get('situation')
if sit is None:
    missing.append('situation')
elif isinstance(sit, dict):
    for f in ['decisions', 'assumptions', 'deviations', 'facts']:
        if f not in sit:
            missing.append('situation.' + f)
delegations = len(d.get('delegationLog', []))
findings = len(d.get('findings', []))
threads = len(d.get('openThreads', []))
if missing:
    print('MISSING:' + ','.join(missing) + '|' + str(delegations) + '|' + str(findings) + '|' + str(threads))
else:
    print('OK|' + str(delegations) + '|' + str(findings) + '|' + str(threads))
" <<< "$estimate_json" 2>/dev/null || echo "CHECK_FAILED")

            if [ "$check_result" = "PARSE_ERROR" ]; then
                healthy=false
                details="${details:+$details, }estimate JSON parse error"
            elif [ "$check_result" = "CHECK_FAILED" ]; then
                details="${details:+$details, }field check unavailable"
            elif printf '%s' "$check_result" | grep -q "^MISSING:"; then
                healthy=false
                local missing_fields=""
                missing_fields=$(printf '%s' "$check_result" | perl -pe 's/^MISSING:([^|]+)\|.*/$1/')
                local counts=""
                counts=$(printf '%s' "$check_result" | perl -pe 's/^MISSING:[^|]+\|//')
                local del_count=""
                del_count=$(printf '%s' "$counts" | cut -d'|' -f1)
                local find_count=""
                find_count=$(printf '%s' "$counts" | cut -d'|' -f2)
                local thread_count=""
                thread_count=$(printf '%s' "$counts" | cut -d'|' -f3)
                details="${details:+$details, }missing fields: $missing_fields ($del_count delegations, $find_count findings, $thread_count threads)"
            elif printf '%s' "$check_result" | grep -q "^OK|"; then
                local counts=""
                counts=$(printf '%s' "$check_result" | perl -pe 's/^OK\|//')
                local del_count=""
                del_count=$(printf '%s' "$counts" | cut -d'|' -f1)
                local find_count=""
                find_count=$(printf '%s' "$counts" | cut -d'|' -f2)
                local thread_count=""
                thread_count=$(printf '%s' "$counts" | cut -d'|' -f3)
                details="${details:+$details, }$del_count delegations, $find_count findings, $thread_count threads"
            fi
        else
            details="${details:+$details, }python not available for field check"
        fi
    elif [ "$http_status" = "200" ]; then
        details="${details:+$details, }no /api/estimate endpoint (static mode?)"
    fi

    if [ "$healthy" = true ]; then
        log_ok "Dashboard on port $port: HEALTHY ($details)"
    else
        log_warn "Dashboard on port $port: UNHEALTHY ($details)"
    fi

    if [ "$healthy" = true ]; then
        return 0
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Migrate legacy PID file on every invocation
# ---------------------------------------------------------------------------
migrate_legacy_pid

# ---------------------------------------------------------------------------
# ACTION: status
# ---------------------------------------------------------------------------
if [ "$ACTION" = "status" ]; then
    local_found=false
    while IFS=' ' read -r inst_port inst_pid; do
        local_found=true
        log_ok "Dashboard server running (PID $inst_pid) on port $inst_port"
        log "  URL: http://localhost:$inst_port/"
        log "  PID file: $(pid_file_for_port "$inst_port")"
    done < <(list_running_instances 2>/dev/null || true)

    if [ "$local_found" = false ]; then
        log "No dashboard instances running"
        if is_port_in_use "$PORT"; then
            log_warn "Port $PORT is in use by another process (not a managed dashboard)"
        fi
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# ACTION: health-check
# ---------------------------------------------------------------------------
if [ "$ACTION" = "health-check" ]; then
    local_found=false
    local_unhealthy=0
    while IFS=' ' read -r inst_port inst_pid; do
        local_found=true
        if ! check_instance_health "$inst_port" "$inst_pid"; then
            local_unhealthy=$((local_unhealthy + 1))
        fi
    done < <(list_running_instances 2>/dev/null || true)

    if [ "$local_found" = false ]; then
        log_warn "No dashboard instances running"
        exit 1
    fi

    if [ "$local_unhealthy" -gt 0 ]; then
        exit 1
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# ACTION: stop
# ---------------------------------------------------------------------------
if [ "$ACTION" = "stop" ]; then
    if [ "$STOP_ALL" = true ]; then
        # Stop all instances
        local_found=false
        while IFS=' ' read -r inst_port inst_pid; do
            local_found=true
            kill "$inst_pid" 2>/dev/null || true
            rm -f "$(pid_file_for_port "$inst_port")"
            log_ok "Stopped dashboard on port $inst_port (PID $inst_pid)"
        done < <(list_running_instances 2>/dev/null || true)

        if [ "$local_found" = false ]; then
            log "No dashboard instances running"
        fi
    else
        # Stop specific port
        if pid=$(is_port_server_running "$PORT"); then
            kill "$pid" 2>/dev/null || true
            rm -f "$(pid_file_for_port "$PORT")"
            log_ok "Stopped dashboard on port $PORT (PID $pid)"
        else
            log "No dashboard running on port $PORT"
        fi
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

# Check if this port already has a running instance
if pid=$(is_port_server_running "$PORT"); then
    log "Dashboard server already running on port $PORT (PID $pid)"
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

PORT_PID_FILE=$(pid_file_for_port "$PORT")

if $BACKGROUND; then
    # Background mode: nohup + disown for hook usage
    nohup "$PYTHON" "$GENERATOR" --estimate "$ESTIMATE" --serve --port "$PORT" \
        >/dev/null 2>&1 &
    SERVER_PID=$!
    disown "$SERVER_PID" 2>/dev/null || true

    # Write PID to port-keyed registry
    printf '%d' "$SERVER_PID" > "$PORT_PID_FILE"

    # Brief pause to let the server bind
    sleep 0.3

    # Verify server started
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        log_ok "Dashboard server started in background (PID $SERVER_PID) on port $PORT"
        log "URL: http://localhost:$PORT/"
        write_summary OK "dashboard" "http://localhost:$PORT/"
    else
        rm -f "$PORT_PID_FILE"
        log_error "Dashboard server failed to start"
        write_summary ERROR "dashboard" "failed to start"
        exit 1
    fi
else
    # Foreground mode: server runs until Ctrl+C
    # Write PID to port-keyed registry
    printf '%d' "$$" > "$PORT_PID_FILE"

    # Trap to clean up PID file on exit
    cleanup() {
        rm -f "$PORT_PID_FILE"
    }
    trap cleanup EXIT

    local_args=("--estimate" "$ESTIMATE" "--serve" "--port" "$PORT")
    if [ "$OPEN_BROWSER" = true ]; then
        local_args+=("--open")
    fi

    write_summary OK "dashboard" "http://localhost:$PORT/"
    "$PYTHON" "$GENERATOR" "${local_args[@]}"
fi
