#!/usr/bin/env python3
"""ait-harvest.py -- aitools session/scratch carry-forward harvester.

Purpose: One stdlib-only helper that owns every carry-forward source so the
SessionEnd hooks and a new SessionStart catch-up share a single, robust,
concurrency-safe implementation. Replaces the triplicated archive/harvest
logic in session-archive.sh / harvest-session.sh / `aitools sessions archive`.

Per-source functions (plan imperative-gliding-newell.md §4):
  - archive_claude_session: copy a CC transcript (and its subagents/*.jsonl)
    to the dotprofile under the flat naming sessions/<project>/<date>_<p8>.jsonl,
    then commit + push (deadline-guarded). Idempotent via dest-exists.
  - harvest_scratch: classify + route + manifest + prune a session's
    .scratch/session-<p10>/ dir (stdlib json; never deletes scratch dirs).
  - catchup: orchestrator -- archive orphaned transcripts globally, harvest
    orphaned scratch dirs in the current repo, push if ahead. Single-flight
    heartbeat lock; transcript-mtime liveness; skip own session via stdin sid.
  - archive_cursor_session: ROADMAP stub (issue #5).

Architecture (stdlib only): json, subprocess, pathlib, shutil, os, sys,
datetime, time, argparse, re, socket, logging.

Logging: ~/.aitools/logs/ait-harvest.log via RotatingFileHandler (5MB x 5),
format [<utc-Z>] [ait-harvest] [<level>] <msg>. Mirrors harness-db.py logging
but per reference/logging.md (unified location). Logging never crashes the tool.

Concurrency (plan §16 + §20.1):
  - Single-flight heartbeat lock at ~/.aitools/locks/harvest.lock via
    os.open(O_CREAT|O_EXCL) (atomic on POSIX and Windows; no flock/fcntl).
  - Holder refreshes the lock timestamp (heartbeat); a contender steals ONLY
    if the timestamp has not advanced past a threshold AND no .git/index.lock
    exists in the dotprofile. Never blocks -- skips its sweep when contended.
  - Release via try/finally + atexit.
  - Liveness PRIMARY guard = transcript mtime (>= ~30 min) + clean tail; the
    per-repo harness DB is at most a per-repo optimization, never the sole
    signal for the global sweep.
  - "Skip your own session" uses the session_id passed on stdin/argv,
    never a DB lookup.

Edge cases (plan §20.2):
  - Zero-byte/unparseable transcript -> skip + log.
  - Missing cwd in transcript -> fall back to sanitized projects-dir name.
  - Transient `claude update` session -> skip by positive signal.
  - AITOOLS_DEPLOY_IN_PROGRESS=1 -> catch-up skips its sweep.
  - dotprofile detached/mid-rebase/no-origin/no-upstream -> skip push, keep
    local commit, log specific reason (no silent exit 0).

Safe to re-run. Platform: macOS, Windows (Git Bash), Linux (Python 3.10+).
"""

from __future__ import annotations

import argparse
import atexit
import json
import logging
import logging.handlers
import os
import re
import shutil
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Liveness: a transcript modified more recently than this is "possibly live".
# Conservative (plan §20.1: >= ~30 min, not 2 min) so a paused live session in
# another repo is never archived mid-flight.
LIVE_MTIME_SECONDS = 30 * 60  # 30 minutes

# A transcript with fewer than this many records is treated as a transient
# `claude update` session (positive signal, plan §20.2 M2).
TRANSIENT_MIN_RECORDS = 3

# Lock heartbeat: holder refreshes the lockfile timestamp this often; a
# contender steals only if the timestamp is older than the steal threshold.
LOCK_HEARTBEAT_SECONDS = 15
LOCK_STALE_SECONDS = 90  # plan §20.1: SessionEnd git is not deadline-bounded

# Archive filename prefix length. Matches existing archives + `aitools sessions
# archive` (session-archive.sh:90). NOTE: scratch dir lookup uses 10 chars to
# match scratch-init.sh -- see SCRATCH_PREFIX_LEN.
ARCHIVE_PREFIX_LEN = 8

# Scratch dir prefix length. Must match scratch-init.sh (cut -c1-10) and
# harness-db.py session_prefix() -- the dir on disk is session-<10char>.
SCRATCH_PREFIX_LEN = 10

LOG_MAX_BYTES = 5 * 1024 * 1024  # 5 MB (reference/logging.md)
LOG_BACKUP_COUNT = 5


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

_LOGGER: Optional[logging.Logger] = None


def _log_dir() -> Path:
    """Unified aitools log directory (reference/logging.md)."""
    return Path.home() / ".aitools" / "logs"


def _get_logger() -> logging.Logger:
    """Lazily build the module logger. Never raises -- logging must not crash
    the tool (reference/logging.md decision 5)."""
    global _LOGGER
    if _LOGGER is not None:
        return _LOGGER

    logger = logging.getLogger("ait-harvest")
    logger.setLevel(logging.DEBUG)
    logger.propagate = False

    try:
        log_dir = _log_dir()
        log_dir.mkdir(parents=True, exist_ok=True)
        handler: logging.Handler = logging.handlers.RotatingFileHandler(
            log_dir / "ait-harvest.log",
            maxBytes=LOG_MAX_BYTES,
            backupCount=LOG_BACKUP_COUNT,
            encoding="utf-8",
        )
    except OSError:
        # $HOME unset, dir unwritable, etc. Fall back to a null handler so the
        # tool keeps running (the shim logs the no-log condition from bash).
        handler = logging.NullHandler()

    # Custom format: [<utc-Z>] [ait-harvest] [<level>] <msg>
    class _UtcFormatter(logging.Formatter):
        _LEVELMAP = {
            "DEBUG": "detail",
            "INFO": "info",
            "WARNING": "warn",
            "ERROR": "error",
            "CRITICAL": "error",
        }

        def format(self, record: logging.LogRecord) -> str:
            ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            level = self._LEVELMAP.get(record.levelname, record.levelname.lower())
            return f"[{ts}] [ait-harvest] [{level}] {record.getMessage()}"

    handler.setFormatter(_UtcFormatter())
    logger.addHandler(handler)
    _LOGGER = logger
    return logger


def log_info(msg: str) -> None:
    _get_logger().info(msg)


def log_ok(msg: str) -> None:
    # No dedicated OK level in stdlib logging; map to info with an 'ok:' marker
    # so deploy.log readers can still grep. Kept distinct from plain info.
    _get_logger().info(f"ok: {msg}")


def log_warn(msg: str) -> None:
    _get_logger().warning(msg)


def log_error(msg: str) -> None:
    _get_logger().error(msg)


def log_detail(msg: str) -> None:
    _get_logger().debug(msg)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def today_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def sanitize_project(name: str) -> str:
    """Lowercase + replace non [a-z0-9-] with '-' (matches the bash hooks)."""
    return re.sub(r"[^a-z0-9-]", "-", name.lower())


def read_config_user_repo() -> Optional[Path]:
    """Read userRepoPath (the dotprofile) from ~/.aitools/config.json.

    Returns the path if it exists on disk, else None (logged)."""
    config_file = Path.home() / ".aitools" / "config.json"
    if not config_file.exists():
        log_detail("skipped: aitools config.json not found")
        return None
    try:
        data = json.loads(config_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        log_warn(f"could not read config.json: {e}")
        return None
    raw = data.get("userRepoPath")
    if not raw:
        log_detail("skipped: userRepoPath not set in config.json")
        return None
    repo = Path(raw).expanduser()
    if not repo.is_dir():
        log_detail(f"skipped: userRepoPath does not exist: {repo}")
        return None
    return repo


def git_root(cwd: Path) -> Optional[Path]:
    """Return the git toplevel for cwd, or None. Never raises."""
    try:
        out = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError) as e:
        log_detail(f"git rev-parse failed for {cwd}: {e}")
        return None
    if out.returncode != 0:
        return None
    top = out.stdout.strip()
    return Path(top) if top else None


def first_record_cwd_and_count(transcript: Path) -> tuple[Optional[str], int]:
    """Return (cwd-from-first-record-with-cwd, total-record-count).

    cwd is None if no record carries a cwd field. Count is the number of
    JSON-parseable lines (used for the transient-session signal). Never raises;
    returns (None, 0) on read errors (caller treats as empty/unreadable)."""
    cwd: Optional[str] = None
    count = 0
    try:
        with open(transcript, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                count += 1
                if cwd is None and isinstance(rec, dict) and rec.get("cwd"):
                    cwd = str(rec["cwd"])
    except OSError as e:
        log_detail(f"could not read transcript {transcript.name}: {e}")
        return None, 0
    return cwd, count


def derive_project(transcript: Path, cwd: Optional[str]) -> str:
    """Derive the archive project name (plan §4 + §20.2 M1 fallbacks).

    1. cwd present -> git root basename, else sanitized cwd basename.
    2. cwd missing/repo-gone -> sanitized projects-dir name (old behavior)."""
    if cwd:
        cwd_path = Path(cwd)
        root = git_root(cwd_path) if cwd_path.is_dir() else None
        if root is not None:
            return root.name
        # cwd recorded but repo gone/renamed -> still archive under cwd basename.
        return sanitize_project(cwd_path.name)
    # No cwd in the transcript: fall back to the sanitized projects-dir name.
    log_detail(f"cwd-derive failed for {transcript.name}, using dir name")
    return sanitize_project(transcript.parent.name)


def transcript_date(transcript: Path) -> str:
    """Date for the archive filename: file mtime (UTC), fallback today.

    The bash hook uses birth time where available; mtime is portable and
    close enough, and this matches `aitools sessions archive` on non-macOS."""
    try:
        mtime = transcript.stat().st_mtime
        return datetime.fromtimestamp(mtime, tz=timezone.utc).strftime("%Y-%m-%d")
    except OSError:
        return today_utc()


# ---------------------------------------------------------------------------
# Single-flight heartbeat lock (plan §16 + §20.1)
# ---------------------------------------------------------------------------

class HarvestLock:
    """Atomic single-flight lock with heartbeat + steal-on-stale.

    Acquire returns True if the lock is held by this process, False if a live
    holder exists (caller must SKIP its sweep -- never block, plan §20.1 C2).
    The holder must periodically call heartbeat(). Release is idempotent and
    registered with atexit + used in try/finally by callers (plan §20.1 m2)."""

    def __init__(self, dotprofile: Optional[Path]) -> None:
        self.path = Path.home() / ".aitools" / "locks" / "harvest.lock"
        self.dotprofile = dotprofile
        self.held = False
        self._fd: Optional[int] = None

    def _write_payload(self, fd: int) -> None:
        payload = json.dumps({
            "pid": os.getpid(),
            "host": socket.gethostname(),
            "start": utcnow(),
            "heartbeat": time.time(),
        })
        os.lseek(fd, 0, os.SEEK_SET)
        os.ftruncate(fd, 0)
        os.write(fd, payload.encode("utf-8"))
        os.fsync(fd)

    def _read_heartbeat(self) -> Optional[float]:
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
            hb = data.get("heartbeat")
            return float(hb) if hb is not None else None
        except (OSError, json.JSONDecodeError, TypeError, ValueError):
            return None

    def _dotprofile_index_locked(self) -> bool:
        """True if the dotprofile has a live .git/index.lock (plan §20.1 C1).
        Conservative: if we cannot tell, return True (do not steal)."""
        if self.dotprofile is None:
            return False
        try:
            return (self.dotprofile / ".git" / "index.lock").exists()
        except OSError:
            return True

    def acquire(self) -> bool:
        # m1: ensure the lock directory exists first; failure -> cannot lock,
        # caller skips (do not crash).
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            log_warn(f"cannot create lock dir, skipping sweep: {e}")
            return False

        try:
            self._fd = os.open(
                str(self.path), os.O_CREAT | os.O_EXCL | os.O_RDWR
            )
            self._write_payload(self._fd)
            self.held = True
            atexit.register(self.release)
            log_detail("lock acquired")
            return True
        except FileExistsError:
            pass
        except OSError as e:
            log_warn(f"lock open failed, skipping sweep: {e}")
            return False

        # Lock exists. Steal ONLY if heartbeat is stale AND dotprofile has no
        # live index.lock (plan §20.1 C1). Never block.
        hb = self._read_heartbeat()
        if hb is None:
            # Unreadable/corrupt lock: treat as stale only if the file itself
            # is older than the stale threshold (mtime), to avoid racing a
            # holder mid-write.
            try:
                age = time.time() - self.path.stat().st_mtime
            except OSError:
                age = 0.0
            stale = age > LOCK_STALE_SECONDS
        else:
            stale = (time.time() - hb) > LOCK_STALE_SECONDS

        if not stale:
            log_detail("lock held by live process, skipping sweep")
            return False
        if self._dotprofile_index_locked():
            log_detail("lock stale but dotprofile index.lock present, skipping")
            return False

        # Steal: remove the orphaned lock and re-acquire. Document the degraded
        # window (a crashed holder leaves a <= LOCK_STALE_SECONDS gap).
        log_warn(f"stealing stale lock (heartbeat > {LOCK_STALE_SECONDS}s)")
        try:
            os.remove(str(self.path))
        except OSError as e:
            log_warn(f"could not remove stale lock, skipping: {e}")
            return False
        try:
            self._fd = os.open(
                str(self.path), os.O_CREAT | os.O_EXCL | os.O_RDWR
            )
            self._write_payload(self._fd)
            self.held = True
            atexit.register(self.release)
            log_detail("lock acquired after steal")
            return True
        except OSError as e:
            # Another contender won the race -- skip.
            log_detail(f"lost steal race, skipping: {e}")
            return False

    def heartbeat(self) -> None:
        if self.held and self._fd is not None:
            try:
                self._write_payload(self._fd)
            except OSError as e:
                log_detail(f"heartbeat write failed: {e}")

    def release(self) -> None:
        if not self.held:
            return
        self.held = False
        if self._fd is not None:
            try:
                os.close(self._fd)
            except OSError:
                pass
            self._fd = None
        try:
            os.remove(str(self.path))
            log_detail("lock released")
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Git operations (deadline-guarded, dotprofile-state aware)
# ---------------------------------------------------------------------------

def _git(repo: Path, args: list[str], remaining: float) -> tuple[int, str, str]:
    """Run a git command with a timeout derived from the deadline budget.
    Returns (returncode, stdout, stderr). returncode 124 == timed out / error."""
    timeout = max(1.0, remaining)
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), *args],
            capture_output=True, text=True, timeout=timeout,
        )
        return out.returncode, out.stdout.strip(), out.stderr.strip()
    except subprocess.TimeoutExpired:
        log_warn(f"git {args[0]} timed out after {timeout:.0f}s")
        return 124, "", "timeout"
    except (OSError, subprocess.SubprocessError) as e:
        log_warn(f"git {args[0]} failed: {e}")
        return 124, "", str(e)


def dotprofile_push_blocked_reason(repo: Path, remaining: float) -> Optional[str]:
    """Return a reason string if the dotprofile is NOT in a clean state to push,
    else None (plan §20.2 M6). Checks: mid-rebase/merge, no origin, no upstream,
    detached HEAD."""
    git_dir = repo / ".git"
    try:
        if (git_dir / "MERGE_HEAD").exists():
            return "merge in progress"
        for rebase in ("rebase-merge", "rebase-apply"):
            if (git_dir / rebase).exists():
                return "rebase in progress"
    except OSError:
        return "cannot inspect .git state"

    rc, _, _ = _git(repo, ["remote", "get-url", "origin"], remaining)
    if rc != 0:
        return "no origin remote"

    rc, out, _ = _git(
        repo, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
        remaining,
    )
    if rc != 0 or not out:
        return "no upstream for current branch"

    rc, head, _ = _git(repo, ["symbolic-ref", "-q", "HEAD"], remaining)
    if rc != 0 or not head:
        return "detached HEAD"

    return None


def commit_and_push(
    repo: Path, rel_path: str, commit_msg: str, deadline: float,
) -> None:
    """Stage one file, commit, and push if the dotprofile is clean. Best-effort:
    every failure path logs a specific reason; the local commit is preserved on
    push failure (plan §20.2 M6 / pass 4 -- no silent exit)."""
    def remaining() -> float:
        return deadline - time.monotonic()

    if remaining() <= 0:
        log_warn(f"deadline exceeded before git add ({rel_path})")
        return

    rc, _, err = _git(repo, ["add", rel_path], remaining())
    if rc != 0:
        log_warn(f"git add failed for {rel_path}: {err}")
        return

    rc, _, err = _git(repo, ["commit", "-m", commit_msg], remaining())
    if rc != 0:
        # Nothing to commit is benign (already staged/committed by a peer).
        log_detail(f"git commit produced no commit ({rel_path}): {err}")
        return
    log_ok(f"committed {rel_path}")

    reason = dotprofile_push_blocked_reason(repo, remaining())
    if reason is not None:
        log_warn(f"push skipped, commit kept: {reason}")
        return

    # Pull --rebase handles the cross-machine race; the lock handles same-machine.
    rc, _, err = _git(repo, ["pull", "--rebase"], remaining())
    if rc != 0:
        log_warn(f"git pull --rebase failed, push skipped, commit kept: {err}")
        return

    rc, _, err = _git(repo, ["push"], remaining())
    if rc != 0:
        log_warn(f"git push failed (offline or remote ahead), commit kept: {err}")
        return
    log_ok(f"pushed {rel_path}")


def dotprofile_is_ahead(repo: Path, remaining: float) -> bool:
    """True if the local branch has commits not on its upstream."""
    rc, out, _ = _git(
        repo, ["rev-list", "--count", "@{u}..HEAD"], remaining
    )
    if rc != 0:
        return False
    try:
        return int(out) > 0
    except ValueError:
        return False


# ---------------------------------------------------------------------------
# archive_claude_session
# ---------------------------------------------------------------------------

def archive_claude_session(
    transcript: Path,
    cwd: Optional[str],
    session_id: Optional[str],
    *,
    user_repo: Optional[Path] = None,
    deadline: Optional[float] = None,
    do_git: bool = True,
) -> bool:
    """Archive one CC transcript (+ subagents) to the dotprofile.

    Returns True if a new file was written, False if skipped (already archived,
    empty, no config, etc. -- each logged at detail). Idempotent."""
    if user_repo is None:
        user_repo = read_config_user_repo()
        if user_repo is None:
            return False

    if not transcript.exists():
        log_detail(f"skipped: transcript missing {transcript}")
        return False

    # Zero-byte / unreadable guard (plan §20.2 M1).
    try:
        if transcript.stat().st_size == 0:
            log_detail(f"skipped: empty (zero-byte) transcript {transcript.name}")
            return False
    except OSError as e:
        log_detail(f"skipped: cannot stat {transcript.name}: {e}")
        return False

    if cwd is None:
        cwd, _ = first_record_cwd_and_count(transcript)

    project = derive_project(transcript, cwd)
    full_id = transcript.stem  # filename without .jsonl == session id
    prefix = full_id[:ARCHIVE_PREFIX_LEN]
    date = transcript_date(transcript)

    dest_dir = user_repo / "sessions" / project
    dest_file = dest_dir / f"{date}_{prefix}.jsonl"

    if dest_file.exists():
        log_detail(f"skipped: already archived {project}/{date}_{prefix}.jsonl")
        return False

    try:
        dest_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(transcript), str(dest_file))
    except OSError as e:
        log_error(f"failed to copy transcript {transcript.name}: {e}")
        return False
    log_ok(f"archived {project}/{date}_{prefix}.jsonl")

    rel_paths = [f"sessions/{project}/{date}_{prefix}.jsonl"]

    # --- Subagent transcripts (plan §3/§4: never archived before) ---
    # Located at <transcript-dir>/<session-id>/subagents/*.jsonl OR
    # <transcript-dir>/subagents/*.jsonl depending on CC version. Copy as flat
    # siblings: <date>_<p8>_subagent-<n>.jsonl (NOT a directory).
    subagent_dirs = [
        transcript.parent / full_id / "subagents",
        transcript.parent / "subagents",
    ]
    n = 0
    for sad in subagent_dirs:
        if not sad.is_dir():
            continue
        try:
            sub_files = sorted(sad.glob("*.jsonl"))
        except OSError:
            sub_files = []
        for sub in sub_files:
            n += 1
            sub_dest = dest_dir / f"{date}_{prefix}_subagent-{n}.jsonl"
            if sub_dest.exists():
                continue
            try:
                shutil.copy2(str(sub), str(sub_dest))
                rel_paths.append(
                    f"sessions/{project}/{date}_{prefix}_subagent-{n}.jsonl"
                )
                log_ok(f"archived subagent {sub_dest.name}")
            except OSError as e:
                log_warn(f"failed to copy subagent {sub.name}: {e}")

    # --- Commit + push (deadline-guarded) ---
    if do_git:
        if deadline is None:
            deadline = time.monotonic() + 10.0
        commit_msg = f"Archive session {date}_{prefix} ({project})"
        # Stage all archived files (transcript + subagents) in one commit.
        for rp in rel_paths:
            rc, _, err = _git(user_repo, ["add", rp], deadline - time.monotonic())
            if rc != 0:
                log_warn(f"git add failed for {rp}: {err}")
        # Single commit + push via the shared path (re-stages safely).
        commit_and_push(user_repo, rel_paths[0], commit_msg, deadline)

    return True


# ---------------------------------------------------------------------------
# harvest_scratch (ports harvest-session.sh, stdlib json, no node)
# ---------------------------------------------------------------------------

CODE_EXTS = {".py", ".sh", ".ps1", ".js", ".ts", ".go", ".rs", ".pl"}
ARTIFACT_EXTS = {".yaml", ".yml", ".toml", ".csv", ".sql", ".html", ".txt"}
LANG_MAP = {
    "py": "python", "sh": "bash", "ps1": "powershell", "js": "javascript",
    "ts": "typescript", "go": "go", "rs": "rust", "pl": "perl", "md": "markdown",
}


def _is_ephemeral(filename: str) -> bool:
    """Classification mirroring harvest-session.sh (extension + name)."""
    lower = filename.lower()
    if lower.startswith("commit-msg") or lower.endswith((".log", ".tmp")):
        return True
    ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext in CODE_EXTS:
        return False
    if ext == ".json":
        if (lower.startswith("package-lock") or lower.startswith("node_modules")
                or lower.endswith(".config.json") or lower.startswith("tsconfig")):
            return True
        return False
    if ext == ".md":
        if "log" in lower or "output" in lower or "dump" in lower:
            return True
        return False
    if ext in ARTIFACT_EXTS:
        return False
    # Unknown extension: harvest with warning rather than silently delete.
    return False


def _atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    """Write JSON atomically via temp file + os.replace (plan §16)."""
    tmp = path.with_name(path.name + f".tmp.{os.getpid()}")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    os.replace(str(tmp), str(path))


def _load_manifest(path: Path) -> dict[str, Any]:
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                data.setdefault("meta", {"schemaVersion": "1.0", "lastAudit": None})
                data.setdefault("artifacts", {})
                return data
        except (OSError, json.JSONDecodeError) as e:
            log_warn(f"manifest unreadable, starting fresh: {e}")
    return {"meta": {"schemaVersion": "1.0", "lastAudit": None}, "artifacts": {}}


def harvest_scratch(
    cwd: str,
    session_id: Optional[str],
    *,
    project_root: Optional[Path] = None,
) -> int:
    """Classify + route + manifest a session's scratch dir. Returns the number
    of artifacts harvested. Never deletes scratch dirs (30-file-loss guard).
    Leaves DB session-end marking to harness-db-sessionend.sh."""
    if project_root is None:
        root = git_root(Path(cwd)) if cwd and Path(cwd).is_dir() else None
        project_root = root if root is not None else Path(cwd)

    scratch_dir = project_root / ".scratch"
    prefix = session_id[:SCRATCH_PREFIX_LEN] if session_id else ""

    session_dir: Optional[Path] = None
    if prefix and (scratch_dir / f"session-{prefix}").is_dir():
        session_dir = scratch_dir / f"session-{prefix}"
    else:
        current = scratch_dir / ".current-session"
        if current.exists():
            try:
                p = current.read_text(encoding="utf-8").strip()
                if p and Path(p).is_dir():
                    session_dir = Path(p)
            except OSError:
                pass

    if session_dir is None or not session_dir.is_dir():
        log_detail(f"skipped harvest: no session dir for {prefix or '(none)'}")
        return 0

    harvesting_dir = project_root / "harvesting"
    handoffs_dir = project_root / ".aitools" / "channel" / "handoffs"
    manifest_path = harvesting_dir / "harvest-manifest.json"
    today = today_utc()
    harvested = 0
    deleted = 0

    try:
        files = sorted(p for p in session_dir.iterdir() if p.is_file())
    except OSError as e:
        log_warn(f"cannot list session dir {session_dir}: {e}")
        return 0

    manifest: Optional[dict[str, Any]] = None

    for f in files:
        filename = f.name
        if _is_ephemeral(filename):
            deleted += 1
            continue

        # Handoff routing.
        if filename.startswith("handoff"):
            try:
                handoffs_dir.mkdir(parents=True, exist_ok=True)
                dest = handoffs_dir / f"{today}_session-{prefix}_{filename}"
                shutil.copy2(str(f), str(dest))
                harvested += 1
                log_ok(f"routed handoff {dest.name}")
            except OSError as e:
                log_warn(f"handoff copy failed for {filename}: {e}")
            continue

        # Harvest to harvesting/.
        try:
            harvesting_dir.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            log_warn(f"cannot create harvesting dir: {e}")
            continue

        session_tag = f"session-{prefix}_" if prefix else ""
        dest_name = f"{today}_{session_tag}{filename}"
        dest_path = harvesting_dir / dest_name
        if dest_path.exists():
            counter = 1
            while (harvesting_dir / f"{today}_{counter}_{session_tag}{filename}").exists():
                counter += 1
            dest_name = f"{today}_{counter}_{session_tag}{filename}"
            dest_path = harvesting_dir / dest_name

        try:
            shutil.copy2(str(f), str(dest_path))
        except OSError as e:
            log_warn(f"harvest copy failed for {filename}: {e}")
            continue

        if manifest is None:
            manifest = _load_manifest(manifest_path)
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
        project_name = project_root.name
        session_ref = f"{project_name}/{today}_{prefix}" if cwd else ""
        # pruneAfter = today + 30 days.
        prune_after = datetime.now(timezone.utc).timestamp() + 30 * 86400
        prune_date = datetime.fromtimestamp(
            prune_after, tz=timezone.utc).strftime("%Y-%m-%d")
        manifest["artifacts"][dest_name] = {
            "harvested": today,
            "session": session_ref,
            "description": "Auto-harvested from session scratch",
            "type": "code",
            "language": LANG_MAP.get(ext),
            "status": "harvested",
            "promotedTo": None,
            "pruneAfter": prune_date,
        }
        harvested += 1
        log_ok(f"harvested {dest_name}")

    if manifest is not None:
        try:
            _atomic_write_json(manifest_path, manifest)
        except OSError as e:
            log_warn(f"manifest write failed: {e}")

    # Clear the legacy session pointer (leave the session dir intact).
    try:
        (scratch_dir / ".current-session").unlink()
    except OSError:
        pass

    # Audit/prune the manifest (mark pruned, never unlink -- 30-file-loss guard).
    _audit_manifest(manifest_path, harvesting_dir, project_root)

    if harvested or deleted:
        log_info(
            f"harvest {prefix or 'unknown'}: {harvested} harvested, "
            f"{deleted} ephemeral skipped"
        )
    return harvested


def _audit_manifest(
    manifest_path: Path, harvesting_dir: Path, project_root: Path,
) -> None:
    """Prune stale artifacts: mark 'pruned' (never delete the file) when past
    pruneAfter with zero git refs, else promote to 'candidate'."""
    if not manifest_path.exists():
        return
    manifest = _load_manifest(manifest_path)
    today = datetime.now(timezone.utc).date()
    changed = False
    for name, entry in manifest.get("artifacts", {}).items():
        status = entry.get("status")
        if status in ("promoted", "pruned"):
            continue
        prune_after = entry.get("pruneAfter")
        if not prune_after:
            continue
        try:
            prune_date = datetime.strptime(prune_after, "%Y-%m-%d").date()
        except (ValueError, TypeError):
            continue
        if today <= prune_date:
            continue
        # Past prune date: check git refs.
        refs = 0
        try:
            out = subprocess.run(
                ["git", "-C", str(project_root), "log", "--all", "--oneline",
                 "--", str(harvesting_dir / name)],
                capture_output=True, text=True, timeout=5,
            )
            if out.returncode == 0:
                refs = len([ln for ln in out.stdout.splitlines() if ln.strip()])
        except (OSError, subprocess.SubprocessError):
            refs = 0
        if refs == 0:
            entry["status"] = "pruned"  # marked, NOT deleted
        else:
            entry["status"] = "candidate"
        changed = True
    if changed:
        manifest.setdefault("meta", {})["lastAudit"] = today_utc()
        try:
            _atomic_write_json(manifest_path, manifest)
        except OSError as e:
            log_warn(f"manifest audit write failed: {e}")


# ---------------------------------------------------------------------------
# catchup (orchestrator)
# ---------------------------------------------------------------------------

def _is_transient_session(transcript: Path) -> bool:
    """Positive signal for a transient `claude update` session (plan §20.2 M2):
    a transcript with very few records."""
    _, count = first_record_cwd_and_count(transcript)
    return 0 < count < TRANSIENT_MIN_RECORDS


def catchup(
    cwd: str,
    session_id: Optional[str],
    deadline_seconds: float = 10.0,
) -> int:
    """Recover what SessionEnd missed: archive orphaned CC transcripts globally,
    harvest the current repo's orphaned scratch dirs, push if ahead. Single-
    flight; skips its sweep if contended or during an aitools deploy."""
    # Skip during an in-flight aitools deploy (plan §20.2 M2).
    if os.environ.get("AITOOLS_DEPLOY_IN_PROGRESS"):
        log_detail("skipped catchup: AITOOLS_DEPLOY_IN_PROGRESS set")
        return 0

    user_repo = read_config_user_repo()
    lock = HarvestLock(user_repo)
    if not lock.acquire():
        # Contended -- the holder covers the global orphan set. Skip, stay fast.
        return 0

    recovered = 0
    deadline = time.monotonic() + deadline_seconds
    try:
        recovered += _catchup_archive(user_repo, session_id, deadline, lock)
        lock.heartbeat()
        # Harvest orphaned scratch dirs in the current repo.
        recovered += _catchup_harvest(cwd, session_id)
        lock.heartbeat()
        # Push if the dotprofile is ahead (e.g. a prior commit never pushed).
        if user_repo is not None:
            remaining = deadline - time.monotonic()
            if remaining > 0 and dotprofile_is_ahead(user_repo, remaining):
                reason = dotprofile_push_blocked_reason(user_repo, remaining)
                if reason is None:
                    rc, _, err = _git(
                        user_repo, ["push"], deadline - time.monotonic())
                    if rc == 0:
                        log_ok("pushed dotprofile (was ahead)")
                    else:
                        log_warn(f"dotprofile push failed, commit kept: {err}")
                else:
                    log_warn(f"dotprofile ahead but push skipped: {reason}")
    finally:
        lock.release()

    if recovered:
        log_info(f"catchup recovered {recovered} item(s)")
    return recovered


def _catchup_archive(
    user_repo: Optional[Path],
    session_id: Optional[str],
    deadline: float,
    lock: HarvestLock,
) -> int:
    """Scan ~/.claude/projects/*/*.jsonl; archive any orphaned, non-live,
    non-transient transcript that has no dotprofile dest yet."""
    if user_repo is None:
        return 0
    projects = Path.home() / ".claude" / "projects"
    if not projects.is_dir():
        return 0

    recovered = 0
    now = time.time()
    try:
        transcripts = sorted(projects.glob("*/*.jsonl"))
    except OSError as e:
        log_warn(f"cannot scan projects dir: {e}")
        return 0

    for t in transcripts:
        if deadline - time.monotonic() <= 0:
            log_warn("catchup archive: deadline reached, stopping sweep")
            break
        lock.heartbeat()

        full_id = t.stem
        # Skip our own session via stdin/argv sid (deterministic, plan §20.1).
        if session_id and full_id.startswith(session_id[:max(8, len(session_id))]):
            continue
        if session_id and full_id == session_id:
            continue

        # Liveness PRIMARY guard: mtime >= LIVE_MTIME_SECONDS (plan §20.1).
        try:
            mtime = t.stat().st_mtime
            size = t.stat().st_size
        except OSError:
            continue
        if size == 0:
            log_detail(f"skipped: empty transcript {t.name}")
            continue
        if (now - mtime) < LIVE_MTIME_SECONDS:
            log_detail(f"skipped: possibly-live transcript {t.name} (recent mtime)")
            continue

        # Transient `claude update` session (positive signal).
        if _is_transient_session(t):
            log_detail(f"skipped: transient/update session {t.name}")
            continue

        if archive_claude_session(
            t, None, None, user_repo=user_repo, deadline=deadline, do_git=True
        ):
            recovered += 1

    return recovered


def _catchup_harvest(cwd: str, session_id: Optional[str]) -> int:
    """Harvest orphaned .scratch/session-* dirs in the current repo whose
    SessionEnd never ran. Skips the current session's own dir."""
    root = git_root(Path(cwd)) if cwd and Path(cwd).is_dir() else None
    project_root = root if root is not None else Path(cwd) if cwd else None
    if project_root is None or not project_root.is_dir():
        return 0
    scratch_dir = project_root / ".scratch"
    if not scratch_dir.is_dir():
        return 0

    own_prefix = session_id[:SCRATCH_PREFIX_LEN] if session_id else None
    recovered = 0
    try:
        session_dirs = [
            p for p in scratch_dir.iterdir()
            if p.is_dir() and p.name.startswith("session-")
        ]
    except OSError:
        return 0

    for sd in session_dirs:
        dir_prefix = sd.name[len("session-"):]
        if own_prefix and dir_prefix == own_prefix:
            continue  # never harvest our own live session
        recovered += harvest_scratch(
            str(project_root), dir_prefix, project_root=project_root
        )
    return recovered


# ---------------------------------------------------------------------------
# archive_cursor_session (ROADMAP stub -- issue #5)
# ---------------------------------------------------------------------------

def archive_cursor_session(*_args: Any, **_kwargs: Any) -> int:
    """ROADMAP stub: Cursor CLI sessions live in ~/.cursor/chats/*/store.db
    (SQLite with live WAL). Safe archiving requires a sqlite3 .backup / WAL
    checkpoint plus a workspace-hash -> project mapping. Deferred to issue #5."""
    log_detail("archive_cursor_session is a stub (issue #5); no-op")
    return 0


# ---------------------------------------------------------------------------
# stdin / argv parsing
# ---------------------------------------------------------------------------

def _read_stdin_json() -> dict[str, Any]:
    """Read a CC hook JSON payload from stdin if present. Returns {} on any
    error (the shim passes raw stdin; argv flags can override)."""
    if sys.stdin is None or sys.stdin.isatty():
        return {}
    try:
        raw = sys.stdin.read()
    except (OSError, ValueError):
        return {}
    if not raw.strip():
        return {}
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        log_detail("stdin was not valid JSON; ignoring")
        return {}


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_archive(args: argparse.Namespace) -> int:
    payload = _read_stdin_json()
    session_id = args.session or payload.get("session_id")
    cwd = args.cwd or payload.get("cwd")
    transcript_path = args.transcript or payload.get("transcript_path")
    if not transcript_path:
        log_detail("archive: no transcript_path on stdin/argv; nothing to do")
        return 0
    transcript = Path(transcript_path)
    archive_claude_session(transcript, cwd, session_id)
    return 0


def cmd_harvest(args: argparse.Namespace) -> int:
    payload = _read_stdin_json()
    session_id = args.session or payload.get("session_id")
    cwd = args.cwd or payload.get("cwd") or os.getcwd()
    harvest_scratch(cwd, session_id)
    return 0


def cmd_catchup(args: argparse.Namespace) -> int:
    payload = _read_stdin_json()
    session_id = args.session or payload.get("session_id")
    cwd = args.cwd or payload.get("cwd") or os.getcwd()
    catchup(cwd, session_id, deadline_seconds=args.deadline)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ait-harvest.py",
        description="aitools session/scratch carry-forward harvester",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_archive = sub.add_parser("archive", help="archive a CC transcript")
    p_archive.add_argument("--session", help="session id (else from stdin)")
    p_archive.add_argument("--cwd", help="working dir (else from stdin/transcript)")
    p_archive.add_argument("--transcript", help="transcript path (else from stdin)")
    p_archive.set_defaults(func=cmd_archive)

    p_harvest = sub.add_parser("harvest", help="harvest a session's scratch dir")
    p_harvest.add_argument("--session", help="session id (else from stdin)")
    p_harvest.add_argument("--cwd", help="working dir (else from stdin/cwd)")
    p_harvest.set_defaults(func=cmd_harvest)

    p_catchup = sub.add_parser("catchup", help="recover what SessionEnd missed")
    p_catchup.add_argument("--session", help="current session id (else from stdin)")
    p_catchup.add_argument("--cwd", help="current working dir (else from stdin/cwd)")
    p_catchup.add_argument(
        "--deadline", type=float, default=10.0,
        help="graceful deadline in seconds (default 10)",
    )
    p_catchup.set_defaults(func=cmd_catchup)

    return parser


def main(argv: Optional[list[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except Exception as e:  # noqa: BLE001 -- top-level guard, must log then exit 0
        # The hook must never break Claude Code: log and exit 0.
        log_error(f"unhandled error in {args.command}: {e}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
