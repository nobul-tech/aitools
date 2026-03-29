# RFC 0002: Mission Control Architecture

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Source decisions**: D-F5, D-F6, D-F7, D-F12 (session f078fb16, 2026-03-28)
**Informed by**: Command channel investigation (12 systems, 7 domains, session c0dc2ddc-f), OL-CC1 through OL-CC5, full harness codebase in context, 3 full session transcripts (8236ca9c, 1bc9fd30, f078fb16), relay entries from 5 agents

---

## 1. Summary

Mission Control is the commander's cockpit to the aitools harness. It is a bidirectional, web-accessible, context-efficient communication channel — not a dashboard. The commander observes what agents are doing, sends directives that reach agents within seconds, reviews session history across all projects and machines, and monitors harness health.

MC has three layers: **Data** (SQLite session/harness DBs, JSONL events, Datadog KPIs), **API** (GraphQL as the single entry point), and **UI** (web frontend accessible from any device). The command channel uses a Stop hook polling pattern validated by investigation of 12 systems across 7 domains — the architecturally correct pattern when the platform does not support push notifications.

This RFC defines the architecture. RFC 0001 defines the product. RFC 0003 defines the OL graph that MC surfaces.

## 2. Background

### What MC evolved from

MC started as ad-hoc shell commands during a 3-mission operation (Alpha/Bravo/Charlie, 2026-03-24). Seven commands provided actual monitoring when dashboards showed zeros. These commands were codified into the /mission-control skill.

Then came prototypes:
- **generate-dashboard.py**: Local Python server reading running-estimate.json, serving HTML on port 8411. Limited to one session's data.
- **session-command-center-v2.py**: DB-backed dashboard with feedback loop. POST /api/feedback for commander input. GET endpoints for session data. The first bidirectional prototype.
- **export-snapshot.py**: Static HTML exporter for Vercel deployment. Snapshot at export time, no live updates. Proved the concept of remote access.

These prototypes are superseded by this architecture but their patterns are preserved.

### What MC IS now

MC is defined by D-F9: "not just a dashboard — it's a context-efficient communication channel, bidirectional, web-accessible, the cockpit to the harness machine."

The cockpit metaphor is precise. A pilot's cockpit provides: instrument readings (telemetry), controls (command input), alerts (anomaly detection), and communication (radio). MC provides the same: session state (telemetry), directives (command input), health indicators (anomaly detection), and the conversation itself (communication).

## 3. Architecture Overview

```
UI LAYER: nobulai.tools/<user>/mc
  Landing page | Session view | Command palette
        |
        | GraphQL
        v
API LAYER: GraphQL API (single entry point)
  Queries: sessions, messages, decisions, OL
  Mutations: directives, feedback
  Adapters: local machine, Datadog, GitHub
        |
        | SQLite / HTTP
        v
DATA LAYER:
  Session DBs (.aitools/sessions/*.db)
  Harness DB (.aitools/harness.db)
  JSONL events (.scratch/session-*/events.jsonl)
  Datadog KPIs (via DD API)
  Git history (commits, diffs)
  Session archives (dotprofile JSONL)
```

## 4. Data Layer

### Session DB (Tier 1)

One SQLite database per Claude Code session at `.aitools/sessions/<prefix>.db`. Written by that session's agents only. Schema from `reference/harness-db-schema.sql`:

| Table | Purpose |
|-------|---------|
| session | Session metadata (schwerpunkt, state, timestamps, platform, identity) |
| missions | Delegated agent missions (self-referential for nesting) |
| decisions | Architectural and session decisions |
| observations | Classified per governed vocabulary (observation, assumption, fact, finding) |
| messages | SITREPs and FINDINGs |
| delegation_log | Every agent launch with duty compliance |
| deviations | Process deviations |
| hard_requirements | Requirements tracking |
| completed_work | Shipped items |
| events | Append-only event log (hook fires, blocks, warns, delegations) |
| commander_directives | Time-critical uplink from commander to agent |
| commander_feedback | Advisory feedback (cross-session lifecycle) |

### Harness DB (Tier 2)

Cross-session state at `.aitools/harness.db`. Written at session boundaries only.

| Table | Purpose |
|-------|---------|
| session_index | Lightweight discovery of all sessions |
| kpi_events | Individual metric measurements |
| kpi_ship_log | Datadog shipping state |
| dashboard_state | Runtime dashboard tracking |
| knowledge_items | Provenance system atoms |
| provenance_edges | Dependency graph |
| nogood_sets | Known contradiction combinations |

### JSONL Events

Enforcement hooks append structured events to `.scratch/session-*/events.jsonl` during sessions (~0.1ms per event). The SessionEnd processor (`harness-db.py process-events`) reads these and computes aggregate metrics for `kpi_events`. This is the hot-path telemetry — zero Python subprocess overhead during the session.

### Datadog KPIs

The harness DB ships KPI events to Datadog via `harness-db.py ship`. Metrics include: guard fire/block/warn counts, delegation compliance scores, session duration, turn count, scratch file count. DD_API_KEY and DD_SITE environment variables configure shipping.

MC reads KPIs from Datadog API through an adapter. The adapter IS the contingency — when Datadog flips to Axiom, the adapter handles it (D-F12).

## 5. Command Channel

### Architecture (from command-channel-investigation.md)

The investigation of 12 systems across 7 domains established:

- **OL-CC1**: Polling a durable shared store at natural pause points is the correct pattern when push is unavailable.
- **OL-CC2**: Observation (telemetry/downlink) and command (uplink) are separate subsystems sharing a common data store. NASA separates them because they have different bandwidth, latency, and reliability requirements.
- **OL-CC3**: The Stop hook is the agent's "idle loop" — same function as Temporal's workflow main loop and Jupyter's kernel idle handler.
- **OL-CC4**: Priority matters more than latency. Flash directives interrupt immediately; context can wait.
- **OL-CC5**: The Claude Agent SDK will eventually solve this better. Design for transport swap.

### Two tables, two purposes (D-F5)

Both tables are kept. They are different W3C PROV entity types:

**commander_directives** — the uplink:
- Trust level: L3 (commander_directive)
- Relationship: "triggered" (triggers immediate agent action)
- Time-critical: per-turn delivery via Stop hook
- Session-scoped lifecycle: pending -> acknowledged -> executed
- The Stop hook reads these ONLY (blocking, exit 2)

**commander_feedback** — advisory:
- Trust level: varies (L2-L3)
- Relationship: "informed" (informs future decisions, becomes OL)
- Not time-critical: readable by agents on demand
- Cross-session lifecycle: submitted -> acknowledged -> resolved
- May span sessions. Becomes knowledge_items when promoted.

### Stop hook polling

`command-channel-stop.sh` fires after every agent response:

1. Opens session SQLite DB
2. Queries `commander_directives WHERE status = 'pending'`
3. Falls back to `commander_feedback WHERE status = 'submitted'`
4. If pending: injects via stderr (CC adds to agent context), updates status to 'acknowledged', exits 2 (blocks agent until addressed)
5. If none: exits 0 (no-op)

Performance: SQLite WAL read <5ms. Total hook budget <50ms. Well within constraints.

Priority handling:
- `flash`: [FLASH] prefix in stderr output
- `priority`: [PRIORITY] prefix
- `normal`: no prefix
- All priorities cause exit 2 — priority affects display, not blocking behavior

### Directive types

| Type | Purpose |
|------|---------|
| correction | "This is wrong, the correct answer is X" |
| redirect | "Stop X, do Y instead" |
| priority | "This is urgent / this can wait" |
| question | "Why did you do X?" (Socratic verification) |
| approve | "Proceed with this plan" |
| reject | "Do not proceed with this plan" |
| context | "Here's additional context: ..." |
| checkpoint | "Commit what you have, summarize progress" |

### CLI access

`harness-db.py` provides CLI access to directives:
- `directive add "message" [--type X] [--priority Y] [--target Z]`
- `directive list [--status S]`
- `directive poll` (used by the Stop hook)
- `directive ack <id> [--response R] [--status S]`

## 6. API Layer

### GraphQL as single entry point

All frontend queries and adapter integrations go through GraphQL. The schema is the contract that survives infrastructure swaps (D-F7).

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

type Decision {
  id: ID!
  title: String!
  description: String
  status: DecisionStatus!
  decidedAt: DateTime!
  implementedAt: DateTime
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

type Delegation {
  id: ID!
  missionId: ID
  agentType: String!
  agentName: String!
  promptSummary: String
  status: DelegationStatus!
  launchedAt: DateTime!
  completedAt: DateTime
  tokenUsage: Int
  durationMs: Int
  outcome: String
}

type SessionKPIs {
  turnCount: Int
  guardFireCount: Int
  guardBlockCount: Int
  delegationAvgScore: Float
  delegationMinScore: Float
  subagentCount: Int
  durationSeconds: Float
  scratchFileCount: Int
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
}
```

### Mutations

```graphql
type Mutation {
  sendDirective(input: DirectiveInput!): Directive!
  acknowledgeDirective(id: ID!, response: String): Directive!
  sendFeedback(input: FeedbackInput!): Feedback!
}

input DirectiveInput {
  sessionId: ID!
  type: DirectiveType!
  priority: Priority = NORMAL
  message: String!
  target: String
}
```

### Adapters

| Adapter | Reads from | Protocol |
|---------|-----------|----------|
| Local machine | Session DB, Harness DB, JSONL events | SQLite (via Cloudflare Tunnel or local endpoint) |
| Datadog | KPI metrics | Datadog API v2 |
| GitHub | Commit history, diffs | GitHub API via gh |
| Git | Local commit log | git CLI |
| Session archives | Dotprofile JSONL | File read (local or via push) |

## 7. UI Layer

### Landing page

Shows all sessions across all projects and machines. Grouped by machine (using machineAlias from profile.json), then repo. Empty levels collapse (D-F6).

For each active session:
- Schwerpunkt
- Turn count and duration
- Last activity timestamp
- Health indicator (from KPIs)
- Quick directive buttons

For recent sessions (last 7 days):
- Clickable to session view
- End time and duration
- Key outcome

### Session view

Tab-based view:

| Tab | Content | Source |
|-----|---------|--------|
| Messages | SITREPs + Findings, filterable by severity/type | session DB: messages |
| Governance | Decisions + observations | session DB: decisions, observations |
| Delegations | Subagent launches with duty scores | session DB: delegation_log |
| Missions | Nested mission tree with status | session DB: missions |
| State | Schwerpunkt, completed work, deviations | session DB: session, completed_work, deviations |
| Feedback | Commander directives + feedback with lifecycle | session DB: commander_directives, commander_feedback |
| Documents | Session artifacts rendered as markdown | .scratch/session-*/files |
| Git Diffs | Commits from this session | git log filtered by session timeframe |

### Command palette

Cmd+K opens a structured command interface:

1. Select directive type
2. Set priority (flash, priority, normal)
3. Write message
4. Optional: set target (mission, file, decision)
5. Submit -> GraphQL mutation -> session DB -> Stop hook reads at next pause

Quick action buttons for common directives are always visible in the header.

## 8. Data Path

### The constraint

The user's machine is the source of truth. Session DBs, JSONL events, and scratch files are local. nobulai.tools needs to display this data from any device.

### Three modes (D-F7)

**Machine online + session active**: Real-time. Cloudflare Tunnel connects the local machine to the cloud API. Directive delivery within 15-60 seconds. Session data refreshes on each query.

**Machine online + no active session**: Near-real-time. Data available via Tunnel. No directive delivery. History and OL queries work normally.

**Machine offline**: Last known state. Cloud cache (Cloudflare D1) serves the most recent sync. Directives queue and deliver when the machine comes back online. This is acceptable (D-F7).

### Directive delivery path

```
Commander (phone/browser)
  -> nobulai.tools UI
    -> GraphQL mutation (sendDirective)
      -> API writes to session DB commander_directives table
        (via Cloudflare Tunnel to local machine)
          -> command-channel-stop.sh reads at next Stop hook firing
            -> stderr injection into agent context
              -> agent addresses the directive
```

Latency: UI to API is instant. API to session DB depends on Tunnel latency (~50-100ms). Stop hook polls every 15-60 seconds. Total: directive reaches agent within 1 minute during an active session.

## 9. KPI Integration

### What's measured

| Metric | Source | What it tells you |
|--------|--------|-------------------|
| guard.fireCount | JSONL events | How many tool calls were inspected |
| guard.blockCount | JSONL events | How many violations were blocked |
| guard.warnCount | JSONL events | How many warnings were issued |
| delegation.avgScore | JSONL events | Average delegation duty compliance (0-6) |
| delegation.minScore | JSONL events | Worst delegation in the session |
| delegation.count | JSONL events | How many subagents were launched |
| session.turnCount | JSONL events | Conversation turns |
| session.durationSeconds | JSONL events | Session length |
| session.subagentCount | JSONL events | Total subagent launches |
| session.scratchFileCount | Filesystem | Work products produced |

### Datadog adapter

The adapter reads from Datadog when available, falls back to local harness DB when Datadog is unavailable or for real-time data not yet shipped.

## 10. Migration from Prototypes

### Keep (infrastructure)

| Artifact | Why |
|----------|-----|
| command-channel-stop.sh | Working Stop hook. The Layer 1 reader. |
| harness-db.py | CLI for all DB operations. The Layer 2 protocol. |
| commander_directives schema | The directive table. Proven. |
| commander_feedback schema | The feedback table. Proven. |
| harness-db-schema.sql | Canonical schema. All tables. |
| generate-dashboard.py | Local dashboard for non-web use. |

### Supersede (replace with MC)

| Artifact | Replaced by |
|----------|------------|
| session-command-center-v2.py | MC session view + command palette |
| export-snapshot.py | MC with live data via Tunnel |
| Vercel static deployment | Cloudflare Pages |
| running-estimate.json dashboard | MC with direct DB access |

### Schema gap to close

The `commander_directives` and `commander_feedback` tables exist in `harness-db.py` SESSION_SCHEMA but are NOT in `reference/harness-db-schema.sql`. The canonical schema file needs updating to include both tables.

## 11. Phase Plan

### Phase 0: Foundation (1 session)
- GraphQL API skeleton (TypeScript/Node.js)
- Session query from local SQLite
- Basic landing page (list sessions)
- Deploy to Cloudflare Pages
- **Exit criteria**: Session list visible from phone

### Phase 1: Session View (1 session)
- Full session view with all tabs
- Message filtering and sorting
- Delegation duty scores displayed
- KPI summary card
- **Exit criteria**: Complete session inspection from any device

### Phase 2: Command Channel (1-2 sessions)
- Directive submission via GraphQL mutation
- Command palette with all 8 directive types
- Directive lifecycle tracking in UI
- Cloudflare Tunnel for local machine connectivity
- **Exit criteria**: Directive sent from phone reaches agent within 60 seconds

### Phase 3: KPI Dashboard (1 session)
- Datadog adapter for KPI queries
- KPI trend visualization
- Health indicators on landing page
- **Exit criteria**: Delegation quality trends visible over time

### Phase 4: Session Viewer (1 session)
- Scratch file browser
- Markdown rendering
- Per-file feedback
- Git diff integration
- **Exit criteria**: Session artifacts browsable from any device

### Phase 5: Cross-Session History (1 session)
- Timeline view across all projects
- Machine grouping with collapse
- Session search and filtering
- **Exit criteria**: "What did I work on last week?" answerable from phone

## 12. Open Questions

1. **Tunnel vs push**: Cloudflare Tunnel provides always-on connectivity but requires a daemon. Push-based sync is simpler but introduces latency. Decision needed before Phase 2.

2. **Authentication for directive submission**: Directives modify session state. Auth is not in Phase 0-1. How do we prevent unauthorized directive submission before auth lands?

3. **Session DB locking**: WAL mode handles concurrent readers, but verify edge cases with Stop hook writing acknowledged_at while MC is reading.

4. **Git diff integration**: How to associate commits with sessions? By timestamp overlap, session_id in commit message, or git note?

5. **Real-time updates**: WebSocket from Cloudflare Workers vs polling the GraphQL endpoint vs SSE.

6. **Mobile command palette**: Cmd+K doesn't exist on phones. Touch-optimized directive entry needed.

7. **Schema file gap**: commander_directives and commander_feedback need to be added to harness-db-schema.sql.

## 13. References

### Session decisions
- D-F5: Feedback Tables (session f078fb16)
- D-F6: MC Session Scope (session f078fb16)
- D-F7: MC Data Path Constraints (session f078fb16)
- D-F12: Datadog as KPI Source (session f078fb16)
- All 14 decisions: plans/session-f078fb16-ol-and-decisions.md

### Command channel provenance
- Command channel investigation: .scratch/session-c0dc2ddc-f/command-channel-investigation.md
- Command channel build: harvesting/2026-03-26_session-2d439e32-3_command-channel-build.md
- Command channel OL: harvesting/2026-03-25_session-c0dc2ddc-f_command-channel-operational-learning.md
- OL-CC1 through OL-CC5

### Existing implementations
- command-channel-stop.sh: shared/hooks/command-channel-stop.sh
- harness-db.py: scripts/harness-db.py
- session-command-center-v2.py: .scratch/session-c0dc2ddc-f/session-command-center-v2.py
- export-snapshot.py: .scratch/session-c0dc2ddc-f/export-snapshot.py
- generate-dashboard.py: scripts/generate-dashboard.py

### Schema
- harness-db-schema.sql: reference/harness-db-schema.sql

### Related RFCs
- RFC 0001: nobulai-tools Product Definition (this series)
- RFC 0003: Operational Learning Graph Architecture (this series)
- nobul-ops RFC 0020: Identity, Secrets, Access Management
- nobul-ops RFC 0023: SaaS Contingency Architecture

### Sessions
- c0dc2ddc-f: Command channel investigation, telemetry redesign, prototypes
- 2d439e32-3: Command channel build (Stop hook, directive CLI)
- f078fb16: Architectural decisions (this RFC's source)
- 8236ca9c: Thinking awareness, harness loading, identity design
- fbf7decb: This session
