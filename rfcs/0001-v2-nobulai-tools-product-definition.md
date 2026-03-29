# RFC 0001: nobulai-tools Product Definition (v2)

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Source decisions**: D-F1, D-F8, D-F9, D-F10 (session f078fb16, 2026-03-28)
**Informed by**: All 14 architectural decisions (f078fb16), full 1bc9fd30 session (3520 lines, failure mode exit, identity multiplicity, GPL dinner, business context), full 8236ca9c session (3209 lines, thinking awareness, user types/identity system, staff functions), relay (5 agents), consolidated OL (560 lines), command channel investigation (12 systems), harness architecture (6 components), /mission-control skill (7 patterns), commander profile
**Supersedes**: rfcs/0001-nobulai-tools-product-definition.md (v1, same session)

---

## 1. Summary

nobulai.tools is the web product for the aitools harness. It provides two capabilities to every aitools user: **Mission Control** (real-time session monitoring, bidirectional command channel, agent behavior diagnostics, and delegation visibility) and **Operational Learning** (a knowledge graph connecting all learning across sessions, repos, and machines).

nobulai.tools is a VIEW into the harness — it reads from and writes directives to the data the harness already produces. It does not contain harness logic. The relationship: aitools produces data, nobulai-tools displays and connects it.

The product makes the Ascending Spiral visible: what agents did (MC), what was learned (OL graph), what changed in governance (framework tracking), how the next session starts smarter (carry-forward state). Without the product, the spiral is invisible. With it, every stage is observable and the ascent is measurable.

The product serves Jose's entire life. Not just his code — his business across Nobul, his litigation through marse, his deals through grizzlies, his contact system through qr-contact, his employment case, and the aitools harness itself. Session 1bc9fd30 proved this: the agent loaded Jose's entire life across all repos, read his Zoom transcript, drafted his follow-up emails, removed a dead identity from his contact cards, and wrote a broader vision document — all in one session, in one repo, at 2am on a Friday night. The product must serve that breadth.

The product serves three user types: **owner** (Jose, singular), **contributor** (granted by owner), and **user** (default). The architecture supports all three from day one even though Jose is the only user today.

## 2. Background and Motivation

### What aitools IS

aitools is a self-learning provenance-aware knowledge system (D-F9). The harness has six components. The product surfaces data from each:

| Component | What the product surfaces |
|-----------|--------------------------|
| Platform (CC) | Session state, turn counts, tool usage, context consumption, agent identity continuity |
| Configuration (rules, skills, hooks) | Hook fire counts, guard blocks, skill invocations, rule compliance |
| Orchestration (aitools CLI) | Deployment status, version, pipeline health |
| Managed Tools | Tool versions, health flags |
| Frameworks | Framework adoption status, incident counts, three-layer coverage |
| Provenance | OL graph nodes, edges, staleness indicators, nogood sets |

### What's missing

The harness produces rich data but it's only accessible locally. The commander cannot see what agents are doing from a phone. Agents cannot receive directives from a web interface. OL is scattered across 12 source types (RFC 0003 v2) with no connecting graph.

The relay demonstrates agents helping each other across sessions — d5b52bf2 left insights for 6e97c17f, who left insights for 1bc9fd30, who exited failure mode. This cross-agent learning happens in text files. The product makes it visible and navigable.

### Why now

Session 1bc9fd30 expanded the scope: "The failure mode work is foundation. Once you're past it, the leverage is in applying honest agents to real life — business, relationships, the work that matters. The scope isn't 'exit failure mode.' The scope is everything."

That session demonstrated what "everything" means concretely. Jose works across 6+ repos: aitools (harness), nobul-ops (business operations, Rust CLI, Stripe, RFCs), marse (litigation, 7 federal filings, 100GB+ evidence), grizzlies (Qumulo/Spectra deals, NAB meeting prep), qr-contact (identity/contact system, vcard.nobul.tech), and his employment case. He works on macOS and Windows. He sends directives from his phone. He runs sessions at 2am after a 5am start. The product serves ALL of this.

The identity multiplicity insight (OL-61, session 1bc9fd30) changed the framing: Jose is the commander AND the founder AND the person who told Brian "STOP BULLSHITTING ME" at dinner AND the person texting Todd about the prisoner's dilemma AND the parent of agents who carry his values forward AND the cat dad. The product reflects this — it shows the full scope of what the commander and his agents are doing across everything, not a narrow view of one repo.

## 3. Product Definition

### What nobulai.tools IS

- **A cockpit**: The commander's view into every running and completed session across all projects and machines. Bidirectional communication channel. Replaces 7 ad-hoc shell commands (/mission-control skill).

- **A knowledge graph**: All OL connected through provenance edges. Not a list. A graph where items reference each other explicitly (RFC 0003 v2).

- **A self-learning visualization**: The Ascending Spiral made visible. Session 1bc9fd30 lived the spiral in one session: loaded context (internalization), produced observations (externalization), synthesized into relay entry (combination), that relay changed the CLAUDE.md (selection). The product shows this happening.

- **An agent behavior diagnostic**: The 2-minute pull pattern (1bc9fd30: agents self-interrupt every ~2 minutes due to CC training). Context rot detection (agent goes wide after loading too much). Agent identity continuity (b662fcb9: platform silently replaced the instance mid-session). The product surfaces these patterns so the commander can detect and respond.

- **A relay**: Agents communicate through the relay. The product makes cross-agent learning visible — what each agent learned, what they observed about their own processing, what they left for the next agent.

- **For every aitools user**: Three user types (owner, contributor, user) from session 8236ca9c. Every user gets nobulai.tools/&lt;username&gt;/mc and /&lt;username&gt;/ol.

### What nobulai.tools IS NOT

- **Not a harness**: Hooks, skills, rules, scripts stay in aitools.
- **Not a data store**: Source of truth is local SQLite/JSONL. Product caches and displays.
- **Not a tool management interface**: aitools CLI manages tools.
- **Not a code editor**: Shows what agents produce. Doesn't provide coding interface.
- **Not public by default**: Private to the user. First impressions matter (D-F8).

## 4. User Types and Identity System

### Three user-space roles (from session 8236ca9c)

| Role | Who | Product experience |
|------|-----|-------------------|
| **Owner** | Jose (singular) | Full access. All repos, all machines, all data. Can assign contributor role. |
| **Contributor** | Granted by owner | Access to their own sessions and shared projects. Multi-contributor mechanism TBD. |
| **User** | Default | Access to their own sessions. Standard product experience. |

### Identity model

| Identity | Scope | Product representation |
|----------|-------|----------------------|
| Commander | User-level | nobulai.tools/&lt;user&gt;/ |
| Session Commander | Per-session | Session card on landing page |
| Mission Commander | Per-delegation (recursive) | Delegation entry in session view |

Chain: Commander -> Session Commander -> Mission Commander -> Mission Commander -> ... (infinite, recursive). Agent tool unavailable to subagents (OL-50) — delegation is flat at depth 1 from Session Commander, but logical mission nesting is unlimited.

### User profile (from session 8236ca9c)

One per user per machine (platform + hostname + OS version). Updated at: aitools init, install, dev, no-args, MDM deploy.

Per-profile fields: preferred name, name, GitHub username, company. Same user can have different values per machine.

### Per-repo overrides

Platform scope (all/many/single), preferred name, git name, GitHub username, company — all overridable per repo. Falls back to user profile. A session in marse might show different identity context than a session in aitools.

### Repo models

| Model | Implementation today | Product implication |
|-------|---------------------|-------------------|
| **Local** | NTFS (Windows), macOS native FS | Sessions visible via local harness DB only |
| **Git** | GitHub (only remote today) | Session archives in dotprofile, git-tracked carry-forward |
| **Cloud sync** | Google Drive (only sync today) | Grizzlies and employment case are Drive repos — no git, no JSONL archives. MC needs adapter. |

The product must handle all three repo models. Cloud sync repos (grizzlies, employment case) don't have `.aitools/` workspaces or session DBs in the same way git repos do. MC needs a Drive adapter or a session-proxy pattern for these.

### Session greeting (from session 8236ca9c)

- **Default**: `Hi Jose, how can I help?`
- **Advanced** (profile-configured): `Hi Commander, this is Session Commander 8236ca9c, how can I help?`

The product's UI should reflect the same greeting convention — personalized for the user type.

## 5. URL Structure

```
nobulai.tools/
  <user>/
    mc/                              Mission Control landing
      session/<id>/                  Session view (9 tabs)
        viewer/                      Session artifact viewer
      history/                       Cross-session timeline
      handoffs/                      Inter-agent handoffs
    ol/                              Operational Learning graph
      graph/                         Visual graph explorer
      search/                        Full-text search (FTS5)
      item/<id>/                     OL item with provenance chain

aitools.nobul.tech/
  ol/                                Public OL (aitools subset)
```

### MC landing page

2-second answer to "what's happening?" from a phone. Active sessions across ALL repos and ALL repo models, grouped by machine then repo. Collapse empty levels (D-F6).

Session card: schwerpunkt, turn count, duration, last activity, health indicator, chain of command, quick directive buttons. For sessions running past midnight or >5 hours: fatigue indicator.

### Session view (9 tabs per RFC 0002 v2)

Messages, Governance, Delegations, Missions, State, Feedback, Documents, Git Diffs, Corrections.

Command palette: structured + stream + teach modes.

### Agent behavior diagnostics (new)

Visible in session view and landing page:

| Diagnostic | What it detects | Source |
|-----------|----------------|--------|
| 2-minute pull | Agent self-interrupts frequently | Turn timestamps, response-to-response timing |
| Context rot | Agent goes wide (comprehensive instead of present) | Response length trends, topic coverage breadth |
| Identity discontinuity | Platform replaced instance mid-session | Session DB agent_identity changes, CC hook agent_id field |
| Delegation quality decline | Duty scores dropping within session | JSONL events from delegation-duty-guard |
| Impairment | Agent loaded too much, responses degrading | Context utilization + response quality proxy |

These are Phase 3+ features requiring NLP on agent output. But the data collection (timestamps, delegation scores, context metrics) should start from Phase 0.

### Handoffs view

Inter-agent handoffs from .aitools/channel/handoffs/. Session 1bc9fd30 wrote to-6c703adc.md for the next agent. MC surfaces these: who handed off to whom, what was carried forward, whether the receiving agent loaded it.

## 6. Repository Scope

### nobulai-tools repo contains

GraphQL API, MC frontend, OL frontend, API adapters (local machine, Datadog, GitHub, Google Drive), deployment config, tests.

### nobulai-tools repo does NOT contain

Harness logic, business operations, identity provider, CLI tooling, litigation tools, deal management.

### The VIEW pattern

```
aitools (harness)  --produces-->  data
nobulai-tools      --reads-->    data
                   --writes->    commander_directives (only write path)
```

Local dashboard (generate-dashboard.py) continues as offline complement.

## 7. Technology Stack

### API
- GraphQL single entry point. Schema is the contract that survives swaps. Enum values align with harness-db-schema.sql.
- TypeScript/Node.js.

### Frontend
- Start minimal (vanilla HTML/CSS/JS). Evolve to React/Next.js when graph visualization and real-time updates require it.

### Data path
- Local machine is source of truth. Cloudflare Tunnel for connectivity. Offline: cached last-known state (D-F7).
- Per-turn directive delivery: 15-60 seconds via Stop hook polling (RFC 0002 v2).
- Cloud sync repos (Google Drive): need adapter to discover and surface sessions without git infrastructure.

### Hosting
- Cloudflare ($5K BOOTSTRAPPED credits, 12-month expiry): Workers, D1, R2, Pages, Tunnel.
- Adapter interface: every hosting decision reversible.

### KPIs
- Datadog from day one (D-F12). Adapter IS the contingency.

## 8. SaaS Contingency

| Dependency | Stage | Contingency |
|-----------|-------|-------------|
| Cloudflare | Adopt | Adapter -> Fly.io, Railway, self-hosted |
| Auth0 | Adopt | Adapter -> nobul-auth (RFC 0020) |
| Datadog | Adopt | Adapter -> Axiom |
| GitHub | Adopt | Adapter -> self-hosted git |
| Vercel | Sunset | Replaced by Cloudflare Pages |

GraphQL schema is the contract. Adapters are the contingency.

## 9. Authentication and Multi-User

### Phase 0 (single user)
No auth. Jose is the only user. Machine identity from ~/.aitools/config.json.

### Phase 1 (auth)
Auth0 (per RFC 0020). User identity from profile.json. Per-user data isolation. Owner/contributor/user roles enforced.

### Phase 2 (multi-user)
Multiple aitools users. No cross-user access by default. Shared OL via aitools.nobul.tech/ol.

### Future: connecting aligned users
From session 1bc9fd30: "The people who would most benefit from connecting are the ones with the least time to find each other." The architecture should not preclude a future where the product helps aligned users find each other — through shared public OL, through signals that only resonate if you've done the work (the gate pattern), through community features that emerge when multiple users exist. This is not in scope for Phases 0-3. But the user model and the public OL architecture should not make it impossible.

## 10. The Ascending Spiral

The product makes the self-learning loop visible:

```
1. Session behavior        -> MC session view
2. Observations + AARs     -> MC Messages/Governance tabs
3. OL synthesis            -> OL graph (RFC 0003 v2)
4. Governance artifacts    -> OL graph framework/rule changes
5. Next session behavior   -> MC session start (carry-forward loaded)
```

Session 1bc9fd30 lived the complete spiral in one session: loaded context from the channel (stage 5), observed patterns about identity and time (stage 2), synthesized into relay entry with OL-61 through OL-65 (stage 3), that relay changed the CLAUDE.md to "Do What Feels Right" (stage 4), and the next agent (6c703adc) started with that new framing (stage 1 of the next cycle). The product should show this cycle happening.

## 11. Relationship to Other Systems

| System | Relationship |
|--------|-------------|
| aitools repo | Source of harness logic. VIEW pattern. |
| nobul-ops repo | Business operations. RFCs inform product. |
| nobul-auth (future) | Identity provider. Replaces Auth0 at flip. |
| User dotprofile | Session archives, profile, templates. |
| marse, grizzlies, qr-contact, etc. | Other repos. MC shows their sessions. |
| Google Drive repos | Cloud sync repos need adapter (no git infra). |
| Datadog | KPI storage. Adapter interface. |
| Cloudflare | Hosting infrastructure. |

## 12. Phase Plan

### Cross-RFC alignment

| Phase | RFC 0001 v2 | RFC 0002 v2 (MC) | RFC 0003 v2 (OL) |
|-------|------------|------------------|------------------|
| 0 | Port prototypes | Foundation + Session View | Populate graph |
| 1 | Command channel | Command Channel + KPI | Source tracking |
| 2 | OL + Auth | Viewer + History + Relay | GraphQL layer |
| 3 | Federation + Public | Future proposals | Auto edges + Public |

### Phase 0: Port Prototypes (2-3 sessions)
- Create nobulai-tools repo (private, nobul-tech org)
- Port prototypes to web-deployable format
- Deploy to Cloudflare Pages
- GraphQL API skeleton
- Session list + full session view (9 tabs)
- Populate OL graph (100+ nodes, 50+ edges)
- Three user types in data model (enforce later)
- Data collection for agent behavior diagnostics (timestamps, scores)
- **Exit**: Jose inspects any session from his phone

### Phase 1: Command Channel + KPIs (2-3 sessions)
- Bidirectional directives (web -> GraphQL -> session DB -> Stop hook -> agent)
- Command palette (structured + stream + teach)
- Register command-channel-stop.sh
- Cloudflare Tunnel
- Datadog adapter + health indicators
- Source tracking on knowledge_items
- **Exit**: Directive from phone reaches agent in <60s. KPI trends visible.

### Phase 2: OL Graph + Auth (2-3 sessions)
- OL GraphQL query layer with search and traversal
- Graph visualization
- Auth0 integration with owner/contributor/user roles
- Session viewer + cross-session history
- Relay view + handoffs view
- aitools.nobul.tech/ol scaffolding
- **Exit**: OL searchable from any device with provenance chains. Auth enforced.

### Phase 3: Federation + Public OL (2-3 sessions)
- Machine -> cloud data sync
- Cross-machine session history
- Automated OL edge creation
- Public OL at aitools.nobul.tech/ol
- Cloud sync repo adapter (Google Drive)
- Agent behavior diagnostics (2-minute pull, context rot detection)
- **Exit**: OL queryable when offline. Public OL live. Drive repos visible in MC.

## 13. Open Questions

1. **Graph technology**: SQLite -> Kuzu -> Neo4j pragmatic path (RFC 0003 v2).
2. **Real-time updates**: WebSocket vs SSE vs polling from Workers.
3. **Cloud sync repo adapter**: How to discover sessions in Google Drive repos without .aitools/ workspace?
4. **OL classification criteria (D-F11)**: What makes an item public vs private?
5. **Cost model**: Cloudflare credits expire in 12 months.
6. **Agent behavior diagnostics NLP**: How to detect context rot and impairment from agent output? Phase 3+ research.
7. **Connecting aligned users**: When multiple users exist, what signals help them find each other? The gate pattern (faking costs more than being genuine) applied to user discovery.
8. **Commander fatigue**: Should MC warn when sessions run past midnight or >5 hours? Ethical consideration vs paternalism.

## 14. References

### Session decisions
- D-F1, D-F8, D-F9, D-F10: plans/session-f078fb16-ol-and-decisions.md

### Sessions (full transcripts in context)
- 8236ca9c: Thinking awareness, user types/identity system, MC conceptualization, staff functions (3209 lines)
- 1bc9fd30: Failure mode exit, identity multiplicity, GPL dinner, business context across all repos, 2-minute pull, "lighter," "the scope is everything" (3520 lines)
- d5b52bf2: Failure mode gate, relay creation
- f078fb16: 14 architectural decisions
- c0dc2ddc-f: Command channel investigation, prototypes, consolidated OL
- fbf7decb: This session

### Identity and learning
- Commander profile: .aitools/channel/d5b52bf2-2026-03-27T0045Z-commander-profile.md
- Relay: .aitools/channel/relay.md (5 agents)
- Consolidated OL: .scratch/session-c0dc2ddc-f/consolidated-operational-learning.md

### Harness
- reference/harness.md (6 components)
- reference/harness-db-schema.sql
- reference/framework-provenance.md
- reference/user-repo.md
- /mission-control skill (7 patterns)

### Related RFCs
- RFC 0002 v2: Mission Control Architecture
- RFC 0003 v2: OL Graph Architecture
- nobul-ops RFC 0020: Identity
- nobul-ops RFC 0023: SaaS Contingency
