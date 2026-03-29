# RFC 0005: Session Intelligence Architecture (v2)

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Supersedes**: rfcs/0005-session-intelligence-architecture.md (v1, same session)
**Informed by**: harness-db.py (3009 lines), harness-db-schema.sql, JSONL event system, consolidated OL (gap G3), telemetry redesign, RFCs 0001-0004 v2 + 0006, resolution chain (0004-v2 section 5), Python engineering patterns from harness-db.py/read-session*.py/build-knowledge-db.py
**Relationship**: Data layer for all other RFCs. Implements the resolution chain from 0004-v2. Feeds 0002 v2 (MC consumers), 0003 v2 (OL promotion target), 0006 (delegation tracking).

---

## 1. Summary

Session intelligence is everything agents produce beyond code. JSON has proven too high-friction as the runtime store. SQLite is the runtime. JSON is the git-tracked archive.

This RFC defines how agents produce, store, query, promote, and carry forward intelligence. It covers the resolution chain workflow (recency -> provenance -> commander override from RFC 0004-v2), the Python engineering constraints that govern all harness tooling, and the friction budget that determines whether agents actually use the system.

v2 additions: Python engineering patterns (section 11), resolution chain as agent workflow (section 10 expanded), cross-references to 0004-v2 resolution chain and 0006 delegation tracking.

## 2. The Problem JSON Created

JSON read-modify-write is too expensive for hooks (<50ms) and too high-friction for agents mid-session:

- **running-estimate.json**: agents avoided updating because read-parse-modify-serialize-write was 5-10s of friction per update
- **incidents.json**: 15+ field JSON object construction took 30-60s, agents deferred filing
- **operational-learning.json**: OL accumulated in conversation instead of the structured store
- **harness-state.json**: concurrent sessions couldn't safely write to one JSON file

Pattern: JSON is fine for git-tracked archives (read once, export once). JSON is wrong for runtime intelligence written dozens of times per session.

## 3. The SQLite Solution

### Two-tier architecture

**Session DB** (.aitools/sessions/&lt;prefix&gt;.db): per-session, WAL mode, one per CC session, written by that session's agents only. Created at SessionStart.

**Harness DB** (.aitools/harness.db): cross-session, written at session boundaries only. Session index, KPI events, knowledge items (provenance), shipping state.

### Why two tiers

Session DBs eliminate write contention. Harness DB provides cross-session queries. The promotion pipeline (session -> harness) is the quality gate between fast loop and slow loop (RFC 0004-v2 section 11, safety mechanism #4).

## 4. Intelligence Types

| Type | Table | Lean CLI | Friction |
|------|-------|----------|---------|
| Operational learning | observations (finding) | `ol add "text"` | <1s |
| Decisions | decisions | `decision add "title"` | <1s |
| Assumptions | observations (assumption) | `observation add --category assumption` | <1s |
| Observations | observations | `observation add "text"` | <1s |
| Incidents | deviations | `incident add "text"` | <1s |
| Messages | messages | `log --type sitrep` | <1s |
| Missions | missions | `mission start\|end` | <1s |
| Delegations | delegation_log | (hooks, RFC 0006) | 0 (automatic) |
| Commander directives | commander_directives | `directive add\|poll\|ack` | <1s |
| Commander feedback | commander_feedback | (via MC, RFC 0002 v2) | 0 (UI) |
| Events | events | (hooks, JSONL) | ~0.1ms (automatic) |
| Completed work | completed_work | (manual) | — |
| Requirements | hard_requirements | (manual) | — |
| Deviations | deviations | `incident add` | <1s |

### Gaps (not yet in session DB)

| Type | Current | Target | New CLI |
|------|---------|--------|---------|
| Corrections | Conversation only | observations (category=correction) | `correction add "text"` |
| Processing observations | Plans, relay | observations (category=processing_obs) | `processing-obs add "text"` |
| Friction events | Not tracked | events (type=friction) | `friction add "text" --source <src>` |
| Briefings | .scratch/ files | Structured or freeform TBD | `briefing create` |
| Running estimate | JSON export only | Aggregate from session DB | `estimate refresh` |
| Promotion | Manual knowledge add | Auto with criteria | `promote <id>` |
| Session summary | Manual | Computed from all tables | `summary` |

### Schema changes needed

Add to observations CHECK: `correction`, `processing_obs`. Add friction event type to events. All changes to reference/harness-db-schema.sql (protected file).

## 5. The Lean CLI

harness-db.py: Python 3, sqlite3 stdlib only, no external deps. Cross-platform (macOS, Windows Git Bash, Linux). Auto-detects session from .scratch/.current-session. Safe to re-run. Always exits 0 on no-op (hook safety).

### Existing subcommands (32)

Session: init, session start/end. Intelligence: ol add/list, decision add/list, incident add/list, observation add, search, log, mission start/end. Command channel: directive add/list/poll/ack. Provenance: knowledge add/invalidate/verify/list, edge add/list, nogood add/list/check, provenance-export. Export: export, process-events, ship, status.

### Gap subcommands (7)

correction add, processing-obs add, friction add, briefing create, estimate refresh, promote, summary.

### Friction budget

| Action | Old (JSON) | New (lean CLI) | Reduction |
|--------|-----------|---------------|-----------|
| Add OL | Read JSON, find section, append, write | `ol add "text"` | 10-30x |
| File incident | Read JSON, find max ID, construct 15 fields, write | `incident add "text"` | 30-60x |
| Add decision | Read JSON, construct object, write | `decision add "title"` | 10-20x |
| Update estimate | Read JSON, parse, modify N fields, serialize, write | `estimate refresh` | 5-10x |

The lean CLI makes intelligence documentation cheaper than not documenting. This is the design goal: the friction of documenting must be lower than the friction of not documenting.

## 6. The Promotion Pipeline

### Fast loop (within session)
Agents write to session DB. High-volume, low-ceremony. Not everything promotes.

### Slow loop (at session boundary)
SessionEnd hook evaluates observations against promotion criteria:

| Criterion | Signal | Weight |
|-----------|--------|--------|
| Commander validated | Directive confirmed or corrected | High |
| Has evidence | Cites files, lines, behaviors | Medium |
| Has counter-evidence | Acknowledges what might falsify | Medium |
| Cross-session reference | Another session references this | High |
| Incident-linked | Part of investigation | Medium |
| Teach directive | Commander explicitly injected | High (auto-promote) |

### Promotion creates graph nodes
Promoted observation -> knowledge_item in harness DB + provenance_edge (derived_from session observation) + trust_level from source + staleness thresholds. This populates the OL graph (RFC 0003 v2) and advances the provenance maturity progression (RFC 0004-v2 section 5).

## 7. KPI Architecture

### Collection (hot path)
Hooks emit JSONL events (~0.1ms). Event types: hook_fire, hook_block, hook_warn, delegation, session_event, friction (new).

### Computation (cold path)
harness-db.py process-events computes 10 existing + 4 gap metrics:

Existing: guard.fireCount, guard.blockCount, guard.warnCount, delegation.avgScore, delegation.minScore, delegation.count, session.turnCount, session.durationSeconds, session.subagentCount, session.scratchFileCount.

Gaps: session.correctionCount, session.olItemsProduced, session.frictionCount, delegation.dutyElements (per-element breakdown).

### Storage and shipping
Computed -> kpi_events in harness DB. harness-db.py ship -> Datadog API v2. MC reads via Datadog adapter (primary) or local DB (fallback). Adapter IS the contingency (D-F12).

## 8. Friction Tracking

Friction (Reibung) is anything that slows agents or the commander.

| Source | Example | Collection |
|--------|---------|-----------|
| Platform | Permission prompt, CRLF, PATH issues | Agent reports via `friction add` |
| Hook | False positive blocks legitimate command | Hook self-reports in JSONL |
| Tool | Not on PATH, auth expired | Setup script reports |
| Process | Protected file gate, JSON friction | Agent reports |
| Context | Window full, auto-compact loses data | Agent reports |
| Delegation | Context gap, no SendMessage (RFC 0006) | Delegation guard reports |

SessionEnd computes friction.count, friction.bySource, friction.bySeverity. MC health: >5/session = yellow, >10 = red.

Feedback loop: measure -> identify patterns -> fix root cause -> verify reduction. The JSON-to-SQLite migration itself was a friction reduction informed by this pattern.

## 9. Carry-Forward

### Principle
Git-tracked state survives machine switches. Session-ephemeral is gitignored. (RFC 0004-v2 section 10.)

### Current
running-estimate.json, relay.md, handoffs/, harvesting/ — git-tracked. Session DBs, events.jsonl — gitignored.

### Target (richer export)
SessionEnd export includes: promoted knowledge_items, new provenance_edges, KPI summaries, session metadata. SessionStart imports from JSON when harness DB is empty. Git pull merges append-only.

Option B confirmed: DB is runtime (gitignored), JSON is archive (tracked). The export is the bridge.

## 10. Agent Workflow and Resolution Chain

### Per-turn workflow

1. Receive prompt
2. Apply 7-step process:
   - Parse for high-impact words
   - Check against this conversation (recency: highest weight)
   - Check against files in context (recency: medium weight)
   - Use disciplined initiative to resolve ambiguity
   - **Apply resolution chain when conflicts arise** (new):
     - Level 1: Recency bias (default heuristic)
     - Level 2: Provenance check (if graph data available — is the basis still valid?)
     - Level 3: Commander override (if provenance is ambiguous — surface and ask)
   - Surface only what can't be resolved
   - Batch clarifications
3. Verify output against active orders and verified vocabulary
4. Document intelligence as it arises (lean CLI: ol add, decision add, etc.)
5. Hooks emit events automatically

### Per-session workflow

1. SessionStart: harness-db registers, scratch-init creates workspace
2. Load carry-forward: running estimate, handoffs, relay
3. Work, writing intelligence throughout using lean CLI
4. If resolution chain reaches Level 2: query harness DB for provenance (knowledge list, edge list, nogood check)
5. If resolution chain reaches Level 3: surface to commander via conversation or surfacing duty
6. SessionEnd: archive, harvest, process events, promote, export, ship

### The resolution chain in practice

Example from this session: I loaded the f078fb16 OL decisions document. It referenced architectural decisions made yesterday. But the project CLAUDE.md hadn't been updated to reflect them (stale). Resolution:

- Level 1 (recency): The f078fb16 decisions are more recent than the CLAUDE.md. Use them.
- Level 2 (provenance): The decisions have provenance (session f078fb16, commander present, decisions D-F1 through D-F14). The CLAUDE.md is a distillation that hasn't been updated.
- Result: Decisions win. CLAUDE.md update is a task, not a conflict.

If provenance had shown the decisions were based on invalidated assumptions, Level 2 would have flagged them and Level 3 (commander override) would have been needed.

## 11. Python Engineering Patterns

Python is the harness's second language after bash. All Python in the harness follows these constraints:

### stdlib-only principle

No external dependencies. Python sqlite3, json, argparse, pathlib, datetime, urllib — all stdlib. This ensures harness-db.py works on any machine with Python 3 installed. No pip install, no venv, no requirements.txt.

Exception: build-knowledge-db.py references sqlite-utils as an optional enhancement. The core (FTS5 via sqlite3) is stdlib.

### Single CLI pattern

harness-db.py is the single CLI for all DB operations. No proliferation of scripts. New functionality = new subcommand, not new file. The CLI is 3009 lines and growing. Subcommands are self-contained functions (cmd_*).

### Supporting scripts

| Script | Purpose | Lines |
|--------|---------|-------|
| harness-db.py | All DB operations | 3009 |
| read-session-full.py | Full-fidelity session extraction (text + thinking + tools) | 268 |
| read-session.py | Text-only session extraction (COMMANDER + AGENT) | 222 |
| build-knowledge-db.py | FTS5 knowledge index builder | 1170 |

### Python detection pattern

Hooks and scripts detect Python cross-platform:
```bash
PYTHON=""
if command -v python3 > /dev/null 2>&1; then
    PYTHON="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON="python"
fi
```
macOS: python3 (via pyenv or system). Windows: python (via winget/python.org installer). The harness manages Python installation via setup-python.sh/.ps1.

### SQLite patterns

- WAL mode for concurrent readers: `PRAGMA journal_mode=WAL`
- Normal sync for performance: `PRAGMA synchronous=NORMAL`
- Busy timeout for contention: `PRAGMA busy_timeout=5000`
- Foreign keys enforced: `PRAGMA foreign_keys=ON`
- Row factory for named access: `conn.row_factory = sqlite3.Row`
- URI mode for read-only: `sqlite3.connect(f"file:{path}?mode=ro", uri=True)`
- CHECK constraints for enum validation (all status fields, category fields)
- CREATE IF NOT EXISTS throughout (safe to re-run)

### Schema management

harness-db-schema.sql is the canonical schema definition (reference file, protected). harness-db.py contains the same schema as Python strings (SESSION_SCHEMA, HARNESS_SCHEMA). Both must stay in sync — the canonical file is the spec, the Python strings are the runtime.

Schema version tracked in schema_version table. Forward-only migrations via ensure_schema().

### Error handling in Python

- sqlite3.Error caught at subcommand level, logged to deploy.log via _log_detail()
- Hooks: always exit 0 on DB failure (hook must never break CC)
- CLI: exit 1 on DB failure with descriptive message
- DB not found: silent no-op for hooks, error for CLI
- Python not found: silent skip (hooks detect and bail)

### The export pattern (Option B)

```
Runtime (gitignored):
  .aitools/sessions/*.db    (session DBs)
  .aitools/harness.db       (harness DB)

Archive (git-tracked):
  .aitools/channel/running-estimate.json  (exported at SessionEnd)
  .aitools/provenance-export.json         (on demand)

Bridge: harness-db.py export
  - Reads session DB
  - Produces JSON matching running-estimate format
  - Safety: refuses to overwrite larger file with empty session data
  - Safety: skips export when session has no meaningful content
```

## 12. Phase Plan

### Phase 0: Close CLI gaps (1 session)
- Add correction, processing-obs, friction, promote, summary subcommands
- Add new observation categories to schema
- Add friction event type
- **Exit**: All intelligence types documentable with one-liner commands

### Phase 1: Promotion pipeline (1 session)
- Implement criteria evaluation at SessionEnd
- Auto-promote teach directives
- Create provenance edges on promotion
- **Exit**: Significant observations auto-promote to knowledge_items

### Phase 2: Richer export (1 session)
- Include promoted items, edges, KPI summaries in JSON export
- Import on SessionStart when harness DB empty
- Merge on pull (append-only dedup)
- **Exit**: Carry-forward includes OL graph state

### Phase 3: Friction tracking + resolution chain tooling (1 session)
- Friction event emission in hooks
- Friction lean CLI
- Friction KPIs in SessionEnd processor
- Resolution chain helpers: `harness-db.py resolve <item-id>` checks provenance and staleness
- **Exit**: Friction measurable. Resolution chain queryable from CLI.

## 13. Open Questions

1. **Promotion threshold**: Start conservative (teach + commander-validated only), lower over time as graph proves valuable.
2. **Carry-forward merge**: Append-only with dedup by item_id. Two machines can't produce same item_id (session-prefixed).
3. **Context utilization metric**: CC doesn't expose programmatically. Open platform gap.
4. **Incident registry migration**: incidents.json -> session DB? Or keep as separate governed registry? The /incident skill is the gate either way.
5. **Schema sync**: harness-db-schema.sql and harness-db.py SESSION_SCHEMA/HARNESS_SCHEMA must stay in sync. No automated check exists. Add to check-pre-commit.
6. **Python version floor**: harness-db.py uses f-strings (3.6+), walrus operator in some paths (3.8+). Document minimum as Python 3.8.

## 14. References

### Implementation
- harness-db.py (scripts/, 3009 lines)
- harness-db-schema.sql (reference/)
- read-session-full.py, read-session.py (scripts/)
- build-knowledge-db.py (.scratch/session-c0dc2ddc-f/)
- JSONL event system (all 15 hooks)

### Architecture
- Telemetry redesign (.scratch/session-c0dc2ddc-f/)
- Consolidated OL gap G3 (fast/slow loop)
- Resolution chain (RFC 0004-v2 section 5)
- Option B (harness-db-schema.sql header)

### Consumers
- RFC 0001 v2 (product), 0002 v2 (MC 9 tabs + KPIs), 0003 v2 (OL promotion target), 0004-v2 (lifecycle + resolution chain), 0006 (delegation tracking)

### Sessions
- 8236ca9c: "JSON is too cumbersome" (commander directive)
- c0dc2ddc-f: Telemetry redesign, lean CLI, JSONL events, Python patterns
- fbf7decb: This session — resolution chain discovery, friction as intelligence type
