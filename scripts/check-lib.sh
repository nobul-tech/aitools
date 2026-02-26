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
# Step formatters
# ---------------------------------------------------------------------------
# Usage: step_pass "1" "Git identity"
step_pass() {
    local num="$1" label="$2"
    printf "%3s. %-42s ${GREEN}[PASS]${RESET}\n" "$num" "$label"
    PASS_COUNT=$((PASS_COUNT + 1))
}

step_fail() {
    local num="$1" label="$2" detail="${3:-}"
    printf "%3s. %-42s ${RED}[FAIL]${RESET}" "$num" "$label"
    [ -n "$detail" ] && printf " %s" "$detail"
    printf "\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

step_warn() {
    local num="$1" label="$2" detail="${3:-}"
    printf "%3s. %-42s ${YELLOW}[WARN]${RESET}" "$num" "$label"
    [ -n "$detail" ] && printf " %s" "$detail"
    printf "\n"
    WARN_COUNT=$((WARN_COUNT + 1))
}

step_skip() {
    local num="$1" label="$2" detail="${3:-}"
    printf "%3s. %-42s ${DIM}[SKIP]${RESET}" "$num" "$label"
    [ -n "$detail" ] && printf " %s" "$detail"
    printf "\n"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    printf "=== SUMMARY: ${GREEN}%d PASS${RESET}, ${DIM}%d SKIP${RESET}, ${YELLOW}%d WARN${RESET}, ${RED}%d FAIL${RESET} ===\n" \
        "$PASS_COUNT" "$SKIP_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
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
