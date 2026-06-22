#!/usr/bin/env bash
# Verify the fire-and-forget session-archive.sh: syntax, fast return, exit 0,
# and that no transcript_path -> the detached helper no-ops cleanly.
set -uo pipefail

HOOK="/Users/new-jose/repos/aitools/shared/hooks/session-archive.sh"

echo "=== 1. syntax check (bash -n) ==="
if bash -n "$HOOK"; then echo "syntax OK"; else echo "SYNTAX FAIL"; exit 1; fi

echo
echo "=== 2. smoke test: clean input, measure return time + exit code ==="
# Use a payload with no transcript_path so the detached helper exits fast
# (cmd_archive returns 0 immediately) and we don't archive a fake session.
payload='{"session_id":"verify-fire-forget","cwd":"/Users/new-jose/repos/aitools"}'
start=$(date +%s.%N 2>/dev/null || date +%s)
printf '%s' "$payload" | bash "$HOOK"
rc=$?
end=$(date +%s.%N 2>/dev/null || date +%s)
elapsed=$(perl -e "printf '%.3f', $end - $start")
echo "exit code: $rc"
echo "hook returned in: ${elapsed}s"

echo
echo "=== 3. confirm hook returns essentially instantly (< 1s) ==="
under1=$(perl -e "print(($end - $start) < 1.0 ? 'yes' : 'no')")
echo "under 1s: $under1"

echo
echo "=== done ==="
