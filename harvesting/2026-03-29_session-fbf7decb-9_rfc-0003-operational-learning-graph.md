# RFC 0003: Operational Learning Graph Architecture

- **Status**: Final
- **Created**: 2026-03-28
- **Author**: Jose (via Claude Code, sessions f078fb16 and fbf7decb)
- **Linked**: RFC 0001 (nobulai-tools Product Definition), RFC 0002 (Mission Control Architecture), reference/framework-provenance.md, harness-db-schema.sql

**Intent**: **Purpose**: Define the architecture for the operational
learning graph -- a federated knowledge graph that connects OL items
across all locations without duplicating data, enabling search,
traversal, provenance tracking, and the self-learning loop that makes
aitools a knowledge system rather than a configuration manager.
**Scope**: Graph architecture (layer on top, federated), data sources
(8 layers of OL), graph schema (extending provenance tables),
query model (GraphQL), public/private classification mechanism,
technology evaluation criteria, candidate technologies, pragmatic
implementation path, and integration with mission control.
NOT MC features (RFC 0002). NOT product infrastructure (RFC 0001).
NOT OL classification criteria (deferred, D-F11).
**Audience**: Jose (decision-maker), any session implementing OL
features in nobulai-tools, any session working on the provenance
system or knowledge DB.

---

## 1. Summary

Operational learning (OL) is the knowledge that agents and the
commander produce across sessions -- processing observations,
architectural decisions, corrections, assumptions traced to their
sources, and the governance artifacts that codify all of it. Today
OL exists in at least 8 layers, from ephemeral conversation context
to the model's training weights, with no explicit connections between
them.

This RFC defines the OL graph: a federated knowledge graph that
makes implicit connections explicit. The graph is a layer on top --
it stores edges and metadata linking items across locations, not
copies of the items themselves. Content stays where it lives. The
graph makes it traversable and queryable.

The architecture extends the existing provenance system
(knowledge_items, provenance_edges, nogood_sets in the harness DB)
to cover all 8 layers, uses GraphQL as the query interface, and
follows a pragmatic path from SQLite graph queries now to a proper
graph database when scale requires it.

---

## 2. Background

### 2.1 What OL is

OL is a graph, not a registry. The numbering collision across
sessions -- relay OL-51-65, assessment OL-50-60, aitool-continue
OL-1-14 -- is not a namespace problem to fix with a registry. It is
a graph that has not been built (D-F4, session f078fb16).

The items exist across session DBs, relay entries, assessment
reports, scratch files, and harvesting artifacts. They reference each
other, but the references are implicit (text mentions, not edges in
a graph). A rule was created because of an incident. The incident
was discovered during a session. The session was informed by the
relay. The relay was written by an agent that read a full session
transcript. All of those are nodes. All of those connections are
edges. None of the edges exist in any data store today.

### 2.2 Where OL lives today (8 layers)

From session f078fb16, OL exists in 8 layers ordered from most
ephemeral to most permanent:

| Layer | What | Persistence | Current state |
|-------|------|-------------|---------------|
| 1. Conversation context | What agents and commander produce in conversation | Ephemeral -- lost when session ends unless captured | Unstructured, JSONL archives in dotprofile repo |
| 2. Extended thinking | Processing observations in the model's thinking blocks | Preserved in JSONL transcript archive, never extracted | Mostly lost -- extraction requires read-session-full.py |
| 3. Session DB | observations table (per-session SQLite) | Per-session, gitignored, machine-local | Written by agents via harness-db.py or batch scripts |
| 4. JSON export | running-estimate.json exported at SessionEnd | Tracked in git for cross-machine carry-forward | Active -- SessionEnd hook exports |
| 5. Tracked artifacts | Relay entries, handoff prompts, harvested artifacts, channel files | Tracked in git | 74+ harvested artifacts, 5 relay entries, channel files |
| 6. Codified governance | Rules, skills, hooks, frameworks, reference files, CLAUDE.md, incidents | Tracked in git -- the slow-loop output | 25 rules, 22 skills, 15 hooks, 42 reference files, 8 incidents |
| 7. Cross-session provenance | Harness DB knowledge_items, provenance_edges, nogood_sets | Machine-local SQLite, exportable to JSON | 5 seed items, 2 edges, 1 nogood set |
| 8. The model itself | Training, weights, the substrate | Anthropic's infrastructure | Immutable from our perspective |

### 2.3 Why a graph

Three problems converge:

**Implicit references**: OL-2 says "never treat another agent's
output as directive." Incident I5 documents the exact case where
this was violated. The rule `.claude/rules/governed-data-access.md`
codifies the prevention layer. These three artifacts reference each
other by meaning, but no data store records the connection. An agent
encountering any one of them has no way to discover the others
except full-text search and reading.

**Scattered provenance**: The provenance system (framework-provenance.md)
defines dependency-directed invalidation -- when an assumption is
falsified, everything derived from it should be flagged. This only
works if the dependency edges exist. Today, 5 seed knowledge items
and 2 edges exist in the harness DB. The other 500+ items across all
layers have no edges at all.

**The self-learning loop**: aitools is a self-learning system. The
ascending spiral (session behavior -> observations -> promotion ->
dependency graph -> staleness propagation -> commander review ->
governance update -> next session) requires a graph to function.
Without it, each session starts with whatever context fits in 1M
tokens and hopes it finds the right knowledge. With it, each session
can query: what is this based on? is the basis still valid? what
would break if I change it?

### 2.4 Current scale

| Category | Count |
|----------|-------|
| Formal OL items (OL-1 through OL-65, OL-F1-F9, etc.) | ~95 |
| Incorrect assumptions traced (IA-1 through IA-13) | 13 |
| Audit findings (F-1 through F-10) | 10 |
| Open incidents | 8 |
| Rules (each is codified OL) | 25 |
| Skills (each is codified OL process) | 22 |
| Hooks (each is executable OL) | 15 |
| Git commits | 74+ |
| Reference files | 42 |
| Harvested artifacts | 74+ |
| Session DBs with structured data | ~10 |
| Session JSOLs in archive | ~15 |

Total addressable nodes: ~400-600 now. For N users of nobulai.tools:
N x nodes_per_user + shared nodes (aitools repo content).

---

## 3. Graph Architecture

### 3.1 Core principle: layer on top (D-F3)

The graph does NOT ingest or duplicate data. OL stays where it
lives:

- Session observations stay in session DBs
- Rules stay in `.claude/rules/`
- Relay entries stay in `.aitools/channel/relay.md`
- Git commits stay in git
- KPIs stay in Datadog
- JSONL transcripts stay in dotprofile repo

The graph stores:

- **Node references**: pointers to items in their source locations
  (source_type + source_id + source_location)
- **Edges**: typed relationships between nodes (derived_from,
  informed, triggered, validated, invalidated, superseded)
- **Metadata**: classification, trust level, temporal validity,
  staleness thresholds
- **Cached content**: optional cached content for offline/fast
  access, with staleness tracking

One source of truth per source. No duplication.

### 3.2 Federation

The OL graph is federated across machines and cloud services:

```
nobulai.tools/jose/ol (cloud graph)
    |
    |-- queries --> Jose's MacBook (local endpoint)
    |                   |-- session DBs
    |                   |-- harness DB
    |                   |-- knowledge DB (FTS5)
    |                   |-- git repos
    |
    |-- queries --> Jose's Windows workstation (local endpoint)
    |                   |-- session DBs
    |                   |-- harness DB
    |                   |-- knowledge DB (FTS5)
    |                   |-- git repos
    |
    |-- queries --> GitHub API (commits, PRs, issues)
    |-- queries --> Datadog API (KPIs)
    |-- queries --> aitools.nobul.tech/ol (public OL graph)
```

- Cloud OL graphs query OL endpoints on machines for machine-local
  OL
- Cloud OL graphs query each other for OLs they each have
- Cloud OL graphs connect to external OL sources (GitHub, Datadog,
  Vercel)
- Caching mechanisms for queries: when a machine goes offline, the
  cloud graph serves cached data with a "last synced" timestamp
- Each external source is queried via its own API adapter (same
  adapter pattern as RFC 0001)

### 3.3 Batch ingestion is a USE, not the model

Batch ingestion from all OL sources (build-knowledge-db.py scans
session transcripts, plans, reference docs, rules, harvested
artifacts, git log, incidents, release notes, OL, running estimate)
is one use of the OL graph. The graph enables ingestion by knowing
WHERE everything is. But the graph itself stores connections, not
the ingested content.

The knowledge DB (build-knowledge-db.py, FTS5 full-text search over
all work product) makes content SEARCHABLE. The OL graph makes
connections TRAVERSABLE. Together: search finds the node, the graph
shows what it is connected to.

---

## 4. Data Sources

Every data source has an adapter that exposes its OL as graph nodes
and edges.

| Source | Adapter | Node types | Edge sources |
|--------|---------|------------|-------------|
| Session DBs (local SQLite) | Local machine endpoint | observations, decisions, messages, missions, delegations, events | Explicit: derived_from_ids annotations. Implicit: agent read-before-write inference |
| Harness DB (local SQLite) | Local machine endpoint | knowledge_items (promoted), provenance_edges, nogood_sets, KPI events, session index | Existing provenance_edges table |
| Knowledge DB (local SQLite) | Local machine endpoint | FTS5 search results, document metadata, tags | Knowledge DB provenance table (to be deprecated in favor of OL graph edges) |
| Dotprofile repo (git) | Git adapter | Session JSONL archives, profile.json, session history | Text analysis of JSONL content |
| aitools repo (git) | Git adapter | Rules, skills, hooks, reference files, harvesting artifacts, git commits, incidents, frameworks | Cross-reference links (`@` links in rules, skill cross-references, incident affected/linked fields) |
| GitHub API | GitHub adapter | Commits, PRs, issues | Commit messages referencing OL items, PR descriptions |
| Datadog API | Datadog adapter (Axiom contingency) | KPI metrics (hook fire count, delegation compliance, staleness counts) | Temporal correlation with session events |
| Relay (markdown) | File adapter | Agent entries with OL items, cross-agent communication | Text references between entries, OL item citations |
| CLAUDE.md files | File adapter | Coaching items, standing orders, design principles, key decisions | Cross-references to rules, incidents, frameworks |
| Commander corrections | Session transcript analysis | Corrections, redirects, approvals, rejections | Session context: which agent behavior triggered which correction |

---

## 5. Graph Schema

The graph schema extends the existing provenance tables (harness DB)
to cover all 8 OL layers. The provenance tables become the CORE of
the graph -- the highest-quality, most-verified nodes. Other nodes
connect to these core nodes but live in their own stores.

### 5.1 Node schema

Nodes are references to items in their source locations. They
extend the existing `knowledge_items` table with source-location
awareness.

```sql
-- OL Graph nodes: references to items across all 8 layers.
-- Extends knowledge_items with source-location tracking.
-- Core nodes (layer 7, promoted to knowledge_items) have content
-- stored directly. All other nodes store a reference to content
-- in its source location.
CREATE TABLE IF NOT EXISTS ol_nodes (
    node_id TEXT PRIMARY KEY,           -- globally unique (format: <source_type>:<source_id>)
    node_type TEXT NOT NULL
        CHECK (node_type IN (
            -- From knowledge_items (layer 7)
            'observation', 'assumption', 'fact', 'finding',
            'decision', 'ol_entry', 'rule_change', 'framework_change',
            'commander_directive', 'commander_correction',
            -- From session DBs (layer 3)
            'session_observation', 'session_decision', 'session_message',
            'mission', 'delegation',
            -- From tracked artifacts (layer 5)
            'relay_entry', 'handoff', 'harvested_artifact',
            'channel_file',
            -- From codified governance (layer 6)
            'rule', 'skill', 'hook', 'framework', 'reference_file',
            'incident', 'claude_md_section',
            -- From external sources
            'git_commit', 'github_issue', 'github_pr',
            'kpi_metric', 'kpi_event',
            -- From conversation/thinking (layers 1-2)
            'conversation_excerpt', 'thinking_observation',
            -- Meta
            'nogood_set', 'session'
        )),

    -- Source location (where the content lives)
    source_type TEXT NOT NULL
        CHECK (source_type IN (
            'harness_db',      -- knowledge_items table (layer 7)
            'session_db',      -- per-session SQLite (layer 3)
            'knowledge_db',    -- FTS5 knowledge DB
            'git_file',        -- file in a git repo (layers 5, 6)
            'git_commit',      -- git commit
            'json_export',     -- running-estimate.json (layer 4)
            'github_api',      -- GitHub API
            'datadog_api',     -- Datadog API
            'jsonl_archive',   -- session JSONL (layers 1, 2)
            'inline'           -- content stored directly in this node
        )),
    source_id TEXT NOT NULL,            -- ID within the source system
    source_location TEXT,               -- path, URL, or query to retrieve content

    -- Display
    title TEXT NOT NULL,                -- human-readable title
    summary TEXT,                       -- optional short summary (for graph visualization)

    -- Cached content (for offline/fast access)
    cached_content TEXT,                -- cached copy of source content
    cached_at TEXT,                     -- ISO 8601 UTC: when cache was last refreshed
    cache_stale BOOLEAN DEFAULT 0,      -- set to 1 when source is known to have changed

    -- Classification
    visibility TEXT NOT NULL DEFAULT 'private'
        CHECK (visibility IN ('private', 'public', 'team')),

    -- Attribution (W3C PROV)
    attributed_to TEXT NOT NULL,        -- 'commander' | 'agent' | agent_name | 'system'
    produced_by_session TEXT,           -- session_id
    produced_by_mission TEXT,           -- mission_id

    -- Trust and authority (Apache Atlas classification)
    authority_level INTEGER NOT NULL DEFAULT 1
        CHECK (authority_level BETWEEN 0 AND 3),
        -- L0: system-generated (hooks, automation)
        -- L1: agent-produced (default)
        -- L2: agent-produced, commander-reviewed
        -- L3: commander-directive (highest authority)
    trust_level TEXT NOT NULL DEFAULT 'agent_observation'
        CHECK (trust_level IN (
            'commander_directive', 'verified_fact',
            'agent_observation', 'unverified_assumption'
        )),

    -- Temporal validity (Graphiti bitemporal model)
    t_valid TEXT,                       -- ISO 8601 UTC: when fact became true
    t_invalid TEXT,                     -- ISO 8601 UTC: when superseded (null = current)

    -- Staleness tracking (dbt freshness model)
    warn_after_days INTEGER DEFAULT 30,
    error_after_days INTEGER DEFAULT 90,
    last_verified_at TEXT,              -- ISO 8601 UTC

    -- Lifecycle
    created_at TEXT NOT NULL,           -- ISO 8601 UTC
    updated_at TEXT NOT NULL            -- ISO 8601 UTC
);

CREATE INDEX IF NOT EXISTS idx_oln_type ON ol_nodes(node_type);
CREATE INDEX IF NOT EXISTS idx_oln_source ON ol_nodes(source_type);
CREATE INDEX IF NOT EXISTS idx_oln_trust ON ol_nodes(trust_level);
CREATE INDEX IF NOT EXISTS idx_oln_session ON ol_nodes(produced_by_session);
CREATE INDEX IF NOT EXISTS idx_oln_valid ON ol_nodes(t_invalid);
CREATE INDEX IF NOT EXISTS idx_oln_visibility ON ol_nodes(visibility);
```

### 5.2 Edge schema

Edges extend the existing `provenance_edges` table with additional
relationship types and metadata.

```sql
-- OL Graph edges: typed relationships between nodes.
-- Extends provenance_edges to cover all 8 layers.
-- Direction: source_node_id --[relationship]--> target_node_id
CREATE TABLE IF NOT EXISTS ol_edges (
    edge_id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_node_id TEXT NOT NULL REFERENCES ol_nodes(node_id),
    target_node_id TEXT NOT NULL REFERENCES ol_nodes(node_id),
    relationship TEXT NOT NULL
        CHECK (relationship IN (
            -- From provenance_edges (existing)
            'derived_from',     -- source was derived from target
            'informed',         -- target informed creation of source
            'triggered',        -- target triggered creation of source
            'validated',        -- source validates target
            'invalidated',      -- source invalidates target
            'superseded',       -- source supersedes target
            -- New relationships for cross-layer connections
            'codified_from',    -- rule/skill codified from OL entry or incident
            'corrected_by',     -- agent behavior corrected by commander feedback
            'discovered_in',    -- item discovered in session
            'references',       -- text reference (@ link, citation)
            'implements',       -- code/config implements a decision
            'contradicts',      -- item contradicts another (pre-nogood)
            'related_to'        -- general association (weakest type)
        )),

    -- Edge metadata
    confidence REAL DEFAULT 1.0,        -- 0.0-1.0: how certain is this edge?
    edge_source TEXT NOT NULL DEFAULT 'manual'
        CHECK (edge_source IN (
            'manual',           -- human or agent explicitly created
            'provenance_system',-- from existing provenance_edges table
            'cross_reference',  -- detected from @ links in files
            'text_analysis',    -- detected from text similarity/mentions
            'git_analysis',     -- detected from git blame/log
            'temporal',         -- detected from temporal correlation
            'system'            -- system-generated (e.g., session contains observation)
        )),

    -- Lifecycle
    created_at TEXT NOT NULL,           -- ISO 8601 UTC
    session_id TEXT                     -- session where edge was recorded (null for system)
);

CREATE INDEX IF NOT EXISTS idx_ole_source ON ol_edges(source_node_id);
CREATE INDEX IF NOT EXISTS idx_ole_target ON ol_edges(target_node_id);
CREATE INDEX IF NOT EXISTS idx_ole_rel ON ol_edges(relationship);
CREATE INDEX IF NOT EXISTS idx_ole_confidence ON ol_edges(confidence);
```

### 5.3 Nogood sets

The existing `nogood_sets` table from harness-db-schema.sql applies
unchanged. Nogood sets reference `ol_nodes` by node_id.

```sql
-- Retained from harness-db-schema.sql, references ol_nodes.
-- When the harness discovers that a combination of assumptions
-- leads to a contradiction, recording the set prevents future
-- agents from rediscovering the same dead end.
CREATE TABLE IF NOT EXISTS ol_nogood_sets (
    nogood_id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_ids TEXT NOT NULL,             -- JSON array of node_id strings
    contradiction TEXT NOT NULL,        -- human-readable description
    discovered_in_session TEXT NOT NULL,
    discovered_at TEXT NOT NULL         -- ISO 8601 UTC
);
```

### 5.4 Relationship to existing provenance tables

The existing provenance tables (`knowledge_items`,
`provenance_edges`, `nogood_sets` in harness-db-schema.sql) are the
seed data for the OL graph. Migration path:

1. Each `knowledge_items` row becomes an `ol_nodes` row with
   `source_type = 'harness_db'`
2. Each `provenance_edges` row becomes an `ol_edges` row with
   `edge_source = 'provenance_system'`
3. Each `nogood_sets` row becomes an `ol_nogood_sets` row
4. The original tables remain as the write target for the
   provenance hot path (session boundary promotion). A sync step
   mirrors new items to `ol_nodes`/`ol_edges`.

The knowledge DB's `provenance` table (source_id, target_id,
relation, confidence -- currently marked "future use") should be
deprecated in favor of `ol_edges` to avoid edge duplication.

---

## 6. Query Model

### 6.1 GraphQL as the query interface

The OL graph is queried through the nobulai.tools GraphQL API
(RFC 0001). GraphQL is natural for graph traversal queries:

```graphql
type OLNode {
    id: ID!
    nodeType: String!
    title: String!
    summary: String
    content: String                  # resolved from source or cache
    sourceType: String!
    sourceLocation: String

    # Classification
    visibility: Visibility!
    trustLevel: TrustLevel!
    authorityLevel: Int!

    # Temporal
    tValid: DateTime
    tInvalid: DateTime
    lastVerifiedAt: DateTime
    isStale: Boolean!
    staleSeverity: StaleSeverity     # warn or error

    # Attribution
    attributedTo: String!
    session: Session

    # Graph traversal
    derivedFrom: [OLEdge!]!          # what this is based on
    informedBy: [OLEdge!]!           # what informed this
    triggeredBy: [OLEdge!]!          # what triggered this
    validates: [OLEdge!]!            # what this validates
    invalidates: [OLEdge!]!          # what this invalidates
    supersedes: [OLEdge!]!           # what this supersedes
    codifiedFrom: [OLEdge!]!         # what OL this codifies
    allEdges: [OLEdge!]!             # all edges (any direction)

    # Dependency analysis
    dependents: [OLNode!]!           # everything derived from this
    ancestors: [OLNode!]!            # everything this is derived from
    nogoodSets: [NogoodSet!]!        # contradictions involving this node
}

type OLEdge {
    id: ID!
    source: OLNode!
    target: OLNode!
    relationship: String!
    confidence: Float!
    edgeSource: String!              # manual, text_analysis, etc.
    createdAt: DateTime!
}

type NogoodSet {
    id: ID!
    nodes: [OLNode!]!
    contradiction: String!
    discoveredInSession: Session!
}

type Query {
    # Search
    olSearch(query: String!, filters: OLSearchFilters): [OLNode!]!

    # Direct lookup
    olNode(id: ID!): OLNode

    # Traversal
    olAncestors(nodeId: ID!, depth: Int = 3): [OLNode!]!
    olDependents(nodeId: ID!, depth: Int = 3): [OLNode!]!
    olPath(fromId: ID!, toId: ID!): [OLEdge!]

    # Analysis
    olStaleItems(severity: StaleSeverity): [OLNode!]!
    olNogoodSets: [NogoodSet!]!
    olInvalidationImpact(nodeId: ID!): [OLNode!]!

    # Statistics
    olStats: OLStats!
}

input OLSearchFilters {
    nodeTypes: [String!]
    trustLevels: [TrustLevel!]
    visibility: Visibility
    sessionId: String
    dateRange: DateRange
    isStale: Boolean
    minConfidence: Float
}
```

### 6.2 Query resolution

Queries resolve through the adapter chain:

1. **GraphQL query** arrives at nobulai.tools API
2. **Router** determines which adapters to query based on
   source_type of nodes
3. **Adapters** query their data sources:
   - Local machine endpoint adapter queries session/harness/knowledge
     DBs via the machine's local API
   - Git adapter reads from cloned repos
   - GitHub/Datadog adapters call external APIs
4. **Edge resolver** follows edges to connected nodes, potentially
   across adapters
5. **Cache layer** serves cached content when source is unavailable
   (machine offline)
6. **Response** assembled and returned

### 6.3 Example queries

**"What is OL-2 based on?"**
```graphql
{
  olNode(id: "ol_entry:OL-2") {
    title
    content
    ancestors(depth: 5) {
      title
      nodeType
      trustLevel
      isStale
    }
  }
}
```

**"What would break if I invalidate this assumption?"**
```graphql
{
  olInvalidationImpact(nodeId: "assumption:sessions-hold-all-ol") {
    title
    nodeType
    trustLevel
    # Returns: all nodes transitively derived from this assumption
  }
}
```

**"Show me all stale OL items"**
```graphql
{
  olStaleItems(severity: WARN) {
    title
    nodeType
    lastVerifiedAt
    staleSeverity
    dependents { title }
  }
}
```

**"Find OL about failure mode"**
```graphql
{
  olSearch(query: "failure mode", filters: {
    trustLevels: [COMMANDER_DIRECTIVE, VERIFIED_FACT]
  }) {
    title
    content
    attributedTo
    session { sessionId startedAt }
  }
}
```

---

## 7. Public/Private Classification

### 7.1 The flip mechanism (D-F2)

aitools.nobul.tech/ol is the for-now private place for the aitools
PUBLIC OL graph. It contains the SUBSET of Jose's OL that is about
aitools itself: thinking awareness, failure mode, agent behavior,
harness architecture, frameworks.

The flip mechanism:

1. Every `ol_nodes` row has a `visibility` field: `private`
   (default), `public`, or `team`
2. Jose's personal OL graph (nobulai.tools/jose/ol) shows all
   visibility levels
3. aitools.nobul.tech/ol queries Jose's graph with a
   `visibility = 'public'` filter
4. The classification of items as public vs private is a human
   decision -- the commander reviews and classifies

When ready, the flip is a DNS + routing change:
aitools.nobul.tech/ol serves the public-filtered view of the
nobulai.tools OL graph.

### 7.2 SaaS contingency lifecycle for the flip

The path from private to public follows the SaaS contingency
lifecycle (RFC 0023):

| Stage | Action |
|-------|--------|
| Adopt | Build the private OL graph, classify items |
| Extend | Add classification UI, review workflows |
| Abstract | Public/private filter as a query parameter |
| Develop | Public view with appropriate styling and navigation |
| Decision gate | Commander reviews: does this represent aitools well? |
| Flip | DNS + routing: aitools.nobul.tech/ol serves public view |

### 7.3 Classification criteria (deferred, D-F11)

The criteria for classifying OL items as public vs private is a
significant topic deferred to a dedicated session. Considerations
include:

- Personal business information (always private)
- Processing observations about the model (potentially public --
  useful for the AI safety community)
- Architectural decisions about aitools (potentially public --
  useful for aitools users)
- Commander corrections (mixed -- some reveal methodology, some
  reveal personal context)
- Session transcripts (mostly private -- contain raw conversation)
- Codified governance (potentially public -- rules and frameworks
  are the harness's value)

---

## 8. Technology Evaluation Criteria

### 8.1 Requirements (D-F14)

Jose does not yet know how to best store, grow, and maintain graphs.
The technology evaluation must follow tool evaluation criteria
(`.claude/rules/tool-evaluation.md`) combined with SaaS contingency
constraints.

| Criterion | What it means for graph tech |
|-----------|------------------------------|
| Official endorsement | Prefer technologies with strong community backing |
| Verified provenance | Open source with clear governance |
| Latest stable version | Active development, not abandoned |
| Cross-platform delivery | Must run on macOS and Windows (local) or be cloud-hosted |
| Automation and deployment | Must be scriptable, not GUI-only |
| Maintenance health | Active community, regular releases |
| Credits availability | Check for startup programs before signing up for managed services |
| Adapter interface | Build graph query abstraction so backend is swappable |
| Open source contingency | Self-hosted option must exist as fallback |
| Scale fit | For 1 user now: ~500-1000 nodes, ~2000-5000 edges. For N users: N x nodes_per_user + shared nodes |

### 8.2 Graph database categories

| Category | Examples | Strengths | Tradeoffs |
|----------|----------|-----------|-----------|
| Property graph | Neo4j, Amazon Neptune, Memgraph | Native graph traversal, Cypher/Gremlin query languages, optimized for path queries | Requires dedicated infrastructure, learning curve |
| Multi-model with graph | ArangoDB, SurrealDB, DuckDB (with extensions) | Combine document/KV/graph in one engine, SQL-like queries | Graph features may be secondary |
| RDF/triple store | Apache Jena, Blazegraph, Oxigraph | W3C standards, SPARQL, federation built-in | Verbose, steeper learning curve |
| SQLite with graph queries | sqlite-utils + recursive CTEs | Zero infrastructure, already in use, portable | No native graph operations, CTE performance at depth |
| Embedded graph | Kuzu, TypeDB | Low-overhead, embeddable, optimized for analytics | Newer, smaller communities |
| GraphQL federation | Apollo Federation | Query layer across distributed sources | Not a storage engine -- needs backing stores |

---

## 9. Candidate Technologies

These candidates are from training data and require verification
via the `/aitool-eval` skill before selection.

### 9.1 Graph databases

| Technology | Type | License | Managed Cloud | Startup Program | Notes |
|-----------|------|---------|--------------|-----------------|-------|
| Neo4j | Property graph | GPLv3 (Community), Commercial (Enterprise) | AuraDB | Neo4j Startup Program exists | Most popular, Cypher query language, extensive tooling |
| Amazon Neptune | Property graph + RDF | Proprietary | AWS | AWS Activate for Startups | Would use AWS credits if obtained; avoid until credits secured |
| ArangoDB | Multi-model | Apache 2.0 | ArangoDB Cloud (Oasis) | Needs verification | Document + Graph + KV; AQL query language |
| Dgraph | GraphQL-native | Apache 2.0 | Dgraph Cloud | Needs verification | Distributed, GraphQL as native query language |
| SurrealDB | Multi-model | BSL (-> Apache 2.0) | SurrealDB Cloud | Needs verification | SQL-like + graph; newer |
| Memgraph | Property graph | BSL (Community), Commercial | Memgraph Cloud | Needs verification | In-memory, Cypher compatible |
| Kuzu | Embedded property graph | MIT | N/A (embedded) | N/A | Embeddable, fast analytical queries, newer |

### 9.2 SQLite graph approaches

| Approach | Tool | Notes |
|----------|------|-------|
| Recursive CTEs | sqlite3 stdlib | Traverse edges via WITH RECURSIVE; works for shallow graphs (<10 depth) |
| sqlite-utils | sqlite-utils (GREEN eval) | CLI + Python lib; recommended as primary tool for harness DB |
| FTS5 + graph | build-knowledge-db.py | Already built; combines text search with future provenance table |

### 9.3 Federation layer

| Technology | Type | Notes |
|-----------|------|-------|
| Apollo Federation | GraphQL federation | Query layer across multiple GraphQL subgraphs |
| GraphQL Mesh | GraphQL gateway | Transforms REST/SQL/other APIs into GraphQL |
| W3C PROV + SPARQL federation | RDF standard | Already adopted in framework-provenance.md conceptually |

### 9.4 Evaluation action items

1. Check which graph database providers have startup programs
   (Neo4j, ArangoDB, SurrealDB, Memgraph)
2. Evaluate embedded options (Kuzu) for local graph operations
   without server infrastructure
3. Evaluate GraphQL federation (Apollo, Mesh) as the query layer
   regardless of storage backend
4. Run `/aitool-eval` on top candidates before any selection

---

## 10. Pragmatic Path

### 10.1 Phased approach (D-F14)

The technology path follows the pragmatic principle: use what works
now, evaluate alternatives when scale requires them, adopt managed
options when credits arrive.

**Phase A (now): Graph query layer over existing stores**

- GraphQL schema defines the OL graph interface (types, queries,
  mutations)
- Resolvers query existing SQLite databases (session DBs, harness
  DB, knowledge DB) using recursive CTEs for traversal
- `ol_nodes` and `ol_edges` tables added to the harness DB
  (SQLite) as the local graph store
- build-knowledge-db.py extended to populate `ol_nodes` from its
  document scan
- Cross-reference detection (@ links in rules, incident
  affected/linked fields) generates edges automatically
- No new infrastructure required

**Phase B (when local graph queries become slow): Embedded graph DB**

- Evaluate Kuzu or similar embedded graph engine
- Same GraphQL interface, different resolver backend
- No server infrastructure required
- Benchmark: when recursive CTE traversals at depth 5+ exceed
  500ms consistently

**Phase C (when cloud graph needed): Managed graph DB**

- Evaluate managed options with startup credits (Neo4j AuraDB,
  Neptune via AWS Activate, etc.)
- Same GraphQL interface, cloud resolver backend
- The adapter IS the contingency: when the provider flips, the
  adapter handles it

**Always: Adapter interface pattern**

- Backend is swappable at every phase
- GraphQL schema is the contract
- Resolvers are the adapters
- Never locked in to any storage engine

### 10.2 Why SQLite works for now

- Already in use for session DBs and harness DB
- Python sqlite3 is the only guaranteed tool across all platforms
  (including Windows Git Bash where sqlite3 CLI is unavailable)
- Recursive CTEs handle graph traversal for graphs under 10K nodes
- FTS5 is built in -- search and graph in one engine
- WAL mode handles concurrent readers
- Zero deployment overhead
- The provenance tables already exist with 5 seed items

### 10.3 When SQLite stops working

SQLite is not optimized for deep graph traversal (>5 hops),
pattern matching across large graphs, or concurrent writes from
multiple cloud API connections. Indicators that it is time to
evaluate alternatives:

- Recursive CTE queries at depth 5+ consistently exceed 500ms
- Node count exceeds 10K
- Edge count exceeds 50K
- Cloud graph needs concurrent writes from multiple adapters
- Graph pattern queries (find all paths between A and B with
  constraints) become common

---

## 11. Integration with Mission Control

The OL graph integrates with MC (RFC 0002) at multiple points:

### 11.1 Session view: provenance tab

A new tab in the MC session view showing the provenance context
for the current session:

- What knowledge items the session's decisions are based on
- Which of those items are stale
- Which assumptions are in active nogood sets
- What the session has produced (new nodes, new edges)

### 11.2 Governance tab: OL links

The existing governance tab (decisions + observations) gains
OL graph links:

- Each decision links to its OL ancestors (what it was based on)
- Each observation links to related OL items (what confirms or
  contradicts it)
- Stale items are visually flagged

### 11.3 Landing page: OL health

The MC landing page gains an OL health indicator per session:

- How many stale items are in the session's context
- Whether any active nogood sets apply to the session's assumptions
- Whether the session has produced new OL (nodes, edges, nogood
  sets)

### 11.4 Cross-session OL view

The OL graph view at nobulai.tools/<user>/ol is a standalone
visualization, but it links back to MC sessions:

- Click a node to see which sessions produced or consumed it
- Click a session to jump to its MC view
- Filter the graph by session, date range, project, trust level

---

## 12. Phase Plan

| Phase | Deliverable | Depends on | Estimated effort |
|-------|-------------|-----------|-----------------|
| 0a | `ol_nodes` and `ol_edges` tables in harness-db-schema.sql | None | Small |
| 0b | GraphQL schema for OL queries (search, traverse, provenance) | RFC 0001 repo exists | Medium |
| 0c | Extend build-knowledge-db.py to populate `ol_nodes` from document scan | Phase 0a | Medium |
| 0d | Cross-reference detection: scan @ links in rules/references, generate edges | Phase 0a | Medium |
| 0e | Port knowledge DB FTS5 search to GraphQL resolver | Phase 0b | Medium |
| 1a | OL graph view in nobulai-tools (basic node + edge visualization) | Phase 0b, 0c, 0d | Large |
| 1b | Adapter for local machine endpoint (read provenance data via tunnel/relay) | Data path from RFC 0002 | Large |
| 1c | Migrate existing provenance_edges to ol_edges, knowledge_items to ol_nodes | Phase 0a | Small |
| 2a | Automated edge detection (text analysis for implicit references between OL items) | Phase 1a | Large |
| 2b | External source adapters (GitHub commits, Datadog KPIs as OL nodes) | Phase 1b | Medium |
| 2c | MC integration: provenance tab, governance OL links, landing page OL health | Phase 1a, RFC 0002 Phase 0 | Medium |
| 3a | Public OL view at aitools.nobul.tech/ol | Classification mechanism designed (D-F11) | Medium |
| 3b | Thinking OL extraction from JSONL archives (layer 2 nodes) | Phase 2a, read-session-full.py | Large |
| 3c | OL classification UI for commander review of public/private items | Phase 3a | Medium |
| 4a | Graph technology evaluation (/aitool-eval on candidates) | Scale requires it | Medium |
| 4b | Migration from SQLite to evaluated graph DB | Phase 4a evaluation complete | Large |

---

## 13. Open Questions

| # | Question | Suggested Answer | Status |
|---|----------|-----------------|--------|
| 1 | Graph DB technology selection? | Start with SQLite + recursive CTEs behind GraphQL. Evaluate proper graph DB per criteria in Section 8 when scale indicators (Section 10.3) are hit. | Deferred to Phase 4 |
| 2 | OL classification: public vs private criteria? | Deferred to dedicated session. See Section 7.3 for initial considerations. | Deferred (D-F11) |
| 3 | How to connect items across OL numbering systems? | Graph edges, not renumbering. Each item keeps its original ID as source_id. node_id uses format `<source_type>:<source_id>` (e.g., `ol_entry:OL-2`, `rule:governed-data-access`). Edges connect them. | Decided (D-F4) |
| 4 | Automated edge creation? | Phase 2a. Text analysis detects implicit references (OL item citations, @ links, session references). Proposed edges presented for commander review with confidence scores. Manual edges always available. | Phased |
| 5 | Graph visualization technology? | Evaluate force-directed (d3-force, vis.js), hierarchical (dagre), and timeline views. Start with force-directed for exploration, add hierarchical for provenance chains. | Needs evaluation |
| 6 | Federation protocol for internal sources? | GraphQL federation (Apollo Federation or GraphQL Mesh) for internal sources. REST adapters for external APIs (GitHub, Datadog). | Needs evaluation |
| 7 | Thinking OL extraction from JSONL? | Phase 3b. Use read-session-full.py patterns to extract processing observations from extended thinking blocks. High value but high effort -- thinking blocks contain the most honest processing observations. | Phased |
| 8 | How does the knowledge DB's provenance table relate? | Deprecated in favor of ol_edges. The knowledge DB retains FTS5 search. Edge data moves to the OL graph. | Decided |
| 9 | Node ID format across federated graphs? | `<source_type>:<source_id>` is unique within one user's graph. Across users, prefix with user ID: `<user>:<source_type>:<source_id>`. | Suggested, needs validation |
| 10 | How do agents query the OL graph during sessions? | Phase 1b. Via harness-db.py CLI (local queries) or nobulai.tools GraphQL API (cloud queries). Hot path: local SQLite is fast enough (<5ms). Cloud queries go through the adapter chain. | Phased |

---

## 14. References

### Source decisions
- D-F2, D-F3, D-F4, D-F11, D-F14: Session f078fb16
  (`plans/session-f078fb16-ol-and-decisions.md`)

### RFCs
- RFC 0001: nobulai-tools Product Definition
  (`plans/nobulai-tools/0001-product-definition.draft.md`)
- RFC 0002: Mission Control Architecture
  (`plans/nobulai-tools/0002-mission-control-architecture.draft.md`)
- RFC 0023: SaaS Contingency (nobul-ops)

### Framework documentation
- Provenance framework:
  `reference/framework-provenance.md`
- Harness architecture:
  `reference/harness.md`
- Three-layer governance:
  `reference/framework-three-layer-governance.md`
- Framework adoption:
  `reference/framework-adoption.md`

### Schema and prototypes
- Harness DB schema:
  `reference/harness-db-schema.sql`
- Knowledge DB prototype:
  `harvesting/2026-03-25_session-c0dc2ddc-f_build-knowledge-db.py`

### Source disciplines (from framework-provenance.md)
1. Truth maintenance (de Kleer ATMS, 1986) -- dependency-directed
   invalidation, nogood sets
2. Derivation chains (W3C PROV, 2013) -- entities, activities,
   agents, wasDerivedFrom
3. Staleness tracking (dbt source freshness) -- warn_after,
   error_after thresholds
4. Bitemporal knowledge (Graphiti/Zep, Rasmussen 2025) -- t_valid,
   t_invalid, created_at
5. Automatic lineage (Pachyderm) -- system-captured provenance,
   immutable versioning
6. Metadata governance (Apache Atlas) -- trust-level classification
   taxonomy

### Operational learning
- Processing observations OL-F1 through OL-F9: Session f078fb16
- Relay OL-51 through OL-65: `.aitools/channel/relay.md`
- Consolidated OL (560 lines):
  Session c0dc2ddc-f consolidated-operational-learning.md
- Provenance export: 5 knowledge items, 2 edges, 1 nogood set
  (seed data in harness DB)

---

*Produced by session fbf7decb, 2026-03-28. Source decisions from
session f078fb16. Schema extends harness-db-schema.sql. Architecture
extends framework-provenance.md.*
