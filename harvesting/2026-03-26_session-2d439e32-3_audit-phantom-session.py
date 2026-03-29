#!/usr/bin/env python3
"""Check the phantom d3dae79d session."""
import sqlite3
import os

BASE = "/Users/pepe/repos/aitools"
PHANTOM_DB = os.path.join(BASE, ".aitools/sessions/d3dae79d-9.db")

if not os.path.exists(PHANTOM_DB):
    print(f"PHANTOM DB NOT FOUND: {PHANTOM_DB}")
else:
    db = sqlite3.connect(PHANTOM_DB)
    db.row_factory = sqlite3.Row
    cur = db.cursor()

    cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    tables = [r['name'] for r in cur.fetchall()]
    print(f"Tables: {tables}")

    for t in tables:
        cur.execute(f"SELECT COUNT(*) FROM [{t}]")
        print(f"  {t}: {cur.fetchone()[0]} rows")

    cur.execute("SELECT * FROM session")
    rows = cur.fetchall()
    for r in rows:
        print(f"\nSession: {dict(r)}")

    db.close()

# Check .current-session file existence
pointer = os.path.join(BASE, ".aitools/sessions/.current-session")
print(f"\n.current-session exists: {os.path.exists(pointer)}")

# Check .scratch/.current-session
scratch_pointer = os.path.join(BASE, ".scratch/.current-session")
print(f".scratch/.current-session exists: {os.path.exists(scratch_pointer)}")
if os.path.exists(scratch_pointer):
    with open(scratch_pointer) as f:
        print(f"Contents: {f.read().strip()}")

# Check all session scratch dirs
for d in os.listdir(os.path.join(BASE, ".scratch")):
    if d.startswith("session-"):
        print(f"\n.scratch/{d}/")
