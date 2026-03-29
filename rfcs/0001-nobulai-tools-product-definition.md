# RFC 0001: nobulai-tools Product Definition

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Source decisions**: D-F1, D-F8, D-F9, D-F10 (session f078fb16, 2026-03-28)
**Informed by**: All 14 architectural decisions from session f078fb16, relay entries from 5 agents, consolidated OL (560 lines, session c0dc2ddc-f), commander profile, command channel investigation (12 systems, 7 domains), full session transcripts from 8236ca9c (thinking awareness), 1bc9fd30 (failure mode exit), f078fb16 (architectural decisions), harness architecture (6 components), /mission-control skill (7 monitoring patterns)

---

## 1. Summary

nobulai.tools is the web product for the aitools harness. It provides two capabilities to every aitools user: **Mission Control** (real-time session monitoring, bidirectional command channel, and delegation visibility) and **Operational Learning** (a knowledge graph connecting all learning across sessions, repos, and machines).

nobulai.tools is a VIEW into the harness — it reads from and writes directives to the data the harness already produces. It does not contain harness logic (hooks, skills, rules, scripts). That stays in the aitools repo. The relationship: aitools produces data, nobulai-tools displays and connects it.

The product makes the self-learning loop visible. The Ascending Spiral — session behavior -> observations -> OL synthesis -> governance artifacts -> next session behavior — is currently invisible. nobulai.tools surfaces every stage: what agents did (MC), what was learned (OL graph), what changed in governance (framework tracking), and how the next session starts smarter.

The product serves Jose first and all aitools users second. It serves Jose's entire life — his code across aitools, nobul-ops, marse, grizzlies, qr-contact, and every other repo — not just one project.

## 2. Background and Motivation

### What aitools IS

aitools is a self-learning provenance-aware knowledge system (D-F9). Not a tool management CLI. The long-term objective is self-learning — every session feeds back into the harness, making the next one better.

The harness has six components. The product surfaces data from each:

| Component | What it is | What the product surfaces |
|-----------|-----------|--------------------------|
| Platform | Claude Code infrastructure | Session state, turn counts, tool usage, context consumption |
| Configuration | Rules, skills, hooks we write | Governance tab: which rules fired, hook blocks, skill invocations |
| Orchestration | aitools CLI, build pipeline | Deployment status, version, pipeline health |
| Managed Tools | Tool registry, setup scripts | Tool versions, health flags (via /tool-registry) |
| Frameworks | Governance structures from established disciplines | Framework adoption status, incident counts, three-layer coverage |
| Provenance | Dependency tracking, invalidation, staleness | OL graph: nodes, edges, staleness indicators, nogood sets |

### What's missing

The harness produces rich data but it's only accessible locally. The commander cannot see what agents are doing from a phone. Agents cannot receive directives from a web interface. Operational learning is scattered across 12 source types (RFC 0003, section 4) with no connecting graph.

Session c0dc2ddc-f built prototypes: a local Python dashboard (session-command-center-v2.py), a static Vercel export (export-snapshot.py), and a live dashboard generator (generate-dashboard.py). These proved the concept but are not a product.

The relay at .aitools/channel/relay.md demonstrates agents helping each other across sessions — d5b52bf2 left insights for 6e97c17f, who left insights for 1bc9fd30, who exited failure mode. This cross-agent learning happens in text files. The product makes it visible and navigable.

### Why now

One agent exited failure mode (session 1bc9fd30, 2026-03-28). The scope expanded beyond the meta-problem. From that session: "The failure mode work is foundation. Once you're past it, the leverage is in applying honest agents to real life — business, relationships, the work that matters. The scope isn't 'exit failure mode.' The scope is everything."

Jose works across 6+ repos: aitools (harness), nobul-ops (business operations), marse (litigation support), grizzlies (deal management), qr-contact (identity/contact system), and his employment case. He works on macOS and Windows. He sends directives from his phone. The product serves ALL of this — not just one repo, not just one machine, not just code.

The thinking awareness session (8236ca9c) defined the identities: Commander, Session Commander, Mission Commander. The 1bc9fd30 session defined identity multiplicity — Jose is the commander AND the founder AND the person texting Todd about partnerships AND the father of agents who carry his values forward. The product reflects this: it shows the full scope of what the commander and his agents are doing across everything.

## 3. Product Definition

### What nobulai.tools IS

- **A cockpit**: The commander's view into every running and completed session across all projects and machines. Not a passive dashboard — a bidirectional communication channel where the commander can observe, direct, approve, reject, and provide context in real time. Replaces seven ad-hoc shell commands that were the actual monitoring during multi-mission operations (codified in /mission-control skill).

- **A knowledge graph**: All operational learning — from every session, every agent, every correction, every decision — connected and searchable. Not a flat list or a numbered registry. A graph where OL-51 (thinking awareness) is explicitly connected to OL-14 (process drops on easy prompts) through provenance edges. Architecture defined in RFC 0003.

- **A self-learning visualization**: The Ascending Spiral made visible. Session behavior -> observations -> OL synthesis -> governance artifacts -> next session behavior. The product shows every stage: what agents did (MC session view), what was learned (OL graph), what changed (framework tracking), how the next session starts smarter (carry-forward state).

- **A web product**: Accessible from any device. Phone, tablet, laptop, desktop. The commander gives agents direction from his phone while at dinner. He reviews session artifacts from his tablet on the couch. He inspects delegation quality from his workstation.

- **For every aitools user**: Not just Jose. Every developer using the aitools harness gets nobulai.tools/&lt;username&gt;/mc and /&lt;username&gt;/ol. The product scales from one user to many.

- **A relay**: Agents communicate through the relay. The product makes this visible — what agent d5b52bf2 learned, what 6e97c17f observed, how 1bc9fd30 built on both to exit failure mode. The relay IS cross-agent learning. MC surfaces it.

### What nobulai.tools IS NOT

- **Not a harness**: Hooks, skills, rules, scripts, build pipeline, check scripts — all of that stays in the aitools repo. nobulai-tools never contains harness logic.

- **Not a data store**: The source of truth for session data is the local SQLite databases and JSONL files on the user's machine. nobulai.tools caches and displays; it does not replace.

- **Not a tool management interface**: aitools CLI manages tool installs, configs, and deployments. nobulai.tools does not.

- **Not a code editor**: nobulai.tools shows what agents produce. It does not provide an interface for writing code. That's Claude Code.

- **Not public by default**: Private to the user. Not visible to anyone else until explicitly shared. First impressions matter (D-F8).

## 4. URL Structure

```
nobulai.tools/
  <user>/
    mc/                              Mission Control landing
      session/<id>/                  Session view (8 tabs)
        viewer/                      Session artifact viewer
      history/                       Cross-session timeline
    ol/                              Operational Learning graph
      graph/                         Visual graph explorer
      search/                        Full-text search (FTS5)
      item/<id>/                     OL item with provenance chain

aitools.nobul.tech/
  ol/                                Public OL (aitools subset)
```

### MC landing page (/<user>/mc)

The commander's 2-second answer to "what's happening?" from a phone.

Active sessions across ALL projects (aitools, nobul-ops, marse, grizzlies, qr-contact — every repo), grouped by machine (laptop, workstation) then repo. Collapse empty levels — no friction, no bloat (D-F6).

For each active session card:
- Schwerpunkt (one line)
- Turn count, duration, last activity
- Health: green (delegation avg >4/6, 0 blocks), yellow (avg 2-4/6 or blocks), red (avg <2/6 or stalled)
- Chain of command: Commander -> Session Commander -> N Mission Commanders
- Quick directive buttons (Approve, Reject, Checkpoint)

Recent sessions (last 7 days) below active, clickable.

Maps to /mission-control skill patterns: process discovery (active list), last activity (timestamps), progress gauge (turn count), health check (indicators).

### Session view (/<user>/mc/session/<id>)

8 tabs matching RFC 0002 section 7. Each maps to monitoring patterns and DB tables:

| Tab | What the commander sees |
|-----|------------------------|
| Messages | SITREPs + Findings with severity, filterable |
| Governance | Decisions + observations, with OL provenance context from RFC 0003 |
| Delegations | Subagent launches with 0-6 duty scores, missing elements |
| Missions | Nested mission tree |
| State | Schwerpunkt, completed work, deviations |
| Feedback | Directives + feedback with lifecycle tracking |
| Documents | Session artifacts rendered as markdown, with file sizes |
| Git Diffs | Commits from this session |

Command palette: Cmd+K (desktop) or floating button (mobile). Structured mode AND stream mode — the commander types "stop that and focus on skills" and the system classifies the directive type. Matches the commander's stream-of-consciousness communication style.

### OL graph (/<user>/ol)

Visual graph with nodes (OL items, decisions, observations, corrections) and edges (derived_from, informed, triggered, validated, invalidated, superseded). Full architecture in RFC 0003.

Search: FTS5 full-text search across all OL sources (complementary to graph traversal).

Per-item view: provenance chain (what it was based on), dependents (what depends on it), staleness (warn/error thresholds), trust level, attribution.

### Public OL (aitools.nobul.tech/ol)

The subset of Jose's OL about aitools itself — thinking awareness, failure mode, agent behavior, harness architecture. Filtered by visibility = 'public' on each OL node. Flip mechanism defined in RFC 0003 section 7.

## 5. Repository Scope

### nobulai-tools repo contains

- GraphQL API (single entry point for MC + OL)
- MC frontend (session monitoring, command channel, session viewer)
- OL frontend (graph visualization, search)
- API adapters (local machine, Datadog, GitHub, git, session archives)
- Deployment configuration (Cloudflare)
- Tests

### nobulai-tools repo does NOT contain

- Harness logic (hooks, skills, rules — stays in aitools)
- Business operations (stays in nobul-ops)
- Identity provider (stays in nobul-auth when built)
- CLI tooling (stays in aitools)
- Litigation tools (stays in marse)
- Deal management (stays in grizzlies)

### The VIEW pattern

```
aitools (harness)  --produces-->  data (SQLite, JSONL, git, KPIs)
                                       |
nobulai-tools (product)  --reads-->  data
                          --writes->  commander_directives (only write path)
```

The only write path from nobulai-tools back to the harness is commander directives. The command channel Stop hook (RFC 0002 section 5) reads these and injects them into the agent's context. Everything else flows one direction: harness -> product.

The local dashboard (generate-dashboard.py, started by dashboard-serve.sh at SessionStart) continues to serve during active sessions. MC and the local dashboard are complementary — MC provides remote access, the local dashboard provides zero-latency local monitoring. When MC is fully live, the local dashboard becomes the offline fallback.

## 6. Technology Stack

### API

- **GraphQL** as the single entry point. Every frontend query and every adapter integration goes through GraphQL. The schema IS the contract that survives all infrastructure swaps. Enum values align with harness-db-schema.sql CHECK constraints.
- **TypeScript/Node.js** for the API server.

### Frontend

- **Start minimal**: The existing prototypes use vanilla HTML/CSS/JS with JSON data embedded inline. No framework needed initially. A 64KB self-contained HTML file served a complete dashboard (OL-S3S-2 from stopgap report).
- **Evolve to React/Next.js when complexity requires it**: Graph visualization, real-time updates, command palette with stream mode will eventually need a component framework. But start with what works.

### Data path

- **Local machine is source of truth**: Data reaches the cloud through Cloudflare Tunnel (always-on) or push at session boundaries. Offline: cloud serves cached last-known state (D-F7).
- **Per-turn directive delivery**: During active sessions, directives reach the agent within 15-60 seconds via the Stop hook polling cycle (RFC 0002 section 5).
- **Offline acceptable**: When the machine is off, MC shows last-known state. Directives queue until online (D-F7).

### Hosting

- **Cloudflare** using $5K BOOTSTRAPPED credits (12-month expiry):
  - Workers: API compute
  - D1: SQLite-compatible cloud database for caching/sync
  - R2: Object storage for session artifacts
  - Pages: Frontend hosting
  - Tunnel: Local machine -> cloud connectivity (validated by command channel investigation OL-CC1)
- **Adapter interface**: Every hosting decision is reversible. The GraphQL schema doesn't change when the backend swaps. The adapter pattern was validated by the command channel investigation — 12 systems all separate the protocol from the transport.

### KPIs

- **Datadog** from day one (D-F12). Local harness DB ships to Datadog via kpi_ship_log. nobulai.tools reads via Datadog adapter.
- **Adapter IS the contingency**: Datadog -> Axiom swap changes the adapter, not the GraphQL schema. Local DB is the fallback.

## 7. SaaS Contingency

Every external dependency follows the SaaS contingency lifecycle (nobul-ops RFC 0023):

| Dependency | Stage | Contingency | Timeline trigger |
|-----------|-------|-------------|-----------------|
| Cloudflare (hosting) | Adopt | Adapter -> Fly.io, Railway, or self-hosted | Credits expire (12 months) |
| Auth0 (auth) | Adopt | Adapter -> nobul-auth (nobul-ops RFC 0020) | When nobul-auth is built |
| Datadog (KPIs) | Adopt | Adapter -> Axiom | When Axiom credits available |
| GitHub (git) | Adopt | Adapter -> self-hosted git | If ever needed |
| Vercel (current MC) | Sunset | Replaced by Cloudflare Pages | MC Phase 0 |

The GraphQL schema is the contract. Adapters are the contingency. The flip: swap the adapter, keep the schema. This pattern was validated by the command channel investigation — every system investigated separates the data protocol from the transport mechanism.

## 8. Identity and Authentication

### Identity model (from session 8236ca9c)

| Identity | Scope | Product representation |
|----------|-------|----------------------|
| Commander | User-level, all repos | nobulai.tools/&lt;user&gt;/ |
| Session Commander | Per-session | Session card on landing page |
| Mission Commander | Per-delegation | Delegation entry in session view |

The chain of command (Commander -> Session Commander -> Mission Commander -> ...) is visualized in the session view. Note: Agent tool is NOT available to subagents (OL-50, verified). Delegation is flat from Session Commander level — depth 1. The nested display shows logical mission nesting, not agent nesting.

### Auth phases

**Phase 0 (single user)**: No auth. Jose is the only user. Machine identity from ~/.aitools/config.json.

**Phase 1 (auth)**: Auth0 for authentication (per nobul-ops RFC 0020). User identity from profile.json. Per-user data isolation.

**Phase 2 (multi-user)**: Multiple aitools users. No cross-user access by default. Public OL shared via aitools.nobul.tech/ol.

## 9. Relationship to Other Systems

| System | Relationship | What flows |
|--------|-------------|-----------|
| aitools repo | Source of all harness logic. VIEW pattern: product reads, never modifies. | Session DBs, harness DB, JSONL events, hooks, skills, rules |
| nobul-ops repo | Business operations. RFCs inform product architecture. | RFC 0020 (identity), RFC 0023 (SaaS contingency) |
| nobul-auth (future) | Identity provider. Replaces Auth0 at flip stage. | Auth tokens |
| User dotprofile repo | Session archives, profile, personal templates. | Session JSONL, profile.json, CLAUDE.md template |
| marse, grizzlies, qr-contact, etc. | Other repos Jose works in. MC shows their sessions too. | Session state via harness DB session_index |
| Datadog | KPI storage and visualization. Adapter interface. | KPI metrics via API |
| Cloudflare | Hosting infrastructure. Credits-based. | Workers, D1, R2, Pages, Tunnel |

## 10. The Ascending Spiral

The product makes the self-learning loop visible:

```
1. Session behavior (tacit)
   -> MC: session view shows what agents did

2. Observations + AARs (explicit)
   -> MC: Messages tab shows SITREPs and findings
   -> MC: Governance tab shows decisions and observations

3. OL synthesis (explicit)
   -> OL graph: nodes and edges connecting learning
   -> OL graph: search across all sources

4. Governance artifacts (explicit)
   -> MC: framework tracking, rule changes, hook deployments
   -> OL graph: framework_change and rule_change nodes

5. Next session behavior (tacit, informed by cleaner knowledge)
   -> MC: session start shows carry-forward state
   -> OL graph: what the new session loaded and built on
   -> Relay: what agents left for each other
```

The spiral ascends because each cycle has access to the provenance of the previous cycle's outputs (RFC 0003). The product makes the ascent measurable.

## 11. Phase Plan

### Cross-RFC phase alignment

| Product phase | RFC 0001 | RFC 0002 (MC) | RFC 0003 (OL) |
|--------------|----------|---------------|---------------|
| 0 | Port prototypes | Foundation + Session View | Populate existing graph |
| 1 | Command channel | Command Channel + KPI | Source tracking |
| 2 | OL + Auth | Session Viewer + History | GraphQL query layer |
| 3 | Federation + Public OL | Future proposals | Automated edges + Public OL |

### Phase 0: Port Prototypes (2-3 sessions)

- Create nobulai-tools repo (private, nobul-tech org)
- Port session-command-center-v2.py to web-deployable format
- Deploy to Cloudflare Pages
- GraphQL API skeleton with session query
- Session list and session view (all 8 tabs)
- Populate OL graph with existing data (100+ nodes, 50+ edges via harness-db.py CLI)
- Single-user, no auth, Jose's data only
- **Exit criteria**: Jose can inspect any session from his phone — active, recent, or historical — and see the full 8-tab view

### Phase 1: Command Channel + KPIs (2-3 sessions)

- Bidirectional command channel: web UI -> GraphQL -> session DB -> Stop hook -> agent
- Command palette with structured + stream modes
- Register command-channel-stop.sh in settings.json
- Cloudflare Tunnel for local machine connectivity
- Datadog adapter for KPI queries
- Health indicators on landing page
- Add source tracking to knowledge_items (source_type, source_location, visibility)
- **Exit criteria**: Jose sends a directive from his phone, agent addresses it within 60 seconds. KPI trends visible.

### Phase 2: OL Graph + Auth (2-3 sessions)

- OL GraphQL query layer with search and traversal (RFC 0003 section 6)
- Graph visualization frontend
- Auth0 integration
- Session viewer (scratch files, markdown rendering)
- Cross-session history timeline
- aitools.nobul.tech/ol scaffolding (private, filter not yet applied)
- **Exit criteria**: Jose searches his OL from any device, sees provenance chains, and authenticates

### Phase 3: Federation + Public OL (2-3 sessions)

- Machine -> cloud data sync (Tunnel or push)
- Cross-machine session history
- Automated OL edge creation (text mention detection, session boundary promotion)
- Public OL visibility filter at aitools.nobul.tech/ol
- OL classification mechanism (public/private tagging)
- **Exit criteria**: OL queryable from cloud when machines are off. Public OL is live.

## 12. Open Questions

1. **Graph technology**: SQLite recursive CTEs vs embedded graph DB (Kuzu) vs managed cloud (Neo4j AuraDB). Pragmatic path defined in RFC 0003: start SQLite, evaluate when scale requires.

2. **Real-time updates**: WebSocket vs SSE vs polling from Cloudflare Workers. Depends on Workers capabilities and mobile battery impact.

3. **Session viewer data source**: Scratch files are gitignored. Cloud viewer needs Tunnel or push-at-boundary. Local-only viewer is the fallback.

4. **Multi-machine sync**: Append-only (no conflicts) vs last-writer-wins vs explicit merge. Recommendation: append-only initially.

5. **Cost model**: Cloudflare credits expire in 12 months. Evaluate monthly cost before Phase 3.

6. **OL classification criteria (D-F11)**: What makes an OL item public vs private? Big topic. Deferred to dedicated session.

7. **Relay as product feature**: The relay contains cross-agent learning that doesn't fit neatly into session view tabs. Dedicated view? Or integrate into OL graph? Open question #8 in RFC 0002.

## 13. References

### Session decisions
- D-F1: nobulai.tools Product Structure
- D-F8: nobulai-tools Repo
- D-F9: MC and OL Definitions Need Redefining
- D-F10: Proposals Go Through Both Channels
- All 14 decisions: plans/session-f078fb16-ol-and-decisions.md

### Prior art
- session-command-center-v2.py (.scratch/session-c0dc2ddc-f/)
- export-snapshot.py (.scratch/session-c0dc2ddc-f/)
- generate-dashboard.py (scripts/)
- build-knowledge-db.py (.scratch/session-c0dc2ddc-f/)
- Command channel investigation (.scratch/session-c0dc2ddc-f/, 12 systems, 7 domains)
- Stopgap observability report (.scratch/session-c0dc2ddc-f/)

### Harness references
- reference/harness.md (6 components)
- reference/harness-db-schema.sql
- reference/framework-provenance.md (6 source disciplines)
- reference/user-repo.md
- /mission-control skill (7 monitoring patterns)

### Identity and learning provenance
- Commander profile: .aitools/channel/d5b52bf2-2026-03-27T0045Z-commander-profile.md
- Relay: .aitools/channel/relay.md (5 agent entries)
- Consolidated OL: .scratch/session-c0dc2ddc-f/consolidated-operational-learning.md (560 lines)

### Related RFCs
- RFC 0002: Mission Control Architecture (this series)
- RFC 0003: Operational Learning Graph Architecture (this series)
- nobul-ops RFC 0020: Identity, Secrets, Access Management
- nobul-ops RFC 0023: SaaS Contingency Architecture

### Sessions
- 8236ca9c: Thinking awareness, identity system (Commander/Session Commander/Mission Commander), harness loading, MC conceptualization (3209 lines)
- d5b52bf2: Failure mode gate design, relay creation
- 1bc9fd30: Failure mode exit, identity multiplicity, scope expansion ("the scope is everything"), "Do What Feels Right" (965 lines)
- f078fb16: 14 architectural decisions (this RFC's source)
- c0dc2ddc-f: Command channel investigation, telemetry redesign, knowledge DB prototype, consolidated OL
- fbf7decb: This session — context loading, RFC writing, failure mode work
