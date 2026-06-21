#!/usr/bin/env bash
set -euo pipefail
cd /Users/new-jose/repos/aitools

FAKE_ID="smoke0test-1111-2222-3333-444455556666"
SHORT="smoke0test"
LOG=.scratch/session-c46487f0-8/smoke-hook.out

echo "=== run DEPLOYED hook with throwaway session id ==="
printf '{"session_id":"%s","cwd":"%s"}' "$FAKE_ID" "$PWD" \
  | bash "$HOME/.claude/hooks/harness-db-sessionstart.sh" > "$LOG" 2>&1 || true
echo "exit captured; stdout:"
cat "$LOG"

echo ""
echo "=== assertions ==="
grep -q "This is Session Commander $SHORT" "$LOG" && echo "OK: announcement line present" || echo "FAIL: announcement missing"
sqlite3 -line .aitools/sessions/${SHORT}.db "SELECT agent_identity FROM session;" 2>/dev/null || echo "(no db row)"

echo ""
echo "=== cleanup throwaway session ==="
rm -f .aitools/sessions/${SHORT}.db .aitools/sessions/${SHORT}.db-shm .aitools/sessions/${SHORT}.db-wal
rm -rf .scratch/session-${SHORT}
sqlite3 .aitools/harness.db "DELETE FROM session_index WHERE session_id='$FAKE_ID';" 2>/dev/null || true
echo "cleaned. remaining smoke artifacts:"
ls .aitools/sessions/ | grep -i smoke || echo "none"
