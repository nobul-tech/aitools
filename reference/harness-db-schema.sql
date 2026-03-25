-- harness-db-schema.sql -- Canonical schema for aitools harness SQLite databases
--
-- Purpose: Define the schema for two database tiers:
--   1. Session DB (.aitools/sessions/<prefix>.db) -- per-session state
--   2. Harness DB (.aitools/harness.db) -- cross-session state
--
-- Architecture: Multi-DB (per-session + harness-level). Each session writes
-- only to its own DB, eliminating WAL write contention between concurrent
-- sessions. Harness DB is written at session boundaries only.
--
-- Runtime model (Option B): DB files are gitignored runtime artifacts.
-- JSON exports (running-estimate.json) are tracked in git for cross-machine
-- carry-forward. Export at session end; import at session start if DB missing.
--
-- Connection pattern: Python sqlite3 stdlib only (sqlite3 CLI unavailable
-- on Windows Git Bash). WAL mode for concurrent readers.
--
-- References:
--   - RFC: .scratch/session-RnTOD5XJFi/rfc-sqlite-harness-architecture.md
--   - Multi-DB design: .scratch/session-RnTOD5XJFi/sqlite-multi-db-design.md
--   - Marse precedent: ~/repos/marse/rfcs/0001-cli-architecture.draft.md
--
-- Safe to re-run: CREATE IF NOT EXISTS throughout.

-- ============================================================================
-- TIER 1: SESSION DB (.aitools/sessions/<prefix>.db)
-- One DB per Claude Code session. Written by that session's agents only.
-- Read by dashboard and other sessions (read-only).
-- ============================================================================

-- Required pragmas (set on every connection open):
-- PRAGMA journal_mode=WAL;
-- PRAGMA synchronous=NORMAL;
-- PRAGMA busy_timeout=5000;
-- PRAGMA foreign_keys=ON;

-- Session metadata (one row per DB)
CREATE TABLE IF NOT EXISTS session (
    session_id TEXT PRIMARY KEY,
    prior_session TEXT,
    schwerpunkt TEXT NOT NULL,
    accepting_schwerpunkt TEXT,
    current_state TEXT,               -- free text summary
    started_at TEXT NOT NULL,         -- ISO 8601 UTC (Z suffix)
    updated_at TEXT NOT NULL,         -- ISO 8601 UTC (Z suffix)
    ended_at TEXT,                    -- ISO 8601 UTC (Z suffix), NULL while active
    version REAL NOT NULL DEFAULT 1.0,
    platform TEXT,                    -- darwin, win32, linux
    agent_identity TEXT               -- e.g. "S3-Victor"
);

-- Missions: delegated agent missions (self-referential for nesting)
CREATE TABLE IF NOT EXISTS missions (
    mission_id TEXT PRIMARY KEY,      -- e.g. "M24", "S2-Echo"
    parent_mission_id TEXT REFERENCES missions(mission_id),
    mission_type TEXT NOT NULL,       -- s2, s3, s5, recon, fragord
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'launched'
        CHECK (status IN ('launched', 'in_progress', 'complete', 'failed', 'killed')),
    launched_at TEXT NOT NULL,        -- ISO 8601 UTC
    completed_at TEXT,                -- ISO 8601 UTC
    findings_count INTEGER DEFAULT 0,
    key_result TEXT                   -- one-line outcome
);
CREATE INDEX IF NOT EXISTS idx_missions_parent ON missions(parent_mission_id);
CREATE INDEX IF NOT EXISTS idx_missions_status ON missions(status);

-- Decisions: architectural and session decisions
CREATE TABLE IF NOT EXISTS decisions (
    decision_id TEXT PRIMARY KEY,     -- e.g. "D-DASHBOARD-SHIP"
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'decided'
        CHECK (status IN ('decided', 'implemented', 'verified', 'deferred', 'reversed')),
    implementation_evidence TEXT,
    decided_at TEXT NOT NULL,         -- ISO 8601 UTC
    implemented_at TEXT               -- ISO 8601 UTC
);
CREATE INDEX IF NOT EXISTS idx_decisions_status ON decisions(status);

-- Observations: classified per governed vocabulary
CREATE TABLE IF NOT EXISTS observations (
    observation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL
        CHECK (category IN ('observation', 'assumption', 'fact', 'finding')),
    text TEXT NOT NULL,
    status TEXT,                      -- verified, falsified, pending
    evidence TEXT,
    severity TEXT                     -- critical, high, medium, low
        CHECK (severity IS NULL OR severity IN ('critical', 'high', 'medium', 'low')),
    created_at TEXT NOT NULL          -- ISO 8601 UTC
);
CREATE INDEX IF NOT EXISTS idx_observations_category ON observations(category);

-- Messages: SITREPs and FINDINGs (replaces channel/session-* files)
CREATE TABLE IF NOT EXISTS messages (
    message_id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_type TEXT NOT NULL
        CHECK (message_type IN ('sitrep', 'finding')),
    agent_role TEXT NOT NULL,         -- e.g. "S3-Victor", "S2-Echo"
    title TEXT,                       -- for findings
    message TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'routine'
        CHECK (severity IN ('routine', 'priority', 'flash', 'low', 'medium', 'high', 'critical')),
    actionable BOOLEAN DEFAULT 0,    -- for findings
    created_at TEXT NOT NULL          -- ISO 8601 UTC
);
CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(message_type);

-- Delegation log: every agent launch
CREATE TABLE IF NOT EXISTS delegation_log (
    entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
    mission_id TEXT REFERENCES missions(mission_id),
    agent_type TEXT NOT NULL,         -- s2, s3, s5
    agent_name TEXT NOT NULL,         -- "S2-Echo", "S3-Mike"
    prompt_summary TEXT,
    status TEXT NOT NULL DEFAULT 'launched'
        CHECK (status IN ('launched', 'in_progress', 'complete', 'failed', 'killed')),
    launched_at TEXT NOT NULL,        -- ISO 8601 UTC
    completed_at TEXT,                -- ISO 8601 UTC
    token_usage INTEGER,
    duration_ms INTEGER,
    outcome TEXT
);
CREATE INDEX IF NOT EXISTS idx_delegation_session ON delegation_log(mission_id);

-- Deviations: process deviations
CREATE TABLE IF NOT EXISTS deviations (
    deviation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    description TEXT NOT NULL,
    impact TEXT,
    batch_origin TEXT,
    created_at TEXT NOT NULL          -- ISO 8601 UTC
);

-- Hard requirements
CREATE TABLE IF NOT EXISTS hard_requirements (
    requirement_id TEXT PRIMARY KEY,
    requirement TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'not-started'
        CHECK (status IN ('not-started', 'in-progress', 'complete', 'deferred')),
    plan_scale_item TEXT,
    prerequisites TEXT,               -- pipe-delimited IDs
    surfaced_by TEXT,
    created_at TEXT NOT NULL          -- ISO 8601 UTC
);

-- Completed work
CREATE TABLE IF NOT EXISTS completed_work (
    work_id INTEGER PRIMARY KEY AUTOINCREMENT,
    item TEXT NOT NULL,
    category TEXT,
    decided_by TEXT,
    completed_at TEXT NOT NULL        -- ISO 8601 UTC
);

-- Session-level event log. Append-only. The WAL for telemetry.
-- Written by enforcement hooks (fast, via JSONL) and ingested at session end.
-- Read by SessionEnd processor (cold path only).
CREATE TABLE IF NOT EXISTS events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    -- Enumerated event types:
    --   'hook_fire'      -- enforcement hook fired (guard, fixup)
    --   'hook_block'     -- enforcement hook blocked a tool use
    --   'hook_warn'      -- enforcement hook warned but allowed
    --   'delegation'     -- subagent launched (from delegation-duty-guard)
    --   'session_event'  -- session lifecycle (start, checkpoint, end)
    source TEXT NOT NULL,            -- hook name or 'agent' or 'system'
    detail TEXT,                     -- JSON blob with event-specific data
    created_at TEXT NOT NULL         -- ISO 8601 UTC (Z suffix)
);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_source ON events(source);

-- Version history (replaces meta.versionHistory array)
CREATE TABLE IF NOT EXISTS version_history (
    version REAL NOT NULL PRIMARY KEY,
    timestamp TEXT NOT NULL,          -- ISO 8601 UTC
    changes TEXT NOT NULL
);

-- Schema version tracking (for forward-only migrations)
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL           -- ISO 8601 UTC
);

-- ============================================================================
-- TIER 2: HARNESS DB (.aitools/harness.db)
-- Cross-session state. Written at session boundaries (start/end) only.
-- ============================================================================

-- Session index: lightweight discovery of all sessions
CREATE TABLE IF NOT EXISTS session_index (
    session_id TEXT PRIMARY KEY,
    db_path TEXT NOT NULL,            -- relative path to session DB
    started_at TEXT NOT NULL,         -- ISO 8601 UTC
    ended_at TEXT,                    -- ISO 8601 UTC
    schwerpunkt TEXT,
    platform TEXT,                    -- darwin, win32, linux
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'crashed'))
);

-- KPI events: individual metric measurements (decision #32 future-proofing)
CREATE TABLE IF NOT EXISTS kpi_events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,        -- e.g. "hook_fire_count", "delegation_compliance"
    metric_value REAL NOT NULL,
    dimensions TEXT,                  -- JSON blob: {"hook": "surfacing-duty", "layer": "detection"}
    collected_at TEXT NOT NULL        -- ISO 8601 UTC
);
CREATE INDEX IF NOT EXISTS idx_kpi_session ON kpi_events(session_id);
CREATE INDEX IF NOT EXISTS idx_kpi_metric ON kpi_events(metric_name);
CREATE INDEX IF NOT EXISTS idx_kpi_collected ON kpi_events(collected_at);

-- KPI shipping state: tracks what has been sent to Datadog
CREATE TABLE IF NOT EXISTS kpi_ship_log (
    ship_id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_size INTEGER NOT NULL,
    shipped_at TEXT NOT NULL,         -- ISO 8601 UTC
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'shipped', 'failed')),
    error_message TEXT,
    datadog_response TEXT
);

-- Dashboard state: runtime tracking of which dashboards are serving
CREATE TABLE IF NOT EXISTS dashboard_state (
    port INTEGER PRIMARY KEY,
    session_id TEXT NOT NULL,
    pid INTEGER,
    db_path TEXT,
    started_at TEXT NOT NULL,         -- ISO 8601 UTC
    last_checked TEXT                 -- ISO 8601 UTC
);

-- Harness schema version (separate from session schema_version)
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL           -- ISO 8601 UTC
);
