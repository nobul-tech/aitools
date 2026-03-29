#!/usr/bin/env python3
"""Batch insert all audit findings into the session DB as observations."""
import sqlite3
import datetime

DB_PATH = "/Users/pepe/repos/aitools/.aitools/sessions/2d439e32-3.db"
NOW = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

findings = [
    {
        "category": "finding",
        "text": "F-1 HIGH: command-channel-stop.sh not registered. Hook exists in shared/hooks/ (committed 934d50c) but NOT in setup-user-hooks.sh/.ps1 deployment pipeline, NOT deployed to ~/.claude/hooks/, NOT in settings.json. Command channel uplink is inert -- commander directives via SQLite will never fire automatically.",
        "severity": "high",
    },
    {
        "category": "finding",
        "text": "F-2 HIGH: Phantom session d3dae79d-9 created 47 min after this session (at 23:45:41Z vs 22:58:10Z). Has 17 observations, 4 decisions, 0 messages. Status: active (never ended). .scratch/.current-session points to it incorrectly instead of 2d439e32-3.",
        "severity": "high",
    },
    {
        "category": "finding",
        "text": "F-3 MEDIUM: Dangling scratch cross-references in reference/framework-provenance.md lines 223-227. References 3 gitignored scratch files that won't survive machine switches. Violates cross-machine carry-forward principle.",
        "severity": "medium",
    },
    {
        "category": "finding",
        "text": "F-4 MEDIUM: Events table empty in session DB and no events.jsonl in scratch dist/. Telemetry rebuild v0.67.0 designed JSONL event emission from enforcement hooks but pipeline is not producing observable output.",
        "severity": "medium",
    },
    {
        "category": "finding",
        "text": "F-5 MEDIUM: 1 unpushed commit (40951fc 'Define Provenance as 6th harness component'). Modifies 3 protected files (CLAUDE.md, reference/harness.md, reference/framework-provenance.md). Not CI-tested.",
        "severity": "medium",
    },
    {
        "category": "finding",
        "text": "F-6 MEDIUM: Session schwerpunkt never set -- remains 'unspecified' throughout entire session 2d439e32-3.",
        "severity": "medium",
    },
    {
        "category": "finding",
        "text": "F-7 LOW: .aitools/sessions/.current-session file does not exist. Only .scratch/.current-session exists and points to wrong session (d3dae79d-9).",
        "severity": "low",
    },
    {
        "category": "finding",
        "text": "F-8 LOW: GitHub Actions Node.js 20 deprecation warning. actions/checkout@v4 runs on Node.js 20, deprecated June 2, 2026. Update CI workflow.",
        "severity": "low",
    },
    {
        "category": "finding",
        "text": "F-9 LOW: 11 .bak files accumulated in ~/.claude/hooks/ from deploy_managed_file backups. Not a bug but growing unbounded.",
        "severity": "low",
    },
    {
        "category": "finding",
        "text": "F-10 LOW: harness-db.py 'ol add' lean subcommand targets operational_learning table that doesn't exist in session DB schema v2. The subcommand will fail at runtime.",
        "severity": "low",
    },
    {
        "category": "observation",
        "text": "AUDIT PASS: All 4 most recent CI runs are green. Pre-commit check: 8 PASS/0 FAIL. Pre-push check: 6 PASS/0 FAIL. No script standards violations found. No unfiled TODO(incident) markers.",
        "severity": "low",
    },
    {
        "category": "observation",
        "text": "AUDIT PASS: nobulai.tools web portal fully functional. All 6 tabs rendering correctly. No JS console errors. Feedback system working (2 prior items verified with GitHub issue links). Static snapshot current (2026-03-26T00:33:03Z).",
        "severity": "low",
    },
    {
        "category": "observation",
        "text": "AUDIT PASS: Hook deployment pipeline fix (924b380) correctly removes stale Stop hooks. All 3 stale hooks gone from settings.json, disk, and deployment pipeline. Both .sh and .ps1 updated in lockstep.",
        "severity": "low",
    },
    {
        "category": "observation",
        "text": "AUDIT PASS: Provenance tables in harness.db are populated with seed data: 5 knowledge items, 2 provenance edges, 1 nogood set. Schema is functional.",
        "severity": "low",
    },
]

db = sqlite3.connect(DB_PATH)
cur = db.cursor()

inserted = 0
for f in findings:
    cur.execute(
        "INSERT INTO observations (category, text, status, severity, created_at) VALUES (?, ?, 'active', ?, ?)",
        (f["category"], f["text"], f["severity"], NOW),
    )
    inserted += 1

db.commit()
db.close()
print(f"Inserted {inserted} audit findings into session DB")
