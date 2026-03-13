#!/usr/bin/env bash
# check-script-compliance.sh -- Verify setup scripts follow script-standards.md
# Usage: bash scripts/check-script-compliance.sh
# Checks: log format, exit footers, write_summary coverage, counter tracking,
#          raw echo/Write-Host, grep pipefail safety, OS guards, logging init,
#          cross-platform pairing, SilentlyContinue result checks, summary categories.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/check-lib.sh
source "$SCRIPT_DIR/check-lib.sh"
# shellcheck source=scripts/init-logging.sh
source "$SCRIPT_DIR/init-logging.sh"

# OS guard: use .ps1 on Windows
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use check-script-compliance.ps1."
        exit 1 ;;
esac

check_log_init "script-compliance"

cd "$REPO_ROOT"

echo ""
echo "${BOLD}=== SCRIPT STANDARDS COMPLIANCE ===${RESET}"
echo ""

# Collect target scripts
SH_SCRIPTS=()
PS1_SCRIPTS=()
for f in scripts/setup-*.sh; do
    [ -f "$f" ] && SH_SCRIPTS+=("$f")
done
[ -f "scripts/aitools-install.sh" ] && SH_SCRIPTS+=("scripts/aitools-install.sh")

for f in scripts/setup-*.ps1; do
    [ -f "$f" ] && PS1_SCRIPTS+=("$f")
done
[ -f "scripts/aitools-install.ps1" ] && PS1_SCRIPTS+=("scripts/aitools-install.ps1")

# ---------------------------------------------------------------------------
# 1. Log format compliance -- verify lib produces [ts] [script] [level] msg
# ---------------------------------------------------------------------------
step1_ok=true
if grep -q '\[level\]' scripts/aitools-lib.sh 2>/dev/null || \
   grep -q '\[\$level\]' scripts/aitools-lib.sh 2>/dev/null; then
    : # format string contains [level] or [$level]
else
    step1_ok=false
fi

if $step1_ok; then
    step_pass "1" "Log format compliance" "aitools-lib.sh uses [level] format"
else
    step_fail "1" "Log format compliance" "aitools-lib.sh missing [level] in format"
fi

# ---------------------------------------------------------------------------
# 2. Exit footer pattern -- every setup script has ERRORS + WARNINGS checks
# ---------------------------------------------------------------------------
step2_fail=0
step2_details=""
for f in "${SH_SCRIPTS[@]}"; do
    if ! grep -q 'WARNINGS' "$f" 2>/dev/null; then
        step2_fail=$((step2_fail + 1))
        step2_details="${step2_details} $(basename "$f")"
    fi
done
for f in "${PS1_SCRIPTS[@]}"; do
    if ! grep -q 'warnings' "$f" 2>/dev/null; then
        step2_fail=$((step2_fail + 1))
        step2_details="${step2_details} $(basename "$f")"
    fi
done

if [ "$step2_fail" -eq 0 ]; then
    step_pass "2" "Exit footer pattern" "all scripts check ERRORS + WARNINGS"
else
    step_fail "2" "Exit footer pattern" "${step2_fail} scripts missing WARNINGS:${step2_details}"
fi

# ---------------------------------------------------------------------------
# 3. write_summary coverage -- every exit 1 has preceding write_summary
#    Exempt: OS guard exits (MINGW/MSYS/CYGWIN in context), main exit footer
#    (ERRORS in context), Windows forwarding blocks (ps1_installer/PowerShell).
# ---------------------------------------------------------------------------
step3_fail=0
step3_details=""
for f in "${SH_SCRIPTS[@]}"; do
    # Find lines with 'exit 1' (not in comments)
    exit_lines=$(grep -n 'exit 1' "$f" 2>/dev/null | grep -v '^\s*#' | grep -v 'esac' || true)
    while IFS= read -r eline; do
        [ -z "$eline" ] && continue
        lineno=$(echo "$eline" | cut -d: -f1)
        # Check preceding 10 lines for context
        start=$((lineno > 10 ? lineno - 10 : 1))
        context=$(sed -n "${start},${lineno}p" "$f")
        # Skip if write_summary is present
        if echo "$context" | grep -q 'write_summary' 2>/dev/null; then continue; fi
        # Skip if this is the main exit footer (ERRORS check)
        if echo "$context" | grep -q 'ERRORS' 2>/dev/null; then continue; fi
        # Skip OS guard exits (fire before summary is available)
        if echo "$context" | grep -q 'MINGW\|MSYS\|CYGWIN' 2>/dev/null; then continue; fi
        # Skip Windows forwarding blocks
        if echo "$context" | grep -q 'ps1_installer\|PowerShell\|ps_args\|cygpath' 2>/dev/null; then continue; fi
        # Skip log_error exits in script body (error is tracked by counter)
        if echo "$context" | grep -q 'log_error' 2>/dev/null; then continue; fi
        step3_fail=$((step3_fail + 1))
        step3_details="${step3_details} $(basename "$f"):${lineno}"
    done <<< "$exit_lines"
done

if [ "$step3_fail" -eq 0 ]; then
    step_pass "3" "write_summary before exit 1" "all early exits have summary"
else
    step_fail "3" "write_summary before exit 1" "${step3_fail} gaps:${step3_details}"
fi

# ---------------------------------------------------------------------------
# 4. Error counter tracking -- log_error increments ERRORS in lib
# ---------------------------------------------------------------------------
if grep -A2 'log_error' scripts/aitools-lib.sh 2>/dev/null | grep -q 'ERRORS='; then
    step_pass "4" "Error counter tracking (bash)" "log_error increments ERRORS"
else
    step_fail "4" "Error counter tracking (bash)" "log_error does not increment ERRORS"
fi

# ---------------------------------------------------------------------------
# 5. Warning counter tracking -- log_warn increments WARNINGS in lib
# ---------------------------------------------------------------------------
if grep -A2 'log_warn' scripts/aitools-lib.sh 2>/dev/null | grep -q 'WARNINGS='; then
    step_pass "5" "Warning counter tracking (bash)" "log_warn increments WARNINGS"
else
    step_fail "5" "Warning counter tracking (bash)" "log_warn does not increment WARNINGS"
fi

# ---------------------------------------------------------------------------
# 6. No raw echo/Write-Host in setup scripts
# ---------------------------------------------------------------------------
step6_fail=0
step6_details=""
for f in "${SH_SCRIPTS[@]}"; do
    # Skip aitools-install.sh (has legitimate echo for help text and prompts)
    [ "$(basename "$f")" = "aitools-install.sh" ] && continue
    # Look for bare 'echo' not in comments, not in heredocs
    raw_echos=$(grep -n '^\s*echo ' "$f" 2>/dev/null | grep -v '^\s*#' | grep -v 'echo ""' || true)
    if [ -n "$raw_echos" ]; then
        count=$(echo "$raw_echos" | wc -l | tr -d ' ')
        step6_fail=$((step6_fail + count))
        step6_details="${step6_details} $(basename "$f")(${count})"
    fi
done

if [ "$step6_fail" -eq 0 ]; then
    step_pass "6" "No raw echo in setup scripts" "all use structured logging"
else
    step_warn "6" "No raw echo in setup scripts" "${step6_fail} raw echo(s):${step6_details}"
fi

# ---------------------------------------------------------------------------
# 7. Grep pipefail safety -- grep without || true in pipefail scripts
# ---------------------------------------------------------------------------
step7_fail=0
step7_details=""
for f in "${SH_SCRIPTS[@]}"; do
    # Only check scripts with set -euo pipefail
    if ! grep -q 'set -euo pipefail' "$f" 2>/dev/null; then continue; fi
    # Find grep in $() command substitutions without || true
    # Match: $(... grep ... | head ...) without || true
    unsafe=$(grep -n 'grep' "$f" 2>/dev/null | grep -v '^\s*#' | grep -v '|| true' | grep -v 'if ' | grep -v 'command -v' | grep -v '&>/dev/null' || true)
    if [ -n "$unsafe" ]; then
        # Filter to only pipeline greps (most dangerous)
        pipeline_unsafe=$(echo "$unsafe" | grep '|' || true)
        if [ -n "$pipeline_unsafe" ]; then
            count=$(echo "$pipeline_unsafe" | wc -l | tr -d ' ')
            step7_fail=$((step7_fail + count))
            step7_details="${step7_details} $(basename "$f")(${count})"
        fi
    fi
done

if [ "$step7_fail" -eq 0 ]; then
    step_pass "7" "Grep pipefail safety" "no unsafe grep pipelines"
else
    step_warn "7" "Grep pipefail safety" "${step7_fail} potential issues:${step7_details}"
fi

# ---------------------------------------------------------------------------
# 8. OS guard present
# ---------------------------------------------------------------------------
step8_fail=0
step8_details=""
for f in "${SH_SCRIPTS[@]}"; do
    if ! grep -q 'MINGW\|MSYS\|CYGWIN' "$f" 2>/dev/null; then
        step8_fail=$((step8_fail + 1))
        step8_details="${step8_details} $(basename "$f")"
    fi
done

if [ "$step8_fail" -eq 0 ]; then
    step_pass "8" "OS guard present (.sh)" "all have MINGW/MSYS/CYGWIN guard"
else
    step_fail "8" "OS guard present (.sh)" "${step8_fail} missing:${step8_details}"
fi

# ---------------------------------------------------------------------------
# 9. Logging init present
# ---------------------------------------------------------------------------
step9_fail=0
step9_details=""
for f in "${SH_SCRIPTS[@]}"; do
    if ! grep -q 'logging_init' "$f" 2>/dev/null; then
        step9_fail=$((step9_fail + 1))
        step9_details="${step9_details} $(basename "$f")"
    fi
done

if [ "$step9_fail" -eq 0 ]; then
    step_pass "9" "Logging init present (.sh)" "all call logging_init"
else
    step_fail "9" "Logging init present (.sh)" "${step9_fail} missing:${step9_details}"
fi

# ---------------------------------------------------------------------------
# 10. Cross-platform pairing
# ---------------------------------------------------------------------------
step10_fail=0
step10_details=""
for f in "${SH_SCRIPTS[@]}"; do
    base=$(basename "$f" .sh)
    ps1_file="scripts/${base}.ps1"
    if [ ! -f "$ps1_file" ]; then
        step10_fail=$((step10_fail + 1))
        step10_details="${step10_details} ${base}.sh"
    fi
done
for f in "${PS1_SCRIPTS[@]}"; do
    base=$(basename "$f" .ps1)
    sh_file="scripts/${base}.sh"
    if [ ! -f "$sh_file" ]; then
        step10_fail=$((step10_fail + 1))
        step10_details="${step10_details} ${base}.ps1"
    fi
done

if [ "$step10_fail" -eq 0 ]; then
    step_pass "10" "Cross-platform pairing" "all .sh have .ps1 and vice versa"
else
    step_fail "10" "Cross-platform pairing" "${step10_fail} unpaired:${step10_details}"
fi

# ---------------------------------------------------------------------------
# 11. -ErrorAction SilentlyContinue has result check (PS1 scripts)
# ---------------------------------------------------------------------------
step11_fail=0
step11_details=""
for f in "${PS1_SCRIPTS[@]}"; do
    # Find lines with -ErrorAction SilentlyContinue (not in comments)
    sc_lines=$(grep -n 'ErrorAction SilentlyContinue' "$f" 2>/dev/null | grep -v '^\s*#' || true)
    while IFS= read -r sc_line; do
        [ -z "$sc_line" ] && continue
        lineno=$(echo "$sc_line" | cut -d: -f1)
        # Check next 3 lines for a null/result check
        check_start=$((lineno + 1))
        check_end=$((lineno + 3))
        total_lines=$(wc -l < "$f" | tr -d ' ')
        [ "$check_end" -gt "$total_lines" ] && check_end=$total_lines
        nearby=$(sed -n "${check_start},${check_end}p" "$f")
        # Look for result checks: -not, if, .Count, .Length, null, catch
        if echo "$nearby" | grep -qE '\-not|\bif\b|\.Count|\.Length|null|catch' 2>/dev/null; then
            continue
        fi
        # Exempt: command-existence checks (Get-Command with explicit fallback)
        preceding_start=$((lineno > 3 ? lineno - 3 : 1))
        preceding=$(sed -n "${preceding_start},${lineno}p" "$f")
        if echo "$preceding" | grep -q 'Get-Command' 2>/dev/null; then continue; fi
        # Also exempt if same line has a result check comment
        if echo "$sc_line" | grep -q 'checked on' 2>/dev/null; then continue; fi
        step11_fail=$((step11_fail + 1))
        step11_details="${step11_details} $(basename "$f"):${lineno}"
    done <<< "$sc_lines"
done

if [ "$step11_fail" -eq 0 ]; then
    step_pass "11" "SilentlyContinue has result check" "all occurrences verified"
else
    step_fail "11" "SilentlyContinue has result check" "${step11_fail} unchecked:${step11_details}"
fi

# ---------------------------------------------------------------------------
# 12. write_summary uses valid categories
# ---------------------------------------------------------------------------
step12_fail=0
step12_details=""
valid_cats="OK|WARN|ERROR|ACTION|DETAIL"
for f in "${SH_SCRIPTS[@]}"; do
    bad_cats=$(grep -n 'write_summary' "$f" 2>/dev/null | grep -v '^\s*#' | grep -vE "write_summary (${valid_cats}) " || true)
    if [ -n "$bad_cats" ]; then
        count=$(echo "$bad_cats" | wc -l | tr -d ' ')
        step12_fail=$((step12_fail + count))
        step12_details="${step12_details} $(basename "$f")(${count})"
    fi
done
for f in "${PS1_SCRIPTS[@]}"; do
    bad_cats=$(grep -n 'Write-Summary' "$f" 2>/dev/null | grep -v '^\s*#' | grep -vE "Write-Summary \"(${valid_cats})\"" || true)
    if [ -n "$bad_cats" ]; then
        count=$(echo "$bad_cats" | wc -l | tr -d ' ')
        step12_fail=$((step12_fail + count))
        step12_details="${step12_details} $(basename "$f")(${count})"
    fi
done

if [ "$step12_fail" -eq 0 ]; then
    step_pass "12" "write_summary valid categories" "all use OK/WARN/ERROR/ACTION/DETAIL"
else
    step_fail "12" "write_summary valid categories" "${step12_fail} invalid:${step12_details}"
fi

# ---------------------------------------------------------------------------
# 13. write_summary auto-promotion -- OK promoted to WARN when WARNINGS > 0
# ---------------------------------------------------------------------------
step13_ok=true
ws_body_sh=$(perl -0777 -ne 'print $1 if /^write_summary\(\)\s*\{(.*?)^\}/sm' scripts/aitools-lib.sh)
if [ -z "$ws_body_sh" ] || ! printf '%s' "$ws_body_sh" | grep -q 'WARNINGS'; then
    step13_ok=false
fi
ws_body_ps1=$(perl -0777 -ne 'print $1 if /^function Write-Summary.*?\{(.*?)^\}/sm' scripts/aitools-lib.ps1)
if [ -z "$ws_body_ps1" ] || ! printf '%s' "$ws_body_ps1" | grep -q 'warnings'; then
    step13_ok=false
fi

if $step13_ok; then
    step_pass "13" "write_summary auto-promotion" "OK->WARN when WARNINGS > 0"
else
    step_fail "13" "write_summary auto-promotion" "write_summary missing WARNINGS auto-promotion"
fi

# ---------------------------------------------------------------------------
# Summary + exit
# ---------------------------------------------------------------------------
print_summary

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
else
    exit 0
fi
