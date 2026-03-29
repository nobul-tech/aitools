# RFC 0010: Python and SQLite Engineering

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Informed by**: harness-db.py (3009 lines), read-session-full.py (268), read-session.py (222), build-knowledge-db.py (1170), harness-db-schema.sql, setup-python.sh/.ps1, all hooks that detect Python, RFCs 0001-0009
**Relationship**: Engineering discipline for the harness's second language. Implements 0005-v2 (session intelligence data layer), feeds 0003 v2 (OL graph via knowledge_items), enables 0008 (verification via py_compile check).

---

## 1. Summary

Python is the harness's second language after bash. It powers the entire data layer: session DBs, harness DB, KPI processing, event aggregation, knowledge DB, session transcript extraction, Datadog shipping, and the provenance system. Every Python artifact follows one rule: stdlib only, no external dependencies. sqlite3 is built into Python's stdlib. This is why SQLite won over every alternative.

## 2. The stdlib-only principle

No pip install. No venv. No requirements.txt. No external packages. Every Python script in the harness runs on a fresh machine with nothing but Python 3.8+ installed. This is a hard architectural constraint, not a preference.

Why: hooks run in environments the harness doesn't control. A SessionEnd hook that fails because numpy isn't installed is worse than no hook. The harness must work on any machine where Python exists. The stdlib boundary is the portability guarantee.

Exception: build-knowledge-db.py references sqlite-utils as optional enhancement. The core (FTS5 via stdlib sqlite3) works without it. sqlite-utils is evaluated but not required.

Decision framework for stdlib exception: the tool must be (a) optional (core works without it), (b) evaluated via /tool-eval, (c) installed via uv tool install (user-level, no sudo), (d) documented as optional in the script header.

## 3. The single CLI pattern

harness-db.py is the single CLI for all DB operations. 3009 lines, 32 subcommands, growing. New functionality = new subcommand, not new file.

Decision framework for when to add a subcommand vs a new script: if it reads/writes session DB or harness DB, it goes in harness-db.py. If it's a standalone tool with its own data (build-knowledge-db.py has its own knowledge.db), it's a separate script. If it's a session transcript tool (read-session*.py), it's separate because it operates on CC's data, not the harness's.

Current scripts and boundaries:

| Script | Purpose | Lines | Data boundary |
|--------|---------|-------|--------------|
| harness-db.py | ALL harness DB operations | 3009 | Session DB + harness DB |
| read-session-full.py | Full-fidelity session extraction | 268 | CC JSONL (read-only) |
| read-session.py | Text-only session extraction | 222 | CC JSONL (read-only) |
| build-knowledge-db.py | FTS5 knowledge index | 1170 | knowledge.db (own DB) |

Splitting threshold: if harness-db.py exceeds ~5000 lines, consider splitting into harness-db-core.py and harness-db-provenance.py. But single-file has value: one import, one PATH entry, one version.

## 4. SQLite patterns (canonical)

Every DB connection:
```python
conn = sqlite3.connect(f"file:{path}?mode={mode}", uri=True, timeout=5.0)
conn.execute("PRAGMA journal_mode=WAL")
conn.execute("PRAGMA synchronous=NORMAL")
conn.execute("PRAGMA busy_timeout=5000")
conn.execute("PRAGMA foreign_keys=ON")
conn.row_factory = sqlite3.Row
```

WAL for concurrent readers (MC reads while agent writes). NORMAL sync for performance. Busy timeout 5s for contention. Foreign keys enforced. Row factory for named access.

URI mode `mode=ro` for read-only operations (export, status, list). Prevents accidental writes.

CREATE IF NOT EXISTS throughout — safe to re-run. Schema applied via ensure_schema() which sets schema_version.

CHECK constraints for all enum fields (status, category, severity, directive_type, priority, relationship, trust_level). Detection layer at the data level — invalid values rejected at INSERT.

## 5. Schema management

harness-db-schema.sql is CANONICAL (reference/, protected). harness-db.py contains the SAME schema as Python strings (SESSION_SCHEMA, HARNESS_SCHEMA). Both must stay in sync.

Known weakness: two copies of the same schema. No automated sync check. Should be added to check-pre-commit (RFC 0008).

Schema version in schema_version table. Forward-only migrations via ensure_schema(). No down-migration. If schema breaks: delete .db, re-init, import from JSON export.

Decision framework for schema changes: add columns with defaults (non-breaking). Add tables (non-breaking). Modify CHECK constraints (breaking — needs migration script). Never remove columns.

## 6. Python detection (cross-platform)

```bash
PYTHON=""
if command -v python3 > /dev/null 2>&1; then
    PYTHON="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON="python"
fi
```

macOS: python3. Windows: python (python3 not standard). Linux: python3.

Hooks MUST handle Python absence gracefully (exit 0, silent skip). Scripts log error and exit 1.

sqlite3 module verification before any DB operation: `"$PYTHON" -c "import sqlite3" 2>/dev/null`.

## 7. The export pattern (Option B)

Runtime (gitignored): .aitools/sessions/*.db, .aitools/harness.db.
Archive (git-tracked): .aitools/channel/running-estimate.json, .aitools/provenance-export.json.

Bridge: harness-db.py export. Safety: refuses to overwrite larger file with empty data. Refuses to export when session has no meaningful content.

Target (RFC 0005-v2): richer export with promoted knowledge_items, provenance_edges, KPI summaries. Import on SessionStart when harness DB missing.

## 8. Error handling

Hooks: ALWAYS exit 0 on Python/DB failure. stderr NOT suppressed for safety warnings. Pattern: `"$PYTHON" "$HELPER" <cmd> || true`.

CLI: exit 1 on failure with descriptive stderr. Log to deploy.log via _log_detail().

DB not found: hooks exit 0 (skip). CLI exit 1 with init instruction.

## 9. Performance budgets

Hot path (hooks): <50ms total. Python startup ~30-50ms. SQLite WAL read <5ms. Leaves ~10-15ms for logic. JSONL append (~0.1ms) preferred over Python subprocess for event emission.

Cold path (SessionEnd): 2-10 seconds. Reads events.jsonl, computes metrics, writes harness DB, exports JSON, ships to Datadog.

This hot/cold split replaced the failed synchronous telemetry (3 Stop hooks at ~200ms each with Perl regex).

## 10. FTS5 and knowledge DB

build-knowledge-db.py creates ~/.aitools/knowledge.db. FTS5 built into stdlib sqlite3. Tokenizer: porter unicode61.

Architecture gap: knowledge.db and harness.db are separate. FTS5 search in one, provenance graph in other. No query federation. Target: merge or define spanning query layer.

## 11. Version floor

Python 3.8+ required. Features: f-strings (3.6+), walrus operator (3.8+), `from __future__ import annotations` (3.7+). No 3.9+ features.

FTS5 in sqlite3 since Python 3.7.15+/3.8.12+. Verify at runtime via CREATE VIRTUAL TABLE attempt.

## 12. Open questions

1. harness-db.py splitting threshold (5000 lines?)
2. Schema sync automation (pre-commit check)
3. knowledge.db + harness.db federation
4. Python naming on Windows Git Bash (python vs python3)
5. Async layer for MC API queries
6. Test suite for harness-db.py (3009 lines untested)

## 13. References

Scripts: harness-db.py, read-session-full.py, read-session.py, build-knowledge-db.py, setup-python.sh/.ps1. Schema: harness-db-schema.sql. Rules: script-standards.md. Related RFCs: 0004-v2, 0005-v2, 0003 v2, 0007, 0008.
