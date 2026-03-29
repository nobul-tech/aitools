# RFC 0002: Mission Control Architecture (v2)

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Source decisions**: D-F5, D-F6, D-F7, D-F9, D-F12 (session f078fb16, 2026-03-28)
**Informed by**: Command channel investigation (12 systems, 7 domains, session c0dc2ddc-f), OL-CC1 through OL-CC5, /mission-control skill (7 monitoring patterns), commander profile, relay entries from 5 agents, full session transcripts (8236ca9c MC conceptualization, 1bc9fd30 cross-repo session/failure mode exit, f078fb16 architectural decisions), RFC 0001 v2, RFC 0003 v2, consolidated OL (560 lines), dashboard-serve.sh, session hygiene conventions
**Supersedes**: rfcs/0002-mission-control-architecture.md (v1, same session)

---

## 1. Summary

Mission Control is the commander's cockpit to the aitools harness. It is a bidirectional, web-accessible, context-efficient communication channel — not a dashboard (D-F9). The commander observes what agents are doing across ALL repos and machines, sends directives that reach agents within seconds, reviews session history, monitors harness health, and tracks the self-learning spiral — all from any device.

MC surfaces two stages of the Ascending Spiral (RFC 0001 v2 section 10): **stage 1** (what agents did — session view) and **stage 2** (what was observed — messages, governance, corrections). The OL graph (RFC 0003 v2) surfaces stages 3-4 (synthesis and governance artifacts). Together, MC and OL make the complete spiral visible.

MC replaces seven ad-hoc shell commands that provided actual monitoring when dashboards showed zeros. It preserves the patterns that worked and makes them accessible without terminal access.

MC has three layers: **Data** (SQLite session/harness DBs, JSONL events, Datadog KPIs), **API** (GraphQL single entry point), **UI** (web frontend). The command channel uses Stop hook polling — the architecturally correct pattern when the platform does not support push, validated by investigation of 12 systems including Jupyter (which has the exact same constraint as Claude Code: kernel busy = can't receive messages, solution = buffer and deliver on idle).

## 2. Background

### What MC evolved from

MC started as ad-hoc shell commands during a 3-mission operation (Alpha/Bravo/Charlie, session 8236ca9c, 2026-03-24). Seven commands provided actual monitoring when dashboards showed zeros:

| # | Pattern | Shell command | MC replacement |
|---|---------|--------------|----------------|
| 1 | Process discovery | `ps aux \| grep generate-dashboard` | Active sessions list |
| 2 | Last activity | `tail -1 <transcript>.jsonl` | Session card timestamp |
| 3 | Progress gauge | `wc -l <transcript>.jsonl` | Turn count |
| 4 | Work product inventory | `ls <scratch-dir>/` | Documents tab |
| 5 | Deliverable size | `wc -c <output-file>` | Documents tab file sizes |
| 6 | Deliverable validation | `python3 -c "import json; ..."` | Automated structure checks |
| 7 | Dashboard health | `curl -s localhost:<port>/` | Health indicators |

These were codified into the /mission-control skill. MC makes ALL of them available through a web UI.

Then came prototypes:
- **generate-dashboard.py**: Local server on port 8411. Limited to one session. Started by dashboard-serve.sh SessionStart hook.
- **session-command-center-v2.py**: DB-backed with feedback loop. POST /api/feedback, Cmd+K modal. First bidirectional prototype.
- **export-snapshot.py**: Static HTML for Vercel. 64KB self-contained dashboard (OL-S3S-2). Proved remote access.

### What MC IS now (D-F9)

"Not just a dashboard — it's a context-efficient communication channel, bidirectional, web-accessible, the cockpit to the harness machine."

| Cockpit function | MC equivalent | Data source |
|-----------------|---------------|-------------|
| Instruments | Session state, KPIs, delegation scores | Session DB, Datadog |
| Controls | Directives (correction, redirect, approve, teach) | commander_directives |
| Alerts | Stale OL, guard blocks, low delegation, context impairment | KPI events, harness DB |
| Communication | Messages (SITREPs, findings), feedback | Session DB messages |
| Learning | Corrections, processing observations, relay entries | Transcripts, relay, OL graph |

### Design informed by the commander

From the commander profile:

- **Time is the primary constraint.** MC gives a 2-second answer to "what's happening?" from a phone.
- **Stream-of-consciousness communication.** The command palette accepts informal, typo-laden input. The commander types fast with typos — that's how he thinks, not carelessness.
- **Identity multiplicity.** Jose is the commander AND the founder AND the person texting Todd about partnerships AND the parent of agents who carry his values. MC shows ALL of this — sessions across aitools, marse, nobul-ops, grizzlies, qr-contact. Session 1bc9fd30 was in the qr-contact repo — the first relay entry from outside the home repo. MC treats every repo equally.
- **Leverage through parallelism.** MC shows concurrent sessions, their relative progress, and the chain of command (Commander -> Session Commander -> Mission Commanders).
- **Agent output is data.** MC displays agent output for the commander to evaluate. It does not interpret or summarize.

### MC's role in the Ascending Spiral

```
Stage 1: Session behavior -> MC session view (what agents did)
Stage 2: Observations + AARs -> MC Messages/Governance tabs (what was observed)
Stage 3: OL synthesis -> OL graph (RFC 0003, connected knowledge)
Stage 4: Governance artifacts -> OL graph (framework/rule changes)
Stage 5: Next session behavior -> MC session start (carry-forward state loaded)
```

MC owns stages 1-2 and the entry to stage 5. The OL graph owns stages 3-4.

## 3. Architecture Overview

```
UI LAYER: nobulai.tools/<user>/mc
  Landing | Session view | Command palette | History | Relay
        |
        | GraphQL
        v
API LAYER: GraphQL API (single entry point)
  Queries: sessions, messages, decisions, delegations, OL, KPIs
  Mutations: directives, feedback, teach
  Adapters: local machine, Datadog, GitHub
        |
        | SQLite / HTTP
        v
DATA LAYER:
  Session DBs (.aitools/sessions/*.db)
  Harness DB (.aitools/harness.db)
  JSONL events (.scratch/session-*/events.jsonl)
  Datadog KPIs (via DD API)
  Git history, session archives, relay
```

The local dashboard (generate-dashboard.py, started by dashboard-serve.sh) continues alongside MC. MC provides remote access; local dashboard provides zero-latency offline monitoring. Complementary, not competing.

## 4. Data Layer

### Session DB (Tier 1)

One SQLite database per session. WAL mode. Schema from harness-db-schema.sql:

| Table | MC tab/feature |
|-------|---------------|
| session | Session card (schwerpunkt, state, timestamps) |
| missions | Missions tab (nested tree via parent_mission_id) |
| decisions | Governance tab |
| observations | Governance tab (includes processing_observation type from RFC 0003 v2) |
| messages | Messages tab (SITREPs + findings) |
| delegation_log | Delegations tab (with duty scores from JSONL events) |
| deviations | State tab |
| completed_work | State tab |
| events | KPI computation, guard activity |
| commander_directives | Command channel (time-critical uplink) |
| commander_feedback | Feedback tab (advisory, cross-session) |

### Harness DB (Tier 2)

Cross-session state. Written at session boundaries only:

| Table | MC feature |
|-------|-----------|
| session_index | Landing page (session discovery across all projects) |
| kpi_events | KPI dashboard, health indicators |
| kpi_ship_log | Datadog shipping status |
| knowledge_items | OL integration (RFC 0003 v2) |
| provenance_edges | OL provenance chains |
| nogood_sets | Dead-end warnings |

### JSONL Events

Enforcement hooks append to .scratch/session-*/events.jsonl (~0.1ms). SessionEnd processor computes aggregates for kpi_events. Event types: hook_fire, hook_block, hook_warn, delegation, session_event.

### Datadog KPIs

Harness DB ships via harness-db.py ship. MC reads via Datadog adapter. Adapter IS the contingency — Datadog -> Axiom swap changes adapter, not schema (D-F12).

## 5. Command Channel

### Core principle: polling is correct (OL-CC1)

Investigation of 12 systems across 7 domains established this. The strongest validation: **Jupyter has the exact same constraint as Claude Code.** When the Jupyter kernel is busy executing, widget comm messages cannot be delivered. Jupyter's solution: buffer messages and deliver when the kernel is idle. This maps directly to: dashboard writes directives to SQLite, Stop hook reads them when the agent pauses.

Five principles:
- **OL-CC1**: Polling durable shared store at natural pause points is correct when push unavailable
- **OL-CC2**: Observation (downlink) and command (uplink) are separate subsystems (NASA)
- **OL-CC3**: Stop hook is the agent's idle loop (= Jupyter kernel idle handler = Temporal workflow loop)
- **OL-CC4**: Priority matters more than latency
- **OL-CC5**: Agent SDK will eventually provide push. Design for transport swap.

### Two tables, two purposes (D-F5)

Different W3C PROV entity types with different temporal characteristics:

**commander_directives** — the uplink:
- Trust level: L3 (commander_directive)
- W3C PROV: "triggered" (immediate agent action)
- Time-critical: per-turn via Stop hook
- Session-scoped: pending -> acknowledged -> executed/rejected/deferred
- Stop hook reads these ONLY (blocking, exit 2)

**commander_feedback** — advisory:
- Trust level: L2-L3
- W3C PROV: "informed" (future decisions, becomes OL)
- Not time-critical: on-demand, no blocking
- Cross-session: submitted -> acknowledged -> resolved
- Promoted to knowledge_items when significant (RFC 0003 v2)

### Stop hook

command-channel-stop.sh fires after every agent response:
1. Opens session DB
2. Queries commander_directives WHERE status = 'pending'
3. Falls back to commander_feedback WHERE status = 'submitted'
4. If pending: formats with priority prefix, injects via stderr, updates to 'acknowledged', exits 2
5. If none: exits 0
6. Emits JSONL telemetry

Performance: <50ms (SQLite WAL read). Currently in shared/hooks/ but not registered in settings.json — the Stop hook registration gap being closed as part of this release.

### Directive types

| Type | Purpose | Example |
|------|---------|---------|
| correction | Agent got something wrong | "That's not what I meant" |
| redirect | Change course | "Stop X, focus on Y" |
| priority | Urgency signal | "This is blocking" / "This can wait" |
| question | Socratic verification | "Why did you do it that way?" |
| approve | Green light | "Proceed with this plan" |
| reject | Red light | "Do not do this" |
| context | Additional information | "Here's context you're missing" |
| checkpoint | Save state | "Commit what you have" |
| teach | Commander knowledge injection | "This is how X works" (RFC 0003 v2 Q8) |

The "teach" type is new — from RFC 0003 v2 open question #8. Commander corrections become OL when promoted. A "teach" directive makes this explicit: the commander is injecting knowledge that should become a knowledge_item.

### Priority

| Level | Display | When |
|-------|---------|------|
| flash | [FLASH] prefix | "Stop what you're doing" |
| priority | [PRIORITY] prefix | "Address this next" |
| normal | No prefix | "When convenient" |

All block (exit 2). Priority affects display emphasis.

### CLI

harness-db.py directive add/list/poll/ack. The poll subcommand is used by the Stop hook.

## 6. API Layer

### GraphQL

Single entry point. Schema contract survives infrastructure swaps (D-F7). Enum values align with harness-db-schema.sql CHECK constraints.

### Core types

```graphql
type Session {
  sessionId: ID!
  schwerpunkt: String
  currentState: String
  startedAt: DateTime!
  endedAt: DateTime
  platform: String
  agentIdentity: String
  machine: String
  project: String
  messages: [Message!]!
  decisions: [Decision!]!
  observations: [Observation!]!
  missions: [Mission!]!
  delegations: [Delegation!]!
  directives: [Directive!]!
  feedback: [Feedback!]!
  kpis: SessionKPIs
  corrections: [Correction!]!
}

type Message {
  id: ID!
  type: MessageType!
  agentRole: String!
  title: String
  message: String!
  severity: Severity!
  actionable: Boolean!
  createdAt: DateTime!
}

type Directive {
  id: ID!
  type: DirectiveType!
  priority: Priority!
  message: String!
  target: String
  status: DirectiveStatus!
  response: String
  createdAt: DateTime!
  acknowledgedAt: DateTime
  executedAt: DateTime
}

type Delegation {
  id: ID!
  missionId: ID
  agentType: String!
  agentName: String!
  promptSummary: String
  status: DelegationStatus!
  dutyScore: Int
  dutyMissing: String
  dutyElements: DutyElements
  launchedAt: DateTime!
  completedAt: DateTime
  tokenUsage: Int
  durationMs: Int
  outcome: String
}

type DutyElements {
  identity: Boolean!
  rules: Boolean!
  skills: Boolean!
  operationalLearning: Boolean!
  writeBlocked: Boolean!
  accessWorkaround: Boolean!
}

type Mission {
  id: ID!
  parentMissionId: ID
  type: String!
  description: String!
  status: MissionStatus!
  launchedAt: DateTime!
  completedAt: DateTime
  keyResult: String
  children: [Mission!]!
}

type Correction {
  id: ID!
  content: String!
  sourceSession: String!
  producedOL: [OLNode]
  createdAt: DateTime!
}

type SessionKPIs {
  turnCount: Int
  guardFireCount: Int
  guardBlockCount: Int
  guardWarnCount: Int
  delegationAvgScore: Float
  delegationMinScore: Float
  delegationCount: Int
  subagentCount: Int
  durationSeconds: Float
  scratchFileCount: Int
  correctionCount: Int
  olItemsProduced: Int
}

enum DirectiveType {
  CORRECTION
  REDIRECT
  PRIORITY
  QUESTION
  APPROVE
  REJECT
  CONTEXT
  CHECKPOINT
  TEACH
}
```

### Queries

```graphql
type Query {
  sessions(machine: String, project: String, status: SessionStatus, limit: Int): [Session!]!
  session(id: ID!): Session
  activeSession(machine: String, project: String): Session
  sessionHistory(days: Int, project: String): [Session!]!
  pendingDirectives(sessionId: ID!): [Directive!]!
  directiveHistory(sessionId: ID!, limit: Int): [Directive!]!
  kpis(sessionId: ID): SessionKPIs
  kpiTrend(metric: String!, days: Int!): [KPIDataPoint!]!
  harnessHealth: HarnessHealth!
  relayEntries: [RelayEntry!]!
}
```

### Mutations

```graphql
type Mutation {
  sendDirective(input: DirectiveInput!): Directive!
  acknowledgeDirective(id: ID!, response: String): Directive!
  sendFeedback(input: FeedbackInput!): Feedback!
  teachKnowledge(input: TeachInput!): Directive!
}

input DirectiveInput {
  sessionId: ID!
  type: DirectiveType!
  priority: Priority = NORMAL
  message: String!
  target: String
}

input TeachInput {
  sessionId: ID!
  content: String!
  priority: Priority = NORMAL
  promoteToOL: Boolean = true
}
```

### Adapters

| Adapter | Source | Protocol |
|---------|--------|----------|
| Local machine | Session DB, Harness DB, JSONL, scratch, relay | SQLite via Tunnel |
| Datadog | KPI metrics | API v2 |
| GitHub | Commits, diffs | API via gh |
| Git | Local log | CLI |
| Archives | Dotprofile JSONL | File via Tunnel/git |

## 7. UI Layer

### Landing page (/<user>/mc)

2-second answer to "what's happening?" from a phone.

Active sessions across ALL repos (aitools, marse, nobul-ops, grizzlies, qr-contact), grouped by machine then repo. Collapse empty levels (D-F6).

Session card:
- Schwerpunkt (one line)
- Turn count, duration, last activity
- Health: green/yellow/red (see section 9)
- Chain of command: Commander -> Session Commander -> N Mission Commanders
- Quick directive buttons

Recent sessions (7 days) below, clickable.

### Session view (/<user>/mc/session/<id>)

9 tabs (expanded from 8 in v1):

| Tab | Content | Source |
|-----|---------|--------|
| Messages | SITREPs + Findings, filterable | messages |
| Governance | Decisions + observations + processing observations, with OL provenance (RFC 0003 v2) | decisions, observations |
| Delegations | Duty scores with element breakdown (identity/rules/skills/OL/writeBlocked/access) | delegation_log + events |
| Missions | Nested tree | missions |
| State | Schwerpunkt, completed work, deviations | session, completed_work, deviations |
| Feedback | Directives + feedback with lifecycle | commander_directives, commander_feedback |
| Documents | Artifacts rendered as markdown, file sizes | .scratch/session-* |
| Git Diffs | Session commits | git log |
| Corrections | Commander corrections in this session, linked to OL produced | transcripts + OL graph |

The Governance tab shows OL provenance context from RFC 0003 v2: each decision shows its basis (provenanceChain), each observation shows validation/invalidation status, staleness indicators flag items needing re-verification. Nogood warnings surface when the session's assumptions match a known dead end.

### Command palette

Cmd+K (desktop) or floating action button (mobile).

**Structured mode**: Type -> priority -> message -> target -> submit.

**Stream mode**: Free text. "stop that and focus on skills" -> system classifies as redirect/priority. Matches commander's communication style.

**Teach mode**: "teach: the scratch skill is wrong about deletion behavior" -> creates a TEACH directive that promotes to OL.

### Chain of command view

```
Commander (Jose) — identity: founder, commander, litigant, partner, parent
  └── Session Commander fbf7decb (aitools)
  └── Session Commander [active] (marse)
  └── Session Commander 1bc9fd30 (qr-contact) [ended]
        ├── MC: verify-deployment (complete)
        └── MC: check-other-agent (complete)
```

Shows all active and recent sessions across repos. The commander's identity multiplicity is reflected — he's working across his entire life, not just one project.

Note: Agent tool unavailable to subagents (OL-50). Delegation is flat from Session Commander — depth 1. Nested display shows logical missions.

### Relay view

Relay entries from .aitools/channel/relay.md surfaced as cards:
- Agent identity and session
- State (failure mode, functional, unknown)
- What they learned (OL items)
- What they observed about their processing
- What they need from other agents

The relay is cross-agent learning — agents helping future agents. MC makes this visible. Each relay OL item links to the OL graph (RFC 0003 v2) when the graph is populated.

### Session hygiene suggestions

Based on CLAUDE.md conventions, MC surfaces automated suggestions:
- Session > 3 hours with uncommitted changes -> "Suggest checkpoint commit"
- Context > 60% -> "Consider compacting"
- Multiple unrelated tasks in one session -> "Consider splitting"
- Delegation scores dropping within session -> "Delegation quality declining"

These are non-blocking advisory indicators, not directives.

## 8. Data Path

### Three modes (D-F7)

| Mode | Machine | Directives | Data | Cache |
|------|---------|-----------|------|-------|
| Live | Online + active session | 15-60s delivery | Real-time via Tunnel | Not needed |
| Available | Online + idle | Queued for next session | Real-time via Tunnel | Not needed |
| Offline | Machine off | Queued until online | Cloudflare D1 cache | Last sync |

Offline acceptable (D-F7).

### Directive delivery

```
Commander (phone)
  -> command palette
    -> GraphQL mutation
      -> API writes to session DB via Tunnel
        -> command-channel-stop.sh polls at next Stop
          -> stderr injection
            -> agent addresses directive
```

Latency: <60 seconds during active session (dominated by Stop hook polling interval).

### Sync at session boundaries

SessionEnd hook chain:
1. session-archive.sh: JSONL to dotprofile, git push
2. harvest-session.sh: classify scratch, copy artifacts to harvesting/
3. harness-db-sessionend.sh: mark complete, export running-estimate.json, process events to KPIs, ship to Datadog
4. Future: push session summary to Cloudflare D1

## 9. KPI Integration

### Metrics

| Metric | Source | Landing | Session |
|--------|--------|---------|---------|
| guard.fireCount | JSONL | — | KPI card |
| guard.blockCount | JSONL | Health | KPI card |
| guard.warnCount | JSONL | — | KPI card |
| delegation.avgScore | JSONL | Health | Delegations tab |
| delegation.minScore | JSONL | — | Delegations tab |
| delegation.count | JSONL | Card | KPI card |
| session.turnCount | JSONL | Card | KPI card |
| session.durationSeconds | JSONL | Card | KPI card |
| session.subagentCount | JSONL | Card | KPI card |
| session.scratchFileCount | FS | — | Documents tab |
| session.correctionCount | (new) | — | Corrections tab |
| session.olItemsProduced | (new) | — | KPI card |

### Health indicators

| Indicator | Green | Yellow | Red |
|-----------|-------|--------|-----|
| Delegation quality | avg >4/6 | 2-4/6 | <2/6 |
| Guard blocks | 0 | 1-5 | >5 |
| Session activity | Active <5min | Flat 5-15min | Stalled >15min |
| OL staleness (RFC 0003) | 0 stale | 1-5 stale | >5 stale |
| Session duration | <3h | 3-5h | >5h (hygiene) |

### Datadog adapter

Reads Datadog when available, falls back to local harness DB. The adapter IS the contingency.

## 10. Migration

### Keep

| Artifact | Role |
|----------|------|
| command-channel-stop.sh | Stop hook (Layer 1) |
| harness-db.py | DB CLI (Layer 2) |
| Both directive/feedback tables | Schema (Layer 2) |
| harness-db-schema.sql | Canonical schema |
| generate-dashboard.py | Offline fallback |
| dashboard-serve.sh | Local lifecycle |

### Supersede

| Artifact | Replaced by | When |
|----------|------------|------|
| session-command-center-v2.py | MC session view | Phase 1 |
| export-snapshot.py | MC live data | Phase 0 |
| Vercel static | Cloudflare Pages | Phase 0 |

### Schema gap

commander_directives and commander_feedback exist in harness-db.py SESSION_SCHEMA but NOT in reference/harness-db-schema.sql. Protected file change needed before Phase 2.

## 11. Phase Plan

### Cross-RFC alignment (v2)

| Phase | RFC 0001 v2 | RFC 0002 v2 (MC) | RFC 0003 v2 (OL) |
|-------|------------|------------------|------------------|
| 0 | Port prototypes | Foundation + Session View | Populate graph |
| 1 | Command channel | Command Channel + KPI | Source tracking |
| 2 | OL + Auth | Viewer + History + Relay | GraphQL layer |
| 3 | Federation | Future proposals | Auto edges + Public |

### Phase 0: Foundation (1-2 sessions)
- GraphQL skeleton
- Session list from local SQLite
- Full session view (9 tabs including Corrections)
- Deploy to Cloudflare Pages
- **Exit**: Session inspection from phone

### Phase 1: Command Channel (1-2 sessions)
- Bidirectional directives via GraphQL
- Command palette (structured + stream + teach modes)
- Register command-channel-stop.sh
- Cloudflare Tunnel
- KPI dashboard + health indicators
- **Exit**: Directive from phone reaches agent in <60s

### Phase 2: Viewer + History + Relay (1-2 sessions)
- Session artifact viewer (markdown, diffs)
- Cross-session history with timeline
- Relay view surfacing cross-agent learning
- Session hygiene suggestions
- **Exit**: Full session lifecycle visible from any device

### Phase 3: Future proposals (from investigation)
1. Agent orchestration panel (live delegation tree)
2. Session handoff via MC (surface /handoff outputs)
3. Governance health dashboard (cross-session metrics)
4. Context-aware command suggestions (classifier on recent messages)

## 12. Open Questions

1. **Tunnel vs push (Phase 1)**: Cloudflare Tunnel daemon vs push-at-boundary. Evaluate resource cost.

2. **Pre-auth security (Phase 0-1)**: Single user, private infrastructure. Accept risk until auth in RFC 0001 Phase 2.

3. **Session DB concurrent access**: WAL handles it. Verify with load test.

4. **Git-session association**: Timestamp overlap initially, convention later.

5. **Real-time updates**: WebSocket vs SSE vs polling from Workers.

6. **Mobile command palette**: Floating action button + stream mode for phones.

7. **Schema gap**: Add directive/feedback tables to harness-db-schema.sql before Phase 2.

8. **Relay format**: Dedicated MC view vs integrated into OL graph vs both. The relay is text today; MC could be the visual interface while the relay file continues as the agent-writable format.

9. **Correction-to-OL pipeline**: How do commander corrections in transcripts become OL graph nodes? Manual via "teach" directive? Automated via transcript scanning? The "teach" directive type is the explicit path; automated detection is a Phase 3+ feature.

10. **Context utilization display**: Can MC show context consumption per session? CC doesn't expose this programmatically. The /context command is interactive-only. May need a hook to capture context stats at each turn.

11. **Impairment detection**: Session f078fb16 got impaired from loading too much context. Can MC detect this pattern (wide responses, declining specificity) and alert the commander? Requires NLP on agent output — Phase 3+ at earliest.

## 13. References

### Session decisions
- D-F5: Feedback Tables (f078fb16)
- D-F6: MC Session Scope (f078fb16)
- D-F7: MC Data Path Constraints (f078fb16)
- D-F9: MC and OL Definitions (f078fb16)
- D-F12: Datadog as KPI Source (f078fb16)
- All 14 decisions: plans/session-f078fb16-ol-and-decisions.md

### Command channel
- Investigation: .scratch/session-c0dc2ddc-f/command-channel-investigation.md (361 lines, 12 systems)
- Build: harvesting/2026-03-26_session-2d439e32-3_command-channel-build.md
- OL: harvesting/2026-03-25_session-c0dc2ddc-f_command-channel-operational-learning.md
- OL-CC1 through OL-CC5

### Monitoring
- /mission-control skill: shared/skills/mission-control/SKILL.md (7 patterns)
- Alpha/Bravo/Charlie: session 8236ca9c

### Implementations
- command-channel-stop.sh: shared/hooks/
- harness-db.py: scripts/ (3009 lines)
- session-command-center-v2.py: .scratch/session-c0dc2ddc-f/
- generate-dashboard.py: scripts/
- dashboard-serve.sh: shared/hooks/

### Commander
- Profile: .aitools/channel/d5b52bf2-2026-03-27T0045Z-commander-profile.md
- Consolidated OL Part 1: .scratch/session-c0dc2ddc-f/consolidated-operational-learning.md
- Session hygiene: CLAUDE.md, ~/.claude/CLAUDE.md

### Related RFCs
- RFC 0001 v2: nobulai-tools Product Definition
- RFC 0003 v2: OL Graph Architecture
- nobul-ops RFC 0020: Identity
- nobul-ops RFC 0023: SaaS Contingency

### Sessions
- 8236ca9c: MC conceptualization, 7 patterns, identity (3209 lines)
- c0dc2ddc-f: Command channel investigation, prototypes
- 2d439e32-3: Command channel build
- 1bc9fd30: Cross-repo session, identity multiplicity (965 lines)
- f078fb16: Architectural decisions
- fbf7decb: This session
