#!/usr/bin/env python3
"""test-delegation-score.py -- unit tests for harness-db.py delegation KPIs.

Purpose: Verify that delegation.avgScore / delegation.minScore are fractions
(score / total per event, 0..1), so events scored out of 6, 7 or 8 elements
are comparable; that events without "total" default to 6; that "checked": 0
events and malformed values are skipped (and logged); and that
delegation.count is the number of scored events.

Isolation: HOME and USERPROFILE point at a temp dir for the whole run, so
harness-db.log is written there, and the harness DB is a temp file. Nothing
touches the real ~/.aitools or any repo .aitools/harness.db.

Usage: python3 tests/harness-db/test-delegation-score.py   (python on Windows)
Exit: 0 all tests pass, 1 any failure (unittest).
Safe to re-run. Platform: macOS, Windows, Linux (stdlib only).
"""

from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import ModuleType
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
HARNESS_DB_PY = REPO_ROOT / "scripts" / "harness-db.py"

_TMP = tempfile.TemporaryDirectory(prefix="h2db-test-")
TMP_HOME = Path(_TMP.name) / "home"
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


def ev(**detail: Any) -> dict[str, Any]:
    """One delegation event as the hooks write it to events.jsonl."""
    return {"t": "2026-10-28T00:00:00Z", "type": "delegation", "src": "ddg", "d": detail}


class DelegationScoreMetrics(unittest.TestCase):
    def metrics(self, events: list[dict[str, Any]]) -> dict[str, float]:
        return hdb.delegation_score_metrics(events)

    def test_mixed_totals_are_normalised(self) -> None:
        # 3 of 6 (old event, no total), 7 of 7, 6 of 8
        m = self.metrics([ev(score=3, missing="a,b,c"), ev(score=7, total=7), ev(score=6, total=8)])
        self.assertAlmostEqual(m["delegation.avgScore"], (0.5 + 1.0 + 0.75) / 3)
        self.assertAlmostEqual(m["delegation.minScore"], 0.5)
        self.assertEqual(m["delegation.count"], 3.0)

    def test_full_scores_on_every_scale_are_equal(self) -> None:
        m = self.metrics([ev(score=6), ev(score=6, total=6), ev(score=7, total=7), ev(score=8, total=8)])
        self.assertEqual(m["delegation.avgScore"], 1.0)
        self.assertEqual(m["delegation.minScore"], 1.0)
        self.assertEqual(m["delegation.count"], 4.0)

    def test_missing_total_defaults_to_six(self) -> None:
        self.assertEqual(hdb.DELEGATION_DEFAULT_TOTAL, 6)
        m = self.metrics([ev(score=3, missing="rules,skills,access")])
        self.assertAlmostEqual(m["delegation.avgScore"], 0.5)

    def test_checked_zero_is_skipped(self) -> None:
        m = self.metrics([
            ev(score=0, total=8, missing="", mode="observe", tool="Workflow", checked=0),
            ev(score=4, total=8, missing="x", mode="observe", tool="Agent", checked=1),
        ])
        self.assertEqual(m["delegation.count"], 1.0)
        self.assertAlmostEqual(m["delegation.minScore"], 0.5)

    def test_only_unchecked_events_give_no_metrics(self) -> None:
        self.assertEqual(self.metrics([ev(score=0, total=8, checked=0)]), {})

    def test_workflow_agent_scope_events_count(self) -> None:
        m = self.metrics([ev(score=8, total=8, tool="Workflow", checked=1, scope="agent")])
        self.assertEqual(m["delegation.avgScore"], 1.0)

    def test_bad_values_are_skipped(self) -> None:
        bad = [
            ev(score="5", total=8),          # string score
            ev(score=5, total="8"),          # string total
            ev(score=5, total=0),            # zero total
            ev(score=5, total=-8),           # negative total
            ev(score=5, total=None),         # null total
            ev(score=None, total=8),         # null score
            ev(score=True, total=8),         # boolean score
            ev(score=json.loads("NaN"), total=8),
            ev(score=5, total=json.loads("Infinity")),
            ev(missing="no score key"),
            {"type": "delegation", "d": "not a dict"},
            {"type": "delegation"},
        ]
        self.assertEqual(self.metrics(bad), {})
        m = self.metrics(bad + [ev(score=2, total=8)])
        self.assertEqual(m["delegation.count"], 1.0)
        self.assertAlmostEqual(m["delegation.avgScore"], 0.25)

    def test_scores_are_clamped(self) -> None:
        m = self.metrics([ev(score=-2, total=8), ev(score=9, total=8), ev(score=2.5, total=5)])
        self.assertEqual(m["delegation.minScore"], 0.0)
        self.assertAlmostEqual(m["delegation.avgScore"], (0.0 + 1.0 + 0.5) / 3)
        for value in (m["delegation.avgScore"], m["delegation.minScore"]):
            self.assertGreaterEqual(value, 0.0)
            self.assertLessEqual(value, 1.0)

    def test_no_events(self) -> None:
        self.assertEqual(self.metrics([]), {})

    def test_skips_are_logged(self) -> None:
        self.metrics([ev(score=5, total=0), ev(score=0, total=8, checked=0)])
        log = TMP_HOME / ".aitools" / "logs" / "harness-db.log"
        self.assertTrue(log.exists(), f"{log} not written")
        text = log.read_text(encoding="utf-8")
        self.assertIn("delegation score: skipped 2 event(s): bad-total=1, unchecked=1", text)


class ProcessSessionEvents(unittest.TestCase):
    """End to end: events.jsonl -> metrics -> kpi_events in a temp harness DB."""

    def test_events_file_to_kpi_rows(self) -> None:
        work = Path(tempfile.mkdtemp(prefix="session-", dir=_TMP.name))
        db_path = Path(_TMP.name) / f"{work.name}-harness.db"
        conn = hdb.open_db(db_path)
        hdb.ensure_schema(conn, hdb.HARNESS_SCHEMA)
        conn.close()

        lines = [
            ev(score=3, missing="rules,skills,access"),
            ev(score=7, total=7, missing="", mode="observe"),
            ev(score=6, total=8, missing="a,b", mode="observe", tool="Agent", checked=1),
            ev(score=0, total=8, missing="", mode="observe", tool="Workflow", checked=0),
        ]
        text = "\n".join(json.dumps(x) for x in lines) + "\nnot json\n"
        (work / "events.jsonl").write_text(text, encoding="utf-8")

        metrics = hdb.process_session_events(work, "h2db-test-session", db_path)
        self.assertAlmostEqual(metrics["delegation.avgScore"], 0.75)
        self.assertAlmostEqual(metrics["delegation.minScore"], 0.5)
        self.assertEqual(metrics["delegation.count"], 3.0)
        self.assertEqual(metrics["session.subagentCount"], 4.0)

        conn = hdb.open_db(db_path, readonly=True)
        rows = {
            r["metric_name"]: r["metric_value"]
            for r in conn.execute(
                "SELECT metric_name, metric_value FROM kpi_events WHERE session_id = ?",
                ("h2db-test-session",),
            )
        }
        conn.close()
        self.assertAlmostEqual(rows["delegation.avgScore"], 0.75)
        self.assertAlmostEqual(rows["delegation.minScore"], 0.5)
        self.assertEqual(rows["delegation.count"], 3.0)


if __name__ == "__main__":
    print(f"python {sys.version.split()[0]}; harness-db: {HARNESS_DB_PY}; temp HOME: {TMP_HOME}")
    result = unittest.main(exit=False, verbosity=2).result
    try:
        _TMP.cleanup()
    except OSError as exc:  # e.g. a SQLite file still locked on Windows
        print(f"warning: temp dir not removed: {exc}", file=sys.stderr)
    sys.exit(0 if result.wasSuccessful() else 1)
