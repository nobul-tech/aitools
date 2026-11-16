"""Probe: how does v4-style DDL behave when `observations` is a VIEW (v5 design)?

Uses a throwaway DB in this scratch dir only. Never touches a real session DB.
"""
from __future__ import annotations

import os
import sqlite3
import sys

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe.db")
if os.path.exists(path):
    os.remove(path)
conn = sqlite3.connect(path)
print("sqlite", sqlite3.sqlite_version, "python", sys.version.split()[0])
conn.executescript(
    """
    CREATE TABLE items (id TEXT, type TEXT, text TEXT, created_at TEXT);
    CREATE VIEW observations AS
        SELECT rowid AS observation_id, type AS category, text, created_at FROM items;
    """
)
cols = [r[1] for r in conn.execute('PRAGMA table_info("observations")')]
print("table_info(view) columns:", cols)
print("v4 _observations_need_v4 would return:", bool(cols) and "legacy_category" not in cols)

for label, sql in [
    ("CREATE TABLE IF NOT EXISTS on a view name",
     "CREATE TABLE IF NOT EXISTS observations (observation_id INTEGER PRIMARY KEY, category TEXT)"),
    ("CREATE INDEX IF NOT EXISTS on the view",
     "CREATE INDEX IF NOT EXISTS idx_observations_category ON observations(category)"),
    ("DROP TABLE on the view (v4 _rebuild_table path)", 'DROP TABLE "observations"'),
    ("INSERT into the view (v4 observation add path)",
     "INSERT INTO observations (category, text, created_at) VALUES ('observation','x','t')"),
]:
    try:
        conn.execute(sql)
        print(f"{label}: OK (no error)")
    except sqlite3.Error as e:
        print(f"{label}: ERROR {type(e).__name__}: {e}")

try:
    conn.execute("SELECT json_extract('{\"a\":1}', '$.a')").fetchone()
    print("json_extract available")
except sqlite3.Error as e:
    print("json_extract unavailable:", e)
conn.close()
os.remove(path)
