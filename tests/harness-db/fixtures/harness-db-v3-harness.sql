-- Frozen copy of the schema-version 3 harness DDL of scripts/harness-db.py
-- (origin/main 70b7054, 2026-11-14). Test fixture for the v3 -> v4 migration
-- (tests/harness-db/test-schema.py). Never edit: it is the old shape.

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
