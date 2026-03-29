# RFC 0005: Session Intelligence Architecture

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Informed by**: harness-db.py (3009 lines, all subcommands), harness-db-schema.sql (session + harness DB), JSONL event system, consolidated OL (gap G3: fast/slow loop promotion), telemetry architecture redesign (session c0dc2ddc-f), command channel investigation, full session transcripts (8236ca9c, 1bc9fd30, f078fb16), RFCs 0001-0004
**Relationship**: Data layer for RFCs 0001 (product), 0002 (MC consumers), 0003 (OL promotion target), 0004 (lifecycle that produces data)

---

## 1. Summary

Session intelligence is everything agents produce beyond code: operational learning, decisions, assumptions, observations, incidents, corrections, processing observations, friction events, KPIs, running estimates, briefings, handoff state, and mission state. JSON has proven too high-friction as the store for this intelligence. SQLite is the runtime store. JSON is the git-tracked archive for cross-machine carry-forward.

This RFC defines the target architecture for how agents produce, store, query, promote, and carry forward intelligence during and between sessions. The current implementation (harness-db.py with lean CLI subcommands) is the baseline. This RFC specifies the gaps and the target state.

## 2. The Problem JSON Created

JSON read-modify-write cycles are too expensive for hooks (<50ms budget) and too high-friction for agents documenting intelligence mid-session. Specific failures:

- **running-estimate.json**: required agents to read, parse, modify, serialize, and write a growing JSON file every time state changed. Agents avoided updating it because the friction was too high.
- **operational-learning.json**: same problem. OL accumulated in conversation and scratch files instead of the structured store.
- **incidents.json**: filing an incident required loading the full registry, finding the next ID, constructing a complex JSON object with 15+ fields, and writing back. Agents deferred filing.
- **harness-state.json**: multiple competing state files (alpha, bravo, charlie) because concurrent sessions couldn't safely write to one JSON file.

The pattern: JSON is fine for git-tracked archives (read once at session start, export once at session end). JSON is wrong for runtime intelligence that agents write dozens of times per session.

## 3. The SQLite Solution

### Two-tier architecture (from harness-db-schema.sql)

**Session DB** (.aitools/sessions/&lt;prefix&gt;.db): Per-session state. One DB per Claude Code session. Written by that session's agents only. WAL mode for concurrent readers. Created at SessionStart by harness-db-sessionstart.sh.

**Harness DB** (.aitools/harness.db): Cross-session state. Written at session boundaries only (SessionStart registration, SessionEnd export/promotion). Contains session index, KPI events, knowledge items (provenance), and shipping state.

### Why two tiers

- Session DBs eliminate write contention between concurrent sessions (each writes only to its own DB)
- Harness DB provides cross-session queries without scanning all session DBs
- Session DBs can be large (events, messages, observations) without bloating the cross-session store
- The promotion pipeline (session -> harness) is the quality gate

## 4. Intelligence Types

### What agents produce during sessions

| Type | Session DB table | Lean CLI | Description |
|------|-----------------|----------|-------------|
| Operational learning | observations (category=finding) | `ol add "text"` | Principles learned from experience |
| Decisions | decisions | `decision add "title"` | Architectural and session decisions |
| Assumptions | observations (category=assumption) | `observation add "text" --category assumption` | Unverified beliefs that may be falsified |
| Observations | observations (category=observation) | `observation add "text"` | Things noticed during work |
| Findings | observations (category=finding) | (same as ol add) | Significant discoveries |
| Incidents | deviations | `incident add "text"` | Process deviations with optional impact |
| Messages | messages | `log --type sitrep\|finding` | SITREPs and structured findings |
| Missions | missions | `mission start\|end` | Delegated agent missions |
| Delegations | delegation_log | (written by hooks) | Every agent launch with duty scores |
| Completed work | completed_work | (manual) | Shipped items |
| Hard requirements | hard_requirements | (manual) | Tracked requirements |
| Deviations | deviations | `incident add` | Process deviations |
| Commander directives | commander_directives | `directive add\|poll\|ack` | Time-critical uplink |
| Commander feedback | commander_feedback | (via MC UI) | Advisory cross-session feedback |
| Events | events | (written by hooks) | JSONL -> session DB at SessionEnd |
| Version history | version_history | (manual) | Session state versions |

### What's NOT in the session DB yet (gaps)

| Type | Current location | Target |
|------|-----------------|--------|
| Running estimate | .aitools/channel/running-estimate.json | Session DB aggregate export |
| Corrections | Conversation only (transcript) | Session DB observations (category=correction, new) |
| Processing observations | Plans, relay, conversation | Session DB observations (category=processing_obs, new) |
| Friction events | Not tracked | Session DB events (type=friction, new) |
| Briefings | .scratch/ files | Session DB or structured handoff table |
| Handoff state | .aitools/channel/handoffs/*.md | Harness DB or dedicated table |

### New observation categories needed

The observations table CHECK constraint currently allows: observation, assumption, fact, finding. Add:
- **correction**: Commander corrections that become OL
- **processing_obs**: Agent observations about its own processing (OL-F1 through OL-F9 type)

The deviations table serves incidents. But a "teach" directive (RFC 0002 v2) that gets promoted to OL needs a path from commander_directives -> observations -> knowledge_items.

## 5. The Lean CLI

harness-db.py provides zero-friction subcommands designed for one-liner Bash calls from hooks and agents:

### Existing subcommands

```
# Session lifecycle
harness-db.py init
harness-db.py session start --id <id> [--schwerpunkt <text>]
harness-db.py session end --id <id>

# Intelligence (lean)
harness-db.py ol add "text"                    # -> observations (finding)
harness-db.py ol list [--limit N]
harness-db.py decision add "title" [--description <text>]
harness-db.py decision list [--limit N]
harness-db.py incident add "text" [--impact <text>]
harness-db.py incident list [--limit N]
harness-db.py observation add "text" [--category <cat>] [--severity <level>]
harness-db.py search "query"

# Command channel
harness-db.py directive add "msg" [--type X] [--priority Y] [--target Z]
harness-db.py directive list [--status S]
harness-db.py directive poll
harness-db.py directive ack <id> [--response R]

# Structured logging
harness-db.py log --session <id> --type sitrep|finding --message <text>
harness-db.py mission start|end --session <id> --mission <name>

# Provenance
harness-db.py knowledge add|invalidate|verify|list
harness-db.py edge add|list
harness-db.py nogood add|list|check

# Export and shipping
harness-db.py export --format json
harness-db.py process-events [--session <id>]
harness-db.py ship
harness-db.py provenance-export
harness-db.py status
```

### Gaps in the lean CLI

| Need | Current state | Target subcommand |
|------|--------------|-------------------|
| Add correction | Not supported | `correction add "text" [--source transcript\|directive]` |
| Add processing observation | Use observation add | `processing-obs add "text"` (shorthand) |
| Add friction event | Not supported | `friction add "text" [--source <hook\|tool\|platform>] [--severity <level>]` |
| Briefing create | Manual file write | `briefing create [--schwerpunkt <text>]` |
| Running estimate refresh | JSON export only | `estimate refresh` (recompute from session DB) |
| Promote to knowledge | Manual knowledge add | `promote <observation-id>` (auto-creates knowledge_item + edges) |
| Session summary | Manual | `summary` (compute from all tables) |

### Design principles for the CLI

- Zero friction: one command, one action. No JSON manipulation required.
- Auto-detection: session ID from .scratch/.current-session when --session omitted.
- Safe to re-run: idempotent where possible.
- Always exits 0 on no-op (hook safety).
- Python sqlite3 stdlib only (no external deps).
- Cross-platform (macOS, Windows Git Bash, Linux).

## 6. The Promotion Pipeline

### Fast loop (within session)

Agents write observations, decisions, incidents to the session DB. This is high-volume, low-ceremony data. Not everything is worth promoting to the harness DB.

### Slow loop (at session boundaries)

SessionEnd hook processes session intelligence:
1. process-events: JSONL events -> kpi_events in harness DB
2. export: session DB -> running-estimate.json (git carry-forward)
3. Future: promote significant observations to knowledge_items

### Promotion criteria (gap G3 from consolidated OL)

When does a session observation become a harness DB knowledge_item?

| Criterion | Signal | Weight |
|-----------|--------|--------|
| Commander validated | Commander directive confirmed or corrected | High |
| Has evidence | Observation cites specific files, lines, behaviors | Medium |
| Has counter-evidence | Observation acknowledges what might falsify it | Medium |
| Cross-session reference | Another session references this observation | High |
| Incident-linked | Observation was filed as part of an incident investigation | Medium |
| Teach directive | Commander explicitly injected knowledge via "teach" | High (auto-promote) |

### Promotion workflow

```
Session DB observation
  -> SessionEnd: evaluate against criteria
    -> Score >= threshold: create knowledge_item in harness DB
      -> Create provenance_edge (derived_from session observation)
      -> Set trust_level based on source (commander_directive vs agent_observation)
      -> Set staleness thresholds (warn_after=30, error_after=90)
    -> Score < threshold: leave in session DB only (still in JSON export)
```

The "teach" directive type (RFC 0002 v2) auto-promotes: commander_directives with type='teach' -> observations -> knowledge_items with trust_level='commander_directive' and authority_level=3.

## 7. KPI Architecture

### Collection (hot path)

Enforcement hooks emit JSONL events to .scratch/session-*/events.jsonl (~0.1ms per event). Event types: hook_fire, hook_block, hook_warn, delegation, session_event.

### Computation (cold path)

harness-db.py process-events reads events.jsonl and computes:

| Metric | Computation | What it measures |
|--------|------------|-----------------|
| guard.fireCount | Count hook_fire + hook_block + hook_warn | Hook activity |
| guard.blockCount | Count hook_block | Violations blocked |
| guard.warnCount | Count hook_warn | Warnings issued |
| delegation.avgScore | Mean of delegation event scores | Delegation quality |
| delegation.minScore | Min of delegation event scores | Worst delegation |
| delegation.count | Count delegation events | Delegation volume |
| session.turnCount | Deduplicated timestamps from hook events | Conversation turns |
| session.durationSeconds | First to last event timestamp delta | Session length |
| session.subagentCount | Count delegation events | Subagent launches |
| session.scratchFileCount | Count files in session scratch dir | Work products |

### Gaps in KPI computation

| Metric needed | Source | RFC consumer |
|--------------|--------|-------------|
| session.correctionCount | New correction observations | RFC 0002 v2 (Corrections tab) |
| session.olItemsProduced | Count of ol add calls | RFC 0002 v2 (KPI card) |
| session.contextUtilization | CC /context output (not programmatic) | RFC 0001 v2 (impairment detection) |
| session.frictionCount | New friction events | This RFC |
| delegation.dutyElements | Per-element breakdown from JSONL | RFC 0002 v2 (Delegations tab) |
| session.promotionCount | Items promoted to harness DB | RFC 0003 v2 |

### Storage

Computed metrics written to harness DB kpi_events table: session_id, metric_name, metric_value, dimensions (JSON blob), collected_at.

### Shipping

harness-db.py ship reads unshipped kpi_events, batch-submits to Datadog API v2. Records shipment in kpi_ship_log. DD_API_KEY and DD_SITE environment variables configure the destination.

### Consumption

MC (RFC 0002 v2) reads KPIs through the Datadog adapter (primary) or local harness DB (fallback). Health indicators derived from KPI thresholds.

## 8. Friction Tracking

### What friction IS

Friction (Reibung) is anything that slows agents or the commander during a session. Sources:

| Source | Example | Severity |
|--------|---------|----------|
| Platform | Permission prompt blocks user, Write tool produces CRLF | Medium |
| Hook | False positive blocks legitimate command | High |
| Tool | Tool not on PATH after install, auth expired | Medium |
| Process | Protected file gate on trivial change, JSON friction | Low-High |
| Context | Context window full, auto-compact loses important data | High |
| Delegation | Subagent can't access files, no SendMessage | Medium |

### Collection

New event type in JSONL: `friction`. Hooks and agents emit friction events:

```json
{"t":"2026-03-28T20:00:00Z","type":"friction","src":"standing-order-guard","d":{"category":"hook","detail":"false positive on perl semicolon","severity":"medium"}}
```

Agents can also report friction through the lean CLI:
```
harness-db.py friction add "Write tool produced CRLF on macOS" --source platform --severity medium
```

### Computation

SessionEnd processor counts friction events by source and severity. Metrics: friction.count, friction.bySource, friction.bySeverity.

### Consumption

MC health indicators (RFC 0002 v2): friction count > 5 per session = yellow, > 10 = red. Governance health dashboard (RFC 0002 v2 future proposal) shows friction trends.

### Reduction

Friction tracking closes the feedback loop: measure -> identify patterns -> fix root cause -> verify reduction. The hook rollout observe-then-enforce cycle is one friction reduction pattern. The JSON-to-SQLite migration is another.

## 9. Carry-Forward

### The principle (from RFC 0004)

Session state that must survive machine switches is tracked in git. Session-ephemeral data is gitignored.

### Current carry-forward artifacts

| Artifact | Format | Location | Git-tracked |
|----------|--------|----------|-------------|
| Running estimate | JSON (exported from session DB) | .aitools/channel/running-estimate.json | Yes |
| Relay | Markdown | .aitools/channel/relay.md | Yes |
| Handoffs | Markdown | .aitools/channel/handoffs/*.md | Yes |
| Harvested artifacts | Various | harvesting/ | Yes |
| Session archives | JSONL | dotprofile sessions/ | Yes (separate repo) |
| Harvest manifest | JSON | harvesting/harvest-manifest.json | Yes |

### What's NOT carried forward (gaps)

| Intelligence | Current state | Impact |
|-------------|--------------|--------|
| Session DB | Gitignored (.aitools/sessions/*.db) | Cross-session OL queries require the machine that produced them |
| KPI events | In harness DB (gitignored) | KPI trends lost on machine switch until Datadog ships |
| Provenance graph | In harness DB (gitignored) | OL graph only available on the machine that built it |
| Friction events | Not tracked | No carry-forward needed (session-scoped) |

### Target carry-forward

The export at SessionEnd (harness-db.py export) produces running-estimate.json which is git-tracked. This is the bridge. The target:

1. **Export richer data**: Include promoted knowledge_items, new provenance_edges, and KPI summaries in the JSON export.
2. **Import on SessionStart**: If harness DB is missing or empty, import from running-estimate.json to bootstrap.
3. **Merge on pull**: When git pull brings new running-estimate.json from another machine, import new items without overwriting local state.

This is Option B from the harness-db-schema.sql: "DB is runtime (gitignored), JSON is archive (tracked in git)."

## 10. Agent Workflow

### Per-turn

1. Agent receives prompt
2. Apply 7-step process (parse, check conversation, check context, disciplined initiative, surface, batch, verify output)
3. During work: write observations/decisions/OL to session DB via lean CLI as they arise
4. Hooks emit JSONL events automatically (no agent action needed)
5. If Stop hook fires: check for commander directives

### Per-session

1. SessionStart: harness-db registers session, scratch-init creates workspace
2. Agent loads carry-forward state (running estimate, handoffs, relay)
3. Agent works, writing intelligence to session DB throughout
4. SessionEnd: archive transcript, harvest artifacts, process events, export JSON, ship KPIs

### The friction budget

Every intelligence-writing action has a friction cost. The lean CLI minimizes it:

| Action | Friction | Time |
|--------|---------|------|
| `ol add "text"` | 1 Bash call | <1s |
| `decision add "title"` | 1 Bash call | <1s |
| `incident add "text"` | 1 Bash call | <1s |
| Writing to running-estimate.json (old) | Read + parse + modify + serialize + write | 5-10s |
| Filing incident in incidents.json (old) | Read + find ID + construct 15-field object + write | 30-60s |

The lean CLI reduces friction by 10-60x compared to JSON.

## 11. Schema Changes Needed

### New observation categories

Add to session DB observations table CHECK constraint:
```sql
CHECK (category IN ('observation', 'assumption', 'fact', 'finding', 'correction', 'processing_obs'))
```

### New event type

Add to session DB events:
```sql
-- friction events
-- event_type = 'friction'
-- source = hook name, 'platform', 'tool', 'process', 'context', 'delegation'
-- detail JSON includes: category, detail text, severity
```

### New harness DB table (optional)

```sql
CREATE TABLE IF NOT EXISTS carry_forward_log (
    entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
    direction TEXT NOT NULL CHECK (direction IN ('export', 'import')),
    items_count INTEGER NOT NULL,
    source_session TEXT,
    target_machine TEXT,
    created_at TEXT NOT NULL
);
```

All schema changes are to reference/harness-db-schema.sql — a protected file requiring commander review.

## 12. Phase Plan

### Phase 0: Close gaps in lean CLI (1 session)
- Add correction, processing-obs, friction subcommands
- Add promote subcommand (observation -> knowledge_item)
- Add new observation categories to schema
- Add friction event type
- **Exit**: Agents can document all intelligence types with one-liner commands

### Phase 1: Promotion pipeline (1 session)
- Implement promotion criteria evaluation at SessionEnd
- Auto-promote "teach" directives
- Create provenance edges on promotion
- **Exit**: Significant observations automatically become knowledge_items

### Phase 2: Richer export (1 session)
- Include promoted knowledge_items in JSON export
- Include new provenance_edges
- Include KPI summaries
- Import on SessionStart when harness DB is empty
- **Exit**: Carry-forward includes OL graph state, not just running estimate

### Phase 3: Friction tracking (1 session)
- Add friction event emission to hooks
- Add friction lean CLI subcommand
- Add friction KPIs to SessionEnd processor
- **Exit**: Friction measurable and trending in MC

## 13. Open Questions

1. **Promotion threshold**: What score makes an observation worth promoting? Start conservative (only teach directives and commander-validated items), lower over time.

2. **Carry-forward merge conflicts**: Two machines produce different knowledge_items. How to merge when git pulls both? Append-only with dedup by item_id.

3. **Context utilization metric**: CC doesn't expose context consumption programmatically. /context is interactive-only. Can a hook capture it?

4. **Briefing format**: Should briefings be structured DB records or freeform markdown in scratch? Markdown is more flexible; DB is more queryable.

5. **Running estimate replacement**: The JSON running estimate was designed for the dashboard (generate-dashboard.py). MC reads the session DB directly. Is the JSON export still needed? Yes — for git carry-forward. But it should be richer.

6. **Incident registry migration**: incidents.json has 20+ incidents with complex fields. Migrate to session DB? Or keep as a separate registry with the /incident skill as the gate?

## 14. References

### Existing implementation
- harness-db.py: scripts/harness-db.py (3009 lines, all subcommands)
- harness-db-schema.sql: reference/harness-db-schema.sql
- JSONL event system: all 15 hooks emit events
- SessionEnd processor: harness-db.py process-events
- Datadog shipper: harness-db.py ship

### Architecture provenance
- Telemetry redesign: .scratch/session-c0dc2ddc-f/telemetry-architecture-redesign.md
- Consolidated OL gap G3: fast/slow loop promotion
- JSON friction: commander directive (session 8236ca9c)
- Option B (DB runtime, JSON archive): harness-db-schema.sql header comment

### Consumers
- RFC 0001 v2: Product (displays intelligence via MC)
- RFC 0002 v2: MC (9 tabs, KPI dashboard, health indicators)
- RFC 0003 v2: OL graph (promotion target for knowledge_items)
- RFC 0004: Harness architecture (lifecycle that produces data)

### Sessions
- 8236ca9c: "JSON is too cumbersome" — commander directive that initiated SQLite migration
- c0dc2ddc-f: Telemetry redesign, lean CLI design, JSONL event architecture
- f078fb16: Architectural decisions
- fbf7decb: This session
