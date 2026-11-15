-- harness-db-schema.sql -- schema of the aitools harness SQLite databases
-- schema-version: 4
--
-- GENERATED FILE: do not edit by hand. The source of truth is
-- scripts/harness-db.py (SCHEMA_VERSION, SESSION_SCHEMA, HARNESS_SCHEMA).
-- After changing it, regenerate this file:
--   python3 scripts/harness-db.py schema --output reference/harness-db-schema.sql
-- tests/harness-db/test-schema.py fails when this file and the script differ.
--
-- Two tiers:
--   1. Session DB (.aitools/sessions/<prefix>.db): per-session state. Each
--      session writes only to its own DB (no WAL write contention between
--      concurrent sessions).
--   2. Harness DB (.aitools/harness.db): cross-session state, written at
--      session boundaries.
-- Both tiers share SCHEMA_VERSION and the schema_version table shape. A DB
-- holds one schema_version row per version it was created at or migrated to.
-- ensure_schema() in harness-db.py migrates forward only and idempotently,
-- whenever the CLI opens a DB to write it.
--
-- Runtime model: DB files are gitignored runtime artifacts; JSON exports
-- (running-estimate.json) are tracked for cross-machine carry-forward.
-- Connection: Python sqlite3 stdlib only (no sqlite3 CLI on Windows Git Bash).
-- Intelligence types and their doctrine: reference/framework-intelligence-types.md
--
-- Version history:
--   1 (2026-03-24) session and harness tiers
--   2 (2026-03-25) provenance tables: knowledge_items, provenance_edges, nogood_sets
--   3 (2026-06-21) session.project_dir, project_claude_md, user_claude_md
--   4 (2026-11-15) intelligence types: finding is the analysis type (criteria,
--      cause, effect, suggestion); the SALUTE FINDING is retired (observation
--      with a severity; message type spotrep); ol_entry is operational_learning;
--      provenance columns (attributed_to, source_kind, source, quote) and
--      confidence; schema_version rows recorded on every migration

-- ============================================================================
-- TIER 1: SESSION DB (.aitools/sessions/<prefix>.db)
-- One DB per Claude Code session, written by that session's agents only.
-- ============================================================================

-- Required pragmas, set on every connection by open_db():
--   journal_mode=WAL, synchronous=NORMAL, busy_timeout=5000, foreign_keys=ON

-- Session metadata (one row per DB)
CREATE TABLE IF NOT EXISTS session (
    session_id TEXT PRIMARY KEY,
    prior_session TEXT,
    schwerpunkt TEXT NOT NULL,  -- the session's main effort (column name predates the English term)
    accepting_schwerpunkt TEXT,
    current_state TEXT,  -- free text summary
    started_at TEXT NOT NULL,  -- ISO 8601 UTC (Z suffix)
    updated_at TEXT NOT NULL,  -- ISO 8601 UTC (Z suffix)
    ended_at TEXT,  -- ISO 8601 UTC (Z suffix), NULL while active
    version REAL NOT NULL DEFAULT 1.0,
    platform TEXT,  -- darwin, win32, linux
    agent_identity TEXT,  -- 'Session Commander <session_id[:10]>', set at session start
    project_dir TEXT,  -- absolute repo/working dir (git root), set at session start
    project_claude_md TEXT,  -- <project_dir>/CLAUDE.md
    user_claude_md TEXT  -- ~/.claude/CLAUDE.md
);

-- Missions: delegated agent missions (self-referential for nesting)
CREATE TABLE IF NOT EXISTS missions (
    mission_id TEXT PRIMARY KEY,  -- e.g. "M24", "S2-Echo"
    parent_mission_id TEXT REFERENCES missions(mission_id),
    mission_type TEXT NOT NULL,  -- s2, s3, s5, recon, fragord
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'launched'
        CHECK (status IN ('launched', 'in_progress', 'complete', 'failed', 'killed')),
    launched_at TEXT NOT NULL,  -- ISO 8601 UTC
    completed_at TEXT,  -- ISO 8601 UTC
    findings_count INTEGER DEFAULT 0,  -- v1 name; no command writes it
    key_result TEXT  -- one-line outcome
);
CREATE INDEX IF NOT EXISTS idx_missions_parent ON missions(parent_mission_id);
CREATE INDEX IF NOT EXISTS idx_missions_status ON missions(status);

-- Decisions: architectural and session decisions
CREATE TABLE IF NOT EXISTS decisions (
    decision_id TEXT PRIMARY KEY,  -- e.g. "D-DASHBOARD-SHIP"
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'decided'
        CHECK (status IN ('decided', 'implemented', 'verified', 'deferred', 'reversed')),
    implementation_evidence TEXT,
    decided_at TEXT NOT NULL,  -- ISO 8601 UTC
    implemented_at TEXT  -- ISO 8601 UTC
);
CREATE INDEX IF NOT EXISTS idx_decisions_status ON decisions(status);

-- Intelligence items of this session, one row per item (the table keeps its
-- v1 name). category is the intelligence type. The finding columns (criteria,
-- cause, effect, suggestion) are NULL for the other types.
CREATE TABLE IF NOT EXISTS observations (
    observation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL
        CHECK (category IN ('observation', 'fact', 'assumption', 'finding', 'operational_learning', 'proposal', 'rfi')),
    text TEXT NOT NULL,  -- the statement; for a finding, the condition found
    status TEXT,  -- pending, verified, falsified
    evidence TEXT,
    severity TEXT
        CHECK (severity IS NULL OR severity IN ('critical', 'high', 'medium', 'low')),
    confidence TEXT  -- analytic confidence (JP 2-0 appendix A)
        CHECK (confidence IS NULL OR confidence IN ('low', 'moderate', 'high')),
    criteria TEXT,  -- finding: what should be (rule, spec, expectation)
    cause TEXT,  -- finding: why the condition differs from the criteria
    effect TEXT,  -- finding: what the condition leads to, or could
    suggestion TEXT,  -- finding: one-line direction; the worked change is a proposal
    refs TEXT,  -- JSON array of the item ids this item rests on, e.g. ["OBS-3"]
    attributed_to TEXT,  -- who reported it: commander, a delegate's name, a hook
    source_kind TEXT
        CHECK (source_kind IS NULL OR source_kind IN ('commander', 'agent', 'telemetry', 'artifact', 'web')),
    source TEXT,  -- where: path:line, commit SHA, URL, transcript line
    quote TEXT,  -- the source text verbatim (always for the commander's words)
    legacy_category TEXT,  -- set only by the v4 migration: the row's v3 category
    created_at TEXT NOT NULL  -- ISO 8601 UTC
);
CREATE INDEX IF NOT EXISTS idx_observations_category ON observations(category);

-- Messages: SITREP (status report) and SPOTREP (an observation reported at
-- once, SALUTE-style; replaced the FINDING message in v4)
CREATE TABLE IF NOT EXISTS messages (
    message_id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_type TEXT NOT NULL
        CHECK (message_type IN ('sitrep', 'spotrep')),
    agent_role TEXT NOT NULL,  -- e.g. "S3-Victor", "S2-Echo"
    title TEXT,
    message TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'routine'
        CHECK (severity IN ('routine', 'priority', 'flash', 'low', 'medium', 'high', 'critical')),
    actionable BOOLEAN DEFAULT 0,
    created_at TEXT NOT NULL  -- ISO 8601 UTC
);
CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(message_type);

-- Delegation log: every agent launch
CREATE TABLE IF NOT EXISTS delegation_log (
    entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
    mission_id TEXT REFERENCES missions(mission_id),
    agent_type TEXT NOT NULL,  -- s2, s3, s5
    agent_name TEXT NOT NULL,  -- "S2-Echo", "S3-Mike"
    prompt_summary TEXT,
    status TEXT NOT NULL DEFAULT 'launched'
        CHECK (status IN ('launched', 'in_progress', 'complete', 'failed', 'killed')),
    launched_at TEXT NOT NULL,  -- ISO 8601 UTC
    completed_at TEXT,  -- ISO 8601 UTC
    token_usage INTEGER,
    duration_ms INTEGER,
    outcome TEXT
);
CREATE INDEX IF NOT EXISTS idx_delegation_mission ON delegation_log(mission_id);

-- Deviations: process deviations (the `incident` verbs write here)
CREATE TABLE IF NOT EXISTS deviations (
    deviation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    description TEXT NOT NULL,
    impact TEXT,
    batch_origin TEXT,
    created_at TEXT NOT NULL  -- ISO 8601 UTC
);

-- Hard requirements
CREATE TABLE IF NOT EXISTS hard_requirements (
    requirement_id TEXT PRIMARY KEY,
    requirement TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'not-started'
        CHECK (status IN ('not-started', 'in-progress', 'complete', 'deferred')),
    plan_scale_item TEXT,
    prerequisites TEXT,  -- pipe-delimited IDs
    surfaced_by TEXT,
    created_at TEXT NOT NULL  -- ISO 8601 UTC
);

-- Completed work
CREATE TABLE IF NOT EXISTS completed_work (
    work_id INTEGER PRIMARY KEY AUTOINCREMENT,
    item TEXT NOT NULL,
    category TEXT,
    decided_by TEXT,
    completed_at TEXT NOT NULL  -- ISO 8601 UTC
);

-- Session event log, append-only. Hooks write events.jsonl; the SessionEnd
-- processor (process-events) reads it. Event types: hook_fire, hook_block,
-- hook_warn, delegation, session_event.
CREATE TABLE IF NOT EXISTS events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    source TEXT NOT NULL,  -- hook name or 'agent' or 'system'
    detail TEXT,  -- JSON blob with event-specific data
    created_at TEXT NOT NULL  -- ISO 8601 UTC (Z suffix)
);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_source ON events(source);

-- Command channel: the commander's directives to the session (`directive`
-- verbs, command-channel-stop.sh)
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

-- Command channel: the commander's feedback (written by Mission Control;
-- acknowledged by command-channel-stop.sh)
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

-- Version history (replaces meta.versionHistory array)
CREATE TABLE IF NOT EXISTS version_history (
    version REAL NOT NULL PRIMARY KEY,
    timestamp TEXT NOT NULL,  -- ISO 8601 UTC
    changes TEXT NOT NULL
);

-- Schema versions this DB was created at or migrated to (one row each)
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL  -- ISO 8601 UTC
);

-- ============================================================================
-- TIER 2: HARNESS DB (.aitools/harness.db)
-- Cross-session state, written at session boundaries.
-- ============================================================================

-- Session index: lightweight discovery of all sessions
CREATE TABLE IF NOT EXISTS session_index (
    session_id TEXT PRIMARY KEY,
    db_path TEXT NOT NULL,  -- relative path to session DB
    started_at TEXT NOT NULL,  -- ISO 8601 UTC
    ended_at TEXT,  -- ISO 8601 UTC
    schwerpunkt TEXT,
    platform TEXT,  -- darwin, win32, linux
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'crashed'))
);

-- KPI events: individual metric measurements
CREATE TABLE IF NOT EXISTS kpi_events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,  -- e.g. "guard.fireCount", "delegation.avgScore"
    metric_value REAL NOT NULL,
    dimensions TEXT,  -- JSON blob
    collected_at TEXT NOT NULL  -- ISO 8601 UTC
);
CREATE INDEX IF NOT EXISTS idx_kpi_session ON kpi_events(session_id);
CREATE INDEX IF NOT EXISTS idx_kpi_metric ON kpi_events(metric_name);
CREATE INDEX IF NOT EXISTS idx_kpi_collected ON kpi_events(collected_at);

-- KPI shipping state: what has been sent to Datadog
CREATE TABLE IF NOT EXISTS kpi_ship_log (
    ship_id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_size INTEGER NOT NULL,
    shipped_at TEXT NOT NULL,  -- ISO 8601 UTC
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'shipped', 'failed')),
    error_message TEXT,
    datadog_response TEXT
);

-- Dashboard state: which dashboards are serving
CREATE TABLE IF NOT EXISTS dashboard_state (
    port INTEGER PRIMARY KEY,
    session_id TEXT NOT NULL,
    pid INTEGER,
    db_path TEXT,
    started_at TEXT NOT NULL,  -- ISO 8601 UTC
    last_checked TEXT  -- ISO 8601 UTC
);

-- PROVENANCE SYSTEM: cross-session knowledge with dependency-directed
-- invalidation. Based on ATMS (de Kleer 1986), W3C PROV, dbt freshness,
-- the Graphiti bitemporal model, Pachyderm lineage and Apache Atlas
-- classification (reference/framework-provenance.md).

-- Knowledge items: intelligence items promoted from sessions, plus decisions
-- and changes. item_type is the intelligence type (or a record type).
CREATE TABLE IF NOT EXISTS knowledge_items (
    item_id TEXT PRIMARY KEY,  -- stable ID, e.g. "OL-2", "D-34"
    item_type TEXT NOT NULL
        CHECK (item_type IN ('observation', 'fact', 'assumption', 'finding', 'operational_learning', 'proposal', 'rfi', 'decision', 'commander_directive', 'rule_change', 'framework_change')),
    version INTEGER NOT NULL DEFAULT 1,  -- monotonic, never reused
    content TEXT NOT NULL,  -- the statement; for a finding, the condition found
    severity TEXT
        CHECK (severity IS NULL OR severity IN ('critical', 'high', 'medium', 'low')),
    confidence TEXT  -- analytic confidence (JP 2-0 appendix A)
        CHECK (confidence IS NULL OR confidence IN ('low', 'moderate', 'high')),
    criteria TEXT,  -- finding: what should be
    cause TEXT,  -- finding: why
    effect TEXT,  -- finding: what it leads to
    suggestion TEXT,  -- finding: one-line direction
    t_valid TEXT,  -- when it became true in the real world (ISO 8601 UTC)
    t_invalid TEXT,  -- when superseded (ISO 8601 UTC; NULL = current)
    attributed_to TEXT NOT NULL,  -- 'commander' | 'agent' | agent name
    produced_by_session TEXT,  -- session_id that created this item
    produced_by_mission TEXT,  -- mission_id, when a delegate produced it
    source_kind TEXT
        CHECK (source_kind IS NULL OR source_kind IN ('commander', 'agent', 'telemetry', 'artifact', 'web')),
    source TEXT,  -- where: path:line, commit SHA, URL, transcript line
    quote TEXT,  -- the source text verbatim
    authority_level INTEGER NOT NULL DEFAULT 1
        CHECK (authority_level BETWEEN 0 AND 3),
        -- L0 system (hooks), L1 agent, L2 agent and commander-reviewed, L3 commander
    warn_after_days INTEGER DEFAULT 30,  -- staleness (dbt freshness)
    error_after_days INTEGER DEFAULT 90,
    last_verified_at TEXT,  -- ISO 8601 UTC (NULL = never verified)
    trust_level TEXT NOT NULL DEFAULT 'agent_observation'
        CHECK (trust_level IN ('commander_directive', 'verified_fact', 'agent_observation', 'unverified_assumption')),
    legacy_item_type TEXT,  -- set only by the v4 migration: the row's v3 item_type
    created_at TEXT NOT NULL,  -- ISO 8601 UTC: when the harness learned this
    updated_at TEXT NOT NULL  -- ISO 8601 UTC: last record modification
);
CREATE INDEX IF NOT EXISTS idx_ki_type ON knowledge_items(item_type);
CREATE INDEX IF NOT EXISTS idx_ki_trust ON knowledge_items(trust_level);
CREATE INDEX IF NOT EXISTS idx_ki_session ON knowledge_items(produced_by_session);
CREATE INDEX IF NOT EXISTS idx_ki_valid ON knowledge_items(t_invalid);

-- Provenance edges: source_item_id --[relationship]--> target_item_id.
-- Example: OL-2 --[derived_from]--> FND-7 (OL-2 was drawn from finding FND-7).
-- Invalidating a target flags its dependents (ATMS).
CREATE TABLE IF NOT EXISTS provenance_edges (
    edge_id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_item_id TEXT NOT NULL REFERENCES knowledge_items(item_id),
    target_item_id TEXT NOT NULL REFERENCES knowledge_items(item_id),
    relationship TEXT NOT NULL
        CHECK (relationship IN ('derived_from', 'informed', 'triggered', 'validated', 'invalidated', 'superseded')),
    created_at TEXT NOT NULL,  -- ISO 8601 UTC
    session_id TEXT NOT NULL  -- session where the edge was recorded
);
CREATE INDEX IF NOT EXISTS idx_prov_source ON provenance_edges(source_item_id);
CREATE INDEX IF NOT EXISTS idx_prov_target ON provenance_edges(target_item_id);
CREATE INDEX IF NOT EXISTS idx_prov_rel ON provenance_edges(relationship);

-- Nogood sets: known contradiction combinations (ATMS)
CREATE TABLE IF NOT EXISTS nogood_sets (
    nogood_id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_ids TEXT NOT NULL,  -- JSON array of item_id strings
    contradiction TEXT NOT NULL,  -- human-readable description
    discovered_in_session TEXT NOT NULL,  -- session_id
    discovered_at TEXT NOT NULL  -- ISO 8601 UTC
);

-- Schema versions this DB was created at or migrated to (one row each)
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL  -- ISO 8601 UTC
);
