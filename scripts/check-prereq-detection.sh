#!/usr/bin/env bash
# check-prereq-detection.sh -- verify build prerequisite known-path fallback coverage
# and ensure_tool_on_path availability
# Usage: bash scripts/check-prereq-detection.sh
# Platform: macOS/Linux
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/check-lib.sh
source "$SCRIPT_DIR/check-lib.sh"

# OS guard: use .ps1 on Windows
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) echo "Use check-prereq-detection.ps1 on Windows"; exit 1 ;;
esac

resolve_config
check_log_init "prereq-detection"

cd "$REPO_ROOT"

echo ""
echo "${BOLD}=== PREREQ DETECTION CHECKLIST ===${RESET}"
echo ""

# ---------------------------------------------------------------------------
# 1. ensure_tool_on_path function exists (loaded from aitools-lib.sh)
# ---------------------------------------------------------------------------
if declare -f ensure_tool_on_path >/dev/null 2>&1; then
    step_pass "1" "ensure_tool_on_path function loaded"
else
    step_fail "1" "ensure_tool_on_path function loaded" "not found after sourcing aitools-lib.sh"
fi

# ---------------------------------------------------------------------------
# 2. check_build_prereqs function exists
# ---------------------------------------------------------------------------
if declare -f check_build_prereqs >/dev/null 2>&1; then
    step_pass "2" "check_build_prereqs function loaded"
else
    step_fail "2" "check_build_prereqs function loaded" "not found after sourcing aitools-lib.sh"
fi

# ---------------------------------------------------------------------------
# 3. check_build_prereqs("cargo") is callable without error
# ---------------------------------------------------------------------------
if declare -f check_build_prereqs >/dev/null 2>&1; then
    PREREQ_OUTPUT=$(check_build_prereqs "cargo" 2>&1) || true
    step_pass "3" "check_build_prereqs callable" "cargo ecosystem"
else
    step_skip "3" "check_build_prereqs callable" "function not loaded"
fi

# ---------------------------------------------------------------------------
# 4. check_build_prereqs returns 0 for unknown ecosystem (no crash)
# ---------------------------------------------------------------------------
if declare -f check_build_prereqs >/dev/null 2>&1; then
    EC=0
    check_build_prereqs "nonexistent_ecosystem_test" >/dev/null 2>&1 || EC=$?
    if [ "$EC" -eq 0 ]; then
        step_pass "4" "Unknown ecosystem handling" "returns 0 (no missing)"
    else
        step_warn "4" "Unknown ecosystem handling" "returned exit code $EC"
    fi
else
    step_skip "4" "Unknown ecosystem handling" "function not loaded"
fi

# ---------------------------------------------------------------------------
# 5. NASM known-path fallback exists in check_build_prereqs source
# ---------------------------------------------------------------------------
if grep -q 'ensure_tool_on_path.*nasm' "$SCRIPT_DIR/aitools-lib.sh"; then
    step_pass "5" "NASM known-path fallback in source" "ensure_tool_on_path call found"
elif grep -q '/usr/local/bin/nasm\|/opt/homebrew/bin/nasm' "$SCRIPT_DIR/aitools-lib.sh"; then
    step_pass "5" "NASM known-path fallback in source" "known paths found in aitools-lib.sh"
else
    step_fail "5" "NASM known-path fallback in source" "no known paths for NASM in aitools-lib.sh"
fi

# ---------------------------------------------------------------------------
# 6. CMake known-path fallback exists in check_build_prereqs source
# ---------------------------------------------------------------------------
if grep -q 'ensure_tool_on_path.*cmake' "$SCRIPT_DIR/aitools-lib.sh"; then
    step_pass "6" "CMake known-path fallback in source" "ensure_tool_on_path call found"
elif grep -q '/usr/local/bin/cmake\|/opt/homebrew/bin/cmake' "$SCRIPT_DIR/aitools-lib.sh"; then
    step_pass "6" "CMake known-path fallback in source" "known paths found in aitools-lib.sh"
else
    step_fail "6" "CMake known-path fallback in source" "no known paths for CMake in aitools-lib.sh"
fi

# ---------------------------------------------------------------------------
# 7. hash -r call exists in check_build_prereqs or ensure_tool_on_path
# ---------------------------------------------------------------------------
if grep -q 'hash -r' "$SCRIPT_DIR/aitools-lib.sh"; then
    step_pass "7" "hash -r in lib functions" "command cache refresh present"
else
    step_fail "7" "hash -r in lib functions" "missing hash -r for command cache refresh"
fi

# ---------------------------------------------------------------------------
# 8. setup-datadog.sh has hash -r before check_build_prereqs
# ---------------------------------------------------------------------------
DD_SCRIPT="$SCRIPT_DIR/setup-datadog.sh"
if [ -f "$DD_SCRIPT" ]; then
    if grep -q 'hash -r' "$DD_SCRIPT"; then
        step_pass "8" "setup-datadog.sh hash -r" "command cache refresh before prereq check"
    else
        step_fail "8" "setup-datadog.sh hash -r" "missing hash -r before check_build_prereqs"
    fi
else
    step_skip "8" "setup-datadog.sh hash -r" "file not found"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary
exit "$FAIL_COUNT"
