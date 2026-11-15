-- Frozen copy of the schema-version 3 session DDL of scripts/harness-db.py
-- (origin/main 70b7054, 2026-11-14). Test fixture for the v3 -> v4 migration
-- (tests/harness-db/test-schema.py). Never edit: it is the old shape.

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
    agent_identity TEXT,  -- 'Session Commander <session_id[:10]>', set at session start
    project_dir TEXT,  -- absolute repo/working dir (git root), set at session start
    project_claude_md TEXT,  -- <project_dir>/CLAUDE.md
    user_claude_md TEXT  -- ~/.claude/CLAUDE.md
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
