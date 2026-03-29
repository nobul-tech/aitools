#!/usr/bin/env python3
"""Full audit queries against session and harness DBs."""
import sqlite3
import os

BASE = "/Users/pepe/repos/aitools"
SESSION_DB = os.path.join(BASE, ".aitools/sessions/2d439e32-3.db")
HARNESS_DB = os.path.join(BASE, ".aitools/harness.db")

def safe_count(cur, table):
    try:
        cur.execute(f"SELECT COUNT(*) FROM [{table}]")
        return cur.fetchone()[0]
    except Exception as e:
        return f"TABLE MISSING ({e})"

def list_tables(cur):
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    return [r[0] for r in cur.fetchall()]

# SESSION DB
print("=" * 60)
print("SESSION DB AUDIT:", SESSION_DB)
print("=" * 60)

db = sqlite3.connect(SESSION_DB)
cur = db.cursor()
tables = list_tables(cur)
print(f"Tables: {tables}")
for t in tables:
    print(f"  {t}: {safe_count(cur, t)} rows")

# Sample observations
try:
    cur.execute("SELECT id, category, text FROM observations ORDER BY id")
    rows = cur.fetchall()
    print(f"\nObservations ({len(rows)}):")
    for r in rows:
        text = r[2][:80] if r[2] else ""
        print(f"  [{r[0]}] cat={r[1]}: {text}")
except Exception as e:
    print(f"Error reading observations: {e}")

# Sample decisions
try:
    cur.execute("SELECT id, text FROM decisions ORDER BY id")
    rows = cur.fetchall()
    print(f"\nDecisions ({len(rows)}):")
    for r in rows:
        text = r[1][:80] if r[1] else ""
        print(f"  [{r[0]}]: {text}")
except Exception as e:
    print(f"Error reading decisions: {e}")

# Events
try:
    cur.execute("SELECT id, event_type, timestamp FROM events ORDER BY id")
    rows = cur.fetchall()
    print(f"\nEvents ({len(rows)}):")
    for r in rows:
        print(f"  [{r[0]}] {r[1]} at {r[2]}")
except Exception as e:
    print(f"Error reading events: {e}")

# Schema version
try:
    cur.execute("SELECT * FROM schema_version")
    rows = cur.fetchall()
    print(f"\nSchema version: {rows}")
except Exception as e:
    print(f"Error reading schema_version: {e}")

db.close()

# HARNESS DB
print("\n" + "=" * 60)
print("HARNESS DB AUDIT:", HARNESS_DB)
print("=" * 60)

db = sqlite3.connect(HARNESS_DB)
cur = db.cursor()
tables = list_tables(cur)
print(f"Tables: {tables}")
for t in tables:
    print(f"  {t}: {safe_count(cur, t)} rows")

# Sample session_index
try:
    cur.execute("SELECT * FROM session_index")
    rows = cur.fetchall()
    print(f"\nSession index ({len(rows)}):")
    for r in rows:
        print(f"  {r}")
except:
    pass

# Sample kpi_events
try:
    cur.execute("SELECT * FROM kpi_events ORDER BY rowid DESC LIMIT 5")
    rows = cur.fetchall()
    print(f"\nRecent KPI events:")
    for r in rows:
        print(f"  {r}")
except:
    pass

db.close()

# CURRENT SESSION
print("\n" + "=" * 60)
print("CURRENT SESSION POINTER")
print("=" * 60)
pointer_file = os.path.join(BASE, ".aitools/sessions/.current-session")
if os.path.exists(pointer_file):
    with open(pointer_file) as f:
        print(f"Contents: {f.read().strip()}")
else:
    print("FILE MISSING")
