#!/usr/bin/env bash
set -euo pipefail
SESS_DIR="/Users/new-jose/repos/aitools/.aitools/sessions"
rm -f "$SESS_DIR/testwire01.db"
rm -f "$SESS_DIR/testwire01.db-shm"
rm -f "$SESS_DIR/testwire01.db-wal"
sqlite3 /Users/new-jose/.aitools/harness.db \
  "DELETE FROM session_index WHERE session_id = 'testwire01-fresh-insert-check';"
echo "cleanup done; remaining testwire files:"
ls "$SESS_DIR" | grep testwire || echo "  none"
echo "remaining harness index rows for testwire:"
sqlite3 /Users/new-jose/.aitools/harness.db \
  "SELECT count(*) FROM session_index WHERE session_id LIKE 'testwire%';"
