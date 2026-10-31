#!/usr/bin/env python3
"""test-ait-harvest.py -- unit tests for scripts/ait-harvest.py (harvest + archive).

Purpose: Verify the fixes for the gaps in reference/artifact-harvesting.md:
  G1  scratch dir names are used verbatim: a dir whose name is longer than
      10 characters is harvested itself, and never resolves to the live
      session's dir through .scratch/.current-session.
  G2  harness bookkeeping (.harvested, .intelligence-last-check, events.jsonl,
      dotfiles) is never harvested; a second harvest copies only new or
      changed files; a legacy timestamp-only marker is honored.
  G3  archive files left uncommitted are committed by catch-up, and an archive
      commit never sweeps in other staged dotprofile work; a stale
      .git/index.lock is reported and does not block a stale-lock steal.
  G5  a transcript that grew is re-archived; subagent copies are named after
      their own files; a subagent already archived under a legacy positional
      name is not copied again.
  G6  .scratch/.current-session is cleared only when it names the harvested dir.
Also: catch-up skips the current session (full or legacy name) and live dirs.

Isolation: HOME and USERPROFILE point at a temp dir for the whole run (the
harvester's log and lock land there); every project and dotprofile is a temp
git repo. Nothing touches the real ~/.aitools, ~/.claude or any repo.

Usage: python3 tests/harvest/test-ait-harvest.py   (python on Windows)
Exit: 0 all tests pass, 1 any failure or no test ran.
Safe to re-run. Platform: macOS, Windows, Linux (stdlib only; needs git).
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import ModuleType

REPO_ROOT = Path(__file__).resolve().parents[2]
# AIT_HARVEST_PY_OVERRIDE: run the suite against another copy of the helper
# (e.g. the pre-fix version, to confirm a test reproduces its bug).
AIT_HARVEST_PY = Path(os.environ.get("AIT_HARVEST_PY_OVERRIDE")
                      or REPO_ROOT / "scripts" / "ait-harvest.py")

# ignore_cleanup_errors: on Windows git makes .git/objects files read-only, so
# removing the temp tree at exit can fail; that must not fail the suite.
_TMP = tempfile.TemporaryDirectory(prefix="aith-test-", ignore_cleanup_errors=True)
TMP = Path(_TMP.name)
TMP_HOME = TMP / "home"
TMP_HOME.mkdir()
os.environ["HOME"] = str(TMP_HOME)
os.environ["USERPROFILE"] = str(TMP_HOME)
for _k, _v in (("GIT_AUTHOR_NAME", "test"), ("GIT_AUTHOR_EMAIL", "test@example.invalid"),
               ("GIT_COMMITTER_NAME", "test"), ("GIT_COMMITTER_EMAIL", "test@example.invalid")):
    os.environ[_k] = _v
os.environ["GIT_CONFIG_NOSYSTEM"] = "1"

SID = "e99e5ef9-938e-4b85-a190-7f315ec84648"
OLD = time.time() - 2 * 3600  # older than the 30-minute liveness window


def load_ait_harvest() -> ModuleType:
    """Import scripts/ait-harvest.py (hyphenated name) as a module."""
    spec = importlib.util.spec_from_file_location("ait_harvest", AIT_HARVEST_PY)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {AIT_HARVEST_PY}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ah = load_ait_harvest()


def git(repo: Path, *args: str) -> str:
    out = subprocess.run(["git", "-C", str(repo), *args],
                         capture_output=True, text=True, check=True)
    return out.stdout


def make_repo(name: str) -> Path:
    """A fresh git repo per call (a new temp dir, never a removed and reused
    one: on Windows .git/objects files are read-only and rmtree fails)."""
    repo = Path(tempfile.mkdtemp(prefix=f"{name}-", dir=TMP))
    git(repo, "init", "-q")
    return repo


def write(p: Path, text: str, mtime: float | None = OLD) -> Path:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")
    if mtime is not None:
        os.utime(p, (mtime, mtime))
    return p


def age_dir(d: Path) -> None:
    """Make a scratch dir and its files look idle (older than the live window)."""
    for p in [d, *d.iterdir()]:
        os.utime(p, (OLD, OLD))


class ScratchNames(unittest.TestCase):
    """G1, G6 and own-session handling."""

    def setUp(self) -> None:
        self.proj = make_repo("proj-names")
        self.scratch = self.proj / ".scratch"
        self.live = self.scratch / f"session-{SID}"
        self.live.mkdir(parents=True)
        (self.scratch / ".current-session").write_text(str(self.live), encoding="utf-8")
        self.orphan = self.scratch / "session-s3maverify99"
        write(self.orphan / "blob-compare.sh", "echo hi\n")
        age_dir(self.orphan)

    def test_long_name_dir_harvested_and_live_dir_untouched(self) -> None:
        n, _ = ah._catchup_harvest(str(self.proj), SID, time.monotonic() + 30)
        self.assertEqual(n, 1)
        harvested = sorted(p.name for p in (self.proj / "harvesting").iterdir())
        self.assertIn(f"{ah.today_utc()}_session-s3maverify99_blob-compare.sh", harvested)
        self.assertTrue((self.orphan / ".harvested").exists())
        self.assertFalse((self.live / ".harvested").exists(), "live dir must not be marked")
        self.assertTrue((self.scratch / ".current-session").exists(), "live pointer must survive")

    def test_resolve_full_then_legacy_then_none(self) -> None:
        self.assertEqual(ah.resolve_session_dir(self.scratch, SID), self.live)
        other = "abcdef1234-5678-90ab-cdef-000000000001"
        legacy = self.scratch / "session-abcdef1234"
        legacy.mkdir()
        self.assertEqual(ah.resolve_session_dir(self.scratch, other), legacy)
        self.assertIsNone(ah.resolve_session_dir(self.scratch, "ffffffffff-nope"),
                          "a known id never falls back to the pointer")
        self.assertEqual(ah.resolve_session_dir(self.scratch, None), self.live)

    def test_own_session_skipped_full_and_legacy(self) -> None:
        write(self.live / "work.sh", "echo live\n")
        age_dir(self.live)
        legacy_own = self.scratch / f"session-{SID[:10]}"
        write(legacy_own / "old.sh", "echo old\n")
        age_dir(legacy_own)
        ah._catchup_harvest(str(self.proj), SID, time.monotonic() + 30)
        self.assertFalse((self.live / ".harvested").exists())
        self.assertFalse((legacy_own / ".harvested").exists())

    def test_live_dir_skipped(self) -> None:
        busy = self.scratch / "session-delegate1"
        write(busy / "wip.py", "print(1)\n", mtime=None)  # modified just now
        ah._catchup_harvest(str(self.proj), SID, time.monotonic() + 30)
        self.assertFalse((busy / ".harvested").exists())

    def test_pointer_cleared_only_for_own_dir(self) -> None:
        ah.harvest_scratch(str(self.proj), None, project_root=self.proj, session_dir=self.orphan)
        self.assertTrue((self.scratch / ".current-session").exists())
        write(self.live / "x.sh", "echo x\n")
        ah.harvest_scratch(str(self.proj), SID, project_root=self.proj)
        self.assertFalse((self.scratch / ".current-session").exists())


class ReHarvest(unittest.TestCase):
    """G2: bookkeeping is never harvested; only new or changed files are."""

    def setUp(self) -> None:
        self.proj = make_repo("proj-reharvest")
        self.sd = self.proj / ".scratch" / f"session-{SID}"
        write(self.sd / "tool.sh", "echo 1\n")
        write(self.sd / "events.jsonl", "{}\n")
        write(self.sd / ".intelligence-last-check", "2026-10-31T00:00:00Z\n")
        write(self.sd / ".hidden-note", "x\n")
        self.hdir = self.proj / "harvesting"

    def harvested(self) -> list[str]:
        return sorted(p.name for p in self.hdir.iterdir() if p.name != "harvest-manifest.json")

    def test_bookkeeping_never_harvested(self) -> None:
        n = ah.harvest_scratch(str(self.proj), SID, project_root=self.proj)
        self.assertEqual(n, 1)
        self.assertEqual(self.harvested(), [f"{ah.today_utc()}_session-{SID}_tool.sh"])

    def test_second_harvest_copies_only_new_or_changed(self) -> None:
        ah.harvest_scratch(str(self.proj), SID, project_root=self.proj)
        self.assertEqual(ah.harvest_scratch(str(self.proj), SID, project_root=self.proj), 0)
        self.assertEqual(len(self.harvested()), 1)
        self.assertEqual(ah.pending_scratch_files(self.sd), [])
        write(self.sd / "new.py", "print(2)\n")
        write(self.sd / "tool.sh", "echo changed\n", mtime=OLD + 60)
        self.assertEqual(ah.harvest_scratch(str(self.proj), SID, project_root=self.proj), 2)
        self.assertEqual(len(self.harvested()), 3)
        record = json.loads((self.sd / ".harvested").read_text(encoding="utf-8"))
        self.assertEqual(sorted(record["files"]), ["new.py", "tool.sh"])

    def test_legacy_marker_honored(self) -> None:
        marker = write(self.sd / ".harvested", "2026-10-01T00:00:00Z\n", mtime=OLD + 10)
        self.assertTrue(marker.exists())
        write(self.sd / "after.sh", "echo after\n", mtime=OLD + 20)
        n = ah.harvest_scratch(str(self.proj), SID, project_root=self.proj)
        self.assertEqual(n, 1, "only the file modified after the legacy marker")
        self.assertEqual(self.harvested(), [f"{ah.today_utc()}_session-{SID}_after.sh"])
        self.assertEqual(ah.harvest_scratch(str(self.proj), SID, project_root=self.proj), 0)

    def test_handoff_routed_with_full_name(self) -> None:
        write(self.sd / "handoff-notes.md", "# handoff\n")
        ah.harvest_scratch(str(self.proj), SID, project_root=self.proj)
        routed = list((self.proj / ".aitools" / "channel" / "handoffs").iterdir())
        self.assertEqual([p.name for p in routed],
                         [f"{ah.today_utc()}_session-{SID}_handoff-notes.md"])


class Archive(unittest.TestCase):
    """G3 and G5."""

    def setUp(self) -> None:
        self.dot = make_repo("dotprofile")
        write(self.dot / "README.md", "dotprofile\n")
        git(self.dot, "add", "README.md")
        git(self.dot, "commit", "-q", "-m", "init")
        self.tdir = TMP_HOME / ".claude" / "projects" / "-tmp-proj"
        if self.tdir.exists():
            shutil.rmtree(self.tdir)
        self.transcript = write(self.tdir / f"{SID}.jsonl",
                                json.dumps({"cwd": str(TMP / "gone-project")}) + "\n")
        self.subdir = self.tdir / SID / "subagents"

    def committed(self) -> list[str]:
        return sorted(git(self.dot, "ls-files", "sessions").split())

    def test_grown_transcript_and_new_subagents_archived(self) -> None:
        write(self.subdir / "agent-bbb.jsonl", '{"a":1}\n')
        self.assertTrue(ah.archive_claude_session(self.transcript, None, None,
                                                  user_repo=self.dot, deadline=time.monotonic() + 30))
        date = ah.transcript_date(self.transcript)
        p8 = SID[:8]
        self.assertIn(f"sessions/gone-project/{date}_{p8}_agent-bbb.jsonl", self.committed())
        # Not grown: nothing to do.
        self.assertFalse(ah.archive_claude_session(self.transcript, None, None,
                                                   user_repo=self.dot, deadline=time.monotonic() + 30))
        # Grown, with a new subagent that sorts first (positional names would shift).
        with open(self.transcript, "a", encoding="utf-8") as f:
            f.write(json.dumps({"more": True}) + "\n")
        os.utime(self.transcript, (OLD, OLD))
        write(self.subdir / "agent-aaa.jsonl", '{"a":2}\n')
        self.assertTrue(ah.archive_claude_session(self.transcript, None, None,
                                                  user_repo=self.dot, deadline=time.monotonic() + 30))
        archived = (self.dot / "sessions" / "gone-project" / f"{date}_{p8}.jsonl").read_text(encoding="utf-8")
        self.assertIn('"more": true', archived)
        self.assertIn(f"sessions/gone-project/{date}_{p8}_agent-aaa.jsonl", self.committed())

    def test_legacy_positional_subagent_not_duplicated(self) -> None:
        date = ah.transcript_date(self.transcript)
        p8 = SID[:8]
        write(self.subdir / "agent-ccc.jsonl", '{"c":1}\n')
        legacy = self.dot / "sessions" / "gone-project" / f"{date}_{p8}_subagent-1.jsonl"
        write(legacy, '{"c":1}\n')
        ah.archive_claude_session(self.transcript, None, None,
                                  user_repo=self.dot, deadline=time.monotonic() + 30)
        self.assertFalse((legacy.parent / f"{date}_{p8}_agent-ccc.jsonl").exists())

    def test_pending_archives_committed_without_other_staged_work(self) -> None:
        write(self.dot / "sessions" / "p" / "2026-10-29_aaaaaaaa.jsonl", "{}\n")
        write(self.dot / "notes.md", "user work in progress\n")
        git(self.dot, "add", "notes.md")
        n = ah.commit_pending_archives(self.dot, time.monotonic() + 30)
        self.assertEqual(n, 1)
        self.assertIn("sessions/p/2026-10-29_aaaaaaaa.jsonl", self.committed())
        head_files = git(self.dot, "show", "--name-only", "--format=", "HEAD").split()
        self.assertNotIn("notes.md", head_files, "other staged work must not be committed")
        self.assertIn("A  notes.md", git(self.dot, "status", "--porcelain"))

    def test_stale_index_lock_reported_and_not_blocking_steal(self) -> None:
        lock = write(self.dot / ".git" / "index.lock", "", mtime=OLD)
        buf = io.StringIO()
        with redirect_stdout(buf):
            ah._report_stale_index_lock(self.dot)
        self.assertIn("dotprofile git index is locked", buf.getvalue())
        self.assertFalse(ah.HarvestLock(self.dot)._dotprofile_index_locked())
        os.utime(lock, None)  # fresh lock: a live git may own it
        self.assertTrue(ah.HarvestLock(self.dot)._dotprofile_index_locked())
        buf = io.StringIO()
        with redirect_stdout(buf):
            ah._report_stale_index_lock(self.dot)
        self.assertEqual(buf.getvalue(), "")
        self.assertTrue(lock.exists(), "the tool never deletes index.lock")
        lock.unlink()


class HarnessDbLookup(unittest.TestCase):
    """harness-db.py process-events finds full-id and legacy scratch dirs."""

    def test_full_then_legacy(self) -> None:
        spec = importlib.util.spec_from_file_location(
            "harness_db", REPO_ROOT / "scripts" / "harness-db.py")
        assert spec is not None and spec.loader is not None
        hdb = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(hdb)
        proj = make_repo("proj-hdb")
        self.assertIsNone(hdb.find_session_scratch_dir(proj, SID))
        legacy = proj / ".scratch" / f"session-{SID[:10]}"
        legacy.mkdir(parents=True)
        self.assertEqual(hdb.find_session_scratch_dir(proj, SID), legacy)
        full = proj / ".scratch" / f"session-{SID}"
        full.mkdir()
        self.assertEqual(hdb.find_session_scratch_dir(proj, SID), full)
        # A delegate's dir name (what find_active_session_id returns) is used as is.
        named = proj / ".scratch" / "session-s3maverify99"
        named.mkdir()
        self.assertEqual(hdb.find_session_scratch_dir(proj, "s3maverify99"), named)


def main() -> int:
    if shutil.which("git") is None:
        print("FAIL: git not on PATH")
        return 1
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if result.testsRun == 0:
        print("FAIL: no test ran")
        return 1
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
