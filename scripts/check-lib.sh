# check-lib.sh -- shared library for check-pre-commit/pre-push/post-push scripts
# Sourced, not executed directly. No shebang, no set -euo pipefail (caller sets it).

# ---------------------------------------------------------------------------
# Colors (disabled if not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    DIM='\033[0;90m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; DIM=''; BOLD=''; RESET=''
fi

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

# ---------------------------------------------------------------------------
# File logging (checks.log + checks.jsonl)
# ---------------------------------------------------------------------------
# Log path: same directory as setup scripts (deploy.log)
_CHECK_LOG_DIR=""
_CHECK_LOG=""
_CHECK_JSONL=""
_CHECK_NAME=""

check_log_init() {
    _CHECK_NAME="${1:?check_log_init requires a check name}"
    # Platform log directory (matches setup script pattern)
    case "$(uname -s)" in
        Darwin*)          _CHECK_LOG_DIR="$HOME/Library/Logs/aitools" ;;
        *)                _CHECK_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools" ;;
    esac
    _CHECK_LOG="$_CHECK_LOG_DIR/checks.log"
    _CHECK_JSONL="$_CHECK_LOG_DIR/checks.jsonl"
    mkdir -p "$_CHECK_LOG_DIR"

    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local host
    host=$(hostname -s 2>/dev/null || hostname)
    local os_name
    case "$(uname -s)" in
        Darwin*) os_name="macOS" ;;
        *)       os_name="$(uname -s)" ;;
    esac

    printf '[%s] [%s] === RUN START ===\n' "$ts" "$_CHECK_NAME" >> "$_CHECK_LOG"
    printf '{"ts":"%s","check":"%s","event":"run_start","host":"%s","os":"%s"}\n' \
        "$ts" "$_CHECK_NAME" "$host" "$os_name" >> "$_CHECK_JSONL"
}

# Internal: log one step result to both files
_check_log_step() {
    [ -z "$_CHECK_LOG" ] && return 0
    local num="$1" label="$2" result="$3" detail="${4:-}"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '[%s] [%s] %3s. %-42s [%s]' "$ts" "$_CHECK_NAME" "$num" "$label" "$result" >> "$_CHECK_LOG"
    [ -n "$detail" ] && printf ' %s' "$detail" >> "$_CHECK_LOG"
    printf '\n' >> "$_CHECK_LOG"
    # Escape detail for JSON (backslashes and double quotes)
    local json_detail
    json_detail=$(printf '%s' "$detail" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"ts":"%s","check":"%s","step":"%s","label":"%s","result":"%s","detail":"%s"}\n' \
        "$ts" "$_CHECK_NAME" "$num" "$label" "$result" "$json_detail" >> "$_CHECK_JSONL"
}

# ---------------------------------------------------------------------------
# Step formatters
# ---------------------------------------------------------------------------
# Usage: step_pass "1" "Git identity" ["optional detail"]
step_pass() {
    local num="$1" label="$2" detail="${3:-}"
    printf "%3s. %-42s ${GREEN}[PASS]${RESET}" "$num" "$label"
    [ -n "$detail" ] && printf " %s" "$detail"
    printf "\n"
    PASS_COUNT=$((PASS_COUNT + 1))
    _check_log_step "$num" "$label" "PASS" "$detail"
}

step_fail() {
    local num="$1" label="$2" detail="${3:-}"
    printf "%3s. %-42s ${RED}[FAIL]${RESET}" "$num" "$label"
    [ -n "$detail" ] && printf " %s" "$detail"
    printf "\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    _check_log_step "$num" "$label" "FAIL" "$detail"
}

step_warn() {
    local num="$1" label="$2" detail="${3:-}"
    printf "%3s. %-42s ${YELLOW}[WARN]${RESET}" "$num" "$label"
    [ -n "$detail" ] && printf " %s" "$detail"
    printf "\n"
    WARN_COUNT=$((WARN_COUNT + 1))
    _check_log_step "$num" "$label" "WARN" "$detail"
}

step_skip() {
    local num="$1" label="$2" detail="${3:-}"
    printf "%3s. %-42s ${DIM}[SKIP]${RESET}" "$num" "$label"
    [ -n "$detail" ] && printf " %s" "$detail"
    printf "\n"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    _check_log_step "$num" "$label" "SKIP" "$detail"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    printf "=== SUMMARY: ${GREEN}%d PASS${RESET}, ${DIM}%d SKIP${RESET}, ${YELLOW}%d WARN${RESET}, ${RED}%d FAIL${RESET} ===\n" \
        "$PASS_COUNT" "$SKIP_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
    # Log summary to files
    if [ -n "$_CHECK_LOG" ]; then
        local ts
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        printf '[%s] [%s] === SUMMARY: %d PASS, %d SKIP, %d WARN, %d FAIL ===\n' \
            "$ts" "$_CHECK_NAME" "$PASS_COUNT" "$SKIP_COUNT" "$WARN_COUNT" "$FAIL_COUNT" >> "$_CHECK_LOG"
        printf '{"ts":"%s","check":"%s","event":"run_end","pass":%d,"skip":%d,"warn":%d,"fail":%d}\n' \
            "$ts" "$_CHECK_NAME" "$PASS_COUNT" "$SKIP_COUNT" "$WARN_COUNT" "$FAIL_COUNT" >> "$_CHECK_JSONL"
    fi
}

# ---------------------------------------------------------------------------
# Config reader (pure bash, handles UTF-8 BOM)
# ---------------------------------------------------------------------------
read_config_key() {
    local file="$1" key="$2"
    [ -f "$file" ] || return 1
    local val
    val=$(tr -d '\357\273\277' < "$file" \
        | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -1 \
        | cut -d'"' -f4)
    [ -n "$val" ] || return 1
    printf '%b' "$val"
}

# ---------------------------------------------------------------------------
# Repo root and config resolution
# ---------------------------------------------------------------------------
# REPO_ROOT must be set by the sourcing script (via BASH_SOURCE or similar).
# This library does NOT set it -- the caller knows its own location.

resolve_config() {
    CONFIG_FILE="$HOME/.aitools/config.json"
    USER_REPO_PATH=""
    if [ -f "$CONFIG_FILE" ]; then
        USER_REPO_PATH=$(read_config_key "$CONFIG_FILE" "userRepoPath" 2>/dev/null || true)
    fi
}

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
IS_MACOS=false
IS_WINDOWS=false
case "$(uname -s)" in
    Darwin*)          IS_MACOS=true ;;
    MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;;
esac

# ---------------------------------------------------------------------------
# pwsh check
# ---------------------------------------------------------------------------
require_pwsh() {
    local step_num="$1" step_label="$2"
    if ! command -v pwsh &>/dev/null; then
        step_fail "$step_num" "$step_label" "pwsh not found -- install: brew install powershell/tap/powershell"
        return 1
    fi
    return 0
}
