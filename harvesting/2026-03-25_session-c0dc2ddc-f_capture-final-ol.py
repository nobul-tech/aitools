#!/usr/bin/env python3
"""Capture final operational learning from context failure and recovery."""
import sqlite3
from datetime import datetime, timezone

def utcnow():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def main():
    conn = sqlite3.connect("file:.aitools/sessions/c0dc2ddc-f.db?mode=rwc", uri=True, timeout=5.0)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    now = utcnow()

    entries = [
        ("finding", "[I-14] Context failure at 95% — session hit cognitive failure mode. Recovery agent launched from future session to diagnose and fix.", "verified", "high"),
        ("finding", "[I-15] harness-db.py stderr consumed by Bash tool — 33 print(file=sys.stderr) calls visible to Claude Code, eating context. FIXED by recovery agent.", "verified", "critical"),
        ("finding", "[I-16] harness-db.py ol list had no filter — dumped all 186 observations instead of filtered subset. FIXED.", "verified", "high"),
        ("finding", "[I-17] harness-db.py no output limits — unbounded queries adding hundreds of lines to context per call. FIXED.", "verified", "high"),
        ("fact", "[OL] Any script callable from agent context must be context-aware: detail to log files, compact to stdout, nothing to stderr", "verified", None),
        ("fact", "[OL] Context consumption is itself a provenance-trackable incident — the cause chain (stderr + no filter + no limits) is traceable through the codebase", "verified", None),
        ("fact", "[OL] Recovery from context failure requires launching from a NEW session with access to the old session's DB — the /aitool-continue skill was created for this", "verified", None),
        ("fact", "[OL] The commander said 'hi its me from the future' — sessions are not isolated, they connect through the commander and through shared state", "verified", None),
        ("fact", "[OL] Mission control deployed to nobulai.tools — first external deployment of aitools infrastructure", "verified", None),
        ("fact", "[OL] CI ALL GREEN for first time — 13 prior runs failed. v0.66.1 and v0.67.0 shipped.", "verified", None),
        ("fact", "[OL] Cloudflare BOOTSTRAPPED credits applied for — $5K-$250K depending on tier", "verified", None),
        ("fact", "[OL] Datadog question still open — US5 vs US3 region, API key storage pattern needed", "verified", None),
    ]

    for cat, text, status, severity in entries:
        conn.execute(
            "INSERT OR IGNORE INTO observations (category, text, status, severity, created_at) VALUES (?, ?, ?, ?, ?)",
            (cat, text, status, severity, now)
        )

    conn.execute("UPDATE session SET current_state = ?, updated_at = ? WHERE session_id LIKE 'c0dc2ddc%'",
                 ("Session at 95% context. Recovery agent from future fixed harness-db.py context consumption. CI green. Mission control on nobulai.tools. Cloudflare applied. 50+ work products in scratch.", now))
    conn.commit()
    total = conn.execute("SELECT COUNT(*) FROM observations").fetchone()[0]
    print(f"Final OL captured: {total} total observations in DB")
    conn.close()

if __name__ == "__main__":
    main()
