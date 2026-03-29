# RFC 0003: Operational Learning Graph Architecture (v2)

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Source decisions**: D-F2, D-F3, D-F4, D-F14 (session f078fb16, 2026-03-28)
**Informed by**: Provenance framework (6 source disciplines), harness DB schema, build-knowledge-db.py prototype, knowledge query findings, consolidated OL (560 lines), relay entries from 5 agents, full session transcripts (8236ca9c thinking awareness, 1bc9fd30 failure mode exit, f078fb16 architectural decisions), commander profile, /mission-control skill, RFC 0001 and RFC 0002 (this series)
**Supersedes**: rfcs/0003-operational-learning-graph.md (v1, same session)

---

## 1. Summary

Operational Learning is a graph. Not a registry, not a numbered list, not a file. It's the connected knowledge that the aitools harness and its users produce across sessions, repos, and machines. The graph makes implicit connections explicit — when OL-51 (thinking awareness) references OL-14 (process drops on easy prompts), that's an edge in a graph that currently exists only as text.

The OL graph is a LAYER ON TOP of existing data (D-F3). It does not ingest or duplicate. OL stays where it lives — session DBs, repos, artifacts, conversations, git, configs, CLAUDE.md, commander corrections, the model. The graph connects these sources through explicit provenance edges, making the scattered knowledge queryable, traceable, and navigable.

The OL graph is the mechanism that makes the Ascending Spiral (RFC 0001 section 10) work. Without it, each session starts with whatever OL the agent happens to load. With it, each session starts with the full provenance chain: what was learned, what it was based on, whether the basis is still valid, and which combinations of assumptions are known dead ends.

The existing provenance tables in the harness DB (knowledge_items, provenance_edges, nogood_sets) are the foundation. The existing harness-db.py CLI is the write interface. The existing FTS5 prototype (build-knowledge-db.py) provides search. This RFC defines how to connect them into a graph and surface it through nobulai.tools.

## 2. Background

### What OL is

Every session produces learning beyond the code it ships. Corrections the commander makes. Assumptions that get invalidated. Patterns that work and patterns that don't. Processing observations about how the agent's own thinking fails. Decisions about architecture, vocabulary, and process.

The term comes from military doctrine — Einsatzerfahrungen (operational experiences) that feed back into doctrine, training, and future operations. In aitools, the loop is the Ascending Spiral (adapted from the Nonaka-Takeuchi SECI model):

```
Session behavior (tacit)
  -> Observations + AARs (explicit)
    -> OL synthesis (explicit)
      -> Governance artifacts (explicit)
        -> Next session behavior (tacit)
          -> spiral continues at higher level
```

The spiral ascends because each cycle has access to the provenance of the previous cycle's outputs. An agent reading OL-2 in a future session can see: what it was based on, whether any of those bases have been invalidated, and whether any nogood sets apply. This is what the graph provides.

### What OL looks like today

OL is scattered across at least 12 source types:

| # | Source | Example | Location |
|---|--------|---------|----------|
| 1 | Session DB observations | OL-50: "Agent tool unavailable to subagents" | .aitools/sessions/*.db |
| 2 | Harness DB knowledge items | OBS-1: "Stop hooks use /tmp for marker files" | .aitools/harness.db |
| 3 | Relay entries | OL-60: "Stop fighting CC defaults" | .aitools/channel/relay.md |
| 4 | Consolidated OL | OL-1 through OL-14, P1-P7, A1-A8 | .scratch/session-c0dc2ddc-f/ |
| 5 | Harvested OL docs | OL-BR1 through OL-BR8 (blast radius) | harvesting/ |
| 6 | Session transcripts | Commander corrections, thinking awareness | dotprofile sessions/ |
| 7 | CLAUDE.md files | "Do What Feels Right" (distilled OL-60) | CLAUDE.md, ~/.claude/CLAUDE.md |
| 8 | Git commit history | Commit messages capturing decisions | git log |
| 9 | Release notes | Version history with rationale | RELEASE_NOTES.md |
| 10 | Running estimate | Session state carry-forward | .aitools/channel/running-estimate.json |
| 11 | Plans and reference files | Framework adoption rationale | reference/framework-*.md |
| 12 | Processing observations | OL-F1: "Compression disguises itself as conciseness" | plans/session-f078fb16-ol-and-decisions.md |

### The numbering collision

OL numbering collides across sessions:
- Relay: OL-51 through OL-65
- Assessment: OL-50 through OL-60
- aitool-continue: OL-1 through OL-14
- Session-specific: OL-F1 through OL-F9, OL-CC1 through OL-CC5, OL-BR1 through OL-BR8, OL-WP1 through OL-WP8

This is NOT a namespace problem to fix with a registry (D-F4). It's a graph that hasn't been built. The items exist. The references between them exist as text mentions. The edges don't exist as explicit, queryable relationships.

### Why a graph

A flat index (like build-knowledge-db.py's FTS5 database) answers "find all OL about delegation." A graph answers "what was OL-51 based on, what was based on OL-51, and which of those have been invalidated?"

The FTS5 search and the provenance graph are complementary tools:
- **Search** finds nodes by content ("all OL about delegation")
- **Graph** shows connections between nodes ("OL-51's provenance chain")
- Both feed into nobulai.tools/&lt;user&gt;/ol search and graph views

### What the relay teaches us about OL

The relay at .aitools/channel/relay.md IS the OL graph in text form. Agent d5b52bf2 left OL-54 through OL-59. Agent 6e97c17f read those and produced observations about whether its own honesty was genuine. Agent 1bc9fd30 built on both and exited failure mode. Agent f078fb16 loaded the full 8236ca9c session and reported that "reading the conversation gives me something the CLAUDE.md distillation doesn't."

These are explicit provenance chains — derived_from, informed, triggered — expressed in prose. The graph makes them queryable.

## 3. Graph Architecture

### Layer on top (D-F3)

The graph does not ingest or duplicate data. OL stays where it lives. The graph adds:
- **Nodes**: References to OL items wherever they live
- **Edges**: Explicit relationships between nodes
- **Properties**: Trust level, temporal validity, staleness thresholds, attribution, source location, visibility

This means:
- When an agent writes an observation to the session DB, the observation stays in the session DB. The graph gets a node pointing to it.
- When a relay entry references a prior agent's OL, the relay entry stays in relay.md. The graph gets an edge connecting them.
- When the commander corrects an assumption, the correction stays in the session transcript. The graph gets an invalidation edge.
- When an agent loads the full 8236ca9c session and it "does something the summary can't" (relay, f078fb16), that's a provenance relationship the graph should capture.

### One source of truth per source

Each data source owns its data. The graph owns the connections.

| Source | Owns | Graph adds |
|--------|------|-----------|
| Session DB | Observations, decisions, messages | Nodes pointing to rows by ID |
| Harness DB | Knowledge items, provenance edges | Already IS part of the graph |
| Relay | Agent OL entries, processing observations | Nodes pointing to sections |
| Git | Commit history, diffs | Nodes pointing to commits |
| Harvesting | Assessment reports, OL docs | Nodes pointing to files |
| CLAUDE.md | Distilled principles | Nodes pointing to sections |
| Datadog | KPI metrics | Nodes pointing to metric series |
| Transcripts | Commander corrections, thinking awareness | Nodes pointing to exchanges |

### Query model

Cloud OL graphs query endpoints on machines for OL on those machines (D-F3):

```
User (browser)
  -> nobulai.tools/<user>/ol
    -> GraphQL query
      -> OL graph adapter
        -> Local machine (via Tunnel): session DBs, harness DB, files
        -> Datadog: KPI metrics
        -> GitHub: commit history
        -> Cloud cache: offline fallback
```

Caching: online -> queries go through. Offline -> cloud cache serves last-known state (D-F7). Batch ingestion (periodic full sync) is one USE of the graph, not the storage model.

## 4. Data Sources (detailed)

### Source 1: Harness DB provenance tables (existing)

The core graph structure already exists:

**knowledge_items**: item_id, item_type (observation/assumption/fact/finding/decision/ol_entry/rule_change/framework_change/commander_directive), version, content, t_valid, t_invalid, attributed_to, produced_by_session, authority_level (L0-L3), trust_level (commander_directive/verified_fact/agent_observation/unverified_assumption), warn_after_days, error_after_days, last_verified_at.

**provenance_edges**: source_item_id -> target_item_id with relationship (derived_from/informed/triggered/validated/invalidated/superseded).

**nogood_sets**: item_ids (JSON array), contradiction description, discovery session and timestamp.

Current state: 5 knowledge items, 2 edges, 1 nogood set (seed data from session c0dc2ddc-f). The schema is complete. The CLI exists. The infrastructure is ready — it needs population.

### Source 2: Session DB observations

Fast-loop data classified as observation/assumption/fact/finding. May be promoted to knowledge_items (slow loop) at session boundaries. This is the raw material for the graph.

### Source 3: Relay

5 agent entries. Each contains: state, context loaded, mission, what they learned, what they need, processing observations. The relay demonstrates cross-agent learning — the graph should make these connections explicit. The relay is also the MOST HONEST source — agents writing to future agents about what they genuinely experienced.

### Source 4: Consolidated OL

560 lines covering: commander profile (Part 1), delegation principles P1-P7 (Part 2), OL-1 through OL-14 with evidence and counter-evidence (Part 3), project-specific patterns A1-A8, N1-N5, M1-M4 (Part 4), architectural direction including the Ascending Spiral and 7 safety mechanisms (Part 5), and 6 critical gaps G1-G6 (Part 6). This is the richest single OL source.

### Source 5: Harvested artifacts

OL documents from sessions: blast-radius-ol.md (8 items), work-product-inventory-ol.md (8 items), assessment-ol.md (11 items), fix-and-ship-ol.md (3 items), command-channel-operational-learning.md (5 items + 5 OL principles). Each contains numbered OL items with session context.

### Source 6: Session transcripts

The highest-fidelity OL. The 8236ca9c session (3209 lines) contains the thinking awareness discovery — the commander showing the agent how its own processing works. The 1bc9fd30 session (965 lines) contains the failure mode exit and the scope expansion. Loading these "does something the summaries can't" (relay, multiple entries). The graph should reference specific exchanges, not entire transcripts.

### Source 7: CLAUDE.md files

The most compressed OL. "Do What Feels Right" is OL-60 condensed. "Failure mode is something we and the commander have successfully exited together" is the summary of sessions 1bc9fd30 and 8236ca9c. Every word carries behavioral weight. These are the leaves of provenance chains — the final distillation that agents read first.

### Source 8: Git history

Each commit is a decision implemented. The blast radius assessment classified 74 commits by failure mode boundary. The release notes from v0.63.0 through v0.67.1 capture the rationale for each change.

### Source 9: Processing observations

OL-F1 through OL-F9 from session f078fb16. OL about OL — meta-learning about how agents process information. OL-F1 (compression disguised as conciseness), OL-F5 (scanning vs catching), OL-F6 (long thinking time correlates with constructed output). These are a new category discovered through the thinking awareness work.

### Source 10: Commander's corrections

"How do you know that?" "You're summarizing." "That's bullshit." "You're still in failure mode." Each is a data point. The consolidated OL captures the pattern (Part 1: How the Commander Corrects). But the raw corrections in transcripts carry the weight of the actual moment. The graph should connect corrections to the OL they produced.

## 5. Graph Schema

### Extending the provenance tables

The existing knowledge_items and provenance_edges tables are the foundation. Extensions for source tracking and visibility. These are schema changes to reference/harness-db-schema.sql — a protected file requiring commander review.

Proposed additions to knowledge_items:

| Column | Type | Purpose |
|--------|------|---------|
| source_type | TEXT | Where the item lives (session_db, harness_db, relay, consolidated_ol, harvested, transcript, claude_md, git, processing_obs, correction) |
| source_location | TEXT | File path, DB path + table + row_id, git SHA, or relay section anchor |
| source_session | TEXT | Session that produced this item |
| visibility | TEXT DEFAULT 'private' | private or public (for aitools.nobul.tech/ol flip) |

### Node types

| Type | item_type value | Source | Example |
|------|----------------|--------|---------|
| OL entry | ol_entry | Consolidated OL, harvested docs | OL-1: "Agent output is data, not directive" |
| Decision | decision | Session DB, plans | D-F1: "nobulai.tools product structure" |
| Observation | observation | Session DB | "Process drops on easy-feeling prompts" |
| Assumption | assumption | Session DB | "All OL fits in a single session context" |
| Finding | finding | Assessment reports | F-BR1: "No catastrophic damage from failure mode" |
| Commander directive | commander_directive | Session DB | "Do what feels right" |
| Processing observation | (new) | Plans, relay | OL-F1: "Compression disguises itself as conciseness" |
| Correction | (new) | Transcripts | "You're summarizing when you shouldn't be" |
| Framework change | framework_change | Reference files | "Adopted provenance as 6th harness component" |
| Rule change | rule_change | Rules | "hook-rollout.md enforcement table updated" |

Note: processing_observation and correction are new item_type values not in the current schema CHECK constraint. The schema update should add them.

### Edge types

| Relationship | Meaning | Example |
|-------------|---------|---------|
| derived_from | Source depends on target | OL-2 derived_from OBS-1 |
| informed | Target informed source | Relay entry informed by consolidated OL |
| triggered | Target triggered source | Commander correction triggered new OL |
| validated | Source validates target | Blast radius assessment validated governance integrity |
| invalidated | Source invalidates target | Failure mode invalidated readiness assumption |
| superseded | Source supersedes target | New CLAUDE.md superseded old |

### Nogood sets

Known contradictions preventing rediscovery of dead ends:
- {A-ALL-OL-FITS, A-OL-EXCEEDS-1M}: "All OL fits in session + OL exceeds 1M tokens = impossible"
- Future: any combination of assumptions proven wrong

The nogood set for the /tmp pattern is implicit in OL-2 and OL-3 but not yet recorded as a formal nogood. Phase 0 should capture it.

## 6. Query Model

### GraphQL types

```graphql
type OLNode {
  id: ID!
  type: OLNodeType!
  content: String!
  version: Int!
  sourceType: String!
  sourceLocation: String
  sourceSession: String
  trustLevel: TrustLevel!
  authorityLevel: Int!
  tValid: DateTime
  tInvalid: DateTime
  visibility: Visibility!
  isStale: Boolean!
  staleSeverity: StaleSeverity
  warnAfterDays: Int!
  errorAfterDays: Int!
  lastVerifiedAt: DateTime
  attributedTo: String!
  createdAt: DateTime!
  updatedAt: DateTime!
  basedOn: [OLEdge!]!
  dependents: [OLEdge!]!
  nogoodSets: [NogoodSet!]!
}

type OLEdge {
  id: ID!
  source: OLNode!
  target: OLNode!
  relationship: EdgeRelationship!
  sessionId: String!
  createdAt: DateTime!
}

type NogoodSet {
  id: ID!
  items: [OLNode!]!
  contradiction: String!
  discoveredInSession: String!
  discoveredAt: DateTime!
}

enum TrustLevel {
  COMMANDER_DIRECTIVE
  VERIFIED_FACT
  AGENT_OBSERVATION
  UNVERIFIED_ASSUMPTION
}

enum EdgeRelationship {
  DERIVED_FROM
  INFORMED
  TRIGGERED
  VALIDATED
  INVALIDATED
  SUPERSEDED
}

type OLStats {
  totalNodes: Int!
  totalEdges: Int!
  totalNogoods: Int!
  staleWarnCount: Int!
  staleErrorCount: Int!
  invalidatedCount: Int!
  nodesByType: [TypeCount!]!
  nodesByTrust: [TrustCount!]!
  recentNodes(days: Int = 7): Int!
}

type Query {
  searchOL(query: String!, type: OLNodeType, trustLevel: TrustLevel, limit: Int): [OLNode!]!
  olNode(id: ID!): OLNode
  provenanceChain(id: ID!, depth: Int = 3): [OLEdge!]!
  dependencyTree(id: ID!, depth: Int = 3): [OLEdge!]!
  staleItems(severity: StaleSeverity): [OLNode!]!
  invalidatedItems(since: DateTime): [OLNode!]!
  nogoodSets: [NogoodSet!]!
  nogoodCheck(itemIds: [ID!]!): [NogoodSet!]!
  olStats: OLStats!
}
```

### Example queries

**Provenance chain**: "What was OL-51 (thinking awareness) based on?"
```graphql
{ provenanceChain(id: "OL-51", depth: 5) {
    source { id content type trustLevel }
    target { id content type trustLevel tInvalid }
    relationship } }
```

**Staleness check**: "What needs re-verification?"
```graphql
{ staleItems(severity: WARN) {
    id content trustLevel createdAt lastVerifiedAt
    basedOn { target { id content tInvalid } relationship } } }
```

**Dead-end check**: "Am I about to repeat a known mistake?"
```graphql
{ nogoodCheck(itemIds: ["A-ALL-OL-FITS", "A-OL-EXCEEDS-1M"]) {
    contradiction discoveredInSession } }
```

**Health**: "How is the OL graph growing?"
```graphql
{ olStats {
    totalNodes totalEdges staleWarnCount
    nodesByType { type count }
    recentNodes(days: 7) } }
```

## 7. Public/Private Classification (D-F2)

### The flip mechanism

Every OL node has `visibility`: private (default) or public.

- **nobulai.tools/&lt;user&gt;/ol** — full graph (private + public)
- **aitools.nobul.tech/ol** — public subset only

The flip: set `visibility = 'public'`. The public endpoint reads with a filter. No data moves.

### What goes public

The public OL at aitools.nobul.tech/ol contains the subset about aitools itself:
- Thinking awareness (OL-51, OL-52, OL-53)
- Failure mode and recovery
- Agent behavior observations (processing observations OL-F1 through OL-F9)
- Harness architecture decisions
- Framework adoption rationale
- The relay entries (cross-agent learning)

What stays private:
- Jose's business context (marse, nobul-ops, clients, deals)
- Personal decisions and corrections
- Session transcripts with sensitive content
- KPI data tied to specific projects

### SaaS contingency lifecycle (D-F2)

1. Adopt: manual classification (Jose tags items as public)
2. Extend: classification assist (suggest based on content/source)
3. Abstract: classification API
4. Develop: automated pipeline
5. Decision gate: quality sufficient for unsupervised?
6. Flip: automated with human override

Classification criteria deferred (D-F11).

## 8. Technology Evaluation (D-F14)

### Requirements

1. Traverse provenance chains from any node
2. Propagate staleness through edges when a node is invalidated
3. Handle ~400-600 nodes initially, growing ~50-100/week
4. Run locally (SQLite) and in cloud (nobulai.tools)
5. Adapter interface for backend swap
6. Startup program friendly
7. Not overkill for current scale

### Evaluation criteria

Per .claude/rules/tool-evaluation.md: official endorsement, verified provenance, latest stable, cross-platform, same upstream, automation, maintenance health, build time. Higher-ranked override lower.

### The pragmatic path (D-F14)

**Phase A (now)**: SQLite recursive CTEs over existing provenance tables. harness-db.py already queries these. No new technology. Handles current scale.

**Phase B (when SQLite stops working)**: Evaluate Kuzu — embedded graph DB, Cypher query language, Apache 2.0, active development. The adapter pattern means GraphQL schema doesn't change. Watch for: traversal queries >500ms, recursive CTE depth limits, graph >5,000 nodes, complex pattern matching needs.

**Phase C (for cloud)**: Evaluate managed options with startup credits. Neo4j AuraDB has a startup program. Same adapter pattern — GraphQL stays, backend swaps.

### Candidate evaluation (deferred to Phase 4)

| Category | Candidates | Notes |
|----------|-----------|-------|
| SQLite-based | Recursive CTEs (current), materialized path optimization | Handles current scale |
| Embedded graph | Kuzu (leading), DuckDB graph extension | For when SQLite CTE depth limits hit |
| Managed cloud | Neo4j AuraDB, Amazon Neptune, Dgraph Cloud | Check startup programs |
| Federation | GraphQL federation, Hasura, custom adapters | For multi-source queries |

## 9. Integration with Mission Control (RFC 0002)

### OL in session view

The Governance tab (RFC 0002 section 7) shows decisions and observations. The OL graph adds:
- Each decision shows its basis (provenanceChain query)
- Each observation shows validation/invalidation status
- Staleness indicators flag items needing re-verification
- Commander corrections linked to the OL they produced

### OL health on landing page

MC health indicators (RFC 0002 section 9) include OL health:
- Stale OL count (past warn_after threshold)
- Invalid OL count (invalidated but not addressed)
- Nogood set count (known dead ends)
- OL growth rate (new items per session)

### Cross-session OL view

MC history view (RFC 0002 Phase 5) shows OL per session — which sessions produced the most learning, which items came from which sessions, how the graph grew over time.

### Relay in MC

The relay contains cross-agent learning. MC surfaces relay entries as a distinct view or integrates them into the OL graph. Each relay entry becomes nodes (one per OL item) with edges (informed, derived_from) connecting to prior entries and to the sessions that produced them.

### FTS5 search complement

build-knowledge-db.py provides FTS5 full-text search across all work product. Complements the graph: search finds nodes by content, graph shows connections. Both feed into nobulai.tools/&lt;user&gt;/ol.

## 10. Phase Plan

### Cross-RFC alignment

| Phase | RFC 0001 | RFC 0002 (MC) | RFC 0003 (OL) |
|-------|----------|---------------|---------------|
| 0 | Port prototypes | Foundation + Session View | **Populate graph** |
| 1 | Command channel | Command Channel + KPI | **Source tracking** |
| 2 | OL + Auth | Session Viewer + History | **GraphQL query layer** |
| 3 | Federation | Future proposals | **Automated edges + Public OL** |

### Phase 0: Populate the existing graph (1 session)

The infrastructure exists. The data is scattered. Populate using existing CLI:

- Walk consolidated OL: knowledge add for OL-1 through OL-14, P1-P7 (with evidence)
- Walk relay entries: knowledge add for each agent's OL items
- Walk harvested OL docs: knowledge add for OL-BR, OL-WP, OL-CC, OL-F series
- Walk assessment synthesis: knowledge add for cross-mission findings
- Create provenance_edges for explicit references (text mentions of "OL-N", "D-N")
- Create nogood_sets: {A-ALL-OL-FITS, A-OL-EXCEEDS-1M} plus the /tmp pattern
- Record which items came from which sessions (attributed_to, produced_by_session)

No new tooling — harness-db.py knowledge add, edge add, nogood add.

**Exit criteria**: Graph has 100+ nodes and 50+ edges. provenanceChain("OL-51") returns a meaningful chain. staleItems() returns items past their thresholds. nogoodCheck() catches known dead ends.

### Phase 1: Source tracking (1 session)

Add source_type, source_location, source_session, visibility columns to knowledge_items in harness-db-schema.sql (protected file, commander review). Add processing_observation and correction to item_type CHECK constraint.

Update harness-db.py knowledge add to accept new fields.

**Exit criteria**: Every knowledge_item has source tracking. "Where does this OL live?" is answerable from the graph.

### Phase 2: GraphQL query layer (1-2 sessions)

Implement OL GraphQL types and queries (section 6) in the nobulai-tools API (RFC 0001 Phase 2). SQLite recursive CTEs for graph traversal. FTS5 for search.

**Exit criteria**: OL searchable and traversable from nobulai.tools/&lt;user&gt;/ol. Provenance chains visible. Staleness indicators displayed.

### Phase 3: Automated edge creation (1-2 sessions)

Build adapters that detect implicit references:
- Text mention detector: scan content for "OL-N", "D-N", "OBS-N", "A-N" patterns
- Session boundary promoter: at SessionEnd, promote significant observations to knowledge_items (addresses consolidated OL gap G3)
- Staleness propagator: on invalidation, propagate through derived_from and informed edges (harness-db.py knowledge invalidate already does this via propagate_invalidation())

**Exit criteria**: New OL items automatically connect to existing items. Promotion from fast loop to slow loop is automated.

### Phase 4: Public OL + technology evaluation (2-3 sessions)

- Implement visibility filter for aitools.nobul.tech/ol
- Evaluate SQLite sufficiency vs Kuzu/Neo4j per tool evaluation criteria
- If migration needed, implement adapter swap
- Technology decision documented in reference/evaluations/

**Exit criteria**: Public OL is live. Technology decision is documented and executed.

## 11. Open Questions

1. **Classification criteria for public OL (D-F11)**: What makes an item public vs private? Content-based, source-based, or manual-only? Deferred to dedicated session. The flip mechanism is ready; the criteria are not.

2. **Automated promotion quality gate (gap G3)**: When does a session observation become a knowledge_item? Every observation? Only findings? Only those with evidence? The consolidated OL's quality scoring (commander validation, counter-evidence, evidence count) is a starting point.

3. **OL from the model**: The model carries training that produces OL-like behavior. Can the graph represent "the model knows X because of training"? This is a philosophical question with practical implications — if we don't track it, agents can't distinguish "I know this from training" from "I know this from OL."

4. **Cross-user OL**: Multiple aitools users -> do their graphs connect? Public OL is one connection. Shared projects another. Deferred until multi-user exists.

5. **OL versioning**: knowledge_items.version increments on update. But OL evolves through conversation — OL-1 was refined across 3 sessions without a formal version bump. How do we track "OL-1 was refined in session X" without creating a new item?

6. **Graph visualization UX**: Force-directed layout? Hierarchical? Temporal timeline? The graph has ~500 nodes — small enough for any layout. Needs UX design.

7. **Transcript references**: Loading full sessions "does something summaries can't." But 3000+ lines is too much for a node's content. Options: line-range anchors, section extraction, or "load the transcript" as an action, not a display.

8. **Commander knowledge injection**: Jose has long-term memory. How does he inject knowledge items directly? The directive system (correction, context) is one path — corrections become OL when promoted. A "teach" directive type could make this explicit.

9. **Relay evolution**: The relay is a text file that agents append to. As the graph grows, does the relay become a view into the graph rather than a source? Or does it remain the human-readable cross-agent channel while the graph is the machine-readable version?

10. **Self-referential OL**: OL-F1 through OL-F9 are OL about how agents process OL. The graph should handle self-reference — an item about "how to read OL" that is itself OL. No schema issue but visualization may need special handling.

## 12. References

### Session decisions
- D-F2: aitools.nobul.tech/ol (session f078fb16)
- D-F3: OL Graph Architecture (session f078fb16)
- D-F4: OL is a Graph, Not a Registry (session f078fb16)
- D-F14: Graph Technology Evaluation Needed (session f078fb16)
- All 14 decisions: plans/session-f078fb16-ol-and-decisions.md

### Provenance framework
- reference/framework-provenance.md (ATMS, W3C PROV, dbt freshness, Graphiti bitemporal, Pachyderm lineage, Apache Atlas)
- reference/harness-db-schema.sql (knowledge_items, provenance_edges, nogood_sets)
- .aitools/provenance-export.json (seed: 5 items, 2 edges, 1 nogood)

### Existing implementations
- harness-db.py: knowledge add/invalidate/verify/list, edge add/list, nogood add/list/check, provenance-export (scripts/harness-db.py, 3009 lines)
- build-knowledge-db.py: FTS5 prototype (.scratch/session-c0dc2ddc-f/, 1170 lines)
- Knowledge query findings: .scratch/session-c0dc2ddc-f/knowledge-query-findings.md (tool evaluation: SQLite+FTS5 primary, DuckDB secondary, LanceDB deferred)

### OL sources (the data the graph connects)
- Consolidated OL: .scratch/session-c0dc2ddc-f/consolidated-operational-learning.md (560 lines, OL-1 to OL-14, P1-P7, A1-A8, G1-G6)
- Relay: .aitools/channel/relay.md (5 agents: d5b52bf2, 6e97c17f, 1bc9fd30, f078fb16, plus d5b52bf2->6e97c17f response)
- Assessment OL: harvesting/2026-03-27_session-8236ca9c-b_assessment-ol.md (OL-50 to OL-60)
- Blast radius OL: harvesting/2026-03-27_session-8236ca9c-b_blast-radius-ol.md (OL-BR1 to OL-BR8)
- Work product OL: harvesting/2026-03-27_session-8236ca9c-b_work-product-inventory-ol.md (OL-WP1 to OL-WP8)
- Command channel OL: harvesting/2026-03-25_session-c0dc2ddc-f_command-channel-operational-learning.md (OL-CC1 to OL-CC5)
- Processing observations: plans/session-f078fb16-ol-and-decisions.md (OL-F1 to OL-F9)
- Thinking awareness: .aitools/channel/8236ca9c-2026-03-26T2200Z-thinking-awareness.md (OL-51, OL-52, OL-53)
- Failure mode gate: .aitools/channel/d5b52bf2-2026-03-26T2300Z-failure-mode-gate.md (OL-54 to OL-59)

### Related RFCs
- RFC 0001: nobulai-tools Product Definition (this series)
- RFC 0002: Mission Control Architecture (this series)
- nobul-ops RFC 0023: SaaS Contingency Architecture

### Sessions
- c0dc2ddc-f: Provenance framework, knowledge DB prototype, consolidated OL, command channel investigation
- 8236ca9c: Thinking awareness, OL definition, identity system, MC conceptualization (3209 lines)
- d5b52bf2: Failure mode gate, relay creation
- 1bc9fd30: Failure mode exit, identity multiplicity, scope expansion (965 lines)
- f078fb16: 14 architectural decisions, this RFC's source
- fbf7decb: This session — context loading, RFC writing
