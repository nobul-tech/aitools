#!/usr/bin/env bash
set -euo pipefail
DB=/Users/new-jose/repos/aitools/.aitools/sessions/c46487f0-8.db

echo "=== TABLES ==="
sqlite3 "$DB" ".tables"

echo ""
echo "=== ROW COUNTS PER TABLE ==="
for t in $(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"); do
  c=$(sqlite3 "$DB" "SELECT count(*) FROM \"$t\";")
  printf "%-28s %s\n" "$t" "$c"
done

echo ""
echo "=== SCHEMA ==="
sqlite3 "$DB" ".schema"
