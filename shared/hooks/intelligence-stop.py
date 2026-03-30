#!/usr/bin/env python3
"""intelligence-stop.py -- Claude Code Stop hook (intelligence carry-forward)

Purpose: Fire at every agentic turn to provide intelligence carry-forward.
  Three functions:
  1. Parse JSONL transcript for context utilization and turn metrics.
  2. Query session SQLite DB for new OL, decisions, observations.
  3. Inject summary via stderr when new intelligence found or context
     threshold crossed.

Scope: Stop hook only. Reads session DB (read-only) and transcript (read-only).
  Writes only: marker file (.intelligence-last-check) and events.jsonl.
Audience: Claude Code Stop hook system -- fires after every assistant response.

Hook contract:
  - Receives JSON on stdin: session_id, transcript_path, cwd
  - Exit 0 = allow (intel injected via stdout JSON additionalContext if present)
  - Exit 2 = block (context warning via stderr, forces agent to address fear)
  - Must complete in <50ms (SQLite WAL read + JSONL tail)
  - Must never crash or hang (would break Claude Code)

Platform: macOS + Linux + Windows Git Bash
Dependencies: Python 3.8+ stdlib only (sqlite3, json, sys, os, pathlib)

Provenance: Session f5fa32f9-c (2026-03-29). Fear & Trust score architecture.
  The insight: intelligence written to session DB via harness-db.py is NOT
  in the agent's conversation context. This hook bridges the gap by reading
  from DB and injecting via stderr at every agentic turn.
"""

from __future__ import annotations

import json
import os
import sqlite3
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MODEL_CONTEXT_SIZES = {
    "claude-opus-4-6": 1_000_000,
    "claude-sonnet-4-5": 200_000,
    "claude-haiku-4-5": 200_000,
}
DEFAULT_CONTEXT_SIZE = 200_000

WARN_THRESHOLD = 70
CRITICAL_THRESHOLD = 90

JSONL_TAIL_BYTES = 64 * 1024


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# JSONL parsing (function 1: context + turn metrics)
# ---------------------------------------------------------------------------

def parse_transcript_tail(transcript_path: str) -> dict:
    """Parse the last assistant entry from a JSONL transcript.

    Returns dict with context_used, output_tokens, model, context_pct,
    context_size, agentic_turns. Empty dict on any error.
    """
    result: dict = {}
    try:
        path = Path(transcript_path)
        if not path.exists():
            return result

        file_size = path.stat().st_size
        if file_size == 0:
            return result

        read_size = min(file_size, JSONL_TAIL_BYTES)
        with open(path, "rb") as f:
            f.seek(max(0, file_size - read_size))
            tail_bytes = f.read()

        tail_text = tail_bytes.decode("utf-8", errors="replace")
        lines = tail_text.strip().split("\n")

        if file_size > read_size:
            lines = lines[1:]

        last_usage: dict = {}
        model = ""
        agentic_turns = 0

        for line in reversed(lines):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue

            entry_type = obj.get("type", "")

            if entry_type == "user":
                msg = obj.get("message", {})
                content = msg.get("content", "")
                if isinstance(content, str) and not content.startswith("<task-notification>"):
                    break
                continue

            if entry_type == "assistant" and not last_usage:
                agentic_turns += 1
                msg = obj.get("message", {})
                usage = msg.get("usage", {})
                if usage and "input_tokens" in usage:
                    last_usage = usage
                    model = msg.get("model", "")
            elif entry_type == "assistant":
                agentic_turns += 1

        if not last_usage:
            return result

        input_tokens = last_usage.get("input_tokens", 0)
        cache_creation = last_usage.get("cache_creation_input_tokens", 0)
        cache_read = last_usage.get("cache_read_input_tokens", 0)
        output_tokens = last_usage.get("output_tokens", 0)

        context_used = input_tokens + cache_creation + cache_read

        context_size = DEFAULT_CONTEXT_SIZE
        for prefix, size in MODEL_CONTEXT_SIZES.items():
            if model.startswith(prefix):
                context_size = size
                break

        context_pct = (context_used / context_size * 100) if context_size > 0 else 0

        result = {
            "context_used": context_used,
            "output_tokens": output_tokens,
            "model": model,
            "context_pct": round(context_pct, 1),
            "context_size": context_size,
            "agentic_turns": agentic_turns,
        }

    except Exception:
        pass

    return result


# ---------------------------------------------------------------------------
# Session DB queries (function 2: recent intelligence)
# ---------------------------------------------------------------------------

def query_new_intelligence(db_path: str, last_check_ts: str) -> list[dict]:
    """Query session DB for intelligence added since last_check_ts."""
    items: list[dict] = []
    try:
        if not os.path.exists(db_path):
            return items

        conn = sqlite3.connect(
            f"file:{db_path}?mode=ro",
            uri=True,
            timeout=2.0,
        )
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA busy_timeout=2000")
        conn.row_factory = sqlite3.Row

        # Observations (OL, assumptions, findings, corrections)
        try:
            rows = conn.execute(
                "SELECT observation_id, category, text "
                "FROM observations WHERE created_at > ? "
                "ORDER BY created_at",
                (last_check_ts,),
            ).fetchall()
            for r in rows:
                items.append({
                    "category": r["category"],
                    "id": f"obs-{r['observation_id']}",
                    "content": r["text"],
                })
        except Exception:
            pass

        # Decisions
        try:
            rows = conn.execute(
                "SELECT decision_id, title "
                "FROM decisions WHERE decided_at > ? "
                "ORDER BY decided_at",
                (last_check_ts,),
            ).fetchall()
            for r in rows:
                items.append({
                    "category": "decision",
                    "id": r["decision_id"],
                    "content": r["title"],
                })
        except Exception:
            pass

        # Deviations
        try:
            rows = conn.execute(
                "SELECT deviation_id, description "
                "FROM deviations WHERE created_at > ? "
                "ORDER BY created_at",
                (last_check_ts,),
            ).fetchall()
            for r in rows:
                items.append({
                    "category": "deviation",
                    "id": f"dev-{r['deviation_id']}",
                    "content": r["description"],
                })
        except Exception:
            pass

        conn.close()

    except Exception:
        pass

    return items


# ---------------------------------------------------------------------------
# Marker file for state tracking
# ---------------------------------------------------------------------------

def read_marker(marker_path: str) -> str:
    try:
        if os.path.exists(marker_path):
            with open(marker_path, "r") as f:
                ts = f.read().strip()
                if ts:
                    return ts
    except Exception:
        pass
    return "1970-01-01T00:00:00Z"


def write_marker(marker_path: str, ts: str) -> None:
    try:
        with open(marker_path, "w") as f:
            f.write(ts)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Event emission
# ---------------------------------------------------------------------------

def emit_event(events_path: str, metrics: dict, intel_count: int) -> None:
    try:
        event = {
            "t": utcnow_iso(),
            "type": "intelligence_stop",
            "src": "intelligence-stop",
            "d": {
                "context_pct": metrics.get("context_pct", 0),
                "context_used": metrics.get("context_used", 0),
                "agentic_turns": metrics.get("agentic_turns", 0),
                "intel_count": intel_count,
            },
        }
        parent = os.path.dirname(events_path)
        if parent and not os.path.isdir(parent):
            return
        with open(events_path, "a") as f:
            f.write(json.dumps(event, separators=(",", ":")) + "\n")
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Stderr formatting (function 3: injection)
# ---------------------------------------------------------------------------

def format_intel_block(items: list[dict]) -> str:
    if not items:
        return ""

    by_cat: dict[str, list[dict]] = {}
    for item in items:
        cat = item["category"]
        if cat not in by_cat:
            by_cat[cat] = []
        by_cat[cat].append(item)

    parts: list[str] = []
    for cat, cat_items in by_cat.items():
        parts.append(f"{len(cat_items)} {cat}")
    header = ", ".join(parts)

    lines = [f"[INTEL] {header} since last check:"]
    for item in items:
        lines.append(f"  {item['id']}: {item['content']}")

    return "\n".join(lines)


def format_context_warning(metrics: dict) -> str:
    # INERT: Context warnings disabled. The 70%/90% blocking loop
    # accelerated agent death — exit 2 every turn forced responses
    # that burned more context. Bug discovered session f5fa32f9-c
    # (2026-03-29). Preserving intelligence injection; context
    # warnings need a non-blocking design before re-enabling.
    return ""


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    try:
        raw_input = sys.stdin.read()
        if not raw_input.strip():
            return 0

        try:
            hook_input = json.loads(raw_input)
        except (json.JSONDecodeError, ValueError):
            return 0

        session_id = hook_input.get("session_id", "")
        transcript_path = hook_input.get("transcript_path", "")
        cwd = hook_input.get("cwd", "")

        if not session_id:
            return 0

        # --- Discover project root ---
        project_root = cwd
        # Check for .aitools dir to find project root
        test_path = cwd
        for _ in range(5):
            if os.path.isdir(os.path.join(test_path, ".aitools")):
                project_root = test_path
                break
            parent = os.path.dirname(test_path)
            if parent == test_path:
                break
            test_path = parent

        if not project_root:
            return 0

        # --- Discover session paths ---
        session_prefix = session_id[:10] if len(session_id) >= 10 else session_id
        session_db = os.path.join(project_root, ".aitools", "sessions", f"{session_prefix}.db")

        session_dir = ""
        current_session_file = os.path.join(project_root, ".scratch", ".current-session")
        try:
            if os.path.exists(current_session_file):
                with open(current_session_file, "r") as f:
                    session_dir = f.read().strip()
        except Exception:
            pass

        if not session_dir:
            session_dir = os.path.join(project_root, ".scratch", f"session-{session_prefix}")

        marker_path = os.path.join(session_dir, ".intelligence-last-check")
        events_path = os.path.join(session_dir, "events.jsonl")

        # --- Function 1: Parse transcript for context metrics ---
        metrics: dict = {}
        if transcript_path:
            metrics = parse_transcript_tail(transcript_path)

        # --- Function 2: Query session DB for new intelligence ---
        last_check_ts = read_marker(marker_path)
        now_ts = utcnow_iso()
        intel_items: list[dict] = []

        if os.path.exists(session_db):
            intel_items = query_new_intelligence(session_db, last_check_ts)

        write_marker(marker_path, now_ts)

        # --- Emit telemetry event ---
        if metrics or intel_items:
            emit_event(events_path, metrics, len(intel_items))

        # --- Function 3: Build injection output ---
        # Intelligence: inject via stdout JSON (informational, exit 0)
        # Context warnings: inject via stderr (blocking, exit 2)
        # Both: stdout JSON for intel + stderr for warning, exit 2

        intel_block = ""
        if intel_items:
            intel_block = format_intel_block(intel_items)

        context_warning = ""
        if metrics:
            context_warning = format_context_warning(metrics)

        if intel_block and context_warning:
            print(intel_block, file=sys.stderr)
            print(context_warning, file=sys.stderr)
            return 2

        if context_warning:
            print(context_warning, file=sys.stderr)
            return 2

        if intel_block:
            print(intel_block, file=sys.stderr)
            return 2

        return 0

    except Exception:
        return 0


if __name__ == "__main__":
    sys.exit(main())
