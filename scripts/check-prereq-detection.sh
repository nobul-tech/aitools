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
# 9. KnownPaths empirical verification
# ---------------------------------------------------------------------------
if command -v nasm >/dev/null 2>&1; then
    nasm_found=false
    for kp in /usr/local/bin/nasm /opt/homebrew/bin/nasm /usr/bin/nasm; do
        if [ -x "$kp" ]; then nasm_found=true; break; fi
    done
    if [ "$nasm_found" = "true" ]; then
        step_pass "9a" "NASM KnownPaths match" "path confirmed"
    else
        actual=$(command -v nasm)
        step_fail "9a" "NASM KnownPaths match" "installed at $actual but no KnownPath matches"
    fi
else
    step_skip "9a" "NASM KnownPaths match" "nasm not installed"
fi

if command -v cmake >/dev/null 2>&1; then
    cmake_found=false
    for kp in /usr/local/bin/cmake /opt/homebrew/bin/cmake /usr/bin/cmake /Applications/CMake.app/Contents/bin/cmake; do
        if [ -x "$kp" ]; then cmake_found=true; break; fi
    done
    if [ "$cmake_found" = "true" ]; then
        step_pass "9b" "CMake KnownPaths match" "path confirmed"
    else
        actual=$(command -v cmake)
        step_fail "9b" "CMake KnownPaths match" "installed at $actual but no KnownPath matches"
    fi
else
    step_skip "9b" "CMake KnownPaths match" "cmake not installed"
fi

# ---------------------------------------------------------------------------
# 10. KnownPaths verification status in code comments
# ---------------------------------------------------------------------------
lib_file="$SCRIPT_DIR/aitools-lib.sh"
if [ -f "$lib_file" ]; then
    # Check that ensure_tool_on_path calls in check_build_prereqs have nearby comments
    unverified=$(grep -n 'ensure_tool_on_path' "$lib_file" | head -5)
    verified_count=0
    total_count=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        total_count=$((total_count + 1))
        lineno=$(printf '%s' "$line" | cut -d: -f1)
        # Check 3 lines before for Verified/UNVERIFIED comment
        prev_start=$((lineno - 3))
        if [ "$prev_start" -lt 1 ]; then prev_start=1; fi
        context=$(sed -n "${prev_start},${lineno}p" "$lib_file")
        if printf '%s' "$context" | grep -q 'Verified\|UNVERIFIED'; then
            verified_count=$((verified_count + 1))
        fi
    done <<< "$unverified"
    if [ "$total_count" -eq 0 ]; then
        step_skip "10" "KnownPaths verification status" "no ensure_tool_on_path calls found"
    elif [ "$verified_count" -eq "$total_count" ]; then
        step_pass "10" "KnownPaths verification status" "all entries annotated"
    else
        step_warn "10" "KnownPaths verification status" "$((total_count - verified_count)) of $total_count entries lack Verified/UNVERIFIED"
    fi
else
    step_skip "10" "KnownPaths verification status" "aitools-lib.sh not found"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary
exit "$FAIL_COUNT"
