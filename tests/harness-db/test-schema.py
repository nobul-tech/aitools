#!/usr/bin/env python3
"""test-schema.py -- the harness-DB schema has one source and migrates cleanly.

Purpose: Keep reference/harness-db-schema.sql and scripts/harness-db.py from
drifting again (they drifted in 2026-03: commander_directives and
commander_feedback existed only in the script), and prove the schema-4
migration on databases in the schema-3 shape.

Checks:
  - the committed .sql is byte-identical (line endings aside) to
    `harness-db.py schema` output, and its "-- schema-version:" header
    equals SCHEMA_VERSION;
  - the value sets of the CHECK constraints equal the module's tuples, and
    the CLI choices are built from the same tuples;
  - a fresh DB of each tier records exactly one schema_version row and
    rejects the retired values ('finding' message, 'ol_entry');
  - v3 -> v4 migration on DBs built from the frozen v3 DDL
    (tests/harness-db/fixtures/harness-db-v3-*.sql): row counts kept, the
    v3 'finding' and 'ol_entry' rows remapped by the documented rule with
    legacy_category / legacy_item_type set, ids and AUTOINCREMENT sequences
    kept, provenance edges intact (foreign_key_check clean), the migrated
    shape equal to a fresh v4 DB, and a second run changing nothing;
  - end to end: `ol list` on a v3 session DB reads it without migrating;
    `ol add` and `log --type spotrep` migrate it and write v4 values.

Isolation: HOME and USERPROFILE point at a temp dir for the whole run (so
harness-db.log is written there); every DB is a temp file. Nothing touches
the real ~/.aitools or any repo .aitools/ database.

Usage: python3 tests/harness-db/test-schema.py   (python on Windows)
Exit: 0 all tests pass, 1 any failure or no test ran.
Safe to re-run. Platform: macOS, Windows, Linux (stdlib only).
"""

from __future__ import annotations

import importlib.util
import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import ModuleType

REPO_ROOT = Path(__file__).resolve().parents[2]
HARNESS_DB_PY = REPO_ROOT / "scripts" / "harness-db.py"
SCHEMA_SQL = REPO_ROOT / "reference" / "harness-db-schema.sql"
FIXTURES = Path(__file__).resolve().parent / "fixtures"

_TMP = tempfile.TemporaryDirectory(prefix="h2db-schema-")
TMP = Path(_TMP.name)
TMP_HOME = TMP / "home"
TMP_HOME.mkdir()
os.environ["HOME"] = str(TMP_HOME)
os.environ["USERPROFILE"] = str(TMP_HOME)


def load_harness_db() -> ModuleType:
    """Import scripts/harness-db.py (hyphenated name) as a module."""
    spec = importlib.util.spec_from_file_location("harness_db", HARNESS_DB_PY)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {HARNESS_DB_PY}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


hdb = load_harness_db()
NOW = "2026-03-26T12:00:00Z"
_counter = 0
_OPEN: list[sqlite3.Connection] = []


def tearDownModule() -> None:
    """Close every test DB (Windows cannot delete the temp dir while one is open)."""
    for conn in _OPEN:
        conn.close()


def new_db_path(name: str) -> Path:
    global _counter
    _counter += 1
    return TMP / f"{_counter:03d}-{name}.db"


def track(conn: sqlite3.Connection) -> sqlite3.Connection:
    _OPEN.append(conn)
    return conn


def shape(conn: sqlite3.Connection) -> dict[str, tuple]:
    """Tables (columns, CHECK value sets) and indexes, independent of comments."""
    out: dict[str, tuple] = {}
    for name, typ, sql in conn.execute(
        "SELECT name, type, sql FROM sqlite_master "
        "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'"
    ):
        if typ == "table":
            cols = tuple(tuple(r[1:6]) for r in conn.execute(f'PRAGMA table_info("{name}")'))
            body = re.sub(r"--[^\n]*", "", sql)
            checks = tuple(sorted(re.sub(r"\s+", " ", m) for m in re.findall(
                r"CHECK\s*\((?:[^()]|\([^()]*\))*\)", body)))
            out[f"table {name}"] = (cols, checks)
        else:
            idx = tuple(r[2] for r in conn.execute(f'PRAGMA index_info("{name}")'))
            tbl = conn.execute(
                "SELECT tbl_name FROM sqlite_master WHERE name = ?", (name,)).fetchone()[0]
            out[f"index {name}"] = (tbl, idx)
    return out


def fresh(tier: str) -> sqlite3.Connection:
    conn = track(hdb.open_db(new_db_path(f"fresh-{tier}")))
    hdb.ensure_schema(conn, tier)
    return conn


def v3_db(tier: str) -> sqlite3.Connection:
    """A DB in the schema-3 shape, built from the frozen v3 DDL."""
    conn = track(hdb.open_db(new_db_path(f"v3-{tier}")))
    conn.executescript((FIXTURES / f"harness-db-v3-{tier}.sql").read_text(encoding="utf-8"))
    conn.execute("INSERT INTO schema_version (version, applied_at) VALUES (3, ?)", (NOW,))
    conn.commit()
    return conn


def check_values(sql: str, column: str) -> list[str]:
    m = re.search(column + r"\s+IN\s*\(([^)]*)\)", sql)
    assert m, f"no IN list for {column}"
    return re.findall(r"'([^']*)'", m.group(1))


class SchemaFileIsGenerated(unittest.TestCase):
    def test_sql_file_matches_script(self) -> None:
        committed = SCHEMA_SQL.read_text(encoding="utf-8").replace("\r\n", "\n")
        self.assertEqual(
            committed, hdb.schema_sql_text(),
            "reference/harness-db-schema.sql differs from scripts/harness-db.py. Regenerate it: "
            "python3 scripts/harness-db.py schema --output reference/harness-db-schema.sql",
        )

    def test_header_version_matches(self) -> None:
        m = re.search(r"^-- schema-version: (\d+)$",
                      SCHEMA_SQL.read_text(encoding="utf-8"), re.MULTILINE)
        self.assertIsNotNone(m, "no '-- schema-version: N' line in the .sql header")
        assert m is not None
        self.assertEqual(int(m.group(1)), hdb.SCHEMA_VERSION)

    def test_sql_file_tiers_build(self) -> None:
        conn = track(sqlite3.connect(":memory:"))
        conn.executescript(SCHEMA_SQL.read_text(encoding="utf-8"))
        tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        for t in ("commander_directives", "commander_feedback", "observations",
                  "knowledge_items", "provenance_edges", "schema_version"):
            self.assertIn(t, tables)


class ValueSets(unittest.TestCase):
    def test_check_lists_equal_tuples(self) -> None:
        self.assertEqual(check_values(hdb.SESSION_SCHEMA, "category"), list(hdb.INTELLIGENCE_TYPES))
        self.assertEqual(check_values(hdb.SESSION_SCHEMA, "message_type"), list(hdb.MESSAGE_TYPES))
        self.assertEqual(check_values(hdb.HARNESS_SCHEMA, "item_type"), list(hdb.KNOWLEDGE_ITEM_TYPES))
        self.assertEqual(check_values(hdb.HARNESS_SCHEMA, "relationship"), list(hdb.RELATIONSHIPS))

    def test_retired_and_new_types(self) -> None:
        self.assertIn("finding", hdb.INTELLIGENCE_TYPES)  # the analysis type since v4
        self.assertIn("operational_learning", hdb.INTELLIGENCE_TYPES)
        self.assertNotIn("ol_entry", hdb.KNOWLEDGE_ITEM_TYPES)
        self.assertNotIn("insight", hdb.KNOWLEDGE_ITEM_TYPES)
        self.assertNotIn("finding", hdb.MESSAGE_TYPES)
        self.assertTrue(set(hdb.INTELLIGENCE_TYPES) <= set(hdb.KNOWLEDGE_ITEM_TYPES))

    def test_cli_choices_come_from_tuples(self) -> None:
        parser = hdb.build_parser()
        sub = next(a for a in parser._actions if isinstance(a, __import__("argparse")._SubParsersAction))
        obs_add = sub.choices["observation"]._actions[-1].choices["add"]
        cat = next(a for a in obs_add._actions if a.dest == "category")
        self.assertEqual(list(cat.choices), list(hdb.INTELLIGENCE_TYPES))
        log = sub.choices["log"]
        typ = next(a for a in log._actions if a.dest == "type")
        self.assertEqual(list(typ.choices), list(hdb.MESSAGE_TYPES))


class FreshDatabases(unittest.TestCase):
    def test_fresh_records_one_version_row(self) -> None:
        for tier in ("session", "harness"):
            conn = fresh(tier)
            rows = conn.execute("SELECT version FROM schema_version").fetchall()
            self.assertEqual([r[0] for r in rows], [hdb.SCHEMA_VERSION], tier)
            self.assertEqual(hdb.ensure_schema(conn, tier), [], f"{tier}: re-run changed something")
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM schema_version").fetchone()[0], 1)

    def test_fresh_rejects_retired_values(self) -> None:
        s = fresh("session")
        with self.assertRaises(sqlite3.IntegrityError):
            s.execute("INSERT INTO messages (message_type, agent_role, message, created_at) "
                      "VALUES ('finding', 'a', 'm', ?)", (NOW,))
        with self.assertRaises(sqlite3.IntegrityError):
            s.execute("INSERT INTO observations (category, text, created_at) "
                      "VALUES ('insight', 't', ?)", (NOW,))
        s.execute("INSERT INTO observations (category, text, cause, effect, suggestion, "
                  "created_at) VALUES ('finding', 'cond', 'c', 'e', 's', ?)", (NOW,))
        h = fresh("harness")
        with self.assertRaises(sqlite3.IntegrityError):
            h.execute("INSERT INTO knowledge_items (item_id, item_type, content, attributed_to, "
                      "created_at, updated_at) VALUES ('X', 'ol_entry', 'c', 'a', ?, ?)", (NOW, NOW))

    def test_newer_db_is_left_alone(self) -> None:
        conn = fresh("session")
        conn.execute("INSERT INTO schema_version (version, applied_at) VALUES (?, ?)",
                     (hdb.SCHEMA_VERSION + 1, NOW))
        conn.commit()
        self.assertFalse(hdb.record_schema_version(conn))
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM schema_version").fetchone()[0], 2)


class MigrateSessionV3(unittest.TestCase):
    def setUp(self) -> None:
        c = v3_db("session")
        c.execute("INSERT INTO session (session_id, schwerpunkt, started_at, updated_at) "
                  "VALUES ('s1', 'x', ?, ?)", (NOW, NOW))
        rows = [
            # (id, category, text, status, evidence, severity)
            (1, "finding", "ol add text", "verified", None, None),          # the `ol add` signature
            (2, "finding", "audit finding", "active", None, "high"),        # SALUTE finding
            (3, "finding", "provenance finding", "verified", "ev", "low"),  # verified, but has severity
            (4, "finding", "pending finding", "pending", None, None),
            (5, "observation", "obs", "pending", None, "medium"),
            (6, "assumption", "asm", "pending", None, None),
            (8, "fact", "fct", "verified", "ev2", None),                    # id 7 deleted below
        ]
        c.executemany("INSERT INTO observations (observation_id, category, text, status, evidence, "
                      "severity, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
                      [(*r, NOW) for r in rows])
        c.execute("INSERT INTO observations (observation_id, category, text, created_at) "
                  "VALUES (9, 'observation', 'deleted later', ?)", (NOW,))
        c.execute("DELETE FROM observations WHERE observation_id = 9")  # sequence stays at 9
        c.executemany("INSERT INTO messages (message_id, message_type, agent_role, title, message, "
                      "severity, actionable, created_at) VALUES (?, ?, 'S2', ?, ?, ?, ?, ?)",
                      [(1, "sitrep", None, "status", "routine", 0, NOW),
                       (2, "finding", "t", "a finding", "high", 1, NOW)])
        c.execute("INSERT INTO commander_directives (directive_type, message, created_at) "
                  "VALUES ('context', 'keep me', ?)", (NOW,))
        c.commit()
        self.conn = c
        self.before = {t: c.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
                       for t in ("observations", "messages", "commander_directives", "session")}

    def test_migration(self) -> None:
        c = self.conn
        changes = hdb.ensure_schema(c, "session")
        self.assertIn("rebuilt observations", changes)
        self.assertIn("rebuilt messages", changes)
        for t, n in self.before.items():
            self.assertEqual(c.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0], n, t)
        got = {r[0]: (r[1], r[2], r[3], r[4]) for r in c.execute(
            "SELECT observation_id, category, legacy_category, status, severity FROM observations")}
        self.assertEqual(got[1], ("operational_learning", "finding", "verified", None))
        self.assertEqual(got[2], ("observation", "finding", "active", "high"))
        self.assertEqual(got[3], ("observation", "finding", "verified", "low"))
        self.assertEqual(got[4], ("observation", "finding", "pending", None))
        self.assertEqual(got[5], ("observation", None, "pending", "medium"))
        self.assertEqual(got[6], ("assumption", None, "pending", None))
        self.assertEqual(got[8], ("fact", None, "verified", None))
        self.assertEqual(c.execute("SELECT evidence FROM observations WHERE observation_id = 3")
                         .fetchone()[0], "ev")
        self.assertEqual(
            [tuple(r) for r in c.execute("SELECT message_id, message_type, title, actionable "
                                         "FROM messages ORDER BY message_id")],
            [(1, "sitrep", None, 0), (2, "spotrep", "t", 1)])
        # AUTOINCREMENT sequence kept: the next id is 10, not 9 (9 was used and deleted)
        c.execute("INSERT INTO observations (category, text, created_at) VALUES ('rfi', 'q', ?)", (NOW,))
        self.assertEqual(c.execute("SELECT MAX(observation_id) FROM observations").fetchone()[0], 10)
        c.rollback()
        # the session columns of schema 3 are present, version 4 recorded
        self.assertIn("user_claude_md", hdb._table_columns(c, "session"))
        self.assertEqual(c.execute("SELECT MAX(version) FROM schema_version").fetchone()[0],
                         hdb.SCHEMA_VERSION)
        # migrated shape == fresh shape
        self.assertEqual(shape(c), shape(fresh("session")))
        # idempotent
        self.assertEqual(hdb.ensure_schema(c, "session"), [])
        self.assertEqual(c.execute("SELECT COUNT(*) FROM schema_version").fetchone()[0], 2)


class MigrateHarnessV3(unittest.TestCase):
    def test_migration(self) -> None:
        c = v3_db("harness")
        items = [("OL-1", "ol_entry"), ("F-1", "finding"), ("O-1", "observation"),
                 ("D-1", "decision"), ("A-1", "assumption")]
        c.executemany("INSERT INTO knowledge_items (item_id, item_type, content, attributed_to, "
                      "trust_level, created_at, updated_at) VALUES (?, ?, ?, 'agent', "
                      "'verified_fact', ?, ?)", [(i, t, f"content {i}", NOW, NOW) for i, t in items])
        c.executemany("INSERT INTO provenance_edges (source_item_id, target_item_id, relationship, "
                      "created_at, session_id) VALUES (?, ?, ?, ?, 's1')",
                      [("OL-1", "F-1", "derived_from", NOW), ("D-1", "OL-1", "informed", NOW)])
        c.execute("INSERT INTO session_index (session_id, db_path, started_at) VALUES ('s1', 'p', ?)",
                  (NOW,))
        c.commit()
        changes = hdb.ensure_schema(c, "harness")
        self.assertIn("rebuilt knowledge_items", changes)
        got = {r[0]: (r[1], r[2]) for r in c.execute(
            "SELECT item_id, item_type, legacy_item_type FROM knowledge_items")}
        self.assertEqual(got, {
            "OL-1": ("operational_learning", "ol_entry"),
            "F-1": ("observation", "finding"),
            "O-1": ("observation", None),
            "D-1": ("decision", None),
            "A-1": ("assumption", None),
        })
        self.assertEqual(c.execute("SELECT COUNT(*) FROM provenance_edges").fetchone()[0], 2)
        self.assertEqual(c.execute("PRAGMA foreign_key_check").fetchall(), [])
        self.assertEqual(c.execute("PRAGMA foreign_keys").fetchone()[0], 1)
        self.assertEqual(c.execute("SELECT COUNT(*) FROM session_index").fetchone()[0], 1)
        # edges still resolve through the foreign key to the rebuilt table
        with self.assertRaises(sqlite3.IntegrityError):
            c.execute("INSERT INTO provenance_edges (source_item_id, target_item_id, relationship, "
                      "created_at, session_id) VALUES ('nope', 'F-1', 'informed', ?, 's1')", (NOW,))
        c.rollback()
        self.assertEqual(shape(c), shape(fresh("harness")))
        self.assertEqual(hdb.ensure_schema(c, "harness"), [])


class EndToEndCli(unittest.TestCase):
    """`ol add` / `log` against a v3 session DB in a temp project (subprocess)."""

    def run_cli(self, proj: Path, *argv: str) -> subprocess.CompletedProcess[str]:
        env = dict(os.environ, HOME=str(TMP_HOME), USERPROFILE=str(TMP_HOME))
        return subprocess.run([sys.executable, str(HARNESS_DB_PY), *argv], cwd=proj, env=env,
                              capture_output=True, text=True, timeout=60)

    def test_ol_add_and_spotrep_migrate_v3(self) -> None:
        proj = TMP / "proj"
        (proj / ".git").mkdir(parents=True)
        sid = "abcdef1234-0000"
        sdir = proj / ".aitools" / "sessions"
        sdir.mkdir(parents=True)
        db = sdir / "abcdef1234.db"
        c = hdb.open_db(db)
        c.executescript((FIXTURES / "harness-db-v3-session.sql").read_text(encoding="utf-8"))
        c.execute("INSERT INTO session (session_id, schwerpunkt, started_at, updated_at) "
                  "VALUES (?, 'x', ?, ?)", (sid, NOW, NOW))
        c.execute("INSERT INTO observations (category, text, status, created_at) "
                  "VALUES ('finding', 'old ol', 'verified', ?)", (NOW,))
        c.commit()
        c.close()
        # A read does not migrate: `ol list` on the v3 DB lists its OL row and
        # leaves the file at schema 3 (the reviewer's N1 on PR #181).
        r = self.run_cli(proj, "ol", "list", "--session", sid)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.splitlines(), ["OL-1: old ol"])
        self.assertNotIn("Migrated", r.stderr)
        c = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True)
        self.assertNotIn("legacy_category", hdb._table_columns(c, "observations"))
        c.close()
        r = self.run_cli(proj, "ol", "add", "new lesson", "--session", sid,
                         "--source", "tests/harness-db/test-schema.py", "--source-kind", "artifact")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "OL-2")
        self.assertIn("Migrated abcdef1234.db to schema", r.stderr)
        r = self.run_cli(proj, "ol", "list", "--session", sid)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.splitlines(), ["OL-1: old ol", "OL-2: new lesson"])
        r = self.run_cli(proj, "log", "--session", sid, "--type", "spotrep", "--message", "m")
        self.assertEqual(r.returncode, 0, r.stderr)
        r = self.run_cli(proj, "log", "--session", sid, "--type", "finding", "--message", "m")
        self.assertNotEqual(r.returncode, 0, "the retired FINDING message type must be refused")
        r = self.run_cli(proj, "observation", "add", "condition", "--session", sid,
                         "--category", "finding", "--cause", "c", "--effect", "e",
                         "--suggestion", "s", "--refs", "OBS-1, OL-2")
        self.assertEqual(r.returncode, 0, r.stderr)
        c = sqlite3.connect(str(db))
        row = c.execute("SELECT category, cause, effect, suggestion, refs, status FROM observations "
                        "WHERE text = 'condition'").fetchone()
        self.assertEqual(row, ("finding", "c", "e", "s", json.dumps(["OBS-1", "OL-2"]), "pending"))
        src = c.execute("SELECT source, source_kind FROM observations WHERE text = 'new lesson'").fetchone()
        self.assertEqual(src, ("tests/harness-db/test-schema.py", "artifact"))
        c.close()


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=2).result
    ran = result.testsRun
    ok = result.wasSuccessful() and ran > 0
    print(f"test-schema: {ran} tests, {'PASS' if ok else 'FAIL'}")
    sys.exit(0 if ok else 1)
