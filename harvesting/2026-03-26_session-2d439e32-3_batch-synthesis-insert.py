#!/usr/bin/env python3
"""Batch-insert synthesis findings into session DB 2d439e32-3."""

import sqlite3
import datetime

DB_PATH = "/Users/pepe/repos/aitools/.aitools/sessions/2d439e32-3.db"
NOW = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

conn = sqlite3.connect(DB_PATH)
c = conn.cursor()

# Get the current max observation_id
max_id = c.execute("SELECT MAX(observation_id) FROM observations").fetchone()[0] or 0
print(f"Current max observation_id: {max_id}")

observations = [
    ("finding", "SYNTHESIS: Phantom session d3dae79d-9 was created by a second CC session at 16:45 local. scratch-init.sh overwrote .current-session (line 70, last-write-wins). 17 observations and 4 decisions written to wrong DB by delegates reading stale pointer. All data is orphaned duplicates -- canonical versions exist in 2d439e32-3.db.", "verified", "high"),
    ("finding", "SYNTHESIS: command-channel-stop.sh (F-1 HIGH) is committed in shared/hooks/ (934d50c) but NOT in setup-user-hooks.sh/.ps1 deployment lists. Hook is inert -- will never deploy to ~/.claude/hooks/ or register in settings.json. Command channel uplink non-functional.", "active", "high"),
    ("finding", "SYNTHESIS: harness.db is empty (0 bytes, no tables). Despite audit reporting populated provenance tables, the file was recreated empty. Provenance seed data (5 knowledge_items, 2 provenance_edges, 1 nogood_set) from prior session is lost.", "active", "high"),
    ("finding", "SYNTHESIS: 1 unpushed commit (40951fc, Provenance as 6th harness component). 3 protected files modified. Not CI-tested. Sits ahead of origin/main.", "active", "medium"),
    ("fact", "SYNTHESIS: 5 commits this session, all correct in intent. 924b380 (hook fix), 8a5e869 (harvest 49 artifacts), 934d50c (deploy rebuild + hook), d33fcf3 (v0.67.1 release, pushed, CI green), 40951fc (provenance framework, not pushed).", "verified", None),
    ("fact", "SYNTHESIS: 18 Vercel deployments to nobulai.tools during session. All Ready. Latest serves current data (snapshot 00:33Z). All 6 tabs functional, no JS errors, feedback system working.", "verified", None),
    ("fact", "SYNTHESIS: Deployed hooks match committed sources (12 of 13 hooks). Drift: command-channel-stop.sh committed but not deployed. 11 .bak files accumulated. settings.json correct.", "verified", None),
    ("fact", "SYNTHESIS: Session DB data integrity confirmed. Main DB (2d439e32-3) has complete canonical data: 38 observations, 3 decisions, 65 messages, 3 directives. Phantom DB (d3dae79d-9) has orphaned duplicates only.", "verified", None),
    ("fact", "SYNTHESIS: 14 audit findings -- 2 HIGH, 4 MEDIUM, 4 LOW, 4 PASS. 0 findings resolved during session. All HIGH/MEDIUM still open. Session produced 61 work product files across scripts, docs, proposals, screenshots, logs.", "verified", None),
]

for i, (cat, text, status, severity) in enumerate(observations, start=1):
    new_id = max_id + i
    c.execute(
        "INSERT INTO observations (observation_id, category, text, status, evidence, severity, created_at) VALUES (?, ?, ?, ?, NULL, ?, ?)",
        (new_id, cat, text, status, severity, NOW)
    )
    print(f"  Inserted observation {new_id}: {text[:60]}...")

# Update session updated_at
c.execute("UPDATE session SET updated_at = ?", (NOW,))

conn.commit()
print(f"\nInserted {len(observations)} observations. Session updated_at set to {NOW}.")

# Verify
total = c.execute("SELECT COUNT(*) FROM observations").fetchone()[0]
print(f"Total observations now: {total}")

conn.close()
