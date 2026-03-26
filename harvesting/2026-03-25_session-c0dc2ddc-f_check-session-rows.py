#!/usr/bin/env python3
"""Check session table rows."""
import sqlite3

DB = "/Users/pepe/repos/aitools/.aitools/sessions/c0dc2ddc-f.db"
conn = sqlite3.connect(DB)
conn.row_factory = sqlite3.Row
rows = conn.execute("SELECT * FROM session").fetchall()
for r in rows:
    print(dict(r))
conn.close()
