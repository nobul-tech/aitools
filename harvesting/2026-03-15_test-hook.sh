#!/usr/bin/env bash
# Test block-claude-code-guide hook with mock inputs
# Tests both the deny (JSON stdout, exit 0) and allow (no output, exit 0) paths.

HOOK="$HOME/.claude/hooks/block-claude-code-guide.sh"
PASS=0
FAIL=0

run_test() {
    local desc="$1" json="$2" expect_deny="$3"
    local stdout_file stderr_file
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)
    local actual_exit
    printf '%s' "$json" | bash "$HOOK" >"$stdout_file" 2>"$stderr_file"
    actual_exit=$?
    local stdout_content stderr_content
    stdout_content=$(cat "$stdout_file")
    stderr_content=$(cat "$stderr_file")
    rm -f "$stdout_file" "$stderr_file"

    if [ "$actual_exit" -ne 0 ]; then
        printf '  FAIL: %s (unexpected exit=%d)\n' "$desc" "$actual_exit"
        FAIL=$((FAIL + 1))
        return
    fi

    local has_deny="false"
    if printf '%s' "$stdout_content" | grep -q '"permissionDecision"'; then
        has_deny="true"
    fi

    if [ "$expect_deny" = "true" ] && [ "$has_deny" = "true" ]; then
        # Verify JSON is valid and contains expected fields
        if printf '%s' "$stdout_content" | grep -q '"deny"'; then
            printf '  PASS: %s (denied with corrective context)\n' "$desc"
            PASS=$((PASS + 1))
        else
            printf '  FAIL: %s (JSON missing deny decision)\n' "$desc"
            FAIL=$((FAIL + 1))
        fi
    elif [ "$expect_deny" = "false" ] && [ "$has_deny" = "false" ]; then
        printf '  PASS: %s (allowed, no output)\n' "$desc"
        PASS=$((PASS + 1))
    else
        printf '  FAIL: %s (expect_deny=%s, has_deny=%s)\n' "$desc" "$expect_deny" "$has_deny"
        FAIL=$((FAIL + 1))
    fi
}

# Additional: verify corrective content includes key references
test_corrective_content() {
    local stdout_file
    stdout_file=$(mktemp)
    printf '{"tool_name":"Agent","tool_input":{"subagent_type":"claude-code-guide","prompt":"test"}}' \
        | bash "$HOOK" >"$stdout_file" 2>/dev/null
    local content
    content=$(cat "$stdout_file")
    rm -f "$stdout_file"

    local checks=0 passed=0
    for keyword in "chrome-devtools" "hooks.md" "permissions.md" "sub-agents.md" "prompt" "command" "#34730"; do
        checks=$((checks + 1))
        if printf '%s' "$content" | grep -q "$keyword"; then
            passed=$((passed + 1))
        else
            printf '  FAIL: corrective content missing keyword: %s\n' "$keyword"
            FAIL=$((FAIL + 1))
        fi
    done
    if [ "$passed" -eq "$checks" ]; then
        printf '  PASS: corrective content has all %d required references\n' "$checks"
        PASS=$((PASS + 1))
    fi
}

echo "Testing block-claude-code-guide.sh hook"
echo "========================================"

# Should deny (JSON stdout with permissionDecision)
run_test "claude-code-guide denied" \
    '{"tool_name":"Agent","tool_input":{"subagent_type":"claude-code-guide","prompt":"test"}}' \
    true

# Should allow (exit 0, no output)
run_test "Explore allowed" \
    '{"tool_name":"Agent","tool_input":{"subagent_type":"Explore","prompt":"test"}}' \
    false

run_test "Plan allowed" \
    '{"tool_name":"Agent","tool_input":{"subagent_type":"Plan","prompt":"test"}}' \
    false

run_test "general-purpose allowed" \
    '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"test"}}' \
    false

run_test "custom agent allowed" \
    '{"tool_name":"Agent","tool_input":{"subagent_type":"my-custom-agent","prompt":"test"}}' \
    false

run_test "no subagent_type allowed" \
    '{"tool_name":"Agent","tool_input":{"prompt":"test"}}' \
    false

run_test "empty input allowed" \
    '{}' \
    false

echo ""
echo "--- Corrective content validation ---"
test_corrective_content

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
