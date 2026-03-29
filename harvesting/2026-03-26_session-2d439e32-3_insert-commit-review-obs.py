#!/usr/bin/env python3
"""Insert observations for commit 40951fc CLAUDE.md/harness/provenance changes into session DB."""

import sqlite3
import datetime

DB_PATH = "/Users/pepe/repos/aitools/.aitools/sessions/2d439e32-3.db"
NOW = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

observations = [
    {
        "category": "finding",
        "text": "Commit 40951fc: CLAUDE.md mission statement updated -- added 'Provenance-aware knowledge system' framing. New design principle added: 'Provenance-aware knowledge' covering dependency tracking, invalidation propagation, nogood sets, and staleness surfacing. Links to reference/framework-provenance.md.",
        "status": "pending-review",
        "evidence": """DIFF (CLAUDE.md):
- Mission: 'Cross-platform tool lifecycle management...' -> 'Provenance-aware knowledge system for cross-platform tool lifecycle management...'
- New design principle block: 'Provenance-aware knowledge: Every knowledge item -- operational learning, decision, observation, rule change -- tracks what it was based on, who produced it, when the basis was valid, and whether the basis has been superseded.'
- Adds reference to reference/framework-provenance.md""",
        "severity": "medium",
    },
    {
        "category": "finding",
        "text": "Commit 40951fc: reference/harness.md -- Provenance added as 6th harness component. New section 'How the Components Relate' documents the dependency chain: Platform -> Configuration -> Orchestration -> (Managed Tools, Frameworks, Provenance). Provenance described as both a component and a cross-cutting concern.",
        "status": "pending-review",
        "evidence": """DIFF (reference/harness.md):
+**Provenance** -- every piece of operational learning, every decision, every work product has provenance: what it was based on, when, by whom, and whether the basis has been superseded.
+## How the Components Relate
+The six components form a dependency chain:
+Platform -> Configuration -> Orchestration -> (Managed Tools, Frameworks, Provenance)
+Provenance cuts across the other components: it tracks the basis for configuration decisions, the history of orchestration changes, the evaluation chain for tool selections, and the adoption rationale for frameworks.""",
        "severity": "medium",
    },
    {
        "category": "finding",
        "text": "Commit 40951fc: reference/framework-provenance.md -- NEW FILE (232 lines). Documents provenance discipline: 6 source disciplines (truth maintenance/ATMS, W3C PROV, dbt staleness, Graphiti bitemporal, Pachyderm lineage, Apache Atlas classification). Architectural decisions: hot-path (<5ms) vs cold-path collection, level separation (session DB vs harness DB), immutability, ascending spiral pattern.",
        "status": "pending-review",
        "evidence": """NEW FILE: reference/framework-provenance.md (232 lines)
Key sections:
- Source Discipline: truth maintenance (de Kleer ATMS 1986), derivation chains (W3C PROV 2013), staleness tracking (dbt), bitemporal knowledge (Graphiti/Zep), automatic lineage (Pachyderm), metadata governance (Apache Atlas)
- Triggering experience: session c0dc2ddc-f traced wrong /tmp assumption propagating through 4 delegation links across 9 days
- Architectural decisions: frictionless collection (hot path <5ms, cold path at session boundary), level separation, immutability
- What we did NOT take: full ATMS inference machinery, W3C PROV RDF, Graphiti three-tier subgraph, Pachyderm pipeline re-execution
- Implementing artifacts: harness-db-schema.sql tables (knowledge_items, provenance_edges, nogood_sets)""",
        "severity": "medium",
    },
]

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

for obs in observations:
    cursor.execute(
        """INSERT INTO observations (category, text, status, evidence, severity, created_at)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (obs["category"], obs["text"], obs["status"], obs["evidence"], obs["severity"], NOW),
    )
    print(f"Inserted observation {cursor.lastrowid}: {obs['text'][:80]}...")

conn.commit()
conn.close()
print(f"\nDone. {len(observations)} observations inserted.")
