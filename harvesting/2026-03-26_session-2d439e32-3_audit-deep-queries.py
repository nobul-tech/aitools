#!/usr/bin/env python3
"""Deep audit queries -- observation count discrepancy, column names, etc."""
import sqlite3
import os

BASE = "/Users/pepe/repos/aitools"
SESSION_DB = os.path.join(BASE, ".aitools/sessions/2d439e32-3.db")

db = sqlite3.connect(SESSION_DB)
db.row_factory = sqlite3.Row
cur = db.cursor()

# Get column names for observations
cur.execute("PRAGMA table_info(observations)")
cols = cur.fetchall()
print("=== Observations columns ===")
for c in cols:
    print(f"  {c['name']} ({c['type']})")

# Read all observations
cur.execute("SELECT * FROM observations")
rows = cur.fetchall()
print(f"\n=== Observations ({len(rows)}) ===")
for r in rows:
    text = r['text'][:100] if r['text'] else ""
    cat = r['category'] if 'category' in r.keys() else "N/A"
    print(f"  cat={cat}: {text}")

# Get column names for decisions
cur.execute("PRAGMA table_info(decisions)")
cols = cur.fetchall()
print("\n=== Decisions columns ===")
for c in cols:
    print(f"  {c['name']} ({c['type']})")

# Read all decisions
cur.execute("SELECT * FROM decisions")
rows = cur.fetchall()
print(f"\n=== Decisions ({len(rows)}) ===")
for r in rows:
    d = dict(r)
    title = d.get('title', '')[:120] if d.get('title') else ''
    print(f"  id={d.get('decision_id','?')}: {title}")

# Get column names for messages
cur.execute("PRAGMA table_info(messages)")
cols = cur.fetchall()
print("\n=== Messages columns ===")
for c in cols:
    print(f"  {c['name']} ({c['type']})")

# Count messages by role
cur.execute("SELECT agent_role, COUNT(*) FROM messages GROUP BY agent_role")
rows = cur.fetchall()
print(f"\n=== Messages by role ===")
for r in rows:
    print(f"  {r[0]}: {r[1]}")

# Check events table
cur.execute("PRAGMA table_info(events)")
cols = cur.fetchall()
print("\n=== Events columns ===")
for c in cols:
    print(f"  {c['name']} ({c['type']})")

cur.execute("SELECT COUNT(*) FROM events")
print(f"Events count: {cur.fetchone()[0]}")

# Check commander_directives
cur.execute("PRAGMA table_info(commander_directives)")
cols = cur.fetchall()
print("\n=== Commander directives columns ===")
for c in cols:
    print(f"  {c['name']} ({c['type']})")

cur.execute("SELECT * FROM commander_directives")
rows = cur.fetchall()
print(f"\n=== Commander directives ({len(rows)}) ===")
for r in rows:
    print(f"  {dict(r)}")

# Check session metadata
cur.execute("SELECT * FROM session")
rows = cur.fetchall()
print(f"\n=== Session metadata ===")
for r in rows:
    print(f"  {dict(r)}")

# Check completed_work
cur.execute("SELECT COUNT(*) FROM completed_work")
print(f"\nCompleted work: {cur.fetchone()[0]}")

# Check deviations
cur.execute("SELECT COUNT(*) FROM deviations")
print(f"Deviations: {cur.fetchone()[0]}")

# Check delegation_log
cur.execute("SELECT COUNT(*) FROM delegation_log")
print(f"Delegation log: {cur.fetchone()[0]}")

db.close()

# Also check the harness DB provenance tables
print("\n" + "=" * 60)
print("HARNESS DB PROVENANCE TABLES")
print("=" * 60)

db = sqlite3.connect(os.path.join(BASE, ".aitools/harness.db"))
db.row_factory = sqlite3.Row
cur = db.cursor()

# Knowledge items
cur.execute("SELECT * FROM knowledge_items")
rows = cur.fetchall()
print(f"\n=== Knowledge items ({len(rows)}) ===")
for r in rows:
    d = dict(r)
    content = d.get('content', '')[:80] if d.get('content') else ''
    print(f"  id={d.get('item_id','?')} type={d.get('item_type','?')} trust={d.get('trust_level','?')}: {content}")

# Provenance edges
cur.execute("SELECT * FROM provenance_edges")
rows = cur.fetchall()
print(f"\n=== Provenance edges ({len(rows)}) ===")
for r in rows:
    print(f"  {dict(r)}")

# Nogood sets
cur.execute("SELECT * FROM nogood_sets")
rows = cur.fetchall()
print(f"\n=== Nogood sets ({len(rows)}) ===")
for r in rows:
    print(f"  {dict(r)}")

db.close()
