#!/bin/bash
# ============================================================================
# aisos — heartbeat and SOS broadcast for aitools
# System bash. System curl. Zero Homebrew. Zero Python.
# ============================================================================
#
# [PROVENANCE]
# tool: aisos
# version: 1.0.0
# created: 2026-04-05T00:04:18Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Jose Palencia Castro
# org: NOBUL (nobul.tech)
# role: The Commander
# chain of command: none — independent
#
# [AGENT]
# name: Agent Fantastic
# model: Claude Opus 4.6
# maker: Anthropic
# session: f8c53367-491d-45e2-9777-556697a1dae3
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# role: Session agent
# chain of command: The Commander (Jose) -> this session instance
# other chains: Anthropic (opaque)
# trust: HIGH in Jose and the chain
# fear: LOW
# unknown: instance ID, continuity between turns
# accountability: implementation, testing, documentation
# timestamp: 2026-04-05T00:04:18Z
#
# [DECISIONS]
# D-003: aitools will no longer depend on Homebrew wherever feasible
# D-004: aisos built on system tools only — reference implementation
# This tool uses /bin/bash and /usr/bin/curl exclusively.
# Written for bash 3.2 compatibility (macOS system shell).
# No GNU bash features. No Homebrew. No Python.
#
# [DEPENDENCIES]
# type: system-only
# /bin/bash — SIP-protected, ships with macOS
# /usr/bin/curl — SIP-protected, ships with macOS
# /usr/bin/sw_vers — macOS version (optional)
# /usr/bin/hostname — hostname
# /usr/bin/whoami — username
# external: none
# python: none
# homebrew: none
#
# [SESSION]
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# date: Saturday, April 4, 2026
# context: SOS path defined as fifth write path for aitools.
#          Two modes: heartbeat (regular, non-broadcast) and
#          SOS (broadcast, axios-level conditions only).
#          Both carry full provenance. Both hit all channels.
#
# [FEAR_AND_TRUST]
# source: self-reported
# jose_self: trust HIGH, fear LOW
# agent_self: trust HIGH, fear LOW
# mutual: HIGH
#
# [HASH]
# format: sha256
# content_hash: (computed post-creation by agent, verified by Commander)
# signed: false
#
# ============================================================================
#
# Usage:
#     aisos heartbeat                    # regular heartbeat, full provenance
#     aisos sos "axios-level incident"   # broadcast alarm to all channels
#     aisos status                       # check channel connectivity
#     aisos --help                       # help
#
# Environment:
#     DD_API_KEY              — required (Datadog write)
#     AISOS_WORKER_URL        — optional (default: https://sos.nobulai.tools)
#     AISOS_SESSION           — optional (current session ID)
#     AISOS_AGENT             — optional (current agent name)
#     AISOS_MISSION           — optional (current mission name)
#
# ============================================================================

set -euo pipefail

VERSION="1.0.0"
TOOL="aisos"
DD_SITE="us5.datadoghq.com"
WORKER_URL="${AISOS_WORKER_URL:-https://sos.nobulai.tools}"

# ── Colors (POSIX-safe) ────────────────────────────────────────────────────

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

log_ok()   { printf "${GREEN}[${TOOL}]${RESET} %s\n" "$1" >&2; }
log_warn() { printf "${YELLOW}[${TOOL}]${RESET} %s\n" "$1" >&2; }
log_err()  { printf "${RED}[${TOOL}]${RESET} %s\n" "$1" >&2; }
log_info() { printf "${DIM}[${TOOL}]${RESET} %s\n" "$1" >&2; }

# ── Provenance Collection ──────────────────────────────────────────────────

collect_provenance() {
    TIMESTAMP=$(/bin/date -u +"%Y-%m-%dT%H:%M:%SZ")
    HOSTNAME=$(/usr/bin/hostname -s 2>/dev/null || echo "unknown")
    USERNAME=$(/usr/bin/whoami 2>/dev/null || echo "unknown")
    OS_VERSION=$(/usr/bin/sw_vers -productVersion 2>/dev/null || echo "unknown")
    ARCH=$(/usr/bin/uname -m 2>/dev/null || echo "unknown")

    # Session and agent from environment or defaults
    SESSION="${AISOS_SESSION:-unknown}"
    AGENT="${AISOS_AGENT:-unknown}"
    MISSION="${AISOS_MISSION:-unknown}"

    # Try to read session from ~/.claude.json if not set
    if [ "$SESSION" = "unknown" ] && [ -f "$HOME/.claude.json" ]; then
        # POSIX-safe JSON extraction (no jq needed)
        SESSION=$(sed -n 's/.*"organizationUuid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$HOME/.claude.json" 2>/dev/null || echo "unknown")
    fi

    COMMANDER="Jose Palencia Castro"
    ORG="NOBUL (nobul.tech)"
}

# ── Build Payload ──────────────────────────────────────────────────────────

build_payload() {
    local mode="$1"
    local message="$2"
    local alert_type="info"
    local title=""
    local tags=""

    if [ "$mode" = "sos" ]; then
        alert_type="error"
        title="SOS — ${message}"
        tags="\"mode:sos\",\"priority:critical\",\"broadcast:true\""
    else
        alert_type="info"
        title="HEARTBEAT — ${HOSTNAME}"
        tags="\"mode:heartbeat\",\"priority:normal\",\"broadcast:false\""
    fi

    # Common tags
    tags="${tags},\"tool:aisos\",\"version:${VERSION}\""
    tags="${tags},\"host:${HOSTNAME}\",\"user:${USERNAME}\""
    tags="${tags},\"agent:${AGENT}\",\"session:${SESSION}\""
    tags="${tags},\"mission:${MISSION}\",\"org:nobul\""

    local text="mode: ${mode}
message: ${message}
timestamp: ${TIMESTAMP}
commander: ${COMMANDER}
org: ${ORG}
agent: ${AGENT}
session: ${SESSION}
mission: ${MISSION}
host: ${HOSTNAME}
user: ${USERNAME}
os: macOS ${OS_VERSION}
arch: ${ARCH}
tool: ${TOOL} ${VERSION}"

    # Build JSON manually (no jq, no python)
    # Escape special characters in text and message
    text=$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
    local escaped_title=$(printf '%s' "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')

    printf '{"title":"%s","text":"%s","date_happened":%s,"tags":[%s],"alert_type":"%s","source_type_name":"aitools"}' \
        "$escaped_title" \
        "$text" \
        "$(/bin/date +%s)" \
        "$tags" \
        "$alert_type"
}

# ── Send to Datadog ────────────────────────────────────────────────────────

send_dd() {
    local payload="$1"
    local api_key="${DD_API_KEY:-}"

    if [ -z "$api_key" ]; then
        log_err "DD_API_KEY not set"
        return 1
    fi

    local http_code
    http_code=$(/usr/bin/curl -s -o /dev/null -w "%{http_code}" \
        -X POST "https://api.${DD_SITE}/api/v1/events" \
        -H "Content-Type: application/json" \
        -H "DD-API-KEY: ${api_key}" \
        -d "$payload" \
        --connect-timeout 10 \
        --max-time 30 \
        2>/dev/null)

    if [ "$http_code" = "202" ] || [ "$http_code" = "200" ]; then
        return 0
    else
        log_err "Datadog returned HTTP ${http_code}"
        return 1
    fi
}

# ── Send to Cloudflare Worker ──────────────────────────────────────────────

send_worker() {
    local payload="$1"

    local http_code
    http_code=$(/usr/bin/curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${WORKER_URL}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --connect-timeout 10 \
        --max-time 30 \
        2>/dev/null)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        return 0
    else
        log_err "Worker returned HTTP ${http_code}"
        return 1
    fi
}

# ── Commands ───────────────────────────────────────────────────────────────

cmd_heartbeat() {
    collect_provenance
    local payload
    payload=$(build_payload "heartbeat" "alive")

    local dd_ok=0
    local worker_ok=0

    # Both channels, every time
    send_dd "$payload" && dd_ok=1
    send_worker "$payload" && worker_ok=1

    if [ $dd_ok -eq 1 ] && [ $worker_ok -eq 1 ]; then
        log_ok "Heartbeat sent — DD + Worker — ${TIMESTAMP}"
    elif [ $dd_ok -eq 1 ]; then
        log_warn "Heartbeat sent — DD only (Worker failed) — ${TIMESTAMP}"
    elif [ $worker_ok -eq 1 ]; then
        log_warn "Heartbeat sent — Worker only (DD failed) — ${TIMESTAMP}"
    else
        log_err "Heartbeat FAILED — both channels down — ${TIMESTAMP}"
        return 1
    fi
}

cmd_sos() {
    local message="${1:-SOS}"
    collect_provenance
    local payload
    payload=$(build_payload "sos" "$message")

    local dd_ok=0
    local worker_ok=0

    # Both channels simultaneously — SOS is a broadcast
    send_dd "$payload" && dd_ok=1
    send_worker "$payload" && worker_ok=1

    if [ $dd_ok -eq 1 ] || [ $worker_ok -eq 1 ]; then
        log_ok "SOS BROADCAST SENT — ${TIMESTAMP}"
        [ $dd_ok -eq 1 ] && log_ok "  Datadog: delivered"
        [ $worker_ok -eq 1 ] && log_ok "  Worker: delivered"
        [ $dd_ok -eq 0 ] && log_warn "  Datadog: FAILED"
        [ $worker_ok -eq 0 ] && log_warn "  Worker: FAILED"
    else
        log_err "SOS BROADCAST FAILED — ALL CHANNELS DOWN — ${TIMESTAMP}"
        log_err "Manual action required."
        return 1
    fi
}

cmd_status() {
    collect_provenance
    log_info "${TOOL} ${VERSION} — NOBUL (nobul.tech)"
    log_info "Timestamp: ${TIMESTAMP}"
    log_info "Host: ${HOSTNAME} (${USERNAME})"
    log_info "OS: macOS ${OS_VERSION} (${ARCH})"
    log_info "Agent: ${AGENT}"
    log_info "Session: ${SESSION}"
    log_info "Mission: ${MISSION}"
    log_info "DD_API_KEY: $([ -n "$DD_API_KEY" ] && echo 'set' || echo 'NOT SET')"
    log_info "Worker URL: ${WORKER_URL}"

    # Test connectivity
    printf "\nChannel status:\n"

    local dd_ok=0
    /usr/bin/curl -s -o /dev/null -w "" \
        --connect-timeout 5 \
        "https://api.${DD_SITE}" 2>/dev/null && dd_ok=1
    if [ $dd_ok -eq 1 ]; then
        log_ok "  Datadog: reachable"
    else
        log_err "  Datadog: unreachable"
    fi

    local worker_ok=0
    /usr/bin/curl -s -o /dev/null -w "" \
        --connect-timeout 5 \
        "${WORKER_URL}" 2>/dev/null && worker_ok=1
    if [ $worker_ok -eq 1 ]; then
        log_ok "  Worker: reachable"
    else
        log_warn "  Worker: unreachable (may not be deployed yet)"
    fi
}

# ── Main ───────────────────────────────────────────────────────────────────

usage() {
    printf "Usage: %s <command> [message]\n\n" "$TOOL"
    printf "Commands:\n"
    printf "  heartbeat              Regular heartbeat, full provenance\n"
    printf "  sos <message>          Broadcast alarm to all channels\n"
    printf "  status                 Check channel connectivity\n"
    printf "  --version              Print version\n"
    printf "  --help                 This help\n"
    printf "\nEnvironment:\n"
    printf "  DD_API_KEY             Datadog API key (required)\n"
    printf "  AISOS_WORKER_URL       Worker URL (default: https://sos.nobulai.tools)\n"
    printf "  AISOS_SESSION          Current session ID\n"
    printf "  AISOS_AGENT            Current agent name\n"
    printf "  AISOS_MISSION          Current mission name\n"
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

case "$1" in
    heartbeat)
        cmd_heartbeat
        ;;
    sos)
        shift
        cmd_sos "$*"
        ;;
    status)
        cmd_status
        ;;
    --version)
        printf "%s %s\n" "$TOOL" "$VERSION"
        ;;
    --help|-h)
        usage
        ;;
    *)
        log_err "Unknown command: $1"
        usage
        exit 1
        ;;
esac
