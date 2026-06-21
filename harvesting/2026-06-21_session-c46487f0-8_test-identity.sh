#!/usr/bin/env bash
set -euo pipefail
cd /Users/new-jose/repos/aitools

echo "=== 1. py syntax check ==="
python3 -m py_compile scripts/harness-db.py && echo "OK: compiles"

echo ""
echo "=== 2. commander_name() unit check ==="
python3 -c "import importlib.util, sys
spec = importlib.util.spec_from_file_location('hdb', 'scripts/harness-db.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
sid='c46487f0-8627-4df8-a1e9-6bbb8fb6d429'
print('short  :', m.session_prefix(sid))
print('ident  :', m.commander_name(sid))
assert m.commander_name(sid)=='Session Commander c46487f0-8', 'mismatch'
print('OK: identity string correct')"

echo ""
echo "=== 3. idempotent re-run of session start (back-fill live row) ==="
python3 scripts/harness-db.py session start --id c46487f0-8627-4df8-a1e9-6bbb8fb6d429

echo ""
echo "=== 4. read back agent_identity from this session DB ==="
sqlite3 -line .aitools/sessions/c46487f0-8.db "SELECT session_id, agent_identity, schwerpunkt FROM session;"
