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
    python3 scripts/harness-db.py process-events [--session <id>]
    python3 scripts/harness-db.py ship
    python3 scripts/harness-db.py status
    python3 scripts/harness-db.py knowledge add --item-id <id> --type <type> --content <text> [--attributed-to <who>] [--session <id>] [--trust-level <level>]
    python3 scripts/harness-db.py knowledge invalidate --item-id <id> [--superseded-by <id>] [--session <id>]
    python3 scripts/harness-db.py knowledge verify --item-id <id> [--trust-level <level>]
    python3 scripts/harness-db.py knowledge list [--type <type>] [--trust-level <level>] [--valid-only] [--stale]
    python3 scripts/harness-db.py edge add --source <id> --target <id> --relationship <rel> [--session <id>]
    python3 scripts/harness-db.py edge list --item-id <id>
    python3 scripts/harness-db.py nogood add --items <id,id,...> --contradiction <text> [--session <id>]
    python3 scripts/harness-db.py nogood list
    python3 scripts/harness-db.py nogood check --items <id,id,...>
    python3 scripts/harness-db.py provenance-export [--output <file>]

    # Lean subcommands -- designed for one-liner Bash calls:
    python3 scripts/harness-db.py ol add "text"
    python3 scripts/harness-db.py ol list
    python3 scripts/harness-db.py decision add "title" [--description <text>]
    python3 scripts/harness-db.py decision list
    python3 scripts/harness-db.py incident add "text" [--impact <text>]
    python3 scripts/harness-db.py incident list
    python3 scripts/harness-db.py observation add "text" [--category <cat>] [--severity <level>]
    python3 scripts/harness-db.py search "query"

    # Command channel -- commander directives:
    python3 scripts/harness-db.py directive add "message" [--type <type>] [--priority <level>] [--target <text>]
    python3 scripts/harness-db.py directive list [--status <status>]
    python3 scripts/harness-db.py directive poll
    python3 scripts/harness-db.py directive ack <id> [--response <text>] [--status <status>]

Safe to re-run. All operations are idempotent where possible.
Platform: macOS, Windows, Linux (Python 3.10+, sqlite3 stdlib)
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# -- Constants ----------------------------------------------------------------

SCHEMA_VERSION = 2

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

CREATE TABLE IF NOT EXISTS events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    source TEXT NOT NULL,
    detail TEXT,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_source ON events(source);

CREATE TABLE IF NOT EXISTS commander_directives (
    directive_id INTEGER PRIMARY KEY AUTOINCREMENT,
    directive_type TEXT NOT NULL
        CHECK (directive_type IN (
            'correction',
            'redirect',
            'priority',
            'question',
            'approve',
            'reject',
            'context',
            'checkpoint'
        )),
    priority TEXT NOT NULL DEFAULT 'normal'
        CHECK (priority IN ('flash', 'priority', 'normal')),
    message TEXT NOT NULL,
    target TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'acknowledged', 'executed', 'rejected', 'deferred')),
    response TEXT,
    created_at TEXT NOT NULL,
    acknowledged_at TEXT,
    executed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_directives_status ON commander_directives(status);

CREATE TABLE IF NOT EXISTS commander_feedback (
    feedback_id INTEGER PRIMARY KEY AUTOINCREMENT,
    feedback_type TEXT NOT NULL
        CHECK (feedback_type IN ('correction', 'directive', 'bug', 'observation', 'priority')),
    message TEXT NOT NULL,
    target TEXT,
    status TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted', 'acknowledged', 'resolved', 'deferred')),
    resolution TEXT,
    created_at TEXT NOT NULL,
    acknowledged_at TEXT,
    resolved_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON commander_feedback(status);

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

CREATE TABLE IF NOT EXISTS knowledge_items (
    item_id TEXT PRIMARY KEY,
    item_type TEXT NOT NULL
        CHECK (item_type IN ('observation', 'assumption', 'fact', 'finding',
               'decision', 'ol_entry', 'rule_change', 'framework_change',
               'commander_directive')),
    version INTEGER NOT NULL DEFAULT 1,
    content TEXT NOT NULL,
    t_valid TEXT,
    t_invalid TEXT,
    attributed_to TEXT NOT NULL,
    produced_by_session TEXT,
    produced_by_mission TEXT,
    authority_level INTEGER NOT NULL DEFAULT 1
        CHECK (authority_level BETWEEN 0 AND 3),
    warn_after_days INTEGER DEFAULT 30,
    error_after_days INTEGER DEFAULT 90,
    last_verified_at TEXT,
    trust_level TEXT NOT NULL DEFAULT 'agent_observation'
        CHECK (trust_level IN ('commander_directive', 'verified_fact',
               'agent_observation', 'unverified_assumption')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ki_type ON knowledge_items(item_type);
CREATE INDEX IF NOT EXISTS idx_ki_trust ON knowledge_items(trust_level);
CREATE INDEX IF NOT EXISTS idx_ki_session ON knowledge_items(produced_by_session);
CREATE INDEX IF NOT EXISTS idx_ki_valid ON knowledge_items(t_invalid);

CREATE TABLE IF NOT EXISTS provenance_edges (
    edge_id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_item_id TEXT NOT NULL REFERENCES knowledge_items(item_id),
    target_item_id TEXT NOT NULL REFERENCES knowledge_items(item_id),
    relationship TEXT NOT NULL
        CHECK (relationship IN ('derived_from', 'informed', 'triggered',
               'validated', 'invalidated', 'superseded')),
    created_at TEXT NOT NULL,
    session_id TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_prov_source ON provenance_edges(source_item_id);
CREATE INDEX IF NOT EXISTS idx_prov_target ON provenance_edges(target_item_id);
CREATE INDEX IF NOT EXISTS idx_prov_rel ON provenance_edges(relationship);

CREATE TABLE IF NOT EXISTS nogood_sets (
    nogood_id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_ids TEXT NOT NULL,
    contradiction TEXT NOT NULL,
    discovered_in_session TEXT NOT NULL,
    discovered_at TEXT NOT NULL
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


def _log_path() -> Path:
    """Return the path to deploy.log following aitools platform conventions."""
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Logs" / "aitools" / "deploy.log"
    else:
        state_home = os.environ.get("XDG_STATE_HOME", "")
        if not state_home:
            state_home = str(Path.home() / ".local" / "state")
        return Path(state_home) / "aitools" / "deploy.log"


def _log_detail(msg: str) -> None:
    """Write a detail-level message to deploy.log. Nothing to stdout or stderr."""
    try:
        log_file = _log_path()
        log_file.parent.mkdir(parents=True, exist_ok=True)
        ts = utcnow()
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"[{ts}] [harness-db] [detail] {msg}\n")
    except OSError:
        pass  # logging must never crash the tool


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


def resolve_session_db(project_root: Path, session_id: str | None = None) -> tuple[Path, str] | None:
    """Resolve session DB path from explicit ID or auto-detection.

    Returns (db_path, session_id) or None if no session found.
    Logs detail to deploy.log on failure.
    """
    if session_id is None:
        session_id = find_active_session_id(project_root)
    if session_id is None:
        _log_detail("No --session specified and no active session found")
        return None
    db_path = get_session_db_path(project_root, session_id)
    if not db_path.exists():
        _log_detail(f"Session DB not found: {db_path}")
        return None
    return db_path, session_id


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
        _log_detail(f"Session DB not found: {db_path}")
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
        _log_detail(f"Session DB not found: {db_path}")
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
        _log_detail(f"Session DB not found: {db_path}")
        return 1

    now = utcnow()
    conn = open_db(db_path)

    existing = conn.execute(
        "SELECT mission_id FROM missions WHERE mission_id = ?",
        (mission_id,),
    ).fetchone()

    if existing is None:
        _log_detail(f"Mission not found: {mission_id}")
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
        _log_detail(f"Session DB not found: {db_path}")
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


def session_has_meaningful_content(conn: sqlite3.Connection) -> bool:
    """Check whether a session DB has content beyond just session registration.

    A session DB with only a session row and no missions, messages, decisions,
    observations, or other data is considered empty/minimal. Exporting such a
    DB would overwrite a potentially rich running-estimate.json with empty data.

    Returns:
        True if the session has meaningful content worth exporting.
    """
    # Check for any content in data tables (beyond the session row itself)
    tables_to_check = [
        ("missions", "SELECT COUNT(*) FROM missions"),
        ("messages", "SELECT COUNT(*) FROM messages"),
        ("decisions", "SELECT COUNT(*) FROM decisions"),
        ("observations", "SELECT COUNT(*) FROM observations"),
        ("delegation_log", "SELECT COUNT(*) FROM delegation_log"),
        ("completed_work", "SELECT COUNT(*) FROM completed_work"),
        ("hard_requirements", "SELECT COUNT(*) FROM hard_requirements"),
        ("deviations", "SELECT COUNT(*) FROM deviations"),
        ("version_history", "SELECT COUNT(*) FROM version_history"),
    ]
    total_records = 0
    for _table_name, query in tables_to_check:
        try:
            row = conn.execute(query).fetchone()
            if row is not None:
                total_records += row[0]
        except sqlite3.OperationalError:
            # Table may not exist in older schema versions
            pass

    return total_records > 0


def cmd_export(args: argparse.Namespace) -> int:
    """Export session DB to JSON (running-estimate.json format).

    Safety: refuses to overwrite a larger existing running-estimate.json with
    empty/minimal session data. This prevents data loss when short-lived or
    competing sessions (e.g., `claude -p` missions) end and export over a
    rich running estimate built by a longer session.
    """
    project_root = find_project_root()

    if args.format != "json":
        _log_detail(f"Unsupported format: {args.format}")
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
        _log_detail("No session ID specified and no active session found")
        return 1

    db_path = get_session_db_path(project_root, session_id)
    if not db_path.exists():
        _log_detail(f"Session DB not found: {db_path}")
        return 1

    conn = open_db(db_path, readonly=True)

    # Safety check: does this session DB have meaningful content?
    has_content = session_has_meaningful_content(conn)

    if not has_content:
        # Check if an existing running-estimate.json exists and has content
        output_path = get_running_estimate_path(project_root)
        if output_path.exists() and output_path.stat().st_size > 10:
            _log_detail(
                f"Session DB for {session_id} has no meaningful content "
                f"(no missions, messages, decisions, etc.). "
                f"Skipping export to preserve existing {output_path.name} "
                f"({output_path.stat().st_size} bytes)."
            )
            conn.close()
            return 0
        # If no existing file or it's trivially small, allow the export
        # (creating a minimal file is fine when there's nothing to lose)

    data = export_session_to_dict(conn)
    conn.close()

    if not data:
        _log_detail("No session data found in DB")
        return 1

    # Safety check: if existing file is substantially larger, warn and skip
    output_path = get_running_estimate_path(project_root)
    new_content = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    if output_path.exists():
        existing_size = output_path.stat().st_size
        new_size = len(new_content.encode("utf-8"))
        # If existing is more than 2x the size of what we'd write, skip
        # This catches the case where a rich running estimate would be
        # replaced by a session that only has a few entries
        if existing_size > 100 and new_size < existing_size // 2:
            if getattr(args, "force", False):
                _log_detail(
                    f"Overwriting {output_path.name} "
                    f"({existing_size} bytes -> {new_size} bytes) due to --force."
                )
            else:
                _log_detail(
                    f"Export would replace {output_path.name} "
                    f"({existing_size} bytes) with smaller content ({new_size} bytes). "
                    f"Skipping export to preserve richer running estimate."
                )
                return 0

    # Write to running-estimate.json
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(new_content)

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


def process_session_events(
    session_dir: Path, session_id: str, harness_db_path: Path
) -> dict[str, Any]:
    """Process events.jsonl from a session into KPI metrics.

    This is the cold-path processor. It runs once at session end.
    It replaces the observation functions of:
      - intent-sentinel-stop.sh (8 telemetry functions)
      - estimate-refresh-stop.sh (turn tracking, freshness)
      - surfacing-duty-stop.sh (duty reminders)

    Reads events.jsonl (written by enforcement hooks during the session),
    computes aggregate metrics, and writes them to kpi_events in the
    harness DB.

    Args:
        session_dir: Path to the session scratch directory.
        session_id: The session ID string.
        harness_db_path: Path to the harness DB.

    Returns:
        Dict of computed metrics (metric_name -> metric_value).
    """
    events_file = session_dir / "events.jsonl"
    if not events_file.exists():
        return {}

    # Parse JSONL events
    events: list[dict[str, Any]] = []
    for line in events_file.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue

    if not events:
        return {}

    metrics: dict[str, float] = {}

    # --- Metrics formerly computed by intent-sentinel ---

    # 1. Hook fires (all types)
    hook_fires = [e for e in events if e.get("type") in ("hook_fire", "hook_block", "hook_warn")]
    metrics["guard.fireCount"] = float(len(hook_fires))

    # 2. Turn count (deduplicate by timestamp -- multiple hooks fire on same turn)
    turn_timestamps = sorted(set(e.get("t", "") for e in hook_fires if e.get("t")))
    metrics["session.turnCount"] = float(len(turn_timestamps))

    # 3. Blocks and warnings
    blocks = [e for e in events if e.get("type") == "hook_block"]
    warns = [e for e in events if e.get("type") == "hook_warn"]
    metrics["guard.blockCount"] = float(len(blocks))
    metrics["guard.warnCount"] = float(len(warns))

    # 4. Subagent count (from delegation events)
    delegations = [e for e in events if e.get("type") == "delegation"]
    metrics["session.subagentCount"] = float(len(delegations))

    # 5. Delegation compliance scores
    if delegations:
        scores = []
        for d in delegations:
            detail = d.get("d", {})
            if isinstance(detail, dict) and "score" in detail:
                try:
                    scores.append(float(detail["score"]))
                except (ValueError, TypeError):
                    pass
        if scores:
            metrics["delegation.avgScore"] = sum(scores) / len(scores)
            metrics["delegation.minScore"] = min(scores)
            metrics["delegation.count"] = float(len(scores))

    # 6. Session duration (from first to last event)
    all_timestamps = sorted(t for e in events if (t := e.get("t")) is not None)
    if len(all_timestamps) >= 2:
        try:
            first_dt = datetime.fromisoformat(all_timestamps[0].replace("Z", "+00:00"))
            last_dt = datetime.fromisoformat(all_timestamps[-1].replace("Z", "+00:00"))
            duration_seconds = (last_dt - first_dt).total_seconds()
            metrics["session.durationSeconds"] = duration_seconds
        except (ValueError, TypeError):
            pass

    # 7. Work product count (scratch files in session dir)
    if session_dir.exists():
        scratch_files = [f for f in session_dir.iterdir() if f.is_file()]
        metrics["session.scratchFileCount"] = float(len(scratch_files))

    # 8. Source breakdown (which hooks fired most)
    source_counts: dict[str, int] = {}
    for e in events:
        src = e.get("src", "unknown")
        source_counts[src] = source_counts.get(src, 0) + 1

    # --- Write metrics to harness DB kpi_events ---
    now = utcnow()
    if harness_db_path.exists():
        try:
            hconn = open_db(harness_db_path)
            for metric_name, metric_value in metrics.items():
                hconn.execute(
                    """INSERT INTO kpi_events
                       (session_id, metric_name, metric_value, dimensions, collected_at)
                       VALUES (?, ?, ?, ?, ?)""",
                    (
                        session_id,
                        metric_name,
                        metric_value,
                        json.dumps({"sources": source_counts}),
                        now,
                    ),
                )
            hconn.commit()
            hconn.close()
        except sqlite3.Error as e:
            _log_detail(f"Failed to write KPI metrics: {e}")

    return metrics


def ship_to_datadog(harness_db_path: Path) -> int:
    """Ship unshipped KPI events to Datadog.

    Uses Datadog Metrics API v2 (submit series).
    Requires DD_API_KEY environment variable.
    DD_SITE defaults to us5.datadoghq.com per harness config.

    Args:
        harness_db_path: Path to the harness DB.

    Returns:
        Number of events shipped (0 if no API key or no events).
    """
    api_key = os.environ.get("DD_API_KEY", "")
    site = os.environ.get("DD_SITE", "us5.datadoghq.com")
    if not api_key:
        return 0

    if not harness_db_path.exists():
        return 0

    try:
        hconn = open_db(harness_db_path, readonly=True)
    except sqlite3.Error:
        return 0

    # Get last shipped event_id from kpi_ship_log
    try:
        row = hconn.execute(
            "SELECT COALESCE(MAX(ship_id), 0) FROM kpi_ship_log WHERE status = 'shipped'"
        ).fetchone()
        # Use the max event_id from shipped batches as high-water mark
        # For simplicity, track by counting: ship all events with id > max previously shipped
        last_row = hconn.execute(
            """SELECT COALESCE(
                (SELECT MAX(ke.event_id) FROM kpi_events ke
                 WHERE ke.collected_at <= (
                   SELECT MAX(shipped_at) FROM kpi_ship_log WHERE status = 'shipped'
                 )), 0)"""
        ).fetchone()
        last_shipped_id = last_row[0] if last_row else 0
    except sqlite3.Error:
        last_shipped_id = 0

    # Get unshipped events
    try:
        rows = hconn.execute(
            """SELECT event_id, session_id, metric_name, metric_value,
                      dimensions, collected_at
               FROM kpi_events WHERE event_id > ?
               ORDER BY event_id""",
            (last_shipped_id,),
        ).fetchall()
    except sqlite3.Error:
        hconn.close()
        return 0

    hconn.close()

    if not rows:
        return 0

    # Detect platform for tags
    platform = detect_platform()

    # Determine project name from cwd
    project_root = find_project_root()
    project_name = project_root.name

    # Build Datadog series payload
    series: list[dict[str, Any]] = []
    for row in rows:
        try:
            ts_str = row["collected_at"].replace("Z", "+00:00")
            ts_epoch = int(datetime.fromisoformat(ts_str).timestamp())
        except (ValueError, TypeError, AttributeError):
            ts_epoch = int(datetime.now(timezone.utc).timestamp())

        series.append({
            "metric": f"aitools.{row['metric_name']}",
            "type": 0,  # gauge
            "points": [{"timestamp": ts_epoch, "value": float(row["metric_value"])}],
            "tags": [
                f"session:{row['session_id']}",
                f"platform:{platform}",
                f"project:{project_name}",
                "source:aitools-harness",
            ],
        })

    payload = json.dumps({"series": series}).encode("utf-8")

    url = f"https://api.{site}/api/v2/series"
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "DD-API-KEY": api_key,
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            status = resp.status
            dd_response = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        status = e.code
        dd_response = e.read().decode("utf-8", errors="replace") if e.fp else str(e)
    except urllib.error.URLError as e:
        status = 0
        dd_response = str(e)
    except Exception as e:
        status = 0
        dd_response = str(e)

    # Record shipment in harness DB
    shipped = status == 202
    try:
        wconn = open_db(harness_db_path)
        wconn.execute(
            """INSERT INTO kpi_ship_log
               (batch_size, shipped_at, status, error_message, datadog_response)
               VALUES (?, ?, ?, ?, ?)""",
            (
                len(rows),
                utcnow(),
                "shipped" if shipped else "failed",
                None if shipped else f"HTTP {status}",
                dd_response[:500] if dd_response else None,
            ),
        )
        wconn.commit()
        wconn.close()
    except sqlite3.Error:
        pass

    return len(rows) if shipped else 0


def cmd_process_events(args: argparse.Namespace) -> int:
    """Process session events.jsonl into KPI metrics."""
    project_root = find_project_root()
    session_id = args.session

    if session_id is None:
        session_id = find_active_session_id(project_root)

    if session_id is None:
        _log_detail("No session ID specified and no active session found")
        return 1

    # Find session scratch directory
    prefix = session_prefix(session_id)
    session_dir = project_root / ".scratch" / f"session-{prefix}"

    if not session_dir.exists():
        _log_detail(f"Session directory not found: {session_dir}")
        return 1

    events_file = session_dir / "events.jsonl"
    if not events_file.exists():
        print(f"No events.jsonl found in {session_dir} (no enforcement hook events recorded)")
        return 0

    harness_db_path = get_harness_db_path(project_root)
    if not harness_db_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    metrics = process_session_events(session_dir, session_id, harness_db_path)

    if metrics:
        print(f"Processed {len(metrics)} metrics from events.jsonl:")
        for name, value in sorted(metrics.items()):
            if isinstance(value, float) and value == int(value):
                print(f"  {name}: {int(value)}")
            else:
                print(f"  {name}: {value:.2f}")
    else:
        print("No metrics computed (events.jsonl may be empty)")

    return 0


def cmd_ship(args: argparse.Namespace) -> int:
    """Ship KPI events to Datadog."""
    project_root = find_project_root()
    harness_db_path = get_harness_db_path(project_root)

    if not harness_db_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    api_key = os.environ.get("DD_API_KEY", "")
    if not api_key:
        print("DD_API_KEY not set. Set it to enable Datadog shipping.")
        print("  export DD_API_KEY=your-api-key")
        print("  export DD_SITE=us5.datadoghq.com  # default")
        return 0

    shipped = ship_to_datadog(harness_db_path)
    if shipped > 0:
        print(f"Shipped {shipped} KPI events to Datadog")
    else:
        print("No events to ship (or shipping failed — check kpi_ship_log)")

    return 0


# -- Provenance subcommands ---------------------------------------------------

def cmd_knowledge_add(args: argparse.Namespace) -> int:
    """Add a knowledge item to the harness provenance system."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    now = utcnow()
    conn = open_db(harness_path)

    # Check for existing item (idempotent on item_id)
    existing = conn.execute(
        "SELECT item_id, version FROM knowledge_items WHERE item_id = ?",
        (args.item_id,),
    ).fetchone()

    if existing is not None:
        # Supersede: bump version, keep old content accessible via provenance
        new_version = existing["version"] + 1
        conn.execute(
            """UPDATE knowledge_items
               SET version = ?, content = ?, updated_at = ?,
                   t_valid = COALESCE(?, t_valid),
                   attributed_to = COALESCE(?, attributed_to),
                   produced_by_session = COALESCE(?, produced_by_session),
                   produced_by_mission = COALESCE(?, produced_by_mission),
                   authority_level = COALESCE(?, authority_level),
                   trust_level = COALESCE(?, trust_level)
               WHERE item_id = ?""",
            (
                new_version, args.content, now,
                args.t_valid,
                args.attributed_to,
                args.session,
                args.mission,
                args.authority_level,
                args.trust_level,
                args.item_id,
            ),
        )
        conn.commit()
        conn.close()
        print(f"Updated knowledge item: {args.item_id} (v{new_version})")
        return 0

    conn.execute(
        """INSERT INTO knowledge_items
           (item_id, item_type, version, content, t_valid, t_invalid,
            attributed_to, produced_by_session, produced_by_mission,
            authority_level, warn_after_days, error_after_days,
            trust_level, created_at, updated_at)
           VALUES (?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            args.item_id,
            args.item_type,
            args.content,
            args.t_valid or now,
            args.attributed_to or "agent",
            args.session,
            args.mission,
            int(args.authority_level) if args.authority_level else 1,
            int(args.warn_after) if args.warn_after else 30,
            int(args.error_after) if args.error_after else 90,
            args.trust_level or "agent_observation",
            now,
            now,
        ),
    )
    conn.commit()
    conn.close()
    print(f"Added knowledge item: {args.item_id} ({args.item_type})")
    return 0


def cmd_knowledge_invalidate(args: argparse.Namespace) -> int:
    """Invalidate a knowledge item and propagate to downstream dependents."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    now = utcnow()
    conn = open_db(harness_path)

    # Check item exists
    item = conn.execute(
        "SELECT item_id, t_invalid FROM knowledge_items WHERE item_id = ?",
        (args.item_id,),
    ).fetchone()

    if item is None:
        _log_detail(f"Knowledge item not found: {args.item_id}")
        conn.close()
        return 1

    if item["t_invalid"] is not None:
        print(f"Item already invalidated at {item['t_invalid']}")
        conn.close()
        return 0

    # Invalidate the item
    conn.execute(
        "UPDATE knowledge_items SET t_invalid = ?, updated_at = ? WHERE item_id = ?",
        (now, now, args.item_id),
    )

    # Record invalidation edge if a superseding item is specified
    if args.superseded_by:
        conn.execute(
            """INSERT INTO provenance_edges
               (source_item_id, target_item_id, relationship, created_at, session_id)
               VALUES (?, ?, 'superseded', ?, ?)""",
            (args.superseded_by, args.item_id, now, args.session or "unknown"),
        )

    # Dependency-directed propagation: flag downstream items
    # Items that derived_from or were informed by the invalidated item
    flagged = propagate_invalidation(conn, args.item_id, now, args.session or "unknown")

    conn.commit()
    conn.close()

    print(f"Invalidated: {args.item_id}")
    if flagged:
        print(f"Downstream items flagged ({len(flagged)}):")
        for fid in flagged:
            print(f"  - {fid}")
    return 0


def propagate_invalidation(
    conn: sqlite3.Connection,
    item_id: str,
    timestamp: str,
    session_id: str,
    _visited: set[str] | None = None,
) -> list[str]:
    """Propagate invalidation through the dependency graph (ATMS principle).

    When an item is invalidated, find all items that depend on it
    (via derived_from or informed edges) and flag them by setting
    trust_level to 'unverified_assumption' if they were higher.

    Returns list of item_ids that were flagged.
    """
    if _visited is None:
        _visited = set()

    if item_id in _visited:
        return []
    _visited.add(item_id)

    flagged: list[str] = []

    # Find items that derive from or are informed by the invalidated item
    # Edge direction: source --[derived_from]--> target
    # So items that have target = invalidated item are the dependents
    # Wait -- the design says source_item_id --[relationship]--> target_item_id
    # "OL-2 derived_from observation-42" means OL-2 depends on observation-42
    # So source is the dependent, target is the basis.
    # When we invalidate target (observation-42), we need to find all sources.
    dependents = conn.execute(
        """SELECT DISTINCT source_item_id FROM provenance_edges
           WHERE target_item_id = ?
             AND relationship IN ('derived_from', 'informed', 'triggered')""",
        (item_id,),
    ).fetchall()

    for row in dependents:
        dep_id = row["source_item_id"]

        # Check if the dependent is still valid (not already invalidated)
        dep_item = conn.execute(
            "SELECT item_id, t_invalid, trust_level FROM knowledge_items WHERE item_id = ?",
            (dep_id,),
        ).fetchone()

        if dep_item is None or dep_item["t_invalid"] is not None:
            continue

        # Flag by downgrading trust level to unverified_assumption
        if dep_item["trust_level"] != "unverified_assumption":
            conn.execute(
                """UPDATE knowledge_items
                   SET trust_level = 'unverified_assumption', updated_at = ?
                   WHERE item_id = ?""",
                (timestamp, dep_id),
            )
            flagged.append(dep_id)

        # Recurse
        flagged.extend(
            propagate_invalidation(conn, dep_id, timestamp, session_id, _visited)
        )

    return flagged


def cmd_knowledge_verify(args: argparse.Namespace) -> int:
    """Mark a knowledge item as verified (resets staleness clock)."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    now = utcnow()
    conn = open_db(harness_path)

    item = conn.execute(
        "SELECT item_id FROM knowledge_items WHERE item_id = ?",
        (args.item_id,),
    ).fetchone()

    if item is None:
        _log_detail(f"Knowledge item not found: {args.item_id}")
        conn.close()
        return 1

    trust = args.trust_level or "verified_fact"
    conn.execute(
        """UPDATE knowledge_items
           SET last_verified_at = ?, trust_level = ?, updated_at = ?
           WHERE item_id = ?""",
        (now, trust, now, args.item_id),
    )
    conn.commit()
    conn.close()
    print(f"Verified: {args.item_id} (trust: {trust})")
    return 0


def cmd_knowledge_list(args: argparse.Namespace) -> int:
    """List knowledge items with optional filters."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    conn = open_db(harness_path, readonly=True)

    query = "SELECT * FROM knowledge_items WHERE 1=1"
    params: list[str] = []

    if args.item_type:
        query += " AND item_type = ?"
        params.append(args.item_type)

    if args.trust_level:
        query += " AND trust_level = ?"
        params.append(args.trust_level)

    if args.valid_only:
        query += " AND t_invalid IS NULL"

    if args.stale:
        # Items past their warn_after_days without verification
        query += """ AND (
            last_verified_at IS NULL
            AND julianday('now') - julianday(created_at) > warn_after_days
            AND t_invalid IS NULL
        )"""

    query += " ORDER BY created_at DESC"

    rows = conn.execute(query, params).fetchall()
    conn.close()

    if not rows:
        print("No knowledge items found matching criteria.")
        return 0

    print(f"Knowledge items ({len(rows)}):")
    for r in rows:
        validity = "CURRENT" if r["t_invalid"] is None else f"INVALID({r['t_invalid']})"
        stale_marker = ""
        if r["t_invalid"] is None and r["last_verified_at"] is None:
            try:
                created = datetime.fromisoformat(r["created_at"].replace("Z", "+00:00"))
                age_days = (datetime.now(timezone.utc) - created).days
                if age_days > r["error_after_days"]:
                    stale_marker = " STALE!"
                elif age_days > r["warn_after_days"]:
                    stale_marker = " stale?"
            except (ValueError, TypeError):
                pass
        print(
            f"  {r['item_id']} [{r['item_type']}] v{r['version']} "
            f"{validity} trust={r['trust_level']} L{r['authority_level']}"
            f"{stale_marker}"
        )
        # Truncate content for display
        content_preview = r["content"][:80].replace("\n", " ")
        if len(r["content"]) > 80:
            content_preview += "..."
        print(f"    {content_preview}")

    return 0


def cmd_edge_add(args: argparse.Namespace) -> int:
    """Add a provenance edge between two knowledge items."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    now = utcnow()
    conn = open_db(harness_path)

    # Verify both items exist
    for item_id in [args.source, args.target]:
        row = conn.execute(
            "SELECT item_id FROM knowledge_items WHERE item_id = ?",
            (item_id,),
        ).fetchone()
        if row is None:
            _log_detail(f"Knowledge item not found: {item_id}")
            conn.close()
            return 1

    conn.execute(
        """INSERT INTO provenance_edges
           (source_item_id, target_item_id, relationship, created_at, session_id)
           VALUES (?, ?, ?, ?, ?)""",
        (args.source, args.target, args.relationship, now, args.session or "unknown"),
    )
    conn.commit()
    conn.close()
    print(f"Edge added: {args.source} --[{args.relationship}]--> {args.target}")
    return 0


def cmd_edge_list(args: argparse.Namespace) -> int:
    """List provenance edges for a knowledge item."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    conn = open_db(harness_path, readonly=True)

    # Edges where this item is source (what it depends on)
    outgoing = conn.execute(
        """SELECT e.*, k.item_type, k.content
           FROM provenance_edges e
           JOIN knowledge_items k ON e.target_item_id = k.item_id
           WHERE e.source_item_id = ?
           ORDER BY e.created_at""",
        (args.item_id,),
    ).fetchall()

    # Edges where this item is target (what depends on it)
    incoming = conn.execute(
        """SELECT e.*, k.item_type, k.content
           FROM provenance_edges e
           JOIN knowledge_items k ON e.source_item_id = k.item_id
           WHERE e.target_item_id = ?
           ORDER BY e.created_at""",
        (args.item_id,),
    ).fetchall()

    conn.close()

    if not outgoing and not incoming:
        print(f"No provenance edges for: {args.item_id}")
        return 0

    print(f"Provenance for: {args.item_id}")

    if outgoing:
        print(f"\n  Bases ({len(outgoing)} -- what this item depends on):")
        for e in outgoing:
            content_preview = e["content"][:60].replace("\n", " ")
            print(
                f"    --[{e['relationship']}]--> {e['target_item_id']} "
                f"[{e['item_type']}] {content_preview}"
            )

    if incoming:
        print(f"\n  Dependents ({len(incoming)} -- what depends on this item):")
        for e in incoming:
            content_preview = e["content"][:60].replace("\n", " ")
            print(
                f"    <--[{e['relationship']}]-- {e['source_item_id']} "
                f"[{e['item_type']}] {content_preview}"
            )

    return 0


def cmd_nogood_add(args: argparse.Namespace) -> int:
    """Record a nogood set (known contradiction combination)."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    now = utcnow()
    conn = open_db(harness_path)

    # Parse item IDs (comma-separated)
    item_ids = [i.strip() for i in args.items.split(",") if i.strip()]
    if len(item_ids) < 2:
        _log_detail("A nogood set requires at least 2 item IDs.")
        conn.close()
        return 1

    # Verify all items exist
    for item_id in item_ids:
        row = conn.execute(
            "SELECT item_id FROM knowledge_items WHERE item_id = ?",
            (item_id,),
        ).fetchone()
        if row is None:
            _log_detail(f"Knowledge item not found: {item_id}")
            conn.close()
            return 1

    item_ids_json = json.dumps(item_ids)
    conn.execute(
        """INSERT INTO nogood_sets
           (item_ids, contradiction, discovered_in_session, discovered_at)
           VALUES (?, ?, ?, ?)""",
        (item_ids_json, args.contradiction, args.session or "unknown", now),
    )
    conn.commit()
    conn.close()
    print(f"Nogood set recorded: {item_ids} -- {args.contradiction}")
    return 0


def cmd_nogood_list(args: argparse.Namespace) -> int:
    """List all nogood sets."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    conn = open_db(harness_path, readonly=True)
    rows = conn.execute(
        "SELECT * FROM nogood_sets ORDER BY discovered_at DESC"
    ).fetchall()
    conn.close()

    if not rows:
        print("No nogood sets recorded.")
        return 0

    print(f"Nogood sets ({len(rows)}):")
    for r in rows:
        items = json.loads(r["item_ids"])
        print(f"  #{r['nogood_id']}: {items}")
        print(f"    Contradiction: {r['contradiction']}")
        print(f"    Discovered: {r['discovered_at']} (session: {r['discovered_in_session']})")

    return 0


def cmd_nogood_check(args: argparse.Namespace) -> int:
    """Check if a set of assumptions hits a known nogood set."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    conn = open_db(harness_path, readonly=True)

    # Parse the assumptions to check
    check_items = set(i.strip() for i in args.items.split(",") if i.strip())

    rows = conn.execute("SELECT * FROM nogood_sets").fetchall()
    conn.close()

    hits: list[dict[str, Any]] = []
    for r in rows:
        nogood_items = set(json.loads(r["item_ids"]))
        # If the nogood set is a subset of the current assumptions, it's a hit
        if nogood_items.issubset(check_items):
            hits.append({
                "nogood_id": r["nogood_id"],
                "items": list(nogood_items),
                "contradiction": r["contradiction"],
            })

    if hits:
        print(f"WARNING: {len(hits)} known contradiction(s) detected:")
        for h in hits:
            print(f"  Nogood #{h['nogood_id']}: {h['items']}")
            print(f"    {h['contradiction']}")
        return 1
    else:
        print("No known contradictions in the given assumption set.")
        return 0


def cmd_provenance_export(args: argparse.Namespace) -> int:
    """Export all provenance data (knowledge items, edges, nogoods) to JSON."""
    project_root = find_project_root()
    harness_path = get_harness_db_path(project_root)

    if not harness_path.exists():
        _log_detail("Harness DB not found. Run 'harness-db.py init' first.")
        return 1

    conn = open_db(harness_path, readonly=True)

    data: dict[str, Any] = {}

    # Knowledge items
    items = conn.execute(
        "SELECT * FROM knowledge_items ORDER BY created_at"
    ).fetchall()
    data["knowledgeItems"] = [
        {
            "itemId": ki["item_id"],
            "itemType": ki["item_type"],
            "version": ki["version"],
            "content": ki["content"],
            "tValid": ki["t_valid"],
            "tInvalid": ki["t_invalid"],
            "attributedTo": ki["attributed_to"],
            "producedBySession": ki["produced_by_session"],
            "producedByMission": ki["produced_by_mission"],
            "authorityLevel": ki["authority_level"],
            "warnAfterDays": ki["warn_after_days"],
            "errorAfterDays": ki["error_after_days"],
            "lastVerifiedAt": ki["last_verified_at"],
            "trustLevel": ki["trust_level"],
            "createdAt": ki["created_at"],
            "updatedAt": ki["updated_at"],
        }
        for ki in items
    ]

    # Provenance edges
    edges = conn.execute(
        "SELECT * FROM provenance_edges ORDER BY created_at"
    ).fetchall()
    data["provenanceEdges"] = [
        {
            "edgeId": e["edge_id"],
            "sourceItemId": e["source_item_id"],
            "targetItemId": e["target_item_id"],
            "relationship": e["relationship"],
            "createdAt": e["created_at"],
            "sessionId": e["session_id"],
        }
        for e in edges
    ]

    # Nogood sets
    nogoods = conn.execute(
        "SELECT * FROM nogood_sets ORDER BY discovered_at"
    ).fetchall()
    data["nogoodSets"] = [
        {
            "nogoodId": ng["nogood_id"],
            "itemIds": json.loads(ng["item_ids"]),
            "contradiction": ng["contradiction"],
            "discoveredInSession": ng["discovered_in_session"],
            "discoveredAt": ng["discovered_at"],
        }
        for ng in nogoods
    ]

    conn.close()

    output = json.dumps(data, indent=2, ensure_ascii=False) + "\n"

    if args.output:
        Path(args.output).write_text(output)
        print(f"Provenance exported to: {args.output}")
    else:
        print(output, end="")

    return 0


# -- Lean subcommands (one-liner Bash calls) ----------------------------------


def cmd_ol_add(args: argparse.Namespace) -> int:
    """Add an operational learning entry to the session observations table."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, session_id = result

    now = utcnow()
    conn = open_db(db_path)
    conn.execute(
        """INSERT INTO observations (category, text, status, created_at)
           VALUES ('finding', ?, 'verified', ?)""",
        (args.text, now),
    )
    conn.execute(
        "UPDATE session SET updated_at = ? WHERE session_id = ?",
        (now, session_id),
    )
    conn.commit()
    row_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
    conn.close()
    print(f"OL-{row_id}")
    return 0


def cmd_ol_list(args: argparse.Namespace) -> int:
    """List operational learning entries (facts and findings only)."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, _session_id = result

    limit = getattr(args, "limit", 20) or 20
    conn = open_db(db_path, readonly=True)
    total = conn.execute(
        "SELECT COUNT(*) as cnt FROM observations WHERE category IN ('fact', 'finding')"
    ).fetchone()["cnt"]
    rows = conn.execute(
        "SELECT observation_id, text, created_at FROM observations "
        "WHERE category IN ('fact', 'finding') "
        "ORDER BY created_at DESC LIMIT ?",
        (limit,),
    ).fetchall()
    conn.close()

    for r in reversed(rows):
        print(f"OL-{r['observation_id']}: {r['text']}")
    if total > limit:
        print(f"({total} total, showing last {limit} — use --limit N for more)")
    return 0


def cmd_decision_add(args: argparse.Namespace) -> int:
    """Add a decision to the session decisions table."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, session_id = result

    now = utcnow()
    conn = open_db(db_path)

    # Auto-generate decision_id from title
    slug = args.title[:30].upper().replace(" ", "-")
    decision_id = f"D-{slug}"

    # Deduplicate: check if exact decision_id exists
    existing = conn.execute(
        "SELECT decision_id FROM decisions WHERE decision_id = ?",
        (decision_id,),
    ).fetchone()
    if existing is not None:
        # Append a counter
        count = conn.execute(
            "SELECT COUNT(*) FROM decisions WHERE decision_id LIKE ?",
            (f"{decision_id}%",),
        ).fetchone()[0]
        decision_id = f"{decision_id}-{count + 1}"

    description = getattr(args, "description", None)
    conn.execute(
        """INSERT INTO decisions (decision_id, title, description, status, decided_at)
           VALUES (?, ?, ?, 'decided', ?)""",
        (decision_id, args.title, description, now),
    )
    conn.execute(
        "UPDATE session SET updated_at = ? WHERE session_id = ?",
        (now, session_id),
    )
    conn.commit()
    conn.close()
    print(decision_id)
    return 0


def cmd_decision_list(args: argparse.Namespace) -> int:
    """List decisions from the session DB."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, _session_id = result

    limit = getattr(args, "limit", 30) or 30
    conn = open_db(db_path, readonly=True)
    total = conn.execute("SELECT COUNT(*) as cnt FROM decisions").fetchone()["cnt"]
    rows = conn.execute(
        "SELECT decision_id, title, description, status, decided_at FROM decisions "
        "ORDER BY decided_at DESC LIMIT ?",
        (limit,),
    ).fetchall()
    conn.close()

    for r in reversed(rows):
        desc = f"\n  {r['description']}" if r["description"] else ""
        print(f"{r['decision_id']}: [{r['status']}] {r['title']}{desc}")
    if total > limit:
        print(f"({total} total, showing last {limit} — use --limit N for more)")
    return 0


def cmd_incident_add(args: argparse.Namespace) -> int:
    """Add a process deviation/incident to the session DB."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, session_id = result

    now = utcnow()
    conn = open_db(db_path)
    conn.execute(
        """INSERT INTO deviations (description, impact, created_at)
           VALUES (?, ?, ?)""",
        (args.text, getattr(args, "impact", None), now),
    )
    conn.execute(
        "UPDATE session SET updated_at = ? WHERE session_id = ?",
        (now, session_id),
    )
    conn.commit()
    row_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
    conn.close()
    print(f"DEV-{row_id}")
    return 0


def cmd_incident_list(args: argparse.Namespace) -> int:
    """List process deviations/incidents from the session DB."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, _session_id = result

    limit = getattr(args, "limit", 30) or 30
    conn = open_db(db_path, readonly=True)
    total = conn.execute("SELECT COUNT(*) as cnt FROM deviations").fetchone()["cnt"]
    rows = conn.execute(
        "SELECT deviation_id, description, impact, created_at FROM deviations "
        "ORDER BY created_at DESC LIMIT ?",
        (limit,),
    ).fetchall()
    conn.close()

    for r in reversed(rows):
        impact = f"\n  impact: {r['impact']}" if r["impact"] else ""
        print(f"DEV-{r['deviation_id']}: {r['description']}{impact}")
    if total > limit:
        print(f"({total} total, showing last {limit} — use --limit N for more)")
    return 0


def cmd_observation_add(args: argparse.Namespace) -> int:
    """Add an observation to the session DB."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, session_id = result

    category = getattr(args, "category", None) or "observation"
    severity = getattr(args, "severity", None)

    now = utcnow()
    conn = open_db(db_path)
    conn.execute(
        """INSERT INTO observations (category, text, status, severity, created_at)
           VALUES (?, ?, 'pending', ?, ?)""",
        (category, args.text, severity, now),
    )
    conn.execute(
        "UPDATE session SET updated_at = ? WHERE session_id = ?",
        (now, session_id),
    )
    conn.commit()
    row_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
    conn.close()
    print(f"OBS-{row_id}")
    return 0


def cmd_search(args: argparse.Namespace) -> int:
    """Search across all session DB tables for a text pattern."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, _session_id = result

    query = f"%{args.query}%"
    limit = getattr(args, "limit", 50) or 50
    conn = open_db(db_path, readonly=True)
    results: list[str] = []

    # Search observations
    rows = conn.execute(
        "SELECT observation_id, category, text FROM observations WHERE text LIKE ?",
        (query,),
    ).fetchall()
    for r in rows:
        text_preview = r["text"][:100].replace("\n", " ")
        results.append(f"[{r['category']}] OBS-{r['observation_id']}: {text_preview}")

    # Search decisions
    rows = conn.execute(
        "SELECT decision_id, title, description FROM decisions WHERE title LIKE ? OR description LIKE ?",
        (query, query),
    ).fetchall()
    for r in rows:
        results.append(f"[decision] {r['decision_id']}: {r['title']}")

    # Search deviations
    rows = conn.execute(
        "SELECT deviation_id, description FROM deviations WHERE description LIKE ?",
        (query,),
    ).fetchall()
    for r in rows:
        text_preview = r["description"][:100].replace("\n", " ")
        results.append(f"[deviation] DEV-{r['deviation_id']}: {text_preview}")

    # Search messages
    rows = conn.execute(
        "SELECT message_id, message_type, message FROM messages WHERE message LIKE ? OR title LIKE ?",
        (query, query),
    ).fetchall()
    for r in rows:
        text_preview = r["message"][:100].replace("\n", " ")
        results.append(f"[{r['message_type']}] MSG-{r['message_id']}: {text_preview}")

    # Search missions
    rows = conn.execute(
        "SELECT mission_id, description, key_result FROM missions WHERE description LIKE ? OR key_result LIKE ?",
        (query, query),
    ).fetchall()
    for r in rows:
        results.append(f"[mission] {r['mission_id']}: {r['description']}")

    conn.close()

    if not results:
        print(f"No results for: {args.query}")
        return 0

    total = len(results)
    for line in results[:limit]:
        print(line)
    if total > limit:
        print(f"({total} total results, showing first {limit} — use --limit N for more)")
    return 0


# -- Directive subcommands (command channel) -----------------------------------


def cmd_directive_add(args: argparse.Namespace) -> int:
    """Add a commander directive to the session DB."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, session_id = result

    now = utcnow()
    directive_type = getattr(args, "type", "context") or "context"
    priority = getattr(args, "priority", "normal") or "normal"
    target = getattr(args, "target", None)

    conn = open_db(db_path)
    # Ensure table exists (schema migration for existing DBs)
    conn.executescript(
        """CREATE TABLE IF NOT EXISTS commander_directives (
            directive_id INTEGER PRIMARY KEY AUTOINCREMENT,
            directive_type TEXT NOT NULL,
            priority TEXT NOT NULL DEFAULT 'normal',
            message TEXT NOT NULL,
            target TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            response TEXT,
            created_at TEXT NOT NULL,
            acknowledged_at TEXT,
            executed_at TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_directives_status
            ON commander_directives(status);"""
    )
    conn.execute(
        """INSERT INTO commander_directives
           (directive_type, priority, message, target, status, created_at)
           VALUES (?, ?, ?, ?, 'pending', ?)""",
        (directive_type, priority, args.message, target, now),
    )
    conn.commit()
    row_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
    conn.close()
    print(f"DIR-{row_id} ({priority})")
    return 0


def cmd_directive_list(args: argparse.Namespace) -> int:
    """List commander directives from the session DB."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, _session_id = result

    status_filter = getattr(args, "status", None)
    limit = getattr(args, "limit", 20) or 20

    conn = open_db(db_path, readonly=True)

    # Check if table exists
    table_exists = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='commander_directives'"
    ).fetchone()
    if not table_exists:
        print("No directives (table not created yet)")
        conn.close()
        return 0

    if status_filter:
        rows = conn.execute(
            "SELECT directive_id, directive_type, priority, message, target, status, "
            "created_at, acknowledged_at FROM commander_directives "
            "WHERE status = ? ORDER BY created_at DESC LIMIT ?",
            (status_filter, limit),
        ).fetchall()
        total = conn.execute(
            "SELECT COUNT(*) as cnt FROM commander_directives WHERE status = ?",
            (status_filter,),
        ).fetchone()["cnt"]
    else:
        rows = conn.execute(
            "SELECT directive_id, directive_type, priority, message, target, status, "
            "created_at, acknowledged_at FROM commander_directives "
            "ORDER BY created_at DESC LIMIT ?",
            (limit,),
        ).fetchall()
        total = conn.execute(
            "SELECT COUNT(*) as cnt FROM commander_directives"
        ).fetchone()["cnt"]
    conn.close()

    if not rows:
        print("No directives found")
        return 0

    for r in reversed(rows):
        priority_tag = f"[{r['priority'].upper()}] " if r["priority"] != "normal" else ""
        status_tag = r["status"]
        msg_preview = r["message"][:100].replace("\n", " ")
        target_str = f" -> {r['target']}" if r["target"] else ""
        print(
            f"DIR-{r['directive_id']} {priority_tag}{r['directive_type']}{target_str} "
            f"({status_tag}): {msg_preview}"
        )
    if total > limit:
        print(f"({total} total, showing last {limit} -- use --limit N for more)")
    return 0


def cmd_directive_poll(args: argparse.Namespace) -> int:
    """Poll for pending directives (used by command-channel-stop.sh).

    Prints pending count to stdout. Prints directive text to stderr.
    Exit 0 always (the hook handles exit codes).
    """
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        print("0")
        return 0
    db_path, _session_id = result

    conn = open_db(db_path)
    pending: list[str] = []
    now = utcnow()

    # Check commander_directives
    try:
        rows = conn.execute(
            "SELECT directive_id, directive_type, priority, message, target "
            "FROM commander_directives WHERE status = 'pending' ORDER BY created_at"
        ).fetchall()
        for r in rows:
            priority = r["priority"]
            prefix = (
                "[FLASH] "
                if priority == "flash"
                else "[PRIORITY] " if priority == "priority" else ""
            )
            dtype = r["directive_type"].upper()
            msg = r["message"]
            target = f" (re: {r['target']})" if r["target"] else ""
            pending.append(f"{prefix}{dtype}{target}: {msg}")
            conn.execute(
                "UPDATE commander_directives SET status = 'acknowledged', "
                "acknowledged_at = ? WHERE directive_id = ?",
                (now, r["directive_id"]),
            )
    except Exception:
        pass

    # Check commander_feedback (fallback)
    try:
        rows = conn.execute(
            "SELECT feedback_id, feedback_type, message, target "
            "FROM commander_feedback WHERE status = 'submitted' ORDER BY created_at"
        ).fetchall()
        for r in rows:
            ftype = r["feedback_type"].upper()
            msg = r["message"]
            target = f" (re: {r['target']})" if r["target"] else ""
            pending.append(f"{ftype}{target}: {msg}")
            conn.execute(
                "UPDATE commander_feedback SET status = 'acknowledged', "
                "acknowledged_at = ? WHERE feedback_id = ?",
                (now, r["feedback_id"]),
            )
    except Exception:
        pass

    if pending:
        conn.commit()
        import sys as _sys

        print("=== COMMANDER DIRECTIVE(S) ===", file=_sys.stderr)
        for p in pending:
            print(f"  {p}", file=_sys.stderr)
        print(
            "=== END DIRECTIVES -- Address these before continuing ===",
            file=_sys.stderr,
        )

    conn.close()
    print(len(pending))
    return 0


def cmd_directive_ack(args: argparse.Namespace) -> int:
    """Mark a directive as executed with an optional response."""
    project_root = find_project_root()
    result = resolve_session_db(project_root, getattr(args, "session", None))
    if result is None:
        return 1
    db_path, _session_id = result

    now = utcnow()
    directive_id = args.directive_id
    response = getattr(args, "response", None)
    status = getattr(args, "status", "executed") or "executed"

    conn = open_db(db_path)
    row = conn.execute(
        "SELECT directive_id, status FROM commander_directives WHERE directive_id = ?",
        (directive_id,),
    ).fetchone()
    if not row:
        print(f"Directive {directive_id} not found")
        conn.close()
        return 1

    conn.execute(
        "UPDATE commander_directives SET status = ?, response = ?, executed_at = ? "
        "WHERE directive_id = ?",
        (status, response, now, directive_id),
    )
    conn.commit()
    conn.close()
    print(f"DIR-{directive_id} -> {status}")
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
    export_parser.add_argument(
        "--force", action="store_true",
        help="Force export even if it would overwrite a larger file",
    )

    # status
    subparsers.add_parser("status", help="Show harness database status")

    # process-events
    process_parser = subparsers.add_parser(
        "process-events", help="Process session events.jsonl into KPI metrics"
    )
    process_parser.add_argument("--session", help="Session ID (auto-detects if omitted)")

    # ship
    subparsers.add_parser("ship", help="Ship KPI events to Datadog")

    # -- Provenance subcommands -----------------------------------------------

    # knowledge
    knowledge_parser = subparsers.add_parser("knowledge", help="Knowledge item operations")
    knowledge_sub = knowledge_parser.add_subparsers(dest="knowledge_command")

    # knowledge add
    ka = knowledge_sub.add_parser("add", help="Add or update a knowledge item")
    ka.add_argument("--item-id", required=True, help="Stable ID (e.g., OL-2, D-34)")
    ka.add_argument(
        "--type", dest="item_type", required=True,
        choices=["observation", "assumption", "fact", "finding", "decision",
                 "ol_entry", "rule_change", "framework_change", "commander_directive"],
        help="Knowledge item type",
    )
    ka.add_argument("--content", required=True, help="The knowledge content")
    ka.add_argument("--attributed-to", help="Who produced it (commander|agent|name)")
    ka.add_argument("--session", help="Producing session ID")
    ka.add_argument("--mission", help="Producing mission ID")
    ka.add_argument("--authority-level", type=int, choices=[0, 1, 2, 3], help="Authority (0-3)")
    ka.add_argument(
        "--trust-level",
        choices=["commander_directive", "verified_fact",
                 "agent_observation", "unverified_assumption"],
        help="Trust classification",
    )
    ka.add_argument("--t-valid", dest="t_valid", help="When fact became true (ISO 8601)")
    ka.add_argument("--warn-after", help="Days before staleness warning (default: 30)")
    ka.add_argument("--error-after", help="Days before staleness error (default: 90)")

    # knowledge invalidate
    ki_inv = knowledge_sub.add_parser("invalidate", help="Invalidate an item and propagate")
    ki_inv.add_argument("--item-id", required=True, help="Item ID to invalidate")
    ki_inv.add_argument("--superseded-by", help="Item ID that supersedes this one")
    ki_inv.add_argument("--session", help="Session ID recording invalidation")

    # knowledge verify
    ki_ver = knowledge_sub.add_parser("verify", help="Mark an item as verified")
    ki_ver.add_argument("--item-id", required=True, help="Item ID to verify")
    ki_ver.add_argument(
        "--trust-level",
        choices=["commander_directive", "verified_fact",
                 "agent_observation", "unverified_assumption"],
        help="New trust level (default: verified_fact)",
    )

    # knowledge list
    ki_ls = knowledge_sub.add_parser("list", help="List knowledge items")
    ki_ls.add_argument(
        "--type", dest="item_type",
        choices=["observation", "assumption", "fact", "finding", "decision",
                 "ol_entry", "rule_change", "framework_change", "commander_directive"],
        help="Filter by type",
    )
    ki_ls.add_argument(
        "--trust-level",
        choices=["commander_directive", "verified_fact",
                 "agent_observation", "unverified_assumption"],
        help="Filter by trust level",
    )
    ki_ls.add_argument("--valid-only", action="store_true", help="Only current (non-invalidated) items")
    ki_ls.add_argument("--stale", action="store_true", help="Only stale items past warn_after_days")

    # edge
    edge_parser = subparsers.add_parser("edge", help="Provenance edge operations")
    edge_sub = edge_parser.add_subparsers(dest="edge_command")

    # edge add
    ea = edge_sub.add_parser("add", help="Add a provenance edge")
    ea.add_argument("--source", required=True, help="Source item ID (the dependent)")
    ea.add_argument("--target", required=True, help="Target item ID (the basis)")
    ea.add_argument(
        "--relationship", required=True,
        choices=["derived_from", "informed", "triggered",
                 "validated", "invalidated", "superseded"],
        help="Edge type",
    )
    ea.add_argument("--session", help="Session ID where edge was recorded")

    # edge list
    el = edge_sub.add_parser("list", help="List edges for a knowledge item")
    el.add_argument("--item-id", required=True, help="Item ID to show edges for")

    # nogood
    nogood_parser = subparsers.add_parser("nogood", help="Nogood set operations")
    nogood_sub = nogood_parser.add_subparsers(dest="nogood_command")

    # nogood add
    na = nogood_sub.add_parser("add", help="Record a known contradiction")
    na.add_argument("--items", required=True, help="Comma-separated item IDs")
    na.add_argument("--contradiction", required=True, help="Description of the contradiction")
    na.add_argument("--session", help="Session ID where discovered")

    # nogood list
    nogood_sub.add_parser("list", help="List all nogood sets")

    # nogood check
    nc = nogood_sub.add_parser("check", help="Check assumptions against known nogoods")
    nc.add_argument("--items", required=True, help="Comma-separated item IDs to check")

    # provenance export
    prov_export = subparsers.add_parser(
        "provenance-export", help="Export all provenance data to JSON"
    )
    prov_export.add_argument("--output", help="Output file path (stdout if omitted)")

    # -- Lean subcommands (one-liner Bash calls) ------------------------------

    # ol (operational learning)
    ol_parser = subparsers.add_parser("ol", help="Operational learning (quick add/list)")
    ol_sub = ol_parser.add_subparsers(dest="ol_command")

    ol_add = ol_sub.add_parser("add", help="Add an OL entry")
    ol_add.add_argument("text", help="The operational learning text")
    ol_add.add_argument("--session", help="Session ID (auto-detects if omitted)")

    ol_ls = ol_sub.add_parser("list", help="List OL entries")
    ol_ls.add_argument("--session", help="Session ID (auto-detects if omitted)")
    ol_ls.add_argument("--limit", type=int, default=20, help="Max entries to show (default: 20)")

    # decision (quick)
    dec_parser = subparsers.add_parser("decision", help="Decisions (quick add/list)")
    dec_sub = dec_parser.add_subparsers(dest="decision_command")

    dec_add = dec_sub.add_parser("add", help="Add a decision")
    dec_add.add_argument("title", help="Decision title")
    dec_add.add_argument("--description", help="Decision description")
    dec_add.add_argument("--session", help="Session ID (auto-detects if omitted)")

    dec_ls = dec_sub.add_parser("list", help="List decisions")
    dec_ls.add_argument("--session", help="Session ID (auto-detects if omitted)")
    dec_ls.add_argument("--limit", type=int, default=30, help="Max entries to show (default: 30)")

    # incident (maps to deviations table)
    inc_parser = subparsers.add_parser("incident", help="Process incidents (quick add/list)")
    inc_sub = inc_parser.add_subparsers(dest="incident_command")

    inc_add = inc_sub.add_parser("add", help="Add an incident/deviation")
    inc_add.add_argument("text", help="Incident description")
    inc_add.add_argument("--impact", help="Impact description")
    inc_add.add_argument("--session", help="Session ID (auto-detects if omitted)")

    inc_ls = inc_sub.add_parser("list", help="List incidents/deviations")
    inc_ls.add_argument("--session", help="Session ID (auto-detects if omitted)")
    inc_ls.add_argument("--limit", type=int, default=30, help="Max entries to show (default: 30)")

    # observation (quick)
    obs_parser = subparsers.add_parser("observation", help="Observations (quick add/list)")
    obs_sub = obs_parser.add_subparsers(dest="observation_command")

    obs_add = obs_sub.add_parser("add", help="Add an observation")
    obs_add.add_argument("text", help="Observation text")
    obs_add.add_argument(
        "--category", default="observation",
        choices=["observation", "assumption", "fact", "finding"],
        help="Category (default: observation)",
    )
    obs_add.add_argument(
        "--severity",
        choices=["critical", "high", "medium", "low"],
        help="Severity level",
    )
    obs_add.add_argument("--session", help="Session ID (auto-detects if omitted)")

    # search
    search_parser = subparsers.add_parser("search", help="Search across all session tables")
    search_parser.add_argument("query", help="Text to search for (LIKE match)")
    search_parser.add_argument("--session", help="Session ID (auto-detects if omitted)")
    search_parser.add_argument("--limit", type=int, default=50, help="Max results to show (default: 50)")

    # -- directive (command channel) --
    dir_parser = subparsers.add_parser("directive", help="Commander directives (command channel)")
    dir_sub = dir_parser.add_subparsers(dest="directive_command")

    dir_add = dir_sub.add_parser("add", help="Add a directive")
    dir_add.add_argument("message", help="Directive message text")
    dir_add.add_argument(
        "--type", default="context",
        choices=["correction", "redirect", "priority", "question",
                 "approve", "reject", "context", "checkpoint"],
        help="Directive type (default: context)",
    )
    dir_add.add_argument(
        "--priority", default="normal",
        choices=["flash", "priority", "normal"],
        help="Priority level (default: normal)",
    )
    dir_add.add_argument("--target", help="What the directive is about (mission, file, decision)")
    dir_add.add_argument("--session", help="Session ID (auto-detects if omitted)")

    dir_ls = dir_sub.add_parser("list", help="List directives")
    dir_ls.add_argument("--status", choices=["pending", "acknowledged", "executed", "rejected", "deferred"],
                        help="Filter by status")
    dir_ls.add_argument("--session", help="Session ID (auto-detects if omitted)")
    dir_ls.add_argument("--limit", type=int, default=20, help="Max results (default: 20)")

    dir_poll = dir_sub.add_parser("poll", help="Poll pending directives (for hooks)")
    dir_poll.add_argument("--session", help="Session ID (auto-detects if omitted)")

    dir_ack = dir_sub.add_parser("ack", help="Acknowledge/execute a directive")
    dir_ack.add_argument("directive_id", type=int, help="Directive ID to acknowledge")
    dir_ack.add_argument("--response", help="Agent's response to the directive")
    dir_ack.add_argument("--status", default="executed",
                         choices=["executed", "rejected", "deferred"],
                         help="Resolution status (default: executed)")
    dir_ack.add_argument("--session", help="Session ID (auto-detects if omitted)")

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
        "process-events": cmd_process_events,
        "ship": cmd_ship,
        "provenance-export": cmd_provenance_export,
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

    if args.command == "knowledge":
        kc = getattr(args, "knowledge_command", None)
        if kc == "add":
            return cmd_knowledge_add(args)
        elif kc == "invalidate":
            return cmd_knowledge_invalidate(args)
        elif kc == "verify":
            return cmd_knowledge_verify(args)
        elif kc == "list":
            return cmd_knowledge_list(args)
        else:
            parser.parse_args(["knowledge", "--help"])
            return 1

    if args.command == "edge":
        ec = getattr(args, "edge_command", None)
        if ec == "add":
            return cmd_edge_add(args)
        elif ec == "list":
            return cmd_edge_list(args)
        else:
            parser.parse_args(["edge", "--help"])
            return 1

    if args.command == "nogood":
        nc = getattr(args, "nogood_command", None)
        if nc == "add":
            return cmd_nogood_add(args)
        elif nc == "list":
            return cmd_nogood_list(args)
        elif nc == "check":
            return cmd_nogood_check(args)
        else:
            parser.parse_args(["nogood", "--help"])
            return 1

    # -- Lean subcommands dispatch --------------------------------------------

    if args.command == "ol":
        oc = getattr(args, "ol_command", None)
        if oc == "add":
            return cmd_ol_add(args)
        elif oc == "list":
            return cmd_ol_list(args)
        else:
            parser.parse_args(["ol", "--help"])
            return 1

    if args.command == "decision":
        dc = getattr(args, "decision_command", None)
        if dc == "add":
            return cmd_decision_add(args)
        elif dc == "list":
            return cmd_decision_list(args)
        else:
            parser.parse_args(["decision", "--help"])
            return 1

    if args.command == "incident":
        ic = getattr(args, "incident_command", None)
        if ic == "add":
            return cmd_incident_add(args)
        elif ic == "list":
            return cmd_incident_list(args)
        else:
            parser.parse_args(["incident", "--help"])
            return 1

    if args.command == "observation":
        obc = getattr(args, "observation_command", None)
        if obc == "add":
            return cmd_observation_add(args)
        else:
            parser.parse_args(["observation", "--help"])
            return 1

    if args.command == "search":
        return cmd_search(args)

    if args.command == "directive":
        dc = getattr(args, "directive_command", None)
        if dc == "add":
            return cmd_directive_add(args)
        elif dc == "list":
            return cmd_directive_list(args)
        elif dc == "poll":
            return cmd_directive_poll(args)
        elif dc == "ack":
            return cmd_directive_ack(args)
        else:
            parser.parse_args(["directive", "--help"])
            return 1

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
