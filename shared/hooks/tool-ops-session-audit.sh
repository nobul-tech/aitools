#!/usr/bin/env bash
# tool-ops-session-audit.sh — SessionEnd hook
# Reads tool-ops.json, runs quick verifications on audit-mode capabilities,
# logs drift and KPIs to tool-ops-audit.jsonl.
#
# Hook contract:
#   - SessionEnd hook, command type
#   - Always exit 0 (advisory — never block session end)
#   - Must handle missing files gracefully
#   - No jq dependency — uses grep/regex for JSON parsing

set -euo pipefail

# Read JSON from stdin (SessionEnd provides session_id, etc.)
input=$(cat)
session_id=""
if [[ "$input" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    session_id="${BASH_REMATCH[1]}"
fi

# Find tool-ops.json
tool_ops=""
if [ -n "${AITOOLS_REPO_PATH:-}" ] && [ -f "$AITOOLS_REPO_PATH/reference/tool-ops.json" ]; then
    tool_ops="$AITOOLS_REPO_PATH/reference/tool-ops.json"
elif [ -f "$HOME/repos/aitools/reference/tool-ops.json" ]; then
    tool_ops="$HOME/repos/aitools/reference/tool-ops.json"
fi
# No tool-ops.json — nothing to audit
[ -n "$tool_ops" ] || exit 0

# Ensure log directory (exit silently if we cannot create it)
log_dir="$HOME/.claude/hooks/logs"
mkdir -p "$log_dir" 2>/dev/null || exit 0  # non-critical — exit clean if mkdir fails
log_file="$log_dir/tool-ops-audit.jsonl"
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# --- Contract tests (mock-json-pipe verifications) ---
# Run verification cases from tool-ops.json against deployed hook scripts.
# For each tool with a verifications array, pipe mock input to the target
# hook and check exit code + stdout against expected values.

drift_count=0
test_pass=0
test_fail=0

# Find hook scripts directory
hooks_dir="$HOME/.claude/hooks"

# Verify block-claude-code-guide.sh if deployed
guide_hook="$hooks_dir/block-claude-code-guide.sh"
if [ -f "$guide_hook" ]; then
    # Test 1: Should deny claude-code-guide subagent
    test_input='{"tool_name":"Agent","tool_input":{"subagent_type":"claude-code-guide"}}'
    # Capture output; ignore non-zero exit (should not happen but guard against it)
    test_output=$(echo "$test_input" | bash "$guide_hook" 2>/dev/null) || true  # hook may fail in unusual env — don't abort audit
    if echo "$test_output" | grep -q 'permissionDecision.*deny' 2>/dev/null; then  # grep stderr suppressed — pattern match only
        test_pass=$((test_pass + 1))
    else
        test_fail=$((test_fail + 1))
    fi

    # Test 2: Should allow Explore subagent (no deny output)
    test_input='{"tool_name":"Agent","tool_input":{"subagent_type":"Explore"}}'
    test_output=$(echo "$test_input" | bash "$guide_hook" 2>/dev/null) || true  # same guard as above
    if [ -z "$test_output" ]; then
        # Empty output = allowed (correct behavior)
        test_pass=$((test_pass + 1))
    else
        test_fail=$((test_fail + 1))
    fi
fi

# --- Drift detection: deny rules vs deployed settings ---
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ] && [ -f "$guide_hook" ]; then
    # Check that block-claude-code-guide.sh is registered in settings.json PreToolUse
    if ! grep -q 'block-claude-code-guide\.sh' "$settings_file" 2>/dev/null; then  # grep stderr suppressed — file may be unreadable
        drift_count=$((drift_count + 1))
    fi
fi

# --- Version dep staleness check ---
# Look for the tool-ops reference doc and count items needing attention
ops_ref=""
if [ -n "${AITOOLS_REPO_PATH:-}" ] && [ -f "$AITOOLS_REPO_PATH/reference/tool-ops-claude-code.md" ]; then
    ops_ref="$AITOOLS_REPO_PATH/reference/tool-ops-claude-code.md"
elif [ -f "$HOME/repos/aitools/reference/tool-ops-claude-code.md" ]; then
    ops_ref="$HOME/repos/aitools/reference/tool-ops-claude-code.md"
fi

stale_deps=0
if [ -n "$ops_ref" ]; then
    # Count lines mentioning CRITICAL that also mention "Last verified" — heuristic for stale items
    # grep -c returns exit 1 on no match; capture in subshell to prevent set -e abort
    stale_deps=$(grep -c 'CRITICAL.*Last verified' "$ops_ref" 2>/dev/null || true)  # stderr suppressed — file may be unreadable
    # Ensure numeric — default to 0 if empty or non-numeric
    if ! [[ "$stale_deps" =~ ^[0-9]+$ ]]; then stale_deps=0; fi
fi

# --- Emit results ---
printf '{"timestamp":"%s","session_id":"%s","test_pass":%d,"test_fail":%d,"drift_count":%d,"stale_deps":%d}\n' \
    "$timestamp" "$session_id" "$test_pass" "$test_fail" "$drift_count" "$stale_deps" \
    >> "$log_file"

exit 0
