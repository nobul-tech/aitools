#!/usr/bin/env python3
"""harness-db.py -- CLI for aitools harness SQLite database operations.

Purpose: Thin programmatic access layer for reading/writing the harness SQLite
databases. Replaces manual JSON editing for session state, missions, messages,
and cross-session data. Uses Python sqlite3 stdlib only (no external deps).

Architecture:
  - Session DB (.aitools/sessions/<prefix>.db): per-session state
  - Harness DB (.aitools/harness.db): cross-session state (session index, KPIs)
  - Option B: DB is runtime (gitignored), JSON is archive (tracked in git)

Usage:
    python3 scripts/harness-db.py init
    python3 scripts/harness-db.py session start --id <session-id> [--schwerpunkt <text>]
    python3 scripts/harness-db.py session end --id <session-id>
    python3 scripts/harness-db.py mission start --session <id> --mission <name> [--type <type>] [--description <text>] [--parent <mission-id>]
    python3 scripts/harness-db.py mission end --session <id> --mission <name> --status <status> [--result <text>]
    python3 scripts/harness-db.py log --session <id> --type <sitrep|finding> --message <text> [--agent <role>] [--severity <level>]
    python3 scripts/harness-db.py export --format json [--session <id>]
    python3 scripts/harness-db.py status

Safe to re-run. All operations are idempotent where possible.
Platform: macOS, Windows, Linux (Python 3.10+, sqlite3 stdlib)
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# -- Constants ----------------------------------------------------------------

SCHEMA_VERSION = 1

# Session DB tables (Tier 1)
SESSION_SCHEMA = """\
CREATE TABLE IF NOT EXISTS session (
    session_id TEXT PRIMARY KEY,
    prior_session TEXT,
    schwerpunkt TEXT NOT NULL,
    accepting_schwerpunkt TEXT,
    current_state TEXT,
    started_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    ended_at TEXT,
    version REAL NOT NULL DEFAULT 1.0,
    platform TEXT,
    agent_identity TEXT
);

CREATE TABLE IF NOT EXISTS missions (
    mission_id TEXT PRIMARY KEY,
    parent_mission_id TEXT REFERENCES missions(mission_id),
    mission_type TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'launched'
        CHECK (status IN ('launched', 'in_progress', 'complete', 'failed', 'killed')),
    launched_at TEXT NOT NULL,
    completed_at TEXT,
    findings_count INTEGER DEFAULT 0,
    key_result TEXT
);
CREATE INDEX IF NOT EXISTS idx_missions_parent ON missions(parent_mission_id);
CREATE INDEX IF NOT EXISTS idx_missions_status ON missions(status);

CREATE TABLE IF NOT EXISTS decisions (
    decision_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'decided'
        CHECK (status IN ('decided', 'implemented', 'verified', 'deferred', 'reversed')),
    implementation_evidence TEXT,
    decided_at TEXT NOT NULL,
    implemented_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_decisions_status ON decisions(status);

CREATE TABLE IF NOT EXISTS observations (
    observation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL
        CHECK (category IN ('observation', 'assumption', 'fact', 'finding')),
    text TEXT NOT NULL,
    status TEXT,
    evidence TEXT,
    severity TEXT
        CHECK (severity IS NULL OR severity IN ('critical', 'high', 'medium', 'low')),
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_observations_category ON observations(category);

CREATE TABLE IF NOT EXISTS messages (
    message_id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_type TEXT NOT NULL
        CHECK (message_type IN ('sitrep', 'finding')),
    agent_role TEXT NOT NULL,
    title TEXT,
    message TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'routine'
        CHECK (severity IN ('routine', 'priority', 'flash', 'low', 'medium', 'high', 'critical')),
    actionable BOOLEAN DEFAULT 0,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(message_type);

CREATE TABLE IF NOT EXISTS delegation_log (
    entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
    mission_id TEXT REFERENCES missions(mission_id),
    agent_type TEXT NOT NULL,
    agent_name TEXT NOT NULL,
    prompt_summary TEXT,
    status TEXT NOT NULL DEFAULT 'launched'
        CHECK (status IN ('launched', 'in_progress', 'complete', 'failed', 'killed')),
    launched_at TEXT NOT NULL,
    completed_at TEXT,
    token_usage INTEGER,
    duration_ms INTEGER,
    outcome TEXT
);
CREATE INDEX IF NOT EXISTS idx_delegation_mission ON delegation_log(mission_id);

CREATE TABLE IF NOT EXISTS deviations (
    deviation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    description TEXT NOT NULL,
    impact TEXT,
    batch_origin TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS hard_requirements (
    requirement_id TEXT PRIMARY KEY,
    requirement TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'not-started'
        CHECK (status IN ('not-started', 'in-progress', 'complete', 'deferred')),
    plan_scale_item TEXT,
    prerequisites TEXT,
    surfaced_by TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS completed_work (
    work_id INTEGER PRIMARY KEY AUTOINCREMENT,
    item TEXT NOT NULL,
    category TEXT,
    decided_by TEXT,
    completed_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS version_history (
    version REAL NOT NULL PRIMARY KEY,
    timestamp TEXT NOT NULL,
    changes TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);
"""

# Harness DB tables (Tier 2)
HARNESS_SCHEMA = """\
CREATE TABLE IF NOT EXISTS session_index (
    session_id TEXT PRIMARY KEY,
    db_path TEXT NOT NULL,
    started_at TEXT NOT NULL,
    ended_at TEXT,
    schwerpunkt TEXT,
    platform TEXT,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'crashed'))
);

CREATE TABLE IF NOT EXISTS kpi_events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    dimensions TEXT,
    collected_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_kpi_session ON kpi_events(session_id);
CREATE INDEX IF NOT EXISTS idx_kpi_metric ON kpi_events(metric_name);
CREATE INDEX IF NOT EXISTS idx_kpi_collected ON kpi_events(collected_at);

CREATE TABLE IF NOT EXISTS kpi_ship_log (
    ship_id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_size INTEGER NOT NULL,
    shipped_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'shipped', 'failed')),
    error_message TEXT,
    datadog_response TEXT
);

CREATE TABLE IF NOT EXISTS dashboard_state (
    port INTEGER PRIMARY KEY,
    session_id TEXT NOT NULL,
    pid INTEGER,
    db_path TEXT,
    started_at TEXT NOT NULL,
    last_checked TEXT
);

CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);
"""


# -- Helpers ------------------------------------------------------------------

def utcnow() -> str:
    """Return current UTC timestamp in ISO 8601 with Z suffix."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def detect_platform() -> str:
    """Return platform string matching session schema conventions."""
    if sys.platform == "darwin":
        return "darwin"
    elif sys.platform == "win32":
        return "win32"
    else:
        return "linux"


def find_project_root() -> Path:
    """Find the git project root, falling back to cwd."""
    cwd = Path.cwd()
    # Walk up looking for .git
    for parent in [cwd, *cwd.parents]:
        if (parent / ".git").exists():
            return parent
    return cwd


def open_db(path: Path, *, readonly: bool = False) -> sqlite3.Connection:
    """Open a SQLite connection with WAL mode and standard pragmas.

    Args:
        path: Path to the database file.
        readonly: If True, open in read-only mode.

    Returns:
        Configured sqlite3.Connection with Row factory.
    """
    mode = "ro" if readonly else "rwc"
    conn = sqlite3.connect(
        f"file:{path}?mode={mode}",
        uri=True,
        timeout=5.0,
        check_same_thread=False,
    )
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.row_factory = sqlite3.Row
    return conn


def session_prefix(session_id: str) -> str:
    """Extract the 10-char prefix used for DB filenames."""
    return session_id[:10]


def get_session_db_path(project_root: Path, session_id: str) -> Path:
    """Return the path to a session's DB file."""
    return project_root / ".aitools" / "sessions" / f"{session_prefix(session_id)}.db"


def get_harness_db_path(project_root: Path) -> Path:
    """Return the path to the harness DB file."""
    return project_root / ".aitools" / "harness.db"


def get_running_estimate_path(project_root: Path) -> Path:
    """Return the path to the running estimate JSON export."""
    return project_root / ".aitools" / "channel" / "running-estimate.json"


def ensure_schema(conn: sqlite3.Connection, schema_sql: str) -> None:
    """Apply schema DDL and set schema version if not already set."""
    conn.executescript(schema_sql)
    # Set schema version if table is empty
    row = conn.execute("SELECT COUNT(*) FROM schema_version").fetchone()
    if row[0] == 0:
        conn.execute(
            "INSERT INTO schema_version (version, applied_at) VALUES (?, ?)",
            (SCHEMA_VERSION, utcnow()),
        )
        conn.commit()


def find_active_session_id(project_root: Path) -> str | None:
    """Find the active session ID from the scratch .current-session file."""
    current_file = project_root / ".scratch" / ".current-session"
    if current_file.exists():
        content = current_file.read_text().strip()
        # Content is a path like /path/to/.scratch/session-XXXXXXXXXX
        # Extract the prefix from the directory name
        basename = Path(content).name
        if basename.startswith("session-"):
            return basename[len("session-"):]
    return None


# -- Subcommands --------------------------------------------------------------

def cmd_init(args: argparse.Namespace) -> int:
    """Initialize harness databases (creates if missing)."""
    project_root = find_project_root()

    # Ensure directories exist
    sessions_dir = project_root / ".aitools" / "sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)

    channel_dir = project_root / ".aitools" / "channel"
    channel_dir.mkdir(parents=True, exist_ok=True)

    # Initialize harness DB
    harness_path = get_harness_db_path(project_root)
    conn = open_db(harness_path)
    ensure_schema(conn, HARNESS_SCHEMA)
    conn.close()
    print(f"Harness DB: {harness_path}")

    print("Harness databases initialized.")
    return 0


def cmd_session_start(args: argparse.Namespace) -> int:
    """Register a new session: create session DB and register in harness."""
    project_root = find_project_root()
    session_id = args.id
    schwerpunkt = args.schwerpunkt or "unspecified"

    # Ensure directories
    sessions_dir = project_root / ".aitools" / "sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)

    # Create session DB
    db_path = get_session_db_path(project_root, session_id)
    conn = open_db(db_path)
    ensure_schema(conn, SESSION_SCHEMA)

    now = utcnow()
    platform = detect_platform()

    # Check if session already exists (idempotent)
    existing = conn.execute(
        "SELECT session_id FROM session WHERE session_id = ?",
        (session_id,),
    ).fetchone()

    if existing is None:
        conn.execute(
            """INSERT INTO session
               (session_id, schwerpunkt, started_at, updated_at, platform)
               VALUES (?, ?, ?, ?, ?)""",
            (session_id, schwerpunkt, now, now, platform),
        )
        conn.commit()
        print(f"Session started: {session_id}")
    else:
        print(f"Session already exists: {session_id}")

    conn.close()

    # Register in harness DB
    harness_path = get_harness_db_path(project_root)
    if harness_path.exists():
        hconn = open_db(harness_path)
        rel_path = str(db_path.relative_to(project_root))
        existing_idx = hconn.execute(
            "SELECT session_id FROM session_index WHERE session_id = ?",
            (session_id,),
        ).fetchone()
        if existing_idx is None:
            hconn.execute(
                """INSERT INTO session_index
                   (session_id, db_path, started_at, schwerpunkt, platform, status)
                   VALUES (?, ?, ?, ?, ?, 'active')""",
                (session_id, rel_path, now, schwerpunkt, platform),
            )
            hconn.commit()
        hconn.close()

    print(f"Session DB: {db_path}")
    return 0


def cmd_session_end(args: argparse.Namespace) -> int:
    """Mark a session as complete."""
    project_root = find_project_root()
    session_id = args.id

    db_path = get_session_db_path(project_root, session_id)
    if not db_path.exists():
        print(f"Error: Session DB not found: {db_path}", file=sys.stderr)
        return 1

    now = utcnow()
    conn = open_db(db_path)

    conn.execute(
        "UPDATE session SET ended_at = ?, updated_at = ? WHERE session_id = ?",
        (now, now, session_id),
    )
    conn.commit()
    conn.close()

    # Update harness index
    harness_path = get_harness_db_path(project_root)
    if harness_path.exists():
        hconn = open_db(harness_path)
        hconn.execute(
            "UPDATE session_index SET ended_at = ?, status = 'completed' WHERE session_id = ?",
            (now, session_id),
        )
        hconn.commit()
        hconn.close()

    print(f"Session ended: {session_id}")
    return 0


def cmd_mission_start(args: argparse.Namespace) -> int:
    """Register a new mission within a session."""
    project_root = find_project_root()
    session_id = args.session
    mission_id = args.mission
    mission_type = args.type or "s2"
    description = args.description or mission_id
    parent = args.parent

    db_path = get_session_db_path(project_root, session_id)
    if not db_path.exists():
        print(f"Error: Session DB not found: {db_path}", file=sys.stderr)
        return 1

    now = utcnow()
    conn = open_db(db_path)

    # Check if mission already exists (idempotent)
    existing = conn.execute(
        "SELECT mission_id FROM missions WHERE mission_id = ?",
        (mission_id,),
    ).fetchone()

    if existing is None:
        conn.execute(
            """INSERT INTO missions
               (mission_id, parent_mission_id, mission_type, description, status, launched_at)
               VALUES (?, ?, ?, ?, 'launched', ?)""",
            (mission_id, parent, mission_type, description, now),
        )
        conn.execute(
            "UPDATE session SET updated_at = ? WHERE session_id = ?",
            (now, session_id),
        )
        conn.commit()
        print(f"Mission started: {mission_id} (session: {session_id})")
    else:
        print(f"Mission already exists: {mission_id}")

    conn.close()
    return 0


def cmd_mission_end(args: argparse.Namespace) -> int:
    """Complete a mission with a status and optional result."""
    project_root = find_project_root()
    session_id = args.session
    mission_id = args.mission
    status = args.status
    result = args.result

    db_path = get_session_db_path(project_root, session_id)
    if not db_path.exists():
        print(f"Error: Session DB not found: {db_path}", file=sys.stderr)
        return 1

    now = utcnow()
    conn = open_db(db_path)

    existing = conn.execute(
        "SELECT mission_id FROM missions WHERE mission_id = ?",
        (mission_id,),
    ).fetchone()

    if existing is None:
        print(f"Error: Mission not found: {mission_id}", file=sys.stderr)
        conn.close()
        return 1

    conn.execute(
        """UPDATE missions
           SET status = ?, completed_at = ?, key_result = ?
           WHERE mission_id = ?""",
        (status, now, result, mission_id),
    )
    conn.execute(
        "UPDATE session SET updated_at = ? WHERE session_id = ?",
        (now, session_id),
    )
    conn.commit()
    conn.close()

    print(f"Mission ended: {mission_id} -> {status}")
    return 0


def cmd_log(args: argparse.Namespace) -> int:
    """Write a SITREP or FINDING message to the session DB."""
    project_root = find_project_root()
    session_id = args.session
    msg_type = args.type
    message = args.message
    agent_role = args.agent or "unknown"
    severity = args.severity or ("routine" if msg_type == "sitrep" else "medium")
    title = args.title

    db_path = get_session_db_path(project_root, session_id)
    if not db_path.exists():
        print(f"Error: Session DB not found: {db_path}", file=sys.stderr)
        return 1

    now = utcnow()
    conn = open_db(db_path)

    conn.execute(
        """INSERT INTO messages
           (message_type, agent_role, title, message, severity, created_at)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (msg_type, agent_role, title, message, severity, now),
    )
    conn.execute(
        "UPDATE session SET updated_at = ? WHERE session_id = ?",
        (now, session_id),
    )
    conn.commit()
    conn.close()

    print(f"Logged {msg_type}: {message[:60]}...")
    return 0


def export_session_to_dict(conn: sqlite3.Connection) -> dict[str, Any]:
    """Export a session DB to a dictionary matching running-estimate JSON format.

    Produces fields compatible with the existing dashboard
    (generate-dashboard.py): meta, delegationLog, findings, openThreads,
    decisions, assumptions, completedWork, hardRequirements, deviations.
    """
    data: dict[str, Any] = {}

    # Session metadata -> meta
    session = conn.execute("SELECT * FROM session LIMIT 1").fetchone()
    if session is None:
        return data

    data["meta"] = {
        "sessionId": session["session_id"],
        "priorSession": session["prior_session"],
        "schwerpunkt": session["schwerpunkt"],
        "acceptingSchwerpunkt": session["accepting_schwerpunkt"],
        "currentState": session["current_state"],
        "startedAt": session["started_at"],
        "updatedAt": session["updated_at"],
        "endedAt": session["ended_at"],
        "version": session["version"],
        "platform": session["platform"],
        "agentIdentity": session["agent_identity"],
    }

    # Missions -> openThreads (active) + completedWork (done)
    missions = conn.execute("SELECT * FROM missions ORDER BY launched_at").fetchall()
    open_threads: list[dict[str, Any]] = []
    for m in missions:
        entry = {
            "missionId": m["mission_id"],
            "parentMissionId": m["parent_mission_id"],
            "missionType": m["mission_type"],
            "description": m["description"],
            "status": m["status"],
            "launchedAt": m["launched_at"],
            "completedAt": m["completed_at"],
            "findingsCount": m["findings_count"],
            "keyResult": m["key_result"],
        }
        open_threads.append(entry)
    data["openThreads"] = open_threads

    # Delegation log -> delegationLog
    delegations = conn.execute(
        "SELECT * FROM delegation_log ORDER BY launched_at"
    ).fetchall()
    data["delegationLog"] = [
        {
            "missionId": d["mission_id"],
            "agentType": d["agent_type"],
            "agentName": d["agent_name"],
            "promptSummary": d["prompt_summary"],
            "status": d["status"],
            "launchedAt": d["launched_at"],
            "completedAt": d["completed_at"],
            "tokenUsage": d["token_usage"],
            "durationMs": d["duration_ms"],
            "outcome": d["outcome"],
        }
        for d in delegations
    ]

    # Messages (findings) -> findings
    findings = conn.execute(
        "SELECT * FROM messages WHERE message_type = 'finding' ORDER BY created_at"
    ).fetchall()
    data["findings"] = [
        {
            "agentRole": f["agent_role"],
            "title": f["title"],
            "message": f["message"],
            "severity": f["severity"],
            "actionable": bool(f["actionable"]),
            "createdAt": f["created_at"],
        }
        for f in findings
    ]

    # Messages (sitreps) -> sitreps
    sitreps = conn.execute(
        "SELECT * FROM messages WHERE message_type = 'sitrep' ORDER BY created_at"
    ).fetchall()
    data["sitreps"] = [
        {
            "agentRole": s["agent_role"],
            "message": s["message"],
            "severity": s["severity"],
            "createdAt": s["created_at"],
        }
        for s in sitreps
    ]

    # Decisions -> decisions
    decisions_rows = conn.execute(
        "SELECT * FROM decisions ORDER BY decided_at"
    ).fetchall()
    data["decisions"] = [
        {
            "decisionId": d["decision_id"],
            "title": d["title"],
            "description": d["description"],
            "status": d["status"],
            "implementationEvidence": d["implementation_evidence"],
            "decidedAt": d["decided_at"],
            "implementedAt": d["implemented_at"],
        }
        for d in decisions_rows
    ]

    # Observations (assumptions) -> assumptions
    assumptions = conn.execute(
        "SELECT * FROM observations WHERE category = 'assumption' ORDER BY created_at"
    ).fetchall()
    data["assumptions"] = [
        {
            "text": a["text"],
            "status": a["status"],
            "evidence": a["evidence"],
            "severity": a["severity"],
            "createdAt": a["created_at"],
        }
        for a in assumptions
    ]

    # Observations (all) -> observations
    all_obs = conn.execute(
        "SELECT * FROM observations ORDER BY created_at"
    ).fetchall()
    data["observations"] = [
        {
            "category": o["category"],
            "text": o["text"],
            "status": o["status"],
            "evidence": o["evidence"],
            "severity": o["severity"],
            "createdAt": o["created_at"],
        }
        for o in all_obs
    ]

    # Completed work
    completed = conn.execute(
        "SELECT * FROM completed_work ORDER BY completed_at"
    ).fetchall()
    data["completedWork"] = [
        {
            "item": c["item"],
            "category": c["category"],
            "decidedBy": c["decided_by"],
            "completedAt": c["completed_at"],
        }
        for c in completed
    ]

    # Hard requirements
    reqs = conn.execute(
        "SELECT * FROM hard_requirements ORDER BY requirement_id"
    ).fetchall()
    data["hardRequirements"] = [
        {
            "requirementId": r["requirement_id"],
            "requirement": r["requirement"],
            "status": r["status"],
            "planScaleItem": r["plan_scale_item"],
            "prerequisites": r["prerequisites"],
            "surfacedBy": r["surfaced_by"],
            "createdAt": r["created_at"],
        }
        for r in reqs
    ]

    # Deviations
    devs = conn.execute(
        "SELECT * FROM deviations ORDER BY created_at"
    ).fetchall()
    data["deviations"] = [
        {
            "description": dv["description"],
            "impact": dv["impact"],
            "batchOrigin": dv["batch_origin"],
            "createdAt": dv["created_at"],
        }
        for dv in devs
    ]

    # Version history
    versions = conn.execute(
        "SELECT * FROM version_history ORDER BY version"
    ).fetchall()
    data["versionHistory"] = [
        {
            "version": v["version"],
            "timestamp": v["timestamp"],
            "changes": v["changes"],
        }
        for v in versions
    ]

    return data


def cmd_export(args: argparse.Namespace) -> int:
    """Export session DB to JSON (running-estimate.json format)."""
    project_root = find_project_root()

    if args.format != "json":
        print(f"Error: Unsupported format: {args.format}", file=sys.stderr)
        return 1

    # Find session to export
    session_id = args.session
    if session_id is None:
        # Try to find active session from scratch dir
        session_id = find_active_session_id(project_root)

    if session_id is None:
        # Try to find the most recent session from harness DB
        harness_path = get_harness_db_path(project_root)
        if harness_path.exists():
            hconn = open_db(harness_path, readonly=True)
            row = hconn.execute(
                "SELECT session_id FROM session_index ORDER BY started_at DESC LIMIT 1"
            ).fetchone()
            hconn.close()
            if row is not None:
                session_id = row["session_id"]

    if session_id is None:
        print("Error: No session ID specified and no active session found.", file=sys.stderr)
        return 1

    db_path = get_session_db_path(project_root, session_id)
    if not db_path.exists():
        print(f"Error: Session DB not found: {db_path}", file=sys.stderr)
        return 1

    conn = open_db(db_path, readonly=True)
    data = export_session_to_dict(conn)
    conn.close()

    if not data:
        print("Error: No session data found in DB.", file=sys.stderr)
        return 1

    # Write to running-estimate.json
    output_path = get_running_estimate_path(project_root)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")

    print(f"Exported to: {output_path}")
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    """Show status of all sessions, missions, and harness health."""
    project_root = find_project_root()

    harness_path = get_harness_db_path(project_root)
    sessions_dir = project_root / ".aitools" / "sessions"

    print(f"Project root: {project_root}")
    print(f"Harness DB:   {harness_path} ({'exists' if harness_path.exists() else 'missing'})")
    print(f"Sessions dir: {sessions_dir} ({'exists' if sessions_dir.exists() else 'missing'})")
    print()

    # List session DBs on disk
    if sessions_dir.exists():
        db_files = sorted(sessions_dir.glob("*.db"))
        if db_files:
            print(f"Session databases ({len(db_files)}):")
            for db_file in db_files:
                try:
                    conn = open_db(db_file, readonly=True)
                    session = conn.execute("SELECT * FROM session LIMIT 1").fetchone()
                    if session is not None:
                        status = "ended" if session["ended_at"] else "active"
                        missions_count = conn.execute("SELECT COUNT(*) FROM missions").fetchone()[0]
                        messages_count = conn.execute("SELECT COUNT(*) FROM messages").fetchone()[0]
                        print(
                            f"  {db_file.name}: {session['session_id']} "
                            f"[{status}] schwerpunkt={session['schwerpunkt']} "
                            f"missions={missions_count} messages={messages_count}"
                        )
                    else:
                        print(f"  {db_file.name}: (empty)")
                    conn.close()
                except sqlite3.Error as e:
                    print(f"  {db_file.name}: ERROR: {e}")
        else:
            print("No session databases found.")
    else:
        print("Sessions directory does not exist.")

    print()

    # Harness DB status
    if harness_path.exists():
        try:
            hconn = open_db(harness_path, readonly=True)
            idx_count = hconn.execute("SELECT COUNT(*) FROM session_index").fetchone()[0]
            kpi_count = hconn.execute("SELECT COUNT(*) FROM kpi_events").fetchone()[0]
            print(f"Harness index: {idx_count} sessions registered")
            print(f"KPI events:    {kpi_count}")

            if idx_count > 0:
                print("\nSession index:")
                rows = hconn.execute(
                    "SELECT * FROM session_index ORDER BY started_at DESC"
                ).fetchall()
                for r in rows:
                    print(
                        f"  {r['session_id']}: {r['status']} "
                        f"schwerpunkt={r['schwerpunkt']} "
                        f"started={r['started_at']}"
                    )
            hconn.close()
        except sqlite3.Error as e:
            print(f"Harness DB error: {e}")
    else:
        print("Harness DB does not exist. Run 'harness-db.py init' to create.")

    return 0


# -- CLI setup ----------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    """Build the argument parser with all subcommands."""
    parser = argparse.ArgumentParser(
        prog="harness-db.py",
        description="CLI for aitools harness SQLite database operations.",
    )
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # init
    subparsers.add_parser("init", help="Initialize harness databases")

    # session
    session_parser = subparsers.add_parser("session", help="Session operations")
    session_sub = session_parser.add_subparsers(dest="session_command")

    session_start = session_sub.add_parser("start", help="Start a new session")
    session_start.add_argument("--id", required=True, help="Session ID")
    session_start.add_argument("--schwerpunkt", help="Session focus area")

    session_end = session_sub.add_parser("end", help="End a session")
    session_end.add_argument("--id", required=True, help="Session ID")

    # mission
    mission_parser = subparsers.add_parser("mission", help="Mission operations")
    mission_sub = mission_parser.add_subparsers(dest="mission_command")

    mission_start = mission_sub.add_parser("start", help="Start a new mission")
    mission_start.add_argument("--session", required=True, help="Session ID")
    mission_start.add_argument("--mission", required=True, help="Mission ID")
    mission_start.add_argument("--type", help="Mission type (s2, s3, s5, recon, fragord)")
    mission_start.add_argument("--description", help="Mission description")
    mission_start.add_argument("--parent", help="Parent mission ID (for nesting)")

    mission_end = mission_sub.add_parser("end", help="End a mission")
    mission_end.add_argument("--session", required=True, help="Session ID")
    mission_end.add_argument("--mission", required=True, help="Mission ID")
    mission_end.add_argument(
        "--status", required=True,
        choices=["complete", "failed", "killed"],
        help="Mission outcome status",
    )
    mission_end.add_argument("--result", help="One-line key result")

    # log
    log_parser = subparsers.add_parser("log", help="Log a SITREP or FINDING")
    log_parser.add_argument("--session", required=True, help="Session ID")
    log_parser.add_argument(
        "--type", required=True, choices=["sitrep", "finding"],
        help="Message type",
    )
    log_parser.add_argument("--message", required=True, help="Message text")
    log_parser.add_argument("--agent", help="Agent role (e.g. S3-Victor)")
    log_parser.add_argument("--severity", help="Message severity")
    log_parser.add_argument("--title", help="Finding title (for findings)")

    # export
    export_parser = subparsers.add_parser("export", help="Export DB to JSON")
    export_parser.add_argument(
        "--format", default="json", choices=["json"],
        help="Export format (default: json)",
    )
    export_parser.add_argument("--session", help="Session ID (auto-detects if omitted)")

    # status
    subparsers.add_parser("status", help="Show harness database status")

    return parser


def main() -> int:
    """Entry point: parse args and dispatch to subcommand."""
    parser = build_parser()
    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        return 1

    dispatch: dict[str, Any] = {
        "init": cmd_init,
        "status": cmd_status,
        "export": cmd_export,
    }

    if args.command in dispatch:
        return dispatch[args.command](args)

    if args.command == "session":
        if args.session_command == "start":
            return cmd_session_start(args)
        elif args.session_command == "end":
            return cmd_session_end(args)
        else:
            parser.parse_args(["session", "--help"])
            return 1

    if args.command == "mission":
        if args.mission_command == "start":
            return cmd_mission_start(args)
        elif args.mission_command == "end":
            return cmd_mission_end(args)
        else:
            parser.parse_args(["mission", "--help"])
            return 1

    if args.command == "log":
        return cmd_log(args)

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
