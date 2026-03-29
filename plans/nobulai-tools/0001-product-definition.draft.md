# RFC 0001: nobulai-tools Product Definition

- **Status**: Draft
- **Created**: 2026-03-28
- **Author**: Jose (via Claude Code, session f078fb16)
- **Linked**: RFC 0002 (Mission Control Architecture), RFC 0003 (OL Graph Architecture), nobul-ops RFC 0022 (nobul-auth), nobul-ops RFC 0023 (SaaS Contingency)

**Intent**: **Purpose**: Define nobulai.tools as the web product for all aitools users -- mission control, operational learning graphs, and the single API entry point for the harness's cloud-facing capabilities. **Scope**: Product identity, URL structure, repo structure, API design, tech stack, hosting, auth, data sources, and relationship to aitools (the harness) and the nobul ecosystem. NOT the MC feature details (RFC 0002). NOT the OL graph architecture (RFC 0003). NOT the harness itself (aitools repo). **Audience**: Jose (decision-maker), any session working on nobulai-tools, any session evaluating the harness's cloud capabilities.

## Problem

aitools is a self-learning provenance-aware knowledge system. Its mission control and operational learning capabilities currently exist as:
- Local Python prototypes in scratch directories (session-command-center-v2.py, session-viewer.py, build-knowledge-db.py)
- Static HTML snapshots deployed to Vercel (nobulai.tools)
- SQLite databases on the user's machine
- Markdown files scattered across repos, harvesting directories, and session scratch

There is no product. The prototypes prove the concepts work. The architecture decisions from session f078fb16 define what the product should be. This RFC captures that definition.

## Product Identity

nobulai.tools is the product for ALL aitools users. It is a VIEW into the harness -- it displays and connects data that the harness produces. It does not contain harness logic (hooks, skills, rules stay in aitools).

From Jose's words (meaning-reconstruction.md):
- "aitools is the foundation for all of Nobul. Much of its knowledge only lives as sessions, plans, briefings, and AARs -- not as shipped code."
- "the long term objective is to make aitools self-learning and improving"
- "i hate using local server. i want a web portal"

## URL Structure

| URL | Purpose |
|-----|---------|
| nobulai.tools/&lt;user&gt;/mc | Per-user mission control |
| nobulai.tools/&lt;user&gt;/mc/session/&lt;id&gt; | Session view (messages, governance, delegations, etc.) |
| nobulai.tools/&lt;user&gt;/mc/session/&lt;id&gt;/viewer | Session artifact viewer |
| nobulai.tools/&lt;user&gt;/ol | Per-user OL graph |
| aitools.nobul.tech/ol | Public aitools OL graph (when ready) |

## Repo Structure

**Repo**: nobulai-tools (private, nobul-tech org)

```
nobulai-tools/
├── api/                    # GraphQL API (single entry point)
│   ├── schema/             # GraphQL schema definitions
│   ├── resolvers/          # Query/mutation resolvers
│   └── adapters/           # Data source adapters
│       ├── local/          # Local machine endpoint adapter
│       ├── git/            # Git repo adapter
│       ├── github/         # GitHub API adapter
│       ├── datadog/        # Datadog KPI adapter
│       └── sqlite/         # SQLite DB adapter (session/harness)
├── mc/                     # Mission control frontend
│   ├── landing/            # Landing page (active sessions, grouped)
│   ├── session/            # Session view (tabs)
│   └── viewer/             # Session artifact viewer
├── ol/                     # OL graph frontend
│   ├── graph/              # Graph visualization
│   └── search/             # Full-text search interface
├── shared/                 # Shared UI components, auth, types
├── rfcs/                   # RFC-driven design (same convention as nobul-ops)
├── plans/                  # Planning artifacts
├── reference/              # Reference documentation
└── CLAUDE.md               # Project instructions
```

**Relationship to other repos**:
- aitools: data source (session DBs, harness DB, hooks, skills, rules, harvesting artifacts). nobulai-tools reads from aitools, never writes to it.
- nobul-ops: separate concern (business operations). Not a data source for nobulai-tools.
- nobul-auth: identity provider for nobulai-tools users when ready. Auth0 until then.
- qr-contact: no relationship.

## API Design

Single GraphQL API entry point at nobulai.tools/api/graphql. GraphQL chosen because:
- OL queries are graph traversals (what is this based on? what depends on this?)
- MC queries are structured data (show me this session's delegations)
- GraphQL federation handles querying across distributed sources
- GraphQL schema documents the API
- Contingencies per SaaS contingency lifecycle -- the GraphQL schema is the adapter interface

## Tech Stack

| Component | Suggested | Rationale | Alternative |
|-----------|-----------|-----------|-------------|
| API server | TypeScript (Node.js) | Matches nobul-auth (RFC 0022), fastest to build for web | Rust (via nobul-ops patterns) |
| Frontend | Vanilla HTML/CSS/JS or lightweight framework | Matches existing MC prototypes (session-command-center-v2.py produces self-contained HTML) | React, Svelte, Preact |
| GraphQL | Apollo Server or graphql-yoga | Standard, well-maintained | Mercurius (Fastify) |
| Database (product) | Per RFC 0023 P0 hosting decision | See Open Questions | -- |
| Auth | nobul-auth (RFC 0022) when ready, Auth0 until then | Flip-the-switch per RFC 0022 | -- |

## Hosting

Per SaaS contingency (RFC 0023):
- Current: Vercel (static snapshots, P0 URGENT -- limits hit, startup program denied)
- Target: per RFC 0023 P0 outcome (Cloudflare or Fly.io)
- Constraint: must NOT be AWS/Azure/GCP (preserving startup credit eligibility)
- Adapter interface: deployment config is portable
- Cloudflare has $5,000 BOOTSTRAPPED credits (Workers, D1, R2, Tunnel)

## Auth

Three user roles (from aitools user profile system):
- **Owner**: Jose only. Full access to all data, all users, all configuration.
- **Contributor**: Granted by owner. Can access their own MC/OL and shared project data.
- **User**: Default. Can access their own MC/OL only.

Auth provider: nobul-auth (RFC 0022) when ready. Auth0 for Startups until then. Flip by changing AUTH_DOMAIN env var.

## Data Sources

nobulai-tools aggregates data from multiple sources through API adapters:

| Source | What it provides | Adapter |
|--------|-----------------|---------|
| Local machine (user's computer) | Active session DB, harness DB, scratch files, running estimates | Local endpoint adapter (relay/tunnel or push) |
| Dotprofile repo (git) | Archived session JSOLs, profile.json, session history | Git adapter |
| GitHub | Commits, PRs, issues (as OL) | GitHub API adapter |
| Datadog | KPI metrics (as OL) | Datadog API adapter with contingency for Axiom |
| aitools repo (git) | Rules, skills, hooks, reference files, harvesting artifacts | Git adapter |

Data path constraints (from session f078fb16 decisions):
- Last known state / offline is acceptable when machine is off
- Commander directives must reach agent within a session, per turn
- Efficient caching with offline state, best effort / cost effective

## Relationship to aitools

aitools (the harness) produces data. nobulai-tools (the product) displays and connects it.

| Concern | Where it lives |
|---------|---------------|
| Hooks, skills, rules | aitools repo |
| Session DBs, harness DB | User's machine (.aitools/) |
| Scripts, build pipeline | aitools repo |
| MC frontend, OL frontend | nobulai-tools repo |
| GraphQL API | nobulai-tools repo |
| Data adapters | nobulai-tools repo |

The harness is the machine. nobulai-tools is the cockpit.

## SaaS Contingency

nobulai-tools follows the same contingency lifecycle as all Nobul SaaS dependencies (RFC 0023):

| Dependency | Current | Contingency |
|-----------|---------|-------------|
| Hosting | Per RFC 0023 P0 | Adapter interface, flip-the-switch |
| Auth | Auth0 → nobul-auth (RFC 0022) | Config change flip |
| KPIs | Datadog | Axiom, adapter handles flip |
| Graph DB | TBD (evaluation needed, RFC 0003) | Adapter interface from day one |

## Implementation Priority

| Priority | Action |
|----------|--------|
| P0 | Create nobulai-tools repo (private, nobul-tech) |
| P0 | Define GraphQL schema (MC + OL queries) |
| P0 | Implement MC landing page (machine → repo → sessions) |
| P1 | Implement session view (port session-command-center-v2.py to web) |
| P1 | Implement session viewer (port session-viewer.py to web) |
| P1 | Implement command channel (directives via API) |
| P2 | Implement OL graph view (RFC 0003) |
| P2 | Implement auth (nobul-auth or Auth0) |
| P3 | Implement federation (external data sources) |
| P3 | Public OL at aitools.nobul.tech/ol |

## Open Questions

| # | Question | Suggested Answer |
|---|----------|-----------------|
| 1 | Frontend framework or vanilla? | Start vanilla (matches prototypes), evaluate framework if complexity grows |
| 2 | GraphQL library? | Apollo Server or graphql-yoga -- evaluate |
| 3 | Hosting platform? | Per RFC 0023 P0 (Cloudflare likely given $5K credits) |
| 4 | Product DB for caching/state? | Cloudflare D1 if on Cloudflare, Fly Postgres if on Fly |
| 5 | When to create the repo? | Now -- even empty, it establishes the product boundary |
| 6 | Mono-repo or multi-repo for MC + OL? | Single repo (nobulai-tools) -- same API, same auth, same deployment |
| 7 | Mobile-responsive from day one? | Yes -- Jose checks MC from phone |

## Test Plan

| # | Test | Verifies |
|---|------|----------|
| 1 | GraphQL schema validates | Schema definition correct |
| 2 | MC landing page renders with mock data | Frontend works |
| 3 | Session view shows messages, governance, delegations | Data flow from adapter to UI |
| 4 | Directive sent from UI reaches local session DB | Command channel end-to-end |
| 5 | OL search returns results from knowledge DB | OL integration |
| 6 | Auth login flow works (Auth0 initially) | Auth integration |
| 7 | Deployment to hosting target succeeds | Hosting portability |
