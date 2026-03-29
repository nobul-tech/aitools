#!/usr/bin/env python3
"""Batch OL insert — one connection, one script, no friction."""
import sqlite3
from datetime import datetime, timezone

DB = "/Users/pepe/repos/aitools/.aitools/sessions/2d439e32-3.db"
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

entries = [
    ("fact", "CRITICAL: Batch all DB operations. Never call harness-db.py one entry at a time. Each Bash call has hook overhead (~50ms). Write a Python script, one connection, all inserts. 12 entries = 1 call not 12"),
    ("fact", "CRITICAL: Batch communication too. If you have 12 things to say to the commander, say them in 1 message not 12. Context window is precious. Every message costs. Consolidate"),
    ("fact", "Don't overcorrect. When corrected, fix the specific thing. Don't swing to the opposite extreme. The correction is a data point, not a reversal of everything"),
]

conn = sqlite3.connect(DB)
conn.execute("PRAGMA journal_mode=WAL")
for cat, text in entries:
    conn.execute(
        "INSERT INTO observations (category, text, status, created_at) VALUES (?, ?, 'verified', ?)",
        (cat, text, now)
    )
conn.commit()
conn.close()
print(f"Inserted {len(entries)} OL entries in 1 call")
