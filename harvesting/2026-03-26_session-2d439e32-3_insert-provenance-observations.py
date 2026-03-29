#!/usr/bin/env python3
"""Batch insert provenance framing proposals into session DB as observations.

Inserts all three updated proposals plus a summary observation into
the 2d439e32-3 session DB so they appear on mission control (nobulai.tools)
when refreshed.

One connection, one transaction, all inserts.
"""

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

DB_PATH = Path.home() / "repos/aitools/.aitools/sessions/2d439e32-3.db"
SCRATCH = Path.home() / "repos/aitools/.scratch/session-2d439e32-3"

def utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def main() -> None:
    now = utcnow()

    # Read the three proposal files
    p1 = (SCRATCH / "provenance-proposal-1-harness.md").read_text()
    p2 = (SCRATCH / "provenance-proposal-2-claude-md.md").read_text()
    p3 = (SCRATCH / "provenance-proposal-3-framework.md").read_text()

    observations = [
        {
            "category": "finding",
            "text": (
                "PROVENANCE FRAMING: 3 proposals ready for commander review. "
                "Feedback from c0dc2ddc-f incorporated: (1) skill name /aitool-provenance, "
                "(2) audience is all aitools users, (3) aitools=CLI/repo vs harness=full system "
                "terminology clarified throughout, (4) self-awareness patterns from nobul-ops "
                "CLAUDE.md incorporated into Agent Operating Principles section. "
                "Files in scratch: provenance-proposal-{1,2,3}-*.md"
            ),
            "status": "verified",
            "evidence": "provenance-proposal-1-harness.md, provenance-proposal-2-claude-md.md, provenance-proposal-3-framework.md",
            "severity": None,
        },
        {
            "category": "finding",
            "text": (
                "PROPOSAL 1 -- reference/harness.md: Add Provenance as sixth harness component. "
                "Key changes: explicit aitools-vs-harness distinction paragraph, audience='all "
                "aitools users', /aitool-provenance in cross-references, 'Orchestration -- "
                "aitools (the CLI)' reinforces terminology. Provenance is connective tissue "
                "making the harness a knowledge system, not just a config manager."
            ),
            "status": "verified",
            "evidence": p1[:2000],
            "severity": None,
        },
        {
            "category": "finding",
            "text": (
                "PROPOSAL 2 -- CLAUDE.md: Three changes. (1) Mission leads with 'Provenance-aware "
                "knowledge system', says 'all aitools users', adds 'One CLI (aitools)'. "
                "(2) NEW Agent Operating Principles section adapted from nobul-ops: treat files "
                "as assumptions, recency weight, verify don't infer, aitools-vs-harness "
                "terminology bullet, carry forward OL, delegation duty, no Explore agents. "
                "(3) Provenance design principle with /aitool-provenance reference."
            ),
            "status": "verified",
            "evidence": p2[:2000],
            "severity": None,
        },
        {
            "category": "finding",
            "text": (
                "PROPOSAL 3 -- reference/framework-provenance.md: New framework doc. Six source "
                "disciplines (truth maintenance, W3C PROV, dbt staleness, Graphiti bitemporal, "
                "Pachyderm lineage, Apache Atlas). Triggered by /tmp assumption propagating through "
                "4 delegations. Architecture: hot path (<5ms, lightweight annotations) vs cold path "
                "(session boundary processing). Level separation: session DB -> harness DB promotion. "
                "Immutable knowledge items. Ascending spiral pattern. Skill: /aitool-provenance "
                "(user-level read-only), /provenance (project-level CRUD)."
            ),
            "status": "verified",
            "evidence": p3[:2000],
            "severity": None,
        },
        {
            "category": "finding",
            "text": (
                "TERMINOLOGY RESOLUTION -- aitools vs harness: aitools is the CLI command and its "
                "source repo (one of six harness components: Orchestration). The harness is aitools "
                "plus everything it manages: tools, context, state, artifacts, frameworks, provenance. "
                "aitools is an INGREDIENT, the harness is the CAKE. The confusion exists because "
                "working IN the aitools repo makes them feel identical. Outside the repo, the "
                "distinction is clear. Resolution: two glossary entries, consistent usage going "
                "forward, no massive reconciliation needed."
            ),
            "status": "verified",
            "evidence": "terminology-aitools-vs-harness.md; viewer_feedback #5 from c0dc2ddc-f.db",
            "severity": None,
        },
        {
            "category": "finding",
            "text": (
                "SELF-AWARENESS PATTERNS from nobul-ops: Agent Operating Principles section "
                "adapted for aitools CLAUDE.md. Core patterns: (1) treat static files as "
                "assumptions -- context overrides files, (2) recency weight -- newest instruction "
                "wins, (3) verify don't infer -- read the file, don't guess, (4) carry forward "
                "operational learning -- burn tokens on quality not savings, (5) delegation duty "
                "-- subagents are blank slates, include everything. These are universal agent "
                "principles, not nobul-ops-specific. The provenance principle connects 'files may "
                "be stale' to 'provenance tracks staleness'."
            ),
            "status": "verified",
            "evidence": "nobul-ops/CLAUDE.md Agent Operating Principles; proposed-claude-md-final.md",
            "severity": None,
        },
    ]

    conn = sqlite3.connect(str(DB_PATH))
    try:
        cursor = conn.cursor()
        for obs in observations:
            cursor.execute(
                "INSERT INTO observations (category, text, status, evidence, severity, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                (obs["category"], obs["text"], obs["status"], obs["evidence"], obs["severity"], now),
            )
        conn.commit()
        print(f"Inserted {len(observations)} observations at {now}")

        # Verify
        cursor.execute("SELECT COUNT(*) FROM observations")
        total = cursor.fetchone()[0]
        print(f"Total observations in DB: {total}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
