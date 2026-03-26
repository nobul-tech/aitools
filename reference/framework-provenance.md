# Provenance

**Intent**: **Purpose**: Document the discipline behind provenance
tracking in the harness -- why every knowledge item tracks its basis,
how invalidation propagates, and how provenance connects to the
broader self-evolution loop. **Scope**: Discipline source, adoption
rationale, architectural decisions, and maintenance guidance. NOT the
provenance data itself (future `/aitool-provenance` user-level skill,
`/provenance` project-level skill in aitools repo). NOT the schema
details (`reference/harness-db-schema.sql`). NOT the governance
principle (future `.claude/rules/provenance.md`). **Audience**: Agents
producing or consuming knowledge items, harness architects extending
the provenance system.

## Source Discipline

Six disciplines converge. Each solves a different facet of the problem
"what is this based on, and is the basis still valid?"

- **Truth maintenance** (de Kleer, ATMS, 1986) -- an inference engine
  that maintains dependency records between assumptions and derived
  conclusions. When an assumption is retracted, all dependent
  conclusions are marked OUT and the invalidation propagates through
  the full chain. Key concept: **nogood sets** -- when a combination
  of assumptions leads to a contradiction, recording that combination
  prevents future rediscovery of the same dead end.

- **Derivation chains** (W3C PROV, 2013) -- a standard for
  representing provenance: Entities (things), Activities (processes),
  Agents (responsible parties). Key relationships: `wasDerivedFrom`
  (dependency), `wasAttributedTo` (who produced it), `wasGeneratedBy`
  (which activity/session). Validates the dependency graph model
  without requiring the full ontology overhead.

- **Staleness tracking** (dbt source freshness) -- upstream data
  declares freshness expectations. Two thresholds: `warn_after`
  (advisory) and `error_after` (blocking). Downstream impact
  propagates: if source X is stale, every model derived from X is
  potentially stale.

- **Bitemporal knowledge** (Graphiti/Zep, Rasmussen 2025) -- a
  temporal knowledge graph for AI agent memory. Every fact has two
  timestamps: event time (when true in the real world) and ingestion
  time (when the system learned it). Superseded facts are invalidated,
  never deleted -- the full history of what was believed and when is
  preserved. Conflict resolution uses temporal metadata.

- **Automatic lineage** (Pachyderm) -- data versioning with automatic
  provenance tracking. Lineage is captured by the SYSTEM, not declared
  by the USER. When input data changes, downstream pipelines are
  automatically flagged. Immutability at source: data is never
  overwritten, only versioned.

- **Metadata governance** (Apache Atlas) -- classification tags
  propagate through lineage. Classifications like
  `commander_directive`, `verified_fact`, `agent_observation`,
  `unverified_assumption` annotate every knowledge item with its trust
  level. The governed vocabulary (glossary.json) integrates with the
  provenance graph.

## How We Adopted It

### The triggering experience

Session c0dc2ddc-f (2026-03-25) traced how a wrong assumption (/tmp
for session-ephemeral state) propagated through 4 delegation links
across 9 days into production code. The recency heuristic -- scanning
recent sessions and giving more weight to newer ones -- propagated the
incorrect assumption just as effectively as it would have propagated a
correct one. No governance layer caught it because no layer tracked
what decisions were BASED ON.

This was not a one-off. Cross-project audit of three sessions (aitools,
marse, nobul-ops) found the same pattern: agents treating other agents'
output as directive rather than data (OL-1), copying the most recent
pattern without evaluating it against conventions (OL-3), and producing
work product whose basis was invisible to future sessions.

### What we took from each discipline

- **Truth maintenance** -> dependency-directed invalidation and nogood
  sets. The `provenance_edges` table tracks which knowledge items
  depend on which. When an item is invalidated, propagation flags all
  downstream items. The `nogood_sets` table records known
  contradiction combinations so agents encountering the same
  combination are warned immediately.

- **W3C PROV** -> the derivation chain model (`derived_from`,
  `informed`, `triggered`, `validated`, `invalidated`, `superseded`)
  and the attribution model (`attributed_to` distinguishing commander
  vs agent vs specific subagent). We use SQLite tables with foreign
  keys, not the PROV RDF/OWL ontology.

- **dbt staleness** -> two-threshold freshness on every knowledge item.
  `warn_after_days` (default 30) means "verify before relying."
  `error_after_days` (default 90) means "do not use without
  re-verification." Staleness propagates through the dependency graph:
  if a foundational item is stale, everything derived from it inherits
  the staleness flag.

- **Graphiti bitemporal** -> every knowledge item has `t_valid` (when
  the fact became true), `t_invalid` (when superseded), and
  `created_at` (when the harness learned it). These diverge on
  retroactive discovery. Superseded items are marked invalid, never
  deleted -- the full history of what was believed is preserved.

- **Pachyderm automatic lineage** -> provenance is captured by the
  system where possible (read-before-write inference at session
  boundaries), supplemented by lightweight agent annotations
  (`derived_from_ids`) during sessions. The goal: zero-friction
  provenance collection during the hot path.

- **Apache Atlas classification** -> trust-level taxonomy on every
  knowledge item (`commander_directive`, `verified_fact`,
  `agent_observation`, `unverified_assumption`). Connects to the
  governed vocabulary via glossary terms.

### What we did NOT take

- Full ATMS inference machinery (designed for theorem-proving scale;
  we have tens to hundreds of knowledge items, not thousands of
  clauses)
- W3C PROV RDF serialization and OWL ontology (web-scale
  interoperability overhead; we are a single-developer harness)
- Graphiti's three-tier subgraph structure (episodic/semantic/community
  -- useful concept but premature to implement in full)
- Pachyderm's pipeline re-execution on upstream change (we flag for
  re-evaluation, not automatic re-processing; the commander gates
  re-evaluation)

## Architectural Decisions

### Frictionless collection (hot path vs cold path)

The sentinel hooks that preceded provenance tracking failed because
they added synchronous processing on every tool use: regex parsing,
/tmp state reads/writes, conditional output. Every observability
system that succeeds at scale uses the opposite pattern.

**Hot path** (during session, < 5ms per event): The agent's natural
behavior already produces provenance data. When the agent reads an OL
entry and makes a decision, the provenance link exists implicitly. The
only additional overhead is an optional `derived_from_ids` annotation
on significant writes -- analogous to a developer adding `trace_id`
to log messages. One SQLite INSERT per observation/decision. No hooks,
no regex, no /tmp.

**Cold path** (at session boundary, can take seconds): The SessionEnd
hook walks the session DB, builds the dependency graph from
`derived_from_ids` and read-before-write inference, classifies items
by significance (tail-based sampling from Honeycomb), promotes
significant items to the harness DB `knowledge_items` table, writes
`provenance_edges`, and propagates staleness.

### Level separation

Provenance tables live in the HARNESS DB (cross-session state),
not the session DB. Sessions write observations to the session DB
(fast loop). Promotion to `knowledge_items` happens at session
boundaries (slow loop). This preserves the level separation safety
mechanism from the self-evolution proposals.

### Immutability

Knowledge items are immutable once created. When an item is
superseded, a new version is created with the same `item_id` and
incremented `version`. The old version is marked with `t_invalid`.
The full history of what was believed and when is always available.

### The ascending spiral

Provenance tracking enables the ascending spiral from the
self-evolution proposals (session RnTOD5XJFi). Each cycle:

```
Session behavior (tacit)
    -> Observations + AARs (explicit, recorded in session DB)
    -> Promotion to knowledge_items (explicit, harness DB)
    -> Dependency graph construction (provenance_edges)
    -> Staleness/invalidation propagation
    -> Commander review of flagged items
    -> Governance artifacts updated
    -> Next session behavior (informed by cleaner knowledge)
```

The spiral ascends because each cycle has access to the provenance of
the previous cycle's outputs. An agent reading OL-2 in a future
session can see: what it was based on, whether any of those bases have
been invalidated, and whether any nogood sets apply.

## How It's Maintained

- Knowledge items promoted at session boundaries by SessionEnd hook
  processing
- Provenance edges constructed from `derived_from_ids` annotations
  and read-before-write inference
- Staleness checked at SessionStart: items past their `warn_after`
  or `error_after` thresholds are flagged
- Nogood sets checked when new knowledge items are created: if the
  new item's basis includes a known nogood combination, warn the agent
- Invalidation propagation runs at session boundaries when any item's
  `t_invalid` is set

## Implementing Artifacts

- `reference/framework-provenance.md` (this file -- discipline source
  and adoption rationale)
- `reference/harness-db-schema.sql` (`knowledge_items`,
  `provenance_edges`, `nogood_sets` tables)
- Future: `.claude/rules/provenance.md` (governance rule -- always in
  context)
- Future: `.claude/skills/provenance/SKILL.md` (project-level CRUD
  access to provenance data in aitools repo)
- Future: `shared/skills/aitool-provenance/SKILL.md` (user-level
  reference card -- read-only provenance knowledge for all projects)
- Future: SessionEnd hook extension for provenance extraction
- Future: SessionStart hook extension for staleness checking

## Cross-References

- Harness definition: `@reference/harness.md`
- Self-evolution proposals (ascending spiral, safety mechanisms):
  `.scratch/session-RnTOD5XJFi/self-evolution-proposals.md`
- Provenance investigation (pattern inventory, schema design):
  `.scratch/session-c0dc2ddc-f/provenance-and-infrastructure-findings.md`
- Consolidated operational learning (OL-1 through OL-21):
  `.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Framework adoption process: `@reference/framework-adoption.md`
- Governed data access: `@reference/framework-governed-data-access.md`
- Harness DB schema: `@reference/harness-db-schema.sql`
- Framework registry: `/frameworks` skill
