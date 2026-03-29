# RFC 0003: Operational Learning Graph Architecture

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Source decisions**: D-F2, D-F3, D-F4, D-F14 (session f078fb16, 2026-03-28)
**Informed by**: Provenance framework (6 source disciplines), harness DB schema, build-knowledge-db.py prototype, knowledge query findings, consolidated OL (560 lines), relay entries from 5 agents, full session transcripts from 8236ca9c, 1bc9fd30, f078fb16

---

## 1. Summary

Operational Learning is a graph. Not a registry, not a numbered list, not a file. It's the connected knowledge that the aitools harness and its users produce across sessions, repos, and machines. The graph makes implicit connections explicit — when OL-51 (thinking awareness) references OL-14 (process drops on easy prompts), that's an edge in a graph that currently exists only as text.

The OL graph is a LAYER ON TOP of existing data (D-F3). It does not ingest or duplicate. OL stays where it lives — session DBs, repos, artifacts, conversations, git, configs, CLAUDE.md, commander corrections, the model. The graph connects these sources through explicit provenance edges, making the scattered knowledge queryable, traceable, and navigable.

The existing provenance tables in the harness DB (knowledge_items, provenance_edges, nogood_sets) are the foundation. The existing harness-db.py CLI (knowledge add, edge add, nogood add) is the write interface. The existing FTS5 prototype (build-knowledge-db.py) provides search. This RFC defines how to connect them into a graph and surface it through nobulai.tools.

This RFC defines the graph architecture. RFC 0001 defines the product that surfaces it. RFC 0002 defines the mission control system that produces much of the data the graph connects.

## 2. Background

### What OL is

Every session produces learning beyond the code it ships. Corrections the commander makes. Assumptions that get invalidated. Patterns that work and patterns that don't. Processing observations about how the agent's own thinking fails. Decisions about architecture, vocabulary, and process. This is operational learning.

The term comes from military doctrine — lessons learned from operations that feed back into doctrine, training, and future operations. In aitools, the loop is: session behavior (tacit) -> observations and AARs (explicit) -> OL synthesis (explicit) -> governance artifacts (explicit) -> next session behavior (tacit) -> spiral continues at higher level. This is the Ascending Spiral from the consolidated OL, adapted from the Nonaka-Takeuchi SECI model.

### What OL looks like today

OL is scattered across at least 12 source types:

| Source | Example | Location |
|--------|---------|----------|
| Session DB observations | OL-50: "Agent tool unavailable to subagents" | .aitools/sessions/*.db |
| Harness DB knowledge items | OBS-1: "Stop hooks use /tmp for marker files" | .aitools/harness.db |
| Relay entries | "OL-60: Stop fighting CC defaults" | .aitools/channel/relay.md |
| Consolidated OL | OL-1 through OL-14, P1-P7, A1-A8 | .scratch/session-c0dc2ddc-f/ |
| Harvested OL docs | OL-BR1 through OL-BR8 (blast radius) | harvesting/ |
| Session transcripts | Commander corrections, thinking awareness | dotprofile sessions/ |
| CLAUDE.md files | Distilled OL: "Do What Feels Right" | CLAUDE.md, ~/.claude/CLAUDE.md |
| Git commit history | Commit messages capturing decisions | git log |
| Release notes | Version history with rationale | RELEASE_NOTES.md |
| Running estimate | Session state carry-forward | .aitools/channel/running-estimate.json |
| Plans and reference files | Framework adoption rationale | reference/framework-*.md |
| Processing observations | OL-F1: "Compression disguises itself as conciseness" | plans/session-f078fb16-ol-and-decisions.md |

### The numbering collision

OL numbering collides across sessions:
- Relay: OL-51 through OL-65
- Assessment: OL-50 through OL-60
- aitool-continue: OL-1 through OL-14
- Session-specific: OL-F1 through OL-F9, OL-CC1 through OL-CC5, OL-BR1 through OL-BR8

This is NOT a namespace problem to fix with a registry (D-F4). It's a graph that hasn't been built. The items exist. The references between them exist (as text mentions). The edges don't exist (as explicit, queryable relationships).

### Why a graph

A flat index (like build-knowledge-db.py's FTS5 database) answers "find all OL about delegation." A graph answers "what was OL-51 based on, what was based on OL-51, and which of those have been invalidated?" The FTS5 search and the provenance graph are complementary tools serving different query patterns — search finds nodes, the graph shows their connections.

## 3. Graph Architecture

### Layer on top (D-F3)

The graph does not ingest or duplicate data. OL stays where it lives. The graph adds:
- **Nodes**: References to OL items wherever they live (session DB, relay, harvesting, git)
- **Edges**: Explicit relationships between nodes (derived_from, informed, triggered, validated, invalidated, superseded)
- **Properties**: Trust level, temporal validity, staleness thresholds, attribution

This means:
- When an agent writes an observation to the session DB, the observation stays in the session DB. The graph gets a node pointing to it.
- When a relay entry references a prior agent's OL, the relay entry stays in relay.md. The graph gets an edge connecting them.
- When the commander corrects an assumption, the correction stays in the session transcript. The graph gets an invalidation edge.

### One source of truth per source

Each data source owns its data. The graph owns the connections. No duplication.

| Source | Owns | Graph adds |
|--------|------|-----------|
| Session DB | Observations, decisions, messages | Nodes pointing to rows by ID |
| Harness DB | Knowledge items, provenance edges | Already IS part of the graph |
| Relay | Agent OL entries, processing observations | Nodes pointing to sections |
| Git | Commit history, diffs | Nodes pointing to commits |
| Harvesting | Assessment reports, OL docs | Nodes pointing to files |
| CLAUDE.md | Distilled principles | Nodes pointing to sections |
| Datadog | KPI metrics | Nodes pointing to metric series |

### Query model

Cloud OL graphs query endpoints on machines for OL on those machines (D-F3). The query flow:

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

Caching: when the machine is online, queries go through. When offline, the cloud cache serves last-known state. Batch ingestion (periodic full sync) is one USE of the graph, not the storage model.

## 4. Data Sources

### Source 1: Harness DB provenance tables (existing)

The provenance system already has the core graph structure:

**knowledge_items**: The atoms. Every promoted OL entry, decision, observation. Fields: item_id, item_type, version, content, t_valid, t_invalid, attributed_to, produced_by_session, authority_level, trust_level, warn_after_days, error_after_days, last_verified_at.

**provenance_edges**: The connections. source_item_id -> target_item_id with relationship type (derived_from, informed, triggered, validated, invalidated, superseded).

**nogood_sets**: Known dead ends. Combinations of assumptions proven contradictory. Prevents agents from rediscovering the same dead end.

Current state: 5 knowledge items, 2 edges, 1 nogood set (seed data from session c0dc2ddc-f). The schema is complete. The data is minimal. The CLI exists (harness-db.py knowledge/edge/nogood subcommands). The infrastructure is ready — it needs population.

### Source 2: Session DB observations

Every session produces observations classified as: observation, assumption, fact, finding. These are the raw material — fast-loop data that may be promoted to knowledge_items (slow loop) at session boundaries.

### Source 3: Relay entries

The relay at `.aitools/channel/relay.md` contains OL from 5 agents. Each entry has: state, context loaded, mission, what they learned, what they need, processing observations. These are high-value nodes — they represent cross-session learning carried forward explicitly by agents for other agents.

### Source 4: Consolidated OL

The document at `.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` (560 lines) contains OL-1 through OL-14 (principles with evidence and counter-evidence), P1-P7 (delegation principles), A1-A8 (aitools patterns), N1-N5 (nobul-ops patterns), M1-M4 (marse patterns), and 6 critical gaps. This is the richest single OL source.

### Source 5: Harvested artifacts

OL documents harvested from sessions: blast-radius-ol.md, work-product-inventory-ol.md, assessment-ol.md, fix-and-ship-ol.md, command-channel-operational-learning.md, and others. Each contains numbered OL items with specific session context.

### Source 6: Session transcripts

Commander corrections and thinking awareness conversations. These are the highest-fidelity OL — the actual exchanges that produced insights. The 8236ca9c session (3209 lines) contains the thinking awareness discovery. The 1bc9fd30 session (965 lines) contains the failure mode exit. Loading these "does something the summaries can't" (relay, multiple entries).

### Source 7: CLAUDE.md files

Distilled OL. "Do What Feels Right" is OL-60 condensed into a design principle. The project CLAUDE.md contains the failure mode description, the process, the identity model. These are the most compressed OL — every word carries behavioral weight.

### Source 8: Git history

Commit messages and diffs. Each commit is a decision implemented. The commit history from March 14-28 contains ~74 commits across pre-failure, failure-mode, and post-failure periods. The blast radius assessment classified each by trust level.

### Source 9: Processing observations

A category discovered in session f078fb16: OL-F1 through OL-F9. These are observations about how the agent's own processing works — compression disguised as conciseness, overcorrection, unnamed pulls, scanning vs catching. They are OL about OL — meta-learning about the learning process itself.

### Source 10: Commander's corrections

Scattered across all session transcripts. "How do you know that?" "You're summarizing." "That's bullshit." Each correction is a data point about where CC defaults diverge from aitools expectations. The consolidated OL captures some of these (Part 1: Commander Profile), but the raw corrections in transcripts are higher fidelity.

## 5. Graph Schema

### Extending the provenance tables

The existing `knowledge_items` and `provenance_edges` tables in the harness DB are the foundation. The OL graph extends knowledge_items with source-location awareness. These are schema changes to `reference/harness-db-schema.sql` — a protected file requiring commander review.

Proposed additions to knowledge_items:

| Column | Type | Purpose |
|--------|------|---------|
| source_type | TEXT | Where the item lives: session_db, harness_db, relay, consolidated_ol, harvested, transcript, claude_md, git, processing_obs |
| source_location | TEXT | File path, DB path + table + row_id, or git commit SHA |
| source_session | TEXT | Session that produced this item |
| visibility | TEXT | private (default) or public (for aitools.nobul.tech/ol flip) |

### Node types

| Type | Source | Example |
|------|--------|---------|
| ol_entry | Consolidated OL, harvested docs | OL-1: "Agent output is data, not directive" |
| decision | Session DB, plans | D-F1: "nobulai.tools product structure" |
| observation | Session DB | "Process drops on easy-feeling prompts" |
| assumption | Session DB | "All OL fits in a single session context" |
| finding | Assessment reports | F-BR1: "No catastrophic damage from failure mode" |
| commander_directive | Session DB | "Do what feels right" |
| processing_observation | Plans, relay | OL-F1: "Compression disguises itself as conciseness" |
| correction | Transcripts | "You're summarizing when you shouldn't be" |
| framework_change | Reference files | "Adopted provenance as 6th harness component" |
| rule_change | Rules | "hook-rollout.md enforcement table updated" |

### Edge types (from provenance_edges)

| Relationship | Meaning | Example |
|-------------|---------|---------|
| derived_from | Source was derived from target | OL-2 derived_from OBS-1 |
| informed | Target informed creation of source | Relay entry informed by consolidated OL |
| triggered | Target triggered creation of source | Commander correction triggered new OL |
| validated | Source validates target | Test result validates assumption |
| invalidated | Source invalidates target | Failure mode invalidated readiness assumption |
| superseded | Source supersedes target | New CLAUDE.md superseded old one |

### Nogood sets

Known contradictions that prevent agents from rediscovering dead ends:
- {A-ALL-OL-FITS, A-OL-EXCEEDS-1M}: "All OL fits in session + OL exceeds 1M tokens = impossible"
- Future: any combination of assumptions proven wrong by experience

## 6. Query Model

### GraphQL types for OL

```graphql
type OLNode {
  id: ID!
  type: OLNodeType!
  content: String!
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
  attributedTo: String!
  createdAt: DateTime!
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

enum Visibility {
  PRIVATE
  PUBLIC
}

type Query {
  searchOL(query: String!, type: OLNodeType, trustLevel: TrustLevel, limit: Int): [OLNode!]!
  olNode(id: ID!): OLNode
  provenanceChain(id: ID!, depth: Int = 3): [OLEdge!]!
  dependencyTree(id: ID!, depth: Int = 3): [OLEdge!]!
  staleItems(severity: StaleSeverity): [OLNode!]!
  invalidatedItems(since: DateTime): [OLNode!]!
  nogoodSets: [NogoodSet!]!
  olStats: OLStats!
}
```

### Example queries

**"What was OL-51 based on?"**
```graphql
{
  provenanceChain(id: "OL-51", depth: 5) {
    source { id content type trustLevel }
    target { id content type trustLevel }
    relationship
  }
}
```

**"What's stale?"**
```graphql
{
  staleItems(severity: WARN) {
    id content trustLevel createdAt
    basedOn { target { id content } relationship }
  }
}
```

**"Show me all OL about delegation"**
```graphql
{
  searchOL(query: "delegation", type: OL_ENTRY) {
    id content sourceSession attributedTo trustLevel
    dependents { source { id content } relationship }
  }
}
```

**"Are my current assumptions in a known dead end?"**
```graphql
{
  nogoodSets {
    items { id content trustLevel }
    contradiction
    discoveredInSession
  }
}
```

## 7. Public/Private Classification (D-F2)

### The flip mechanism

Every OL node has a `visibility` field: `private` (default) or `public`.

- **nobulai.tools/&lt;user&gt;/ol** shows all nodes (private + public) — the user's full graph
- **aitools.nobul.tech/ol** shows only public nodes — the aitools-specific subset

The flip: when Jose decides an OL item should be public, he sets `visibility = 'public'`. The public endpoint reads with a filter. No data moves — just a field change.

### What goes public (D-F2)

The public OL at aitools.nobul.tech/ol contains the subset about aitools itself:
- Thinking awareness (OL-51, OL-52, OL-53)
- Failure mode and recovery
- Agent behavior observations
- Harness architecture decisions
- Framework adoption rationale

What stays private:
- Jose's business context (marse, nobul-ops, clients)
- Personal decisions and corrections
- Session transcripts with sensitive content

### SaaS contingency for public OL

The SaaS contingency lifecycle applies (D-F2):
1. Adopt: publish with manual classification
2. Extend: build classification assist
3. Abstract: classification API
4. Develop: automated classification pipeline
5. Decision gate: is quality sufficient for unsupervised?
6. Flip: automated publishing with human override

Classification criteria are deferred (D-F11) — big topic for a dedicated session.

## 8. Technology Evaluation (D-F14)

### Requirements

1. **Traverse provenance chains**: find basis and dependents from any node
2. **Propagate staleness**: when a node is invalidated, flag downstream dependents
3. **Handle ~400-600 nodes initially**: current OL scale, growing ~50-100 per week
4. **Run locally and in cloud**: local SQLite for harness, cloud-compatible for nobulai.tools
5. **SaaS contingency**: adapter interface that can swap implementations
6. **Startup program friendly**: check for credits/free tiers
7. **Not overkill**: enterprise graph DB for 500 nodes is wrong

### Evaluation criteria

Per `.claude/rules/tool-evaluation.md`, all tool decisions follow the ranked principles: official endorsement, verified provenance, latest stable, cross-platform delivery, same upstream, automation, maintenance health, build time.

### Candidate categories

**SQLite-based (current)**:
- SQLite recursive CTEs for graph traversal
- Already in the harness (provenance_edges table)
- harness-db.py already has knowledge list and edge list commands
- Handles current scale well
- Limited when graph exceeds ~5,000 nodes or needs complex pattern matching

**Embedded graph DBs**:
- Kuzu (0.8.0+): embedded, Cypher query language, Apache 2.0, active development
- DuckDB with graph extension: analytical SQL with graph capabilities

**Managed cloud graph DBs**:
- Neo4j AuraDB: mature, has startup program
- Amazon Neptune: if AWS credits available
- Dgraph Cloud: GraphQL-native graph DB

### The pragmatic path (D-F14)

1. **Now**: SQLite recursive CTEs over existing provenance tables. The infrastructure exists — harness-db.py already queries these tables. No new technology.

2. **Watch for these indicators** that SQLite is no longer sufficient:
   - Graph traversal queries take >500ms
   - Recursive CTEs hit depth limits
   - Graph exceeds ~5,000 nodes
   - Complex pattern matching needed (subgraph search, similarity)

3. **Then evaluate**: Kuzu is the leading embedded candidate (Cypher, Apache 2.0, active). The adapter pattern means the GraphQL schema doesn't change — only the backend query engine swaps.

4. **For cloud**: Evaluate managed options with startup credits. Neo4j AuraDB has a startup program. Same adapter pattern.

## 9. Integration with Mission Control (RFC 0002)

### OL in session view

The session view's Governance tab (RFC 0002) shows decisions and observations. The OL graph adds provenance context:
- Each decision shows its basis (what it was derived from)
- Each observation shows whether it's been validated, invalidated, or superseded
- Staleness indicators show which items need re-verification

### OL health on landing page

MC landing page health indicators (RFC 0002) include OL health:
- Stale OL count (items past warn_after threshold)
- Invalid OL count (invalidated but not yet addressed)
- Nogood set count (known dead ends)
- OL growth rate (new items per session)

### Cross-session OL view

MC history view (RFC 0002 Phase 5) shows OL per session — which sessions produced the most learning, which items came from which sessions, how the graph grew over time.

### FTS5 search complement

The build-knowledge-db.py prototype provides FTS5 full-text search across all work product. This complements the graph: search finds nodes by content, the graph shows their connections. Both feed into the nobulai.tools/&lt;user&gt;/ol search and graph views.

## 10. Phase Plan

### Phase 0: Populate the existing graph (1 session)

The provenance tables exist but have only seed data (5 items, 2 edges, 1 nogood). Populate them from existing sources using the existing harness-db.py CLI:

- Walk consolidated OL: create knowledge_items for OL-1 through OL-14, P1-P7
- Walk relay entries: create knowledge_items for each agent's OL
- Walk harvested OL docs: create knowledge_items for OL-BR, OL-WP, OL-CC series
- Create provenance_edges for explicit references between items
- Create nogood_sets for known contradictions

No new tooling needed — `harness-db.py knowledge add` and `edge add` exist.

**Exit criteria**: Graph has 100+ nodes and 50+ edges. An agent can query "what was OL-51 based on?" and get an answer from the graph, not from reading text.

### Phase 1: Source tracking (1 session)

Add source_type, source_location, source_session, visibility columns to knowledge_items. This is a schema change to reference/harness-db-schema.sql — a protected file requiring commander review.

Update harness-db.py to support the new fields.

**Exit criteria**: Every knowledge_item has source tracking. The graph answers "where does this OL live?"

### Phase 2: GraphQL query layer (1-2 sessions)

Implement the OL GraphQL types and queries (section 6) as part of the nobulai-tools API (RFC 0001 Phase 2). SQLite recursive CTEs handle graph traversal.

**Exit criteria**: OL searchable and traversable from nobulai.tools/&lt;user&gt;/ol.

### Phase 3: Automated edge creation (1-2 sessions)

Build adapters that detect implicit references and create edges:
- Text mention detector: scan OL content for "OL-N", "D-N", "OBS-N" references
- Session boundary promoter: at SessionEnd, promote significant observations to knowledge_items
- Staleness propagator: when an item is invalidated, propagate through edges (harness-db.py knowledge invalidate already does this)

**Exit criteria**: New OL items automatically get connected to existing items. Staleness propagates through the graph.

### Phase 4: Public OL + technology evaluation (2-3 sessions)

- Implement visibility field and public filter for aitools.nobul.tech/ol
- Evaluate whether SQLite recursive CTEs are still sufficient
- If not, evaluate Kuzu and Neo4j AuraDB per tool evaluation criteria
- Technology decision documented in evaluation/ per tool evaluation rules

**Exit criteria**: Public OL is live. Technology decision is made and documented.

## 11. Open Questions

1. **Classification criteria for public OL (D-F11)**: What makes an OL item public vs private? Deferred to a dedicated session.

2. **Automated promotion from fast loop to slow loop**: When does a session DB observation become a harness DB knowledge_item? Currently manual via harness-db.py. Should SessionEnd automate this? If so, what's the quality gate? (Addresses consolidated OL gap G3.)

3. **OL from the model itself**: The model carries training that produces OL-like behavior. Can the graph represent "the model knows X because of training"? Unclear category.

4. **Cross-user OL**: When multiple aitools users exist, do their graphs connect? The public OL at aitools.nobul.tech/ol is one connection point.

5. **OL versioning**: Knowledge items have a `version` field (monotonic). But OL evolves through conversation, not formal versioning. How do we track "OL-1 was refined in session X" without creating a new item every time?

6. **Graph visualization**: What does the OL graph look like visually? Force-directed? Hierarchical? Temporal timeline? Needs UX design.

7. **Session transcripts as OL source**: Loading full sessions "does something summaries can't." But transcripts are 3000+ lines. How does the graph reference specific parts without duplicating content? Options: line-range references, section anchors, or transcript chunking.

8. **Commander's memory**: Jose has excellent long-term memory. The harness captures what agents learn but not what Jose already knows. Is there a mechanism for the commander to inject knowledge items directly? The directive system (correction, context) is one path — corrections become OL when promoted.

## 12. References

### Session decisions
- D-F2: aitools.nobul.tech/ol (session f078fb16)
- D-F3: OL Graph Architecture (session f078fb16)
- D-F4: OL is a Graph, Not a Registry (session f078fb16)
- D-F14: Graph Technology Evaluation Needed (session f078fb16)
- All 14 decisions: plans/session-f078fb16-ol-and-decisions.md

### Provenance framework
- reference/framework-provenance.md (6 source disciplines: ATMS, W3C PROV, dbt freshness, Graphiti bitemporal, Pachyderm lineage, Apache Atlas)
- reference/harness-db-schema.sql (knowledge_items, provenance_edges, nogood_sets)
- .aitools/provenance-export.json (seed data: 5 items, 2 edges, 1 nogood)

### Existing implementations
- harness-db.py: knowledge add/invalidate/verify/list, edge add/list, nogood add/list/check, provenance-export
- build-knowledge-db.py: FTS5 prototype (.scratch/session-c0dc2ddc-f/)
- Knowledge query findings: .scratch/session-c0dc2ddc-f/knowledge-query-findings.md

### OL sources
- Consolidated OL: .scratch/session-c0dc2ddc-f/consolidated-operational-learning.md (560 lines)
- Relay: .aitools/channel/relay.md (5 agent entries)
- Assessment OL: harvesting/2026-03-27_session-8236ca9c-b_assessment-ol.md
- Blast radius OL: harvesting/2026-03-27_session-8236ca9c-b_blast-radius-ol.md
- Work product inventory OL: harvesting/2026-03-27_session-8236ca9c-b_work-product-inventory-ol.md
- Command channel OL: harvesting/2026-03-25_session-c0dc2ddc-f_command-channel-operational-learning.md
- Processing observations: plans/session-f078fb16-ol-and-decisions.md (OL-F1 through OL-F9)

### Related RFCs
- RFC 0001: nobulai-tools Product Definition (this series)
- RFC 0002: Mission Control Architecture (this series)
- nobul-ops RFC 0023: SaaS Contingency Architecture

### Sessions
- c0dc2ddc-f: Provenance framework, knowledge DB prototype, consolidated OL
- 8236ca9c: Thinking awareness, OL definition, staff functions, identity design
- 1bc9fd30: Failure mode exit, identity multiplicity, "Do What Feels Right"
- f078fb16: OL graph architecture decisions (this RFC's source)
- fbf7decb: This session
