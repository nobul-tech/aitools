---
# RFC 0003: Operational Learning Graph Architecture

- **Status**: Draft
- **Created**: 2026-03-28
- **Author**: Jose (via Claude Code, session f078fb16)
- **Linked**: RFC 0001 (nobulai-tools Product Definition), RFC 0002 (Mission Control Architecture), reference/framework-provenance.md

**Intent**: **Purpose**: Define the architecture for the operational learning graph — a federated knowledge graph that connects OL items across all locations without duplicating data, enabling search, traversal, provenance tracking, and the self-learning loop. **Scope**: Graph architecture (layer on top, federated), where OL lives (8 layers), graph technology evaluation criteria, relationship to existing provenance system and knowledge DB, public OL at aitools.nobul.tech/ol, batch ingestion, and federation with external systems. NOT MC features (RFC 0002). NOT product infrastructure (RFC 0001). NOT OL classification (deferred). **Audience**: Jose (decision-maker), any session implementing OL features in nobulai-tools, any session working on the provenance system.

## What OL Means

OL is a graph, not a registry. The numbering collision across sessions (relay OL-51-65, assessment OL-50-60, aitool-continue OL-1-14) is not a namespace problem to fix with a registry — it's a graph that hasn't been built (D-F4).

From session f078fb16, OL lives in 8 layers:

1. **Conversation context** — what agents and commander produce in conversation. Ephemeral unless externalized. Lost when session ends unless captured.
2. **Extended thinking** — processing observations in the model's thinking. Preserved in JSONL transcript archive. Never extracted to any database. Mostly lost.
3. **Session DB** — observations table (per-session SQLite). Written by agents via harness-db.py or batch scripts. Per-session, gitignored.
4. **JSON export** — running-estimate.json exported at SessionEnd. Tracked in git for cross-machine carry-forward.
5. **Tracked artifacts** — relay entries, handoff prompts, harvested artifacts, channel files. Carried forward via git.
6. **Codified governance** — rules, skills, hooks, frameworks, reference files, CLAUDE.md, incidents. Each IS codified OL. The slow-loop output.
7. **Cross-session provenance** — harness DB knowledge_items, provenance_edges, nogood_sets. Currently 5 seed items from one session.
8. **The model itself** — training, weights, the substrate.

The graph connects items ACROSS all these layers. A rule was created because of an incident. The incident was discovered during a session. The session was informed by the relay. The relay was written by an agent that read a full session transcript. All of those are nodes. All of those connections are edges.

## Core Architecture Principles

### The graph is a layer on top (D-F3)
- Does NOT ingest or duplicate data
- OL stays where it lives
- The graph stores EDGES and METADATA that link items across locations
- One source of truth per source — no duplication
- Traversing the graph means querying the source for content

### Federation
- Cloud OL graphs query OL endpoints on user machines for OL on those machines
- Cloud OL graphs query each other for OLs they each have
- Cloud OL graphs connect to external sources (GitHub commits, Datadog KPIs, Vercel deployments)
- Each external source is queried via its own API adapter
- Caching for query results with staleness tracking

### Batch ingestion is a USE, not the model
- Batch ingestion from all OL sources feeds the self-learning loop
- The graph enables ingestion by knowing WHERE everything is
- But the graph itself doesn't store the ingested content — it stores connections

## Relationship to Existing Systems

### Provenance System (harness DB)
The provenance system (framework-provenance.md) already defines:
- knowledge_items table with: item_id, item_type, version, content, bitemporal timestamps (t_valid/t_invalid), attribution, authority levels (L0-L3), staleness thresholds, trust levels (commander_directive > verified_fact > agent_observation > unverified_assumption)
- provenance_edges table with: source → target, relationship types (derived_from, informed, triggered, validated, invalidated, superseded)
- nogood_sets table with: item combinations known to contradict
- Dependency-directed invalidation: when an item is invalidated, propagation flags all downstream dependents

Current state: 5 seed items, 2 edges, 1 nogood set. The schema and CLI exist. The graph doesn't.

The OL graph EXTENDS the provenance system to cover all 8 layers, not just items manually promoted to knowledge_items. The provenance tables become the CORE of the graph — the highest-quality, most-verified nodes. Other nodes (from session DBs, git, artifacts) connect to these core nodes but live in their own stores.

### Knowledge DB (build-knowledge-db.py)
The knowledge DB (~/.aitools/knowledge.db) provides FTS5 full-text search over all work product. It indexes: plans, reference docs, rules, harvested artifacts, session transcripts, git logs, incidents, release notes, OL, JSON files, other repos.

The knowledge DB makes content SEARCHABLE. The OL graph makes connections TRAVERSABLE. Together: search finds the node, the graph shows what it's connected to.

The knowledge DB has its own provenance table (source_id, target_id, relation, confidence) — marked "future use." This table should be deprecated in favor of the OL graph's edge system to avoid duplication.

### Existing OL Artifacts
The OL items scattered across the harness are the CONTENT that should be nodes in the graph:
- ~95 formal OL items (OL-1 through OL-14 in aitool-continue, OL-50-60 in assessment, OL-51-65 in relay, OL-HD1-10, OL-BR1-8, OL-WP1-8, OL-CC1-5, etc.)
- 13 incorrect assumptions traced (IA-1 through IA-13)
- 10 audit findings (F-1 through F-10)
- 8 open incidents
- 25 rules (each is codified OL)
- 22 skills (each is codified OL process)
- 15 hooks (each is executable OL)
- 74+ git commits
- 42 reference files
- Hundreds of harvested artifacts

These exist. The graph makes their connections explicit.

## Graph Technology

### Evaluation Criteria (D-F14)
Follow tool evaluation criteria (.claude/rules/tool-evaluation.md) + SaaS contingency (RFC 0023):

| Criterion | What it means for graph tech |
|-----------|------------------------------|
| Credits availability | Check for startup programs before signing up |
| Adapter interface | Build graph query abstraction, backend swappable |
| Open source | Self-hosted option as contingency |
| Scale | For 1 user: ~500-1000 nodes, ~2000-5000 edges. For N users: N x nodes_per_user + shared nodes |

### Pragmatic Path
1. **Now**: Graph query layer (GraphQL) over existing stores (SQLite session DBs, harness DB, git, external APIs)
2. **When scale requires**: Add a proper graph database behind the same query interface
3. **When credits arrive**: Evaluate managed options (Neptune on AWS, AuraDB on Neo4j Cloud)
4. **Always**: Adapter interface pattern. Backend swappable. Never locked in.

### Candidate Technologies (from training data — needs verification via /aitool-eval)

| Technology | Type | Open Source | Managed Cloud | Notes |
|-----------|------|------------|--------------|-------|
| Neo4j | Property graph | Community (GPLv3) | AuraDB | Most popular, Cypher query, has startup program |
| Amazon Neptune | Property graph + RDF | No | AWS only | Would use AWS Activate credits if obtained |
| ArangoDB | Multi-model | Apache 2.0 | ArangoDB Cloud | Document + Graph + KV |
| Dgraph | GraphQL-native | Apache 2.0 | Dgraph Cloud | Distributed |
| SurrealDB | Multi-model | BSL -> Apache | SurrealDB Cloud | SQL + graph |

For linked data / federation:
- GraphQL federation (Apollo Federation) — query layer across sources
- W3C PROV + SPARQL — standard for distributed provenance (already adopted in framework-provenance.md)

## Public OL: aitools.nobul.tech/ol (D-F2)

The public aitools OL graph is a SUBSET of Jose's OL graph, filtered by classification:
- For-now private, flips to public when ready
- Contains OL about aitools itself: thinking awareness, failure mode, agent behavior, harness architecture, frameworks
- SaaS contingency lifecycle applies: adopt (build private) -> extend (classify) -> abstract (public/private filter) -> develop (public view) -> decision gate -> flip

Classification mechanism: deferred (D-F11). This is a big topic requiring a dedicated session.

## Data Sources and Adapters

| Source | Adapter | What it provides to the graph |
|--------|---------|------------------------------|
| Session DBs (local SQLite) | Local machine endpoint | Observations, decisions, messages, delegations, missions, events |
| Harness DB (local SQLite) | Local machine endpoint | knowledge_items, provenance_edges, nogood_sets, KPI events, session index |
| Knowledge DB (local SQLite) | Local machine endpoint | FTS5 search results, document metadata, tags |
| Dotprofile repo (git) | Git adapter | Session JSONL archives, profile, session history |
| aitools repo (git) | Git adapter | Rules, skills, hooks, reference files, harvesting artifacts, git log |
| GitHub API | GitHub adapter | Commits, PRs, issues as OL nodes |
| Datadog API | Datadog adapter (with Axiom contingency) | KPI metrics as OL nodes |
| Relay (markdown) | File adapter | Agent entries with OL items, cross-agent communication |
| CLAUDE.md files | File adapter | Coaching items, standing orders, design principles |

## The Self-Learning Loop

The OL graph enables the ascending spiral (from consolidated-operational-learning.md Part 5):

```
Session behavior (tacit)
    -> Externalization: observations + AARs (explicit, recorded in session DB)
    -> Promotion to knowledge_items (explicit, harness DB)
    -> Dependency graph construction (provenance_edges)
    -> Staleness/invalidation propagation
    -> Commander review of flagged items
    -> Governance artifacts updated
    -> Next session behavior (informed by cleaner knowledge)
```

The OL graph makes this loop VISIBLE and QUERYABLE. The commander can see: what was learned, what it was based on, whether the basis is still valid, and what would be affected if it were invalidated.

## Open Questions

| # | Question | Suggested Answer |
|---|----------|-----------------|
| 1 | Graph DB technology? | Start with GraphQL layer over existing stores, evaluate proper DB per criteria |
| 2 | OL classification (public vs private)? | Deferred to dedicated session |
| 3 | How to connect items across OL numbering systems? | Graph edges, not renumbering. Each item keeps its original ID. Edges connect them. |
| 4 | Automated edge creation? | Phase 2 — text analysis to detect implicit references, propose edges for commander review |
| 5 | Graph visualization? | Evaluate force-directed, hierarchical, and timeline views |
| 6 | Federation protocol? | GraphQL federation for internal sources, REST adapters for external APIs |
| 7 | Thinking OL extraction? | Phase 3 — extract from JSONL archives using read-session-full.py patterns |

## Implementation Phases

| Phase | What | Depends on |
|-------|------|-----------|
| 0 | GraphQL schema for OL queries (search, traverse, provenance) | RFC 0001 repo exists |
| 0 | Port knowledge DB search to GraphQL resolver | Phase 0 |
| 1 | OL graph view in nobulai-tools (basic node + edge visualization) | Phase 0 |
| 1 | Adapter for local machine endpoint (read provenance data) | Data path from RFC 0002 |
| 2 | Automated edge detection (text analysis for implicit references) | Phase 1 |
| 2 | External source adapters (GitHub, Datadog) | Phase 1 |
| 3 | Public OL view at aitools.nobul.tech/ol | Classification mechanism designed |
| 3 | Thinking OL extraction from JSONL archives | Phase 2 |
| 4 | Proper graph DB evaluation and migration | Scale requires it |

## Test Plan

| # | Test | Verifies |
|---|------|----------|
| 1 | GraphQL OL search returns results | Search works |
| 2 | Graph traversal: given node, find all derived_from ancestors | Traversal works |
| 3 | Invalidation propagation: invalidate node, dependents flagged | Provenance works |
| 4 | Nogood check: detect known contradiction in assumption set | Safety mechanism works |
| 5 | External adapter: GitHub commits appear as OL nodes | Federation works |
| 6 | Offline: graph shows cached data when machine is off | Caching works |
| 7 | Public filter: aitools.nobul.tech/ol shows only classified-public items | Classification works |
