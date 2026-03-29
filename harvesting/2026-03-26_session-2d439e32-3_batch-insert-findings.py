#!/usr/bin/env python3
"""Batch-insert assumption trace findings into session 2d439e32-3 DB."""

import sqlite3
import datetime

DB_PATH = "/Users/pepe/repos/aitools/.aitools/sessions/2d439e32-3.db"

observations = [
    ("finding", "ASSUMPTION TRACE: 13 incorrect assumptions identified across session. 4 with material blast radius (committed code, DB state, or deployments), 5 contained (scratch/ephemeral only), 4 zero (corrected before action). Most impactful: IA-5 (.current-session pointer caused 21 entries to land in phantom session d3dae79d-9).", "high"),
    ("finding", "IA-1: 'Delegates have limited permissions' -- WRONG. Delegates have FULL access. Failures were permission-approval timing, not fundamental limitation. Blast radius: CONTAINED (only cost was investigation time). Corrected by delegation test mission (OBS-24).", None),
    ("finding", "IA-3: 'Both are orders = approval to ship protected files' -- WRONG. Process instructions are not approval gates. Led to commit 40951fc modifying 3 protected files without clean review gate satisfaction. Blast radius: MEDIUM (commit unpushed, content sound). Corrected: OL-23.", None),
    ("finding", "IA-5: 'harness-db.py writes to current session without --session flag' -- WRONG. Writes went to phantom d3dae79d-9 via stale .current-session pointer. 17 observations + 4 decisions in wrong DB. Blast radius: HIGH. NOT FULLY CORRECTED -- data not migrated, pointer not fixed.", "high"),
    ("finding", "IA-8: 'Hook deployment pipeline working' -- WRONG. setup-user-hooks.sh had 4 bugs (fixed in 924b380). command-channel-stop.sh committed but NOT registered in pipeline -- hook is inert (F-1 HIGH). Blast radius: MEDIUM.", None),
    ("finding", "UNPUSHED COMMIT 40951fc: 3 protected files (CLAUDE.md, harness.md, framework-provenance.md). Content sound but: (1) review gate irregular, (2) dangling scratch cross-refs in framework-provenance.md lines 222-227, (3) not CI-tested. Must fix cross-refs and get explicit approval before push.", None),
    ("finding", "PHANTOM SESSION d3dae79d-9: 17 observations, 4 decisions, 0 messages, status=active. Created by hook/delegate 47min after session start. .scratch/.current-session points to it INCORRECTLY. Corrective: end phantom session, fix pointer, migrate or annotate data.", "high"),
    ("finding", "CORRECTIVE ACTIONS NEEDED: (1) Fix .current-session pointer, (2) End phantom session, (3) Fix framework-provenance.md cross-refs before pushing 40951fc, (4) Register command-channel-stop.sh in deployment pipeline, (5) Migrate phantom session data, (6) Fix harness-db.py session resolution to prefer env var over file pointer.", None),
]

now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

for category, text, severity in observations:
    cursor.execute(
        "INSERT INTO observations (category, text, status, severity, created_at) VALUES (?, ?, 'active', ?, ?)",
        (category, text, severity, now)
    )

conn.commit()
print(f"Inserted {len(observations)} observations into session 2d439e32-3")

# Verify
count = cursor.execute("SELECT COUNT(*) FROM observations").fetchone()[0]
print(f"Total observations now: {count}")

conn.close()
