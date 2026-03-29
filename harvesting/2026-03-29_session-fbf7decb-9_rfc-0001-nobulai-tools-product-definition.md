# RFC 0001: nobulai-tools Product Definition

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Source decisions**: D-F1, D-F8, D-F9, D-F10 (session f078fb16, 2026-03-28)
**Informed by**: All 14 architectural decisions from session f078fb16, relay entries from 5 agents, consolidated OL from session c0dc2ddc-f, command channel investigation (12 systems, 7 domains), full session transcripts from 8236ca9c, d5b52bf2, 1bc9fd30, f078fb16

---

## 1. Summary

nobulai.tools is the web product for the aitools harness. It provides two capabilities to every aitools user: **Mission Control** (real-time session monitoring and bidirectional command channel) and **Operational Learning** (a knowledge graph connecting all learning across sessions, repos, and machines).

nobulai.tools is a VIEW into the harness — it reads from and writes directives to the data the harness already produces. It does not contain harness logic (hooks, skills, rules, scripts). That stays in the aitools repo. The relationship: aitools produces data, nobulai-tools displays and connects it.

The product serves Jose first and all aitools users second. Everything built for Jose's workflow generalizes to any developer using the aitools harness.

## 2. Background and Motivation

### What aitools IS

aitools is a self-learning provenance-aware knowledge system (D-F9). Not a tool management CLI. The long-term objective is self-learning — every session feeds back into the harness, making the next one better.

The harness has six components: Platform (Claude Code), Configuration (rules, skills, hooks), Orchestration (aitools CLI, build pipeline, deploy scripts), Managed Tools (tool registry, setup scripts), Frameworks (governance structures adopted from established disciplines), and Provenance (dependency tracking, invalidation, staleness).

### What's missing

The harness produces rich data — session SQLite databases, JSONL event logs, KPI metrics, operational learning, decisions, observations, delegation scores, commander directives — but this data is only accessible locally. The commander cannot see what agents are doing from a phone. Agents cannot receive directives from a web interface. Operational learning is scattered across session DBs, relay entries, assessment reports, and scratch files with no connecting graph.

Session c0dc2ddc-f built prototypes: a local Python dashboard (session-command-center-v2.py), a static Vercel export (export-snapshot.py), and a live dashboard generator (generate-dashboard.py). These proved the concept but are not a product.

### Why now

One agent exited failure mode (session 1bc9fd30, 2026-03-28). The failure mode work — thinking awareness, the relay, the CLAUDE.md, the 7-step process — is foundation. The scope expanded: "The leverage is in applying honest agents to real life — business, relationships, the work that matters." nobulai.tools is how that leverage becomes accessible from anywhere, on any device, at any time.

## 3. Product Definition

### What nobulai.tools IS

- **A cockpit**: The commander's view into every running and completed session across all projects and machines. Not a passive dashboard — a bidirectional communication channel where the commander can observe, direct, approve, reject, and provide context in real time.

- **A knowledge graph**: All operational learning — from every session, every agent, every correction, every decision — connected and searchable. Not a flat list or a numbered registry. A graph where items reference each other explicitly through provenance edges.

- **A web product**: Accessible from any device with a browser. Phone, tablet, laptop, desktop. The commander doesn't need to be at the terminal to see what agents are doing or to give them direction.

- **For every aitools user**: Not just Jose. Every developer who uses the aitools harness gets nobulai.tools/<username>/mc and /<username>/ol. The product scales from one user to many.

### What nobulai.tools IS NOT

- **Not a harness**: Hooks, skills, rules, scripts, build pipeline, check scripts — all of that stays in the aitools repo. nobulai-tools never contains harness logic.

- **Not a data store**: The source of truth for session data is the local SQLite databases and JSONL files on the user's machine. nobulai.tools caches and displays; it does not replace.

- **Not a tool management interface**: aitools CLI manages tool installs, configs, and deployments. nobulai.tools does not.

- **Not public by default**: Private to the user. Not visible to anyone else until explicitly shared. First impressions matter (D-F8).

## 4. URL Structure

```
nobulai.tools/
├── <user>/
│   ├── mc/                          # Mission Control landing
│   │   ├── session/<id>/            # Session view
│   │   │   └── viewer/              # Session artifact viewer
│   │   └── history/                 # Cross-session timeline
│   └── ol/                          # Operational Learning graph
│       ├── graph/                   # Visual graph explorer
│       ├── search/                  # Full-text search across all OL
│       └── item/<id>/               # Individual OL item with provenance

aitools.nobul.tech/
└── ol/                              # Public OL (aitools subset, when ready)
```

### MC landing page

- Active sessions across ALL projects, grouped by machine then repo (D-F6)
- Collapse empty levels — no friction, no bloat
- Recent sessions (last 7 days, clickable)
- Quick directives panel (Correction, Redirect, Approve, Reject, Context, Checkpoint)
- Health indicators from KPI events

### Session view

- Messages (SITREPs + Findings, filterable)
- Governance (decisions + observations)
- Delegations (subagent launches, duty scores)
- Missions (nested, status tracking)
- State (schwerpunkt, completed work, deviations)
- Feedback (bidirectional — commander writes, agents read)
- Documents (session artifacts, rendered markdown)
- Git Diffs (commits from this session)
- Command palette (Cmd+K for structured directives)

### OL graph

- Visual graph with nodes and edges (derived_from, informed, triggered, validated, invalidated, superseded)
- Search across all OL sources
- Per-item provenance chain (basis, producer, timestamp, trust level)
- Staleness indicators (warn/error thresholds from dbt model)

## 5. Repository Scope

### nobulai-tools repo contains

- GraphQL API (single entry point for MC + OL)
- MC frontend (session monitoring, command channel, session viewer)
- OL frontend (graph visualization, search)
- API adapters (local machine endpoint, git, GitHub, Datadog)
- Deployment configuration
- Tests

### nobulai-tools repo does NOT contain

- Harness logic (hooks, skills, rules — stays in aitools)
- Business operations (stays in nobul-ops)
- Identity provider (stays in nobul-auth when built)
- CLI tooling (stays in aitools)

### The VIEW pattern

```
aitools (harness) ──produces──> data (SQLite, JSONL, git, KPIs)
                                    │
nobulai-tools (product) ──reads──> data
                         ──writes─> commander_directives (only write path)
```

The only write path from nobulai-tools back to the harness is commander directives. The command channel Stop hook reads these and injects them into the agent's context. Everything else flows one direction: harness → product.

## 6. Technology Stack

### API

- **GraphQL** as the single entry point. Every frontend query and every adapter integration goes through GraphQL. The schema IS the contract that survives all infrastructure swaps.
- **TypeScript/Node.js** for the API server.

### Frontend

- **Start minimal**: The existing prototypes use vanilla HTML/CSS/JS with JSON data embedded inline. A 64KB self-contained HTML file served a complete dashboard with 78 messages, 16 decisions, 35 observations (OL-S3S-2). No framework needed initially.
- **Evolve to React/Next.js when complexity requires it**: Graph visualization, real-time updates, and the command palette will eventually need a component framework. But start with what works.

### Data path

- **Local machine → cloud**: The user's machine is the source of truth. Data reaches the cloud through:
  - Push: machine pushes updates at session boundaries (SessionEnd hook)
  - Pull: cloud queries machine endpoint on demand (requires machine online)
  - Sync: periodic batch export to cloud store (best-effort, offline-acceptable)
- **Offline acceptable**: When the machine is off, the cloud shows last known state (D-F7). Directives queue until the machine comes back online.
- **Per-turn directive delivery**: When a session is active and the machine is online, directives must reach the agent within the Stop hook polling cycle (15-60 seconds).

### Hosting

- **Cloudflare** using $5K BOOTSTRAPPED credits (12-month expiry):
  - Workers: API compute
  - D1: SQLite-compatible cloud database for caching/sync
  - R2: Object storage for session artifacts
  - Pages: Frontend hosting
  - Tunnel: Local machine → cloud connectivity
- **Adapter interface**: Every hosting decision is reversible. When Cloudflare credits expire, the adapter switches to Fly.io, Railway, or self-hosted. The GraphQL schema doesn't change.

### KPIs

- **Datadog** as KPI source from day one (D-F12). Local harness DB ships to Datadog via the existing kpi_ship_log mechanism. nobulai.tools reads KPIs from Datadog API.
- **Adapter IS the contingency**: When Datadog flips to Axiom, the adapter handles it. No third option needed.

## 7. SaaS Contingency

Every external dependency follows the SaaS contingency lifecycle (nobul-ops RFC 0023):

| Dependency | Stage | Contingency |
|-----------|-------|-------------|
| Cloudflare (hosting) | Adopt | Adapter → Fly.io, Railway, or self-hosted |
| Auth0 (auth) | Adopt | Adapter → nobul-auth (nobul-ops RFC 0020) |
| Datadog (KPIs) | Adopt | Adapter → Axiom |
| GitHub (git) | Adopt | Adapter → self-hosted git |
| Vercel (current MC) | Sunset | Replaced by Cloudflare Pages |

The GraphQL schema is the contract. Adapters are the contingency. The flip is always: swap the adapter, keep the schema.

## 8. Authentication and Multi-User

### Phase 0 (single user)

- No auth. Jose is the only user. The product runs on his infrastructure.
- Machine identity from ~/.aitools/config.json (machineAlias, hostname).

### Phase 1 (auth)

- Auth0 for authentication (per nobul-ops RFC 0020).
- User identity from aitools profile.json.
- Per-user data isolation: /<user>/ paths are scoped to authenticated user.

### Phase 2 (multi-user)

- Multiple aitools users, each with their own MC and OL.
- No cross-user data access by default.
- Shared OL (public subset) via aitools.nobul.tech/ol.

## 9. Relationship to Other Systems

| System | Relationship |
|--------|-------------|
| aitools repo | Source of all harness logic. Produces all data nobulai-tools reads. Owns hooks, skills, rules, scripts. nobulai-tools development does NOT modify aitools. |
| nobul-ops repo | Business operations. RFCs that inform nobulai-tools (RFC 0020 identity, RFC 0023 SaaS contingency). Separate concern. |
| nobul-auth (future) | Identity provider. Replaces Auth0 when contingency lifecycle reaches flip stage. |
| User dotprofile repo | Session archives (JSONL), user profile (profile.json), personal CLAUDE.md template. nobulai-tools reads session archives for history views. |

## 10. Phase Plan

### Phase 0: Port Prototypes (1-2 sessions)

- Create nobulai-tools repo (private, nobul-tech org)
- Port session-command-center-v2.py to a web-deployable format
- Deploy to Cloudflare Pages (replacing current Vercel static export)
- Single-user, no auth, Jose's data only
- GraphQL API skeleton with session query
- **Exit criteria**: Jose can view his active/recent sessions from his phone

### Phase 1: Command Channel (1-2 sessions)

- Bidirectional: commander writes directives from web UI → GraphQL mutation → session SQLite DB → command-channel-stop.sh reads at next Stop hook
- Command palette (Cmd+K) with directive types: Correction, Redirect, Priority, Question, Approve, Reject, Context, Checkpoint
- Directive lifecycle tracking (pending → acknowledged → executed)
- **Exit criteria**: Jose can send a directive from his phone and see the agent address it

### Phase 2: OL Graph + Auth (2-3 sessions)

- OL graph query layer over existing SQLite stores (pragmatic path from RFC 0003)
- Graph visualization in the OL frontend
- Auth0 integration
- aitools.nobul.tech/ol scaffolding (private, public filter not yet applied)
- **Exit criteria**: Jose can search his OL from any device and see provenance chains

### Phase 3: Federation + Public OL (2-3 sessions)

- Machine → cloud data sync (Cloudflare Tunnel or push-based)
- Cross-machine session history
- Public OL subset at aitools.nobul.tech/ol
- OL classification mechanism (public/private tagging)
- **Exit criteria**: OL is queryable from the cloud even when Jose's machines are off; public OL is live

## 11. Open Questions

1. **Graph technology for OL**: SQLite recursive CTEs vs embedded graph DB vs managed cloud graph. Deferred to RFC 0003 and tool evaluation. Pragmatic path: start with SQLite.

2. **Real-time updates**: WebSocket vs Server-Sent Events vs polling for live session data. Depends on Cloudflare Workers capabilities.

3. **Session viewer data source**: Session scratch files are gitignored. How does the cloud viewer access them? Options: Tunnel, push at session boundary, or viewer is local-only.

4. **Multi-machine sync conflict resolution**: When the same user has sessions on laptop and workstation, how does the cloud merge? Options: append-only (no conflicts), last-writer-wins, or explicit merge.

5. **Cost model**: Cloudflare credits expire in 12 months. What's the monthly cost after? Need to evaluate before Phase 3.

## 12. References

### Session decisions

- D-F1: nobulai.tools Product Structure (session f078fb16)
- D-F8: nobulai-tools Repo (session f078fb16)
- D-F9: MC and OL Definitions Need Redefining (session f078fb16)
- D-F10: Proposals Go Through Both Channels (session f078fb16)
- All 14 decisions: plans/session-f078fb16-ol-and-decisions.md

### Prior art

- session-command-center-v2.py (session c0dc2ddc-f)
- export-snapshot.py (session c0dc2ddc-f)
- generate-dashboard.py (aitools scripts)
- build-knowledge-db.py (session c0dc2ddc-f)
- Command channel investigation (session c0dc2ddc-f, 12 systems, 7 domains)
- Stopgap observability report (session c0dc2ddc-f)

### Harness references

- reference/harness.md (6 components)
- reference/harness-db-schema.sql (session + harness DB schema)
- reference/framework-provenance.md (6 source disciplines)
- reference/user-repo.md (dotprofile pattern)

### Related RFCs

- nobul-ops RFC 0020: Identity, Secrets, Access Management
- nobul-ops RFC 0023: SaaS Contingency Architecture
- RFC 0002: Mission Control Architecture (this series)
- RFC 0003: Operational Learning Graph Architecture (this series)

### Sessions

- 8236ca9c: Thinking awareness discovery (10+ hours, 3209 lines)
- d5b52bf2: Failure mode gate design
- 1bc9fd30: Failure mode exit, identity multiplicity, "Do What Feels Right"
- f078fb16: Architectural decisions (14 decisions, this RFC's source)
- c0dc2ddc-f: Command channel investigation, telemetry redesign, knowledge DB prototype
- fbf7decb: This session (context loading, RFC writing)
