#!/usr/bin/env bash
# Smoke-test block-explore-agent.sh: allow path + block path.
set -uo pipefail
HOOK=/Users/new-jose/repos/aitools/shared/hooks/block-explore-agent.sh

echo "===== ALLOW: general-purpose (expect exit 0, NO output) ====="
printf '%s' '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}' | bash "$HOOK"
echo "exit: $?"

echo
echo "===== ALLOW: Plan (expect exit 0, NO output) ====="
printf '%s' '{"tool_name":"Agent","tool_input":{"subagent_type":"Plan","prompt":"x"}}' | bash "$HOOK"
echo "exit: $?"

echo
echo "===== BLOCK: Explore (expect exit 0 + deny JSON) ====="
printf '%s' '{"tool_name":"Agent","tool_input":{"subagent_type":"Explore","prompt":"x"}}' | bash "$HOOK"
echo "exit: $?"
