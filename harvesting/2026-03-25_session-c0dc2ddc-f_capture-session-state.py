#!/usr/bin/env python3
"""Capture in-context session state to the session SQLite DB.

This session produced OL, incidents, decisions, observations, and proposals
that exist only in conversation context. This script writes them to the
session DB so they persist beyond the context window.
"""

import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

def utcnow():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def open_db(path):
    conn = sqlite3.connect(f"file:{path}?mode=rwc", uri=True, timeout=5.0)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.row_factory = sqlite3.Row
    return conn

def main():
    db_path = Path(".aitools/sessions/c0dc2ddc-f.db")
    if not db_path.exists():
        print(f"Error: {db_path} not found", file=sys.stderr)
        sys.exit(1)

    conn = open_db(db_path)
    now = utcnow()

    # Update session schwerpunkt
    conn.execute(
        "UPDATE session SET schwerpunkt = ?, current_state = ?, updated_at = ? WHERE session_id LIKE 'c0dc2ddc%'",
        ("Provenance-aware knowledge system design + self-learning infrastructure",
         "15hr session. Loaded full codebase. Discovered /tmp bug. Identified aitools as provenance-aware knowledge system. Built session command center, file viewer, feedback loop. Launched 20+ delegations. Applied for Cloudflare credits. Fixed CI pipeline. Fixed harness DB registration.",
         now)
    )

    # Incidents
    incidents = [
        ("I-1", "Agent conserved tokens when told not to (3 corrections before stopping)"),
        ("I-2", "Agent delegated to Explore agents which can't write"),
        ("I-3", "Agent assumed running estimate was future capability when SessionStart hooks exist"),
        ("I-4", "Agent anchored on SQLite as answer to everything — consolidation matters more than format"),
        ("I-5", "Agent assumed 1M context couldn't hold all OL — it can if consolidated"),
        ("I-6", "Agent produced consolidated OL then didn't carry it forward to delegate"),
        ("I-7", "Agent framed OL verification as commander approval when commander is one source among many"),
        ("I-8", "Agent framed all assumptions as needing binary verification when some are ongoing learning areas"),
        ("I-9", "OL index delegate chose markdown over SQLite for an INDEX — didn't carry forward architectural direction"),
        ("I-10", "CI/CD delegate denied Bash access — permission barrier not anticipated"),
        ("I-11", "CLAUDE_EFFORT_LEVEL unbound variable — 20 days, 17 commits undetected. FIXED."),
        ("I-12", "Propagation investigation delegate proposed /tmp fallback despite no-fallback directive"),
        ("I-13", "Harness DB never created — hooks deployed but not registered in settings.json. FIXED."),
    ]
    for iid, text in incidents:
        conn.execute(
            "INSERT OR IGNORE INTO observations (category, text, status, severity, created_at) VALUES (?, ?, ?, ?, ?)",
            ("finding", f"[{iid}] {text}", "verified", "medium", now)
        )

    # Key decisions
    decisions = [
        ("D-TMP-DISABLE", "Three Stop hooks disabled — /tmp state tracking unreliable"),
        ("D-SQLITE-RUNTIME", "SQLite is the runtime layer. JSON is git archive only."),
        ("D-SELF-LEARNING", "aitools long-term objective is self-learning and self-improvement"),
        ("D-USER-LEVERAGE", "User's long-term objective is aitools as leverage across all projects"),
        ("D-PROVENANCE", "aitools is a provenance-aware knowledge system"),
        ("D-RELAY-PATTERN", "Portal uses relay pattern (like UniFi) — no DB sync, tunnel to local machine"),
        ("D-NO-MVP", "No versioning on dashboard. No MVP. Just mission control, continuously evolving."),
        ("D-PROMPT-TO-SCRATCH", "Delegation prompts written to scratch files, audited, launched with pointer"),
        ("D-OL-DISTRIBUTED", "OL is not a single document. It lives in many places viewed through one dashboard"),
        ("D-CONTINUOUS", "Sessions work until context runs out. No premature handoff."),
        ("D-CLOUDFLARE", "Applied for Cloudflare BOOTSTRAPPED credits. Portal on Cloudflare."),
        ("D-DOMAIN", "Register nobulai.tools and nobul.tools"),
        ("D-COMMAND-CHANNEL", "Command channel via Stop hook polling commander_directives table in SQLite"),
        ("D-PROCESS-REG", "Process registration as delegation duty element #7"),
        ("D-ZERO-HOOKS-PROV", "Zero hooks for provenance during session. Annotate at write time. Process at boundary."),
        ("D-CI-FIX", "Fixed CLAUDE_EFFORT_LEVEL unbound var + rebuilt deploy/. Pushed."),
    ]
    for did, desc in decisions:
        conn.execute(
            "INSERT OR IGNORE INTO decisions (decision_id, title, status, decided_at) VALUES (?, ?, ?, ?)",
            (did, desc, "decided", now)
        )

    # Key operational learning as observations
    ol_entries = [
        "Never use /tmp for session-ephemeral harness state",
        "Never use Explore agents when delegating",
        "JSON is too cumbersome as runtime format — SQLite runtime, JSON archive",
        "Long-term objective of aitools is self-learning",
        "User values time above all else",
        "Recency-biased scanning propagates wrong assumptions as effectively as right ones",
        "Incorrect assumptions are incidents — name them, move on",
        "Commander directives based on experience are authoritative",
        "Never rewrite a skill inline — point at the skill",
        "Agent output is data, not directive",
        "Write intent documents before launching delegates",
        "Launch self-corrective investigation agents when delegation quality drops",
        "Every session is a testing ground for the harness itself",
        "Parallelization with discrete scopes is highest leverage",
        "SaaS contingency lifecycle is cross-project pattern",
        "Data flows through layers not into buckets",
        "Delegates consistently fail to carry forward architectural direction even with OL",
        "The agent's existing behavior IS the instrumentation — no separate observation hooks needed",
        "OL is not a single document — it lives in many places viewed through one dashboard",
        "There is no 'next session' — the harness learns continuously",
        "aitools is a provenance-aware knowledge system",
        "Every work product carries the understanding of the moment it was produced — superseded understanding propagates through work product",
    ]
    for ol in ol_entries:
        conn.execute(
            "INSERT OR IGNORE INTO observations (category, text, status, created_at) VALUES (?, ?, ?, ?)",
            ("fact", f"[OL] {ol}", "verified", now)
        )

    conn.execute("UPDATE session SET updated_at = ? WHERE session_id LIKE 'c0dc2ddc%'", (now,))
    conn.commit()

    # Count what was written
    total = conn.execute("SELECT COUNT(*) FROM observations").fetchone()[0]
    decisions_count = conn.execute("SELECT COUNT(*) FROM decisions").fetchone()[0]
    print(f"Session DB updated: {total} observations, {decisions_count} decisions")
    conn.close()

if __name__ == "__main__":
    main()
