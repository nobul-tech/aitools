#!/usr/bin/env python3
"""ait-harvest.py -- aitools session/scratch carry-forward harvester.

Purpose: One stdlib-only helper that owns every carry-forward source so the
SessionEnd hooks and a new SessionStart catch-up share a single, robust,
concurrency-safe implementation. Replaces the triplicated archive/harvest
logic in session-archive.sh / harvest-session.sh / `aitools sessions archive`.

Per-source functions (plan imperative-gliding-newell.md §4):
  - archive_claude_session: copy a CC transcript (and its subagents/*.jsonl)
    to the dotprofile under the flat naming sessions/<project>/<date>_<p8>.jsonl,
    then commit ONLY those paths + push (deadline-guarded). Idempotent: an
    archive is re-copied only when the transcript grew.
  - harvest_scratch: classify + route + manifest a session's
    .scratch/session-<name>/ dir, name used verbatim (stdlib json; never
    deletes scratch dirs). A per-dir harvest record (.harvested, JSON) makes
    later runs copy only new or changed files.
  - catchup: orchestrator -- report a stale dotprofile index.lock, archive
    orphaned transcripts globally, commit archives left uncommitted, harvest
    pending scratch dirs in the current repo, audit the manifest, push if
    ahead. Single-flight heartbeat lock; mtime liveness for transcripts and
    scratch dirs; skip own session via stdin sid.
  Design and gaps: reference/artifact-harvesting.md.
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
import filecmp
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
# archive`. Archive names only; scratch names are never truncated.
ARCHIVE_PREFIX_LEN = 8

# Scratch dir names are used verbatim (2026-10-31): scratch-init.sh creates
# .scratch/session-<full session id>, delegates create session-<any name>.
# Dirs created before that are session-<first 10 chars of the id>; this length
# is used ONLY to find such a legacy dir from a session id (SessionEnd) and to
# recognize the current session's own legacy dir in catch-up. A dir name is
# never cut to this length (the cut made a 12-char delegate dir resolve to
# the live session's dir: reference/artifact-harvesting.md gap G1).
LEGACY_SCRATCH_PREFIX_LEN = 10

# Files a session dir holds for the harness, not for the user: the harvest
# record, the intelligence-stop marker, and hook telemetry (consumed by
# harness-db.py process-events). Never harvested (gap G2). Every other name
# that starts with "." is treated the same way.
HARNESS_SCRATCH_FILES = {".harvested", ".intelligence-last-check", "events.jsonl"}

# Name of the per-dir harvest record (JSON since 2026-10-31; older markers are
# a single UTC timestamp line).
HARVEST_MARKER = ".harvested"

# A dotprofile .git/index.lock older than this is reported as stale (it blocks
# every archive commit, gap G3) and no longer prevents stealing a stale
# harvest lock. It is never deleted by this tool.
INDEX_LOCK_STALE_SECONDS = 10 * 60

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

    Returns the path if it exists on disk, else None (logged).

    utf-8-sig: a config.json written with a UTF-8 BOM (Windows PowerShell 5.1
    and some editors) parses instead of failing, so a BOM does not disable
    archiving (M3 B8c). ValueError covers JSONDecodeError and
    UnicodeDecodeError (a non-UTF-8 file, e.g. UTF-16), which used to escape
    uncaught."""
    config_file = Path.home() / ".aitools" / "config.json"
    if not config_file.exists():
        log_detail("skipped: aitools config.json not found")
        return None
    try:
        data: Any = json.loads(config_file.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as e:
        log_warn(f"could not read config.json -- sessions not archived: {e}")
        return None
    if not isinstance(data, dict):
        log_warn("config.json is not a JSON object -- sessions not archived")
        return None
    raw = data.get("userRepoPath")
    if raw is None or raw == "":
        log_detail("skipped: userRepoPath not set in config.json")
        return None
    if not isinstance(raw, str):
        log_warn(f"config.json userRepoPath is not a string ({type(raw).__name__}) -- sessions not archived")
        return None
    repo = Path(raw).expanduser()
    if not repo.is_dir():
        # A configured dotprofile that is missing stops archiving: warn, not detail.
        log_warn(f"userRepoPath does not exist -- sessions not archived: {repo}")
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


def first_record_cwd(transcript: Path) -> Optional[str]:
    """Return the cwd from the first record that carries one, else None.

    Short-circuits on the first cwd found -- transcripts can be many MB, so we
    never read the whole file just to derive a project name. Never raises."""
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
                if isinstance(rec, dict) and rec.get("cwd"):
                    return str(rec["cwd"])
    except OSError as e:
        log_detail(f"could not read transcript {transcript.name}: {e}")
    return None


def record_count_capped(transcript: Path, cap: int) -> int:
    """Count JSON-parseable records, stopping once `cap` is reached.

    Used for the transient-session signal so we never read a multi-MB
    transcript in full just to learn it has more than a couple of records.
    Returns 0 on read errors. Never raises."""
    count = 0
    try:
        with open(transcript, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    json.loads(line)
                except json.JSONDecodeError:
                    continue
                count += 1
                if count >= cap:
                    break
    except OSError as e:
        log_detail(f"could not read transcript {transcript.name}: {e}")
        return 0
    return count


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


def index_lock_age(repo: Path) -> Optional[float]:
    """Age in seconds of repo/.git/index.lock: None when there is no lock,
    -1.0 when it exists but cannot be inspected. Never raises."""
    lock = repo / ".git" / "index.lock"
    try:
        if not lock.exists():
            return None
        return max(0.0, time.time() - lock.stat().st_mtime)
    except OSError as e:
        log_detail(f"cannot inspect {lock}: {e}")
        return -1.0


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
        A lock older than INDEX_LOCK_STALE_SECONDS is a leftover of a crashed
        git, not a live one, and does not block the steal (it is reported by
        catchup, never deleted). Conservative: if we cannot tell, True."""
        if self.dotprofile is None:
            return False
        age = index_lock_age(self.dotprofile)
        if age is None:
            return False
        if age < 0:
            return True
        return age < INDEX_LOCK_STALE_SECONDS

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


def worktree_dirty(repo: Path, remaining: float) -> bool:
    """True if the repo has staged or unstaged tracked changes (untracked
    ignored). Used to skip a `pull --rebase` that would deterministically fail:
    the dotprofile is EXPECTED to carry uncommitted work-in-progress, and that
    must not error out or hang the sweep. Conservative: False if we cannot tell
    (let the normal rebase path run)."""
    rc, out, _ = _git(
        repo, ["status", "--porcelain", "--untracked-files=no"], remaining)
    if rc != 0:
        return False
    return bool(out.strip())


def commit_and_push(
    repo: Path, rel_paths: list[str], commit_msg: str, deadline: float,
) -> bool:
    """Stage the given paths, commit ONLY those paths (`git commit -- <paths>`,
    so other work staged in the dotprofile is never swept into an archive
    commit), and push if the dotprofile is clean. Returns True when a commit
    was made. Best-effort: every failure path logs a specific reason; a commit
    is kept on push failure (plan §20.2 M6 / pass 4 -- no silent exit). Files
    left uncommitted are picked up by catchup's commit_pending_archives()."""
    def remaining() -> float:
        return deadline - time.monotonic()

    if not rel_paths:
        return False
    label = rel_paths[0] if len(rel_paths) == 1 else f"{len(rel_paths)} paths"
    if remaining() <= 0:
        log_warn(f"deadline exceeded before git add ({label}); left uncommitted")
        return False

    rc, _, err = _git(repo, ["add", "--", *rel_paths], remaining())
    if rc != 0:
        log_warn(f"git add failed for {label}, left uncommitted: {err}")
        return False

    rc, out, err = _git(
        repo, ["commit", "-m", commit_msg, "--", *rel_paths], remaining())
    if rc != 0:
        # Nothing to commit is benign (already committed by a peer).
        if "nothing to commit" in (out + err) or "no changes added" in (out + err):
            log_detail(f"git commit produced no commit ({label}): nothing to commit")
        else:
            log_warn(f"git commit failed for {label}, left uncommitted: {err or out}")
        return False
    log_ok(f"committed {label}")

    reason = dotprofile_push_blocked_reason(repo, remaining())
    if reason is not None:
        log_warn(f"push skipped, commit kept: {reason}")
        return True

    # The dotprofile is expected to carry uncommitted work-in-progress; a
    # pull --rebase fails deterministically on a dirty tree, so skip it rather
    # than error/hang on the expected-dirty condition. The single-flight lock
    # covers the same-machine race; cross-machine divergence is reconciled on
    # the next clean push (push below just no-ops with a logged 'remote ahead').
    if worktree_dirty(repo, remaining()):
        log_detail("dotprofile worktree dirty; skipping pull --rebase")
    else:
        # Pull --rebase handles the cross-machine race; lock handles same-machine.
        rc, _, err = _git(repo, ["pull", "--rebase"], remaining())
        if rc != 0:
            log_warn(f"git pull --rebase failed, push skipped, commit kept: {err}")
            return True

    rc, _, err = _git(repo, ["push"], remaining())
    if rc != 0:
        log_warn(f"git push failed (offline or remote ahead), commit kept: {err}")
        return True
    log_ok(f"pushed {label}")
    return True


def commit_pending_archives(repo: Path, deadline: float) -> int:
    """Commit archive files left uncommitted under sessions/ by an earlier
    failed git step (gap G3: a run that copied a transcript but could not
    commit it saw "already archived" next time and never retried). Commits
    only sessions/ paths. Returns the number of files committed."""
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        return 0
    rc, out, err = _git(
        repo, ["status", "--porcelain", "--untracked-files=all", "--", "sessions"],
        remaining)
    if rc != 0:
        log_warn(f"cannot list pending archives in dotprofile: {err}")
        return 0
    pending = [ln for ln in out.splitlines() if ln.strip()]
    if not pending:
        return 0
    log_info(f"{len(pending)} archived file(s) uncommitted in dotprofile; committing")
    if commit_and_push(
        repo, ["sessions"],
        f"Archive {len(pending)} pending session file(s) (catch-up)", deadline,
    ):
        return len(pending)
    return 0


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
        cwd = first_record_cwd(transcript)

    project = derive_project(transcript, cwd)
    full_id = transcript.stem  # filename without .jsonl == session id
    prefix = full_id[:ARCHIVE_PREFIX_LEN]
    date = transcript_date(transcript)

    dest_dir = user_repo / "sessions" / project
    dest_name = f"{date}_{prefix}.jsonl"
    dest_file = dest_dir / dest_name

    # Already archived and not grown since: nothing to do (fast path). A
    # transcript that grew after its first archive (a resumed or continued
    # session) is copied again, with its new subagents (gap G5).
    try:
        src_size = transcript.stat().st_size
        dest_size = dest_file.stat().st_size if dest_file.exists() else -1
    except OSError as e:
        log_warn(f"cannot stat transcript or archive for {transcript.name}: {e}")
        return False
    if dest_size >= src_size:
        log_detail(f"skipped: already archived {project}/{dest_name}")
        return False
    grown = dest_size >= 0

    try:
        dest_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(transcript), str(dest_file))
    except OSError as e:
        log_error(f"failed to copy transcript {transcript.name}: {e}")
        return False
    if grown:
        log_ok(f"re-archived grown transcript {project}/{dest_name} "
               f"({dest_size} -> {src_size} bytes)")
    else:
        log_ok(f"archived {project}/{dest_name}")

    rel_paths = [f"sessions/{project}/{dest_name}"]
    for sub_name in _archive_subagents(transcript, full_id, dest_dir, date, prefix):
        rel_paths.append(f"sessions/{project}/{sub_name}")

    # --- Commit + push (deadline-guarded) ---
    # A failed git step leaves the files uncommitted; catchup's
    # commit_pending_archives() commits them on a later session start.
    if do_git:
        if deadline is None:
            deadline = time.monotonic() + 10.0
        verb = "Update archived" if grown else "Archive"
        commit_msg = f"{verb} session {date}_{prefix} ({project})"
        commit_and_push(user_repo, rel_paths, commit_msg, deadline)

    return True


def _archive_subagents(
    transcript: Path, full_id: str, dest_dir: Path, date: str, prefix: str,
) -> list[str]:
    """Copy the session's subagent transcripts next to its archive. Returns
    the names written.

    Subagent transcripts live at <transcript-dir>/<session-id>/subagents/ or
    <transcript-dir>/subagents/ depending on the CC version. Each copy is
    named after its own file (<date>_<p8>_<subagent stem>.jsonl), so a
    subagent added later never shifts the names of earlier ones; the old
    positional names (<date>_<p8>_subagent-<n>.jsonl) did (gap G5). A copy
    that grew is replaced. A file already archived under a legacy positional
    name (byte-identical) is not copied again."""
    subagent_dirs = [
        transcript.parent / full_id / "subagents",
        transcript.parent / "subagents",
    ]
    legacy: list[Path] = []
    try:
        legacy = [
            p for p in dest_dir.glob(f"{date}_{prefix}_subagent-*.jsonl")
            if re.fullmatch(rf"{re.escape(date)}_{re.escape(prefix)}_subagent-\d+\.jsonl", p.name)
        ]
    except OSError as e:
        log_detail(f"cannot list legacy subagent archives in {dest_dir}: {e}")

    written: list[str] = []
    for sad in subagent_dirs:
        if not sad.is_dir():
            continue
        try:
            sub_files = sorted(sad.glob("*.jsonl"))
        except OSError as e:
            log_warn(f"cannot list subagent transcripts in {sad}: {e}")
            continue
        for sub in sub_files:
            sub_dest = dest_dir / f"{date}_{prefix}_{sub.stem}.jsonl"
            try:
                src_size = sub.stat().st_size
                if sub_dest.exists() and sub_dest.stat().st_size >= src_size:
                    continue
                if not sub_dest.exists() and any(
                    p.stat().st_size == src_size
                    and filecmp.cmp(str(p), str(sub), shallow=False)
                    for p in legacy
                ):
                    continue
                shutil.copy2(str(sub), str(sub_dest))
            except OSError as e:
                log_warn(f"failed to copy subagent {sub.name}: {e}")
                continue
            written.append(sub_dest.name)
            log_ok(f"archived subagent {sub_dest.name}")
    return written


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
    """Classification mirroring harvest-session.sh (extension + name).
    Harness bookkeeping (HARNESS_SCRATCH_FILES, any dotfile) is ephemeral."""
    lower = filename.lower()
    if filename in HARNESS_SCRATCH_FILES or filename.startswith("."):
        return True
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


def _scratch_tag(session_dir: Path) -> str:
    """The name part of a scratch dir (session-<tag>), used verbatim in
    harvested and routed file names. Never truncated."""
    name = session_dir.name
    return name[len("session-"):] if name.startswith("session-") else name


def _read_pointer(scratch_dir: Path) -> Optional[Path]:
    """The dir named by .scratch/.current-session, or None. Never raises."""
    current = scratch_dir / ".current-session"
    try:
        if not current.exists():
            return None
        p = current.read_text(encoding="utf-8").strip()
    except OSError as e:
        log_detail(f"cannot read {current}: {e}")
        return None
    return Path(p) if p and Path(p).is_dir() else None


def resolve_session_dir(scratch_dir: Path, session_id: Optional[str]) -> Optional[Path]:
    """Find a session's scratch dir from its Claude Code session id.

    1. .scratch/session-<full id>        (scratch-init.sh since 2026-10-31)
    2. .scratch/session-<id[:10]>        (legacy dirs created before that)
    3. only when there is no session id: the dir in .scratch/.current-session

    The pointer is never used for a known id: it names whichever session
    started last in this repo, which is how a 12-char delegate dir used to
    resolve to the live session's dir (gap G1)."""
    if session_id:
        for name in (session_id, session_id[:LEGACY_SCRATCH_PREFIX_LEN]):
            candidate = scratch_dir / f"session-{name}"
            if candidate.is_dir():
                return candidate
        return None
    return _read_pointer(scratch_dir)


def _file_sig(f: Path) -> Optional[dict[str, Any]]:
    try:
        st = f.stat()
    except OSError as e:
        log_detail(f"cannot stat {f}: {e}")
        return None
    return {"size": st.st_size, "mtime": st.st_mtime}


def _read_harvest_record(session_dir: Path) -> tuple[dict[str, Any], Optional[float]]:
    """Read the dir's harvest record. Returns (files, legacy_time):
    files maps a file name to its {size, mtime} when it was harvested;
    legacy_time is the mtime of a pre-2026-10-31 timestamp-only marker (every
    file not modified after it counts as harvested), else None."""
    marker = session_dir / HARVEST_MARKER
    try:
        if not marker.exists():
            return {}, None
        text = marker.read_text(encoding="utf-8")
        mtime = marker.stat().st_mtime
    except OSError as e:
        log_detail(f"cannot read harvest record {marker}: {e}")
        return {}, None
    try:
        data = json.loads(text)
    except ValueError:
        return {}, mtime  # legacy marker: one UTC timestamp line
    if isinstance(data, dict) and isinstance(data.get("files"), dict):
        return data["files"], data.get("legacyTime")
    return {}, mtime


def _already_harvested(
    f: Path, files: dict[str, Any], legacy_time: Optional[float],
) -> bool:
    sig = _file_sig(f)
    if sig is None:
        return True  # cannot stat: do not try to copy it
    rec = files.get(f.name)
    if isinstance(rec, dict) and rec.get("size") == sig["size"] \
            and rec.get("mtime") == sig["mtime"]:
        return True
    return rec is None and legacy_time is not None and sig["mtime"] <= legacy_time


def pending_scratch_files(session_dir: Path) -> list[Path]:
    """Top-level files of a session dir that are neither ephemeral nor
    already harvested (unchanged since their recorded harvest)."""
    files, legacy_time = _read_harvest_record(session_dir)
    try:
        candidates = sorted(p for p in session_dir.iterdir() if p.is_file())
    except OSError as e:
        log_warn(f"cannot list session dir {session_dir}: {e}")
        return []
    return [
        p for p in candidates
        if not _is_ephemeral(p.name) and not _already_harvested(p, files, legacy_time)
    ]


def harvest_scratch(
    cwd: str,
    session_id: Optional[str],
    *,
    project_root: Optional[Path] = None,
    session_dir: Optional[Path] = None,
) -> int:
    """Classify + route + manifest a session's scratch dir. Returns the number
    of artifacts harvested. Never deletes scratch dirs (30-file-loss guard).
    Leaves DB session-end marking to harness-db-sessionend.sh.

    session_dir: the dir to harvest, used as is (catch-up passes each orphan
    dir it found). Without it the dir is resolved from session_id
    (resolve_session_dir). Only files that are new or changed since the dir's
    last harvest are copied (gap G2), so a resumed or re-ended session is not
    harvested twice."""
    if project_root is None:
        root = git_root(Path(cwd)) if cwd and Path(cwd).is_dir() else None
        project_root = root if root is not None else Path(cwd)

    scratch_dir = project_root / ".scratch"
    if session_dir is None:
        session_dir = resolve_session_dir(scratch_dir, session_id)
    if session_dir is None or not session_dir.is_dir():
        log_detail(f"skipped harvest: no session dir for {session_id or '(no session id)'}")
        return 0

    tag = _scratch_tag(session_dir)
    harvesting_dir = project_root / "harvesting"
    handoffs_dir = project_root / ".aitools" / "channel" / "handoffs"
    manifest_path = harvesting_dir / "harvest-manifest.json"
    today = today_utc()
    harvested = 0
    deleted = 0
    unchanged = 0

    record_files, legacy_time = _read_harvest_record(session_dir)
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
        if _already_harvested(f, record_files, legacy_time):
            unchanged += 1
            continue
        sig = _file_sig(f)

        # Handoff routing.
        if filename.startswith("handoff"):
            try:
                handoffs_dir.mkdir(parents=True, exist_ok=True)
                dest = handoffs_dir / f"{today}_session-{tag}_{filename}"
                shutil.copy2(str(f), str(dest))
                harvested += 1
                record_files[filename] = sig
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

        session_tag = f"session-{tag}_" if tag else ""
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
        session_ref = f"{project_name}/{today}_{tag}" if cwd else ""
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
        record_files[filename] = sig
        log_ok(f"harvested {dest_name}")

    if manifest is not None:
        try:
            _atomic_write_json(manifest_path, manifest)
        except OSError as e:
            log_warn(f"manifest write failed: {e}")

    # Clear the session pointer only when it names THIS dir (gap G6): the
    # pointer belongs to whichever session started last in this repo, and
    # catch-up harvests other sessions' dirs. The session dir stays intact.
    pointer = _read_pointer(scratch_dir)
    try:
        if pointer is not None and pointer.resolve() == session_dir.resolve():
            (scratch_dir / ".current-session").unlink()
    except OSError as e:
        log_detail(f"could not clear .current-session: {e}")

    # Harvest record: every file harvested from this dir, with the size and
    # mtime it had, so a later harvest (catch-up, a resumed session's
    # SessionEnd) copies only new or changed files. Written even when nothing
    # was harvested, so an empty or ephemeral-only dir settles.
    record: dict[str, Any] = {
        "version": 1,
        "lastHarvest": utcnow(),
        "files": record_files,
    }
    if legacy_time is not None:
        record["legacyTime"] = legacy_time
    try:
        _atomic_write_json(session_dir / HARVEST_MARKER, record)
    except OSError as e:
        log_warn(f"could not write harvest record in {session_dir}: {e}")

    # Manifest audit/prune is hoisted to catchup() (the SessionStart owner of
    # audit, per reference/artifact-harvesting.md) so it runs at most once
    # per session, not once per harvested dir.
    if harvested or deleted or unchanged:
        log_info(
            f"harvest {tag or 'unknown'}: {harvested} harvested, "
            f"{unchanged} unchanged since last harvest, "
            f"{deleted} ephemeral skipped"
        )
    return harvested


def _audit_manifest(
    manifest_path: Path,
    harvesting_dir: Path,
    project_root: Path,
    deadline: Optional[float] = None,
) -> None:
    """Prune stale artifacts: mark 'pruned' (never delete the file) when past
    pruneAfter with zero git refs, else promote to 'candidate'.

    Perf: a SINGLE `git log --name-only` pass builds the set of basenames ever
    committed under harvesting/, replacing the previous one-subprocess-per-
    artifact scan (was O(past-due artifacts) git invocations; now O(1)).
    Deadline-bounded -- skips cleanly when the catchup budget is spent."""
    if not manifest_path.exists():
        return
    if deadline is not None and (deadline - time.monotonic()) <= 0:
        log_detail("audit skipped: deadline reached")
        return
    manifest = _load_manifest(manifest_path)
    today = datetime.now(timezone.utc).date()

    # Collect past-due active artifacts first; only pay for git if any exist.
    due: list[tuple[str, dict[str, Any]]] = []
    for name, entry in manifest.get("artifacts", {}).items():
        if entry.get("status") in ("promoted", "pruned"):
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
        due.append((name, entry))

    if not due:
        return

    # ONE git pass: basenames of every path ever committed under harvesting/.
    # On any failure we leave `referenced` empty -> due artifacts mark 'pruned'
    # (treat-as-unreferenced), matching the prior per-artifact behavior.
    referenced: set[str] = set()
    try:
        rel = harvesting_dir.relative_to(project_root).as_posix()
    except ValueError:
        rel = "harvesting"
    timeout = 8.0
    if deadline is not None:
        timeout = max(1.0, min(timeout, deadline - time.monotonic()))
    try:
        out = subprocess.run(
            ["git", "-C", str(project_root), "log", "--all", "--name-only",
             "--pretty=format:", "--", rel],
            capture_output=True, text=True, timeout=timeout,
        )
        if out.returncode == 0:
            for ln in out.stdout.splitlines():
                ln = ln.strip()
                if ln:
                    referenced.add(os.path.basename(ln))
    except (OSError, subprocess.SubprocessError) as e:
        log_detail(f"audit git log failed, treating all as unreferenced: {e}")

    changed = False
    for name, entry in due:
        entry["status"] = "candidate" if name in referenced else "pruned"
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
    count = record_count_capped(transcript, TRANSIENT_MIN_RECORDS)
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
        if user_repo is not None:
            _report_stale_index_lock(user_repo)
        recovered += _catchup_archive(user_repo, session_id, deadline, lock)
        lock.heartbeat()
        # Commit archive files an earlier failed git step left uncommitted
        # (gap G3); the push-if-ahead step below pushes them.
        if user_repo is not None:
            recovered += commit_pending_archives(user_repo, deadline)
            lock.heartbeat()
        # Harvest orphaned scratch dirs in the current repo (deadline-bounded).
        harvested, project_root = _catchup_harvest(cwd, session_id, deadline)
        recovered += harvested
        lock.heartbeat()
        # Audit/prune the manifest ONCE here -- SessionStart owns audit
        # (reference/artifact-harvesting.md) -- not once per harvested dir.
        if project_root is not None and project_root.is_dir():
            harvesting_dir = project_root / "harvesting"
            manifest_path = harvesting_dir / "harvest-manifest.json"
            _audit_manifest(manifest_path, harvesting_dir, project_root, deadline)
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


def _report_stale_index_lock(user_repo: Path) -> None:
    """A dotprofile .git/index.lock older than INDEX_LOCK_STALE_SECONDS makes
    every archive commit fail (gap G3: one sat there for two days). Report it
    in the log and on stdout, which SessionStart adds to Claude's context, so
    a person can remove it. Never removes it: a live git may own it."""
    age = index_lock_age(user_repo)
    if age is None or age < INDEX_LOCK_STALE_SECONDS:
        return
    lock = user_repo / ".git" / "index.lock"
    hours = age / 3600
    msg = (f"dotprofile git index is locked: {lock} is {hours:.1f}h old; "
           "session archives cannot be committed until it is removed "
           "(check that no git process is running first)")
    log_warn(msg)
    print(f"Harvest: {msg}", flush=True)


def _newest_mtime(d: Path) -> float:
    """Newest mtime of a dir and its top-level entries (0.0 on error)."""
    try:
        newest = d.stat().st_mtime
        for p in d.iterdir():
            try:
                newest = max(newest, p.stat().st_mtime)
            except OSError:
                continue
        return newest
    except OSError as e:
        log_detail(f"cannot stat {d}: {e}")
        return 0.0


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


def _catchup_harvest(
    cwd: str, session_id: Optional[str], deadline: float,
) -> tuple[int, Optional[Path]]:
    """Harvest .scratch/session-* dirs in the current repo that hold files no
    harvest has copied yet (SessionEnd never ran, or files were added after
    it). Each dir is passed to harvest_scratch() by path, its name used
    verbatim: a dir name is never cut to a prefix (gap G1). Skips the current
    session's own dir (session-<full id>, or the legacy session-<id[:10]>),
    dirs modified in the last LIVE_MTIME_SECONDS (a session or delegate still
    working), and dirs with nothing pending (idempotency: the harvest record
    in .harvested). Deadline-bounded. Returns (recovered, project_root)."""
    root = git_root(Path(cwd)) if cwd and Path(cwd).is_dir() else None
    project_root = root if root is not None else Path(cwd) if cwd else None
    if project_root is None or not project_root.is_dir():
        return 0, project_root
    scratch_dir = project_root / ".scratch"
    if not scratch_dir.is_dir():
        return 0, project_root

    own_names: set[str] = set()
    if session_id:
        own_names = {session_id, session_id[:LEGACY_SCRATCH_PREFIX_LEN]}
    recovered = 0
    now = time.time()
    try:
        session_dirs = sorted(
            p for p in scratch_dir.iterdir()
            if p.is_dir() and p.name.startswith("session-")
        )
    except OSError as e:
        log_warn(f"cannot list {scratch_dir}: {e}")
        return 0, project_root

    for sd in session_dirs:
        if deadline - time.monotonic() <= 0:
            log_warn("catchup harvest: deadline reached, stopping sweep")
            break
        if _scratch_tag(sd) in own_names:
            continue  # never harvest our own live session
        if not pending_scratch_files(sd):
            continue  # nothing new since its last harvest (idempotency)
        if (now - _newest_mtime(sd)) < LIVE_MTIME_SECONDS:
            log_detail(f"skipped harvest: possibly-live scratch dir {sd.name}")
            continue
        recovered += harvest_scratch(
            str(project_root), None, project_root=project_root, session_dir=sd
        )
    return recovered, project_root


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
