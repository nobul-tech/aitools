#!/usr/bin/env bash
set -euo pipefail
DB=/Users/new-jose/repos/aitools/.aitools/sessions/c46487f0-8.db
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sqlite3 "$DB" "UPDATE session SET schwerpunkt = 'Formalize the SessionStart hook and how sessions populate agent identity — in terminal context and in the session DB', updated_at = '$NOW' WHERE session_id = 'c46487f0-8627-4df8-a1e9-6bbb8fb6d429';"
echo "=== updated session row ==="
sqlite3 -line "$DB" "SELECT session_id, schwerpunkt, updated_at, agent_identity FROM session;"
