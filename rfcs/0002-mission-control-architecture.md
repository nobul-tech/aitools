# RFC 0002: Mission Control Architecture

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Source decisions**: D-F5, D-F6, D-F7, D-F12 (session f078fb16, 2026-03-28)
**Informed by**: Command channel investigation (12 systems, 7 domains, session c0dc2ddc-f), OL-CC1 through OL-CC5, /mission-control skill (7 monitoring patterns), commander profile, relay entries from 5 agents, full session transcripts from 8236ca9c (MC conceptualization), 1bc9fd30, f078fb16, dashboard-serve.sh, existing prototypes

---

## 1. Summary

Mission Control is the commander's cockpit to the aitools harness. It is a bidirectional, web-accessible, context-efficient communication channel — not a dashboard (D-F9). The commander observes what agents are doing, sends directives that reach agents within seconds, reviews session history across all projects and machines, and monitors harness health — all from any device, including a phone.

MC replaces seven ad-hoc shell commands that provided actual monitoring when dashboards showed zeros during a 3-mission operation. It preserves the patterns that worked and makes them accessible without terminal access.

MC has three layers: **Data** (SQLite session/harness DBs, JSONL events, Datadog KPIs), **API** (GraphQL as the single entry point), and **UI** (web frontend). The command channel uses a Stop hook polling pattern validated by investigation of 12 systems across 7 domains — the architecturally correct pattern when the platform does not support push notifications (OL-CC1).

This RFC defines the architecture. RFC 0001 defines the product. RFC 0003 defines the OL graph that MC surfaces.

## 2. Background

### What MC evolved from

MC started as ad-hoc shell commands during a 3-mission operation (Alpha/Bravo/Charlie, session 8236ca9c, 2026-03-24). Seven commands provided actual monitoring when dashboards showed zeros:

| Pattern | Shell command | What it revealed |
|---------|--------------|------------------|
| 1. Process discovery | `ps aux \| grep generate-dashboard` | Which dashboards are running, PIDs, ports |
| 2. Last activity | `tail -1 <transcript>.jsonl \| python3 ...` | Most recent agent action |
| 3. Progress gauge | `wc -l <transcript>.jsonl` | Rough work volume |
| 4. Work product inventory | `ls <scratch-dir>/` | Files produced by the mission |
| 5. Deliverable size | `wc -c <output-file>` | Completeness proxy |
| 6. Deliverable validation | `python3 -c "import json; ..."` | JSON valid, expected structure present |
| 7. Dashboard health | `curl -s localhost:<port>/` | HTTP liveness + data quality |

These were codified into the /mission-control skill. MC makes ALL of these available through a web UI without requiring shell access.

Then came prototypes:
- **generate-dashboard.py**: Local Python server reading running-estimate.json on port 8411. Limited to one session. Started by dashboard-serve.sh SessionStart hook.
- **session-command-center-v2.py**: DB-backed dashboard with feedback loop. POST /api/feedback for commander input. Cmd+K modal for quick commands. The first bidirectional prototype.
- **export-snapshot.py**: Static HTML exporter deployed to Vercel. A 64KB self-contained dashboard with 78 messages, 16 decisions, 35 observations. Proved remote access works.

### What MC IS now (D-F9)

"Not just a dashboard — it's a context-efficient communication channel, bidirectional, web-accessible, the cockpit to the harness machine."

The cockpit metaphor is precise. A pilot's cockpit provides: instrument readings (telemetry), controls (command input), alerts (anomaly detection), and communication (radio). MC provides the same:

| Cockpit function | MC equivalent | Data source |
|-----------------|---------------|-------------|
| Instruments | Session state, KPIs, delegation scores | Session DB, Datadog |
| Controls | Directives (correction, redirect, approve) | commander_directives table |
| Alerts | Stale OL, guard blocks, low delegation scores | KPI events, harness DB |
| Communication | Messages (SITREPs, findings), feedback | Session DB messages table |

### Design informed by the commander

From the commander profile (consolidated OL, Part 1):
- **Time is the primary constraint.** MC must give a 2-second answer to "what's happening?" from a phone. No clicking through tabs to find the status.
- **Stream-of-consciousness communication.** The command palette must accept informal, typo-laden input — not just structured forms. The commander types fast with typos; that's how he thinks.
- **Leverage through parallelism.** MC must show concurrent sessions and their relative progress. The chain of command (Commander -> Session Commander -> Mission Commander) should be visible.
- **Agent output is data.** MC displays agent output for the commander to evaluate. It does not interpret or summarize what agents produce.

## 3. Architecture Overview

```
UI LAYER: nobulai.tools/<user>/mc
  Landing | Session view | Command palette | History
        |
        | GraphQL
        v
API LAYER: GraphQL API (single entry point)
  Queries: sessions, messages, decisions, OL, KPIs
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

The local dashboard (generate-dashboard.py, started by dashboard-serve.sh) continues to serve during active sessions. MC (web) and the local dashboard are complementary — MC provides remote access, the local dashboard provides zero-latency local monitoring. When MC is fully live, the local dashboard becomes the offline fallback.

## 4. Data Layer

### Session DB (Tier 1)

One SQLite database per session at `.aitools/sessions/<prefix>.db`. Written by that session's agents only. WAL mode for concurrent readers. Schema from `reference/harness-db-schema.sql`:

| Table | MC uses it for |
|-------|---------------|
| session | Schwerpunkt, state, timestamps — the session card |
| missions | Nested mission tree — Missions tab |
| decisions | Architectural decisions — Governance tab |
| observations | Classified findings — Governance tab |
| messages | SITREPs + FINDINGs — Messages tab |
| delegation_log | Subagent launches with duty scores — Delegations tab |
| deviations | Process deviations — State tab |
| completed_work | Shipped items — State tab |
| events | Hook fires, blocks, warns — KPI computation |
| commander_directives | Time-critical uplink — Command channel |
| commander_feedback | Advisory feedback — Feedback tab |

### Harness DB (Tier 2)

Cross-session state at `.aitools/harness.db`. Written at session boundaries only.

| Table | MC uses it for |
|-------|---------------|
| session_index | Session discovery — Landing page |
| kpi_events | Metrics — KPI dashboard, health indicators |
| kpi_ship_log | Datadog shipping state — KPI dashboard |
| knowledge_items | OL graph nodes — OL integration (RFC 0003) |
| provenance_edges | OL graph edges — OL integration (RFC 0003) |
| nogood_sets | Known dead ends — OL integration (RFC 0003) |

### JSONL Events

Enforcement hooks append structured events to `.scratch/session-*/events.jsonl` (~0.1ms per event). The SessionEnd processor (`harness-db.py process-events`) computes aggregate metrics for `kpi_events`. Hot-path telemetry — zero overhead during sessions.

Event types: hook_fire, hook_block, hook_warn, delegation, session_event. Each carries source (hook name), detail (JSON), and timestamp.

### Datadog KPIs

Harness DB ships to Datadog via `harness-db.py ship`. MC reads KPIs from Datadog API through an adapter. The adapter IS the contingency — when Datadog flips to Axiom, the adapter handles it (D-F12). Local harness DB is the fallback when Datadog is unavailable.

## 5. Command Channel

### Architecture (from command-channel-investigation.md)

Investigation of 12 systems across 7 domains (LangGraph, Temporal, OpenAI SDK, HumanLayer, Slack, Jenkins, Argo CD, Jupyter, VS Code, NASA Open MCT, JPL, Claude Code) established five principles:

- **OL-CC1**: Polling a durable shared store at natural pause points is the correct pattern when push is unavailable. Every major framework uses this.
- **OL-CC2**: Observation (telemetry/downlink) and command (uplink) are separate subsystems. NASA separates them because they have different requirements.
- **OL-CC3**: The Stop hook is the agent's "idle loop" — same function as Temporal's workflow main loop and Jupyter's kernel idle handler.
- **OL-CC4**: Priority matters more than latency. Flash directives interrupt immediately; context can wait.
- **OL-CC5**: The Claude Agent SDK will eventually provide push. Design for transport swap.

### Two tables, two purposes (D-F5)

Both tables are kept. They are different W3C PROV entity types with different temporal characteristics:

**commander_directives** — the uplink:
- Trust level: L3 (commander_directive)
- W3C PROV relationship: "triggered" (triggers immediate agent action)
- Time-critical: per-turn delivery via Stop hook polling
- Session-scoped lifecycle: pending -> acknowledged -> executed/rejected/deferred
- The Stop hook reads these ONLY (blocking, exit 2)

**commander_feedback** — advisory:
- Trust level: varies (L2-L3)
- W3C PROV relationship: "informed" (informs future decisions, becomes OL)
- Not time-critical: readable by agents on demand, no Stop hook blocking
- Cross-session lifecycle: submitted -> acknowledged -> resolved
- Becomes knowledge_items in the provenance graph when promoted (RFC 0003)

### Stop hook polling

`command-channel-stop.sh` fires after every agent response:

1. Opens session SQLite DB at `.aitools/sessions/<prefix>.db`
2. Queries `commander_directives WHERE status = 'pending' ORDER BY created_at`
3. Falls back to `commander_feedback WHERE status = 'submitted' ORDER BY created_at`
4. If pending: formats with priority prefix ([FLASH], [PRIORITY], or none), injects via stderr, updates status to 'acknowledged', exits 2 (blocks agent)
5. If none: exits 0 (no-op)
6. Emits JSONL telemetry event to events.jsonl

Performance: SQLite WAL read <5ms. Total hook <50ms. The hook is currently in `shared/hooks/` but not registered in `~/.claude/settings.json` (the Stop hook registration gap identified by the assessment).

### Directive types

| Type | Use case | Commander example |
|------|----------|-------------------|
| correction | Agent got something wrong | "That's not what I meant, the correct approach is..." |
| redirect | Change course | "Stop working on X, focus on Y" |
| priority | Urgency signal | "This is blocking, do it now" / "This can wait" |
| question | Socratic verification | "Why did you do it that way?" |
| approve | Green light | "Proceed with this plan" |
| reject | Red light | "Do not do this" |
| context | Additional information | "Here's context you're missing: ..." |
| checkpoint | Save state | "Commit what you have, summarize progress" |

### Directive priority

| Priority | Behavior | When to use |
|----------|----------|-------------|
| flash | [FLASH] prefix, exit 2 | "Stop what you're doing" |
| priority | [PRIORITY] prefix, exit 2 | "Address this next" |
| normal | No prefix, exit 2 | "When convenient" |

All priorities block (exit 2). Priority affects display emphasis, not blocking behavior.

### CLI access

`harness-db.py` provides directive management:
- `directive add "message" [--type X] [--priority Y] [--target Z]`
- `directive list [--status S]`
- `directive poll` (used by the Stop hook, also standalone)
- `directive ack <id> [--response R] [--status S]`

## 6. API Layer

### GraphQL as single entry point

All frontend queries and adapter integrations go through GraphQL. The schema is the contract that survives infrastructure swaps (D-F7). Enum values align with the CHECK constraints in `reference/harness-db-schema.sql`.

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
  type: MessageType!          # sitrep | finding (matches DB CHECK)
  agentRole: String!
  title: String
  message: String!
  severity: Severity!         # routine | priority | flash | low | medium | high | critical
  actionable: Boolean!
  createdAt: DateTime!
}

type Directive {
  id: ID!
  type: DirectiveType!        # correction | redirect | priority | question | approve | reject | context | checkpoint
  priority: Priority!         # flash | priority | normal
  message: String!
  target: String
  status: DirectiveStatus!    # pending | acknowledged | executed | rejected | deferred
  response: String
  createdAt: DateTime!
  acknowledgedAt: DateTime
  executedAt: DateTime
}

type Mission {
  id: ID!
  parentMissionId: ID
  type: String!               # s2 | s3 | s5 | recon | fragord
  description: String!
  status: MissionStatus!      # launched | in_progress | complete | failed | killed
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
  status: DelegationStatus!   # launched | in_progress | complete | failed | killed
  dutyScore: Int              # 0-6 (from delegation-duty-guard)
  dutyMissing: String         # comma-separated missing elements
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
  guardWarnCount: Int
  delegationAvgScore: Float
  delegationMinScore: Float
  delegationCount: Int
  subagentCount: Int
  durationSeconds: Float
  scratchFileCount: Int
}
```

### Queries

```graphql
type Query {
  # Landing page
  sessions(machine: String, project: String, status: SessionStatus, limit: Int): [Session!]!
  activeSession(machine: String, project: String): Session

  # Session view
  session(id: ID!): Session

  # History
  sessionHistory(days: Int, project: String): [Session!]!

  # Command channel
  pendingDirectives(sessionId: ID!): [Directive!]!
  directiveHistory(sessionId: ID!, limit: Int): [Directive!]!

  # KPIs
  kpis(sessionId: ID): SessionKPIs
  kpiTrend(metric: String!, days: Int!): [KPIDataPoint!]!

  # Health
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

| Adapter | Source | Protocol |
|---------|--------|----------|
| Local machine | Session DB, Harness DB, JSONL events, scratch files | SQLite via Cloudflare Tunnel |
| Datadog | KPI metrics | Datadog API v2 |
| GitHub | Commit history, diffs | GitHub API via gh |
| Git | Local commit log | git CLI |
| Session archives | Dotprofile JSONL | File read via Tunnel or git |

## 7. UI Layer

### Landing page (/<user>/mc)

The commander's 2-second answer to "what's happening?" — viewable from a phone.

**Active sessions** across ALL projects, grouped by machine (machineAlias from profile.json) then repo. Collapse empty levels (D-F6).

For each active session card:
- Schwerpunkt (one line)
- Turn count, duration, last activity
- Health indicator: green (delegation avg >4/6, zero guard blocks), yellow (avg 2-4/6 or blocks >0), red (avg <2/6 or session stalled >15min)
- Quick directive buttons (Approve, Reject, Checkpoint)
- Chain of command indicator: Commander -> Session Commander -> N Mission Commanders

**Recent sessions** (last 7 days) below active, clickable to session view.

Maps to monitoring patterns 1 (process discovery), 2 (last activity), 3 (progress gauge), 7 (health check).

### Session view (/<user>/mc/session/<id>)

Tab-based view. Each tab maps to monitoring patterns and DB tables:

| Tab | Content | Source | Monitoring pattern |
|-----|---------|--------|--------------------|
| Messages | SITREPs + Findings, filterable by severity/type | messages table | Pattern 2 (last activity) |
| Governance | Decisions + observations, with OL provenance context (RFC 0003) | decisions, observations | — |
| Delegations | Subagent launches with 0-6 duty scores, missing elements listed | delegation_log + JSONL events | — |
| Missions | Nested mission tree (self-referential via parent_mission_id) | missions table | — |
| State | Schwerpunkt, completed work, deviations | session, completed_work, deviations | — |
| Feedback | Directives + feedback with lifecycle status | commander_directives, commander_feedback | — |
| Documents | Session artifacts rendered as markdown, file sizes | .scratch/session-* files | Patterns 4, 5 (work product, size) |
| Git Diffs | Commits from this session's timeframe | git log | — |

### Command palette

Cmd+K (desktop) or floating action button (mobile) opens the command interface.

**Structured mode**: Select type -> set priority -> write message -> optional target -> submit.

**Stream mode**: Free text input. The commander types naturally ("stop what youre doing and focus on the skills deployment"). The system classifies type and priority from content. This matches the commander's stream-of-consciousness communication style.

Both modes: GraphQL mutation -> session DB commander_directives -> Stop hook reads at next pause.

### Chain of command view

Visual representation of the delegation hierarchy within a session:

```
Commander (Jose)
  └── Session Commander fbf7decb
        ├── MC: hook-design (complete, 77s)
        ├── MC: verify-and-propose (complete, 312s)
        └── MC: assessment-lead (complete, 900s)
              ├── blast-radius (sequential, complete)
              ├── tool-ops-verify (sequential, complete)
              └── work-product-inventory (sequential, complete)
```

Note: Agent tool is NOT available to subagents (OL-50, verified). Delegation is flat from Session Commander level — depth 1 only. The nested display above shows logical nesting (missions), not agent nesting.

## 8. Data Path

### The constraint

The user's machine is the source of truth. Session DBs, JSONL events, and scratch files are local. nobulai.tools needs to display this data from any device (D-F7).

### Three modes

| Mode | Machine state | Latency | Directive delivery | Data freshness |
|------|--------------|---------|-------------------|----------------|
| **Live** | Online + session active | Real-time via Tunnel | 15-60s (Stop hook cycle) | Current |
| **Available** | Online + no active session | Near-real-time via Tunnel | Queued for next session | Current |
| **Offline** | Machine off | Cached in Cloudflare D1 | Queued until online | Last sync |

Offline is acceptable (D-F7). Directives queue and deliver when the machine comes back online.

### Directive delivery path

```
Commander (phone)
  -> nobulai.tools command palette
    -> GraphQL mutation (sendDirective)
      -> API writes to session DB via Cloudflare Tunnel
        -> command-channel-stop.sh polls at next Stop hook firing
          -> stderr injection into agent context
            -> agent addresses the directive
```

Total latency during active session: <60 seconds (dominated by Stop hook polling interval).

### Sync mechanism

At session boundaries (SessionEnd hook chain):
1. session-archive.sh copies JSONL to dotprofile, git push
2. harvest-session.sh classifies scratch, copies artifacts to harvesting/
3. harness-db-sessionend.sh marks session complete, exports to running-estimate.json, processes events to KPIs, ships to Datadog
4. Future: push session summary to Cloudflare D1 cache

Between sessions:
- `aitools` pull syncs git-tracked state
- Dotprofile pull syncs session archives
- Cloud cache may be stale (offline-acceptable)

## 9. KPI Integration

### What's measured (from harness-db.py process_session_events)

| Metric | Source | Landing page | Session view |
|--------|--------|-------------|--------------|
| guard.fireCount | JSONL events | — | KPI card |
| guard.blockCount | JSONL events | Health indicator | KPI card |
| guard.warnCount | JSONL events | — | KPI card |
| delegation.avgScore | JSONL events | Health indicator | Delegations tab |
| delegation.minScore | JSONL events | — | Delegations tab |
| delegation.count | JSONL events | Session card | KPI card |
| session.turnCount | JSONL events | Session card | KPI card |
| session.durationSeconds | JSONL events | Session card | KPI card |
| session.subagentCount | JSONL events | Session card | KPI card |
| session.scratchFileCount | Filesystem | — | Documents tab |

### Datadog adapter

```
harness DB kpi_events -> harness-db.py ship -> Datadog API v2
                                                     |
nobulai.tools MC <- GraphQL query <- Datadog adapter -+
                                  <- Local DB adapter -+ (fallback)
```

Adapter reads Datadog when available, falls back to local harness DB for real-time data not yet shipped or when Datadog is unavailable.

### Health indicators

| Indicator | Green | Yellow | Red |
|-----------|-------|--------|-----|
| Delegation quality | avg >4/6 | avg 2-4/6 | avg <2/6 |
| Guard activity | 0 blocks | 1-5 blocks | >5 blocks |
| Session activity | Active within 5min | Flat 5-15min | Stalled >15min |
| OL staleness (RFC 0003) | 0 stale items | 1-5 stale | >5 stale |

## 10. Migration from Prototypes

### Keep (infrastructure)

| Artifact | Role | Location |
|----------|------|----------|
| command-channel-stop.sh | Stop hook (Layer 1 reader) | shared/hooks/ |
| harness-db.py | DB CLI (Layer 2 protocol) | scripts/ |
| commander_directives table | Directive schema | harness-db.py SESSION_SCHEMA |
| commander_feedback table | Feedback schema | harness-db.py SESSION_SCHEMA |
| harness-db-schema.sql | Canonical schema | reference/ |
| generate-dashboard.py | Local dashboard (offline fallback) | scripts/ |
| dashboard-serve.sh | Local dashboard lifecycle hook | shared/hooks/ |

### Supersede (replace with MC)

| Artifact | Replaced by | Keep until |
|----------|------------|------------|
| session-command-center-v2.py | MC session view + command palette | MC Phase 2 |
| export-snapshot.py | MC with live data via Tunnel | MC Phase 0 |
| Vercel static deployment | Cloudflare Pages | MC Phase 0 |
| running-estimate.json dashboard | MC with direct DB access | MC Phase 1 |

### Schema gap

commander_directives and commander_feedback tables exist in harness-db.py SESSION_SCHEMA but NOT in reference/harness-db-schema.sql. The canonical schema file needs updating. This is a protected file change.

## 11. Phase Plan

Phases map to RFC 0001's product phases:

| RFC 0002 Phase | RFC 0001 Phase | Focus |
|---------------|---------------|-------|
| 0: Foundation | 0: Port Prototypes | Basic session list |
| 1: Session View | 0: Port Prototypes | Full inspection |
| 2: Command Channel | 1: Command Channel | Bidirectional |
| 3: KPI Dashboard | 1: Command Channel | Metrics |
| 4: Session Viewer | — | Artifacts |
| 5: Cross-Session | — | History |

### Phase 0: Foundation (1 session)

- GraphQL API skeleton (TypeScript/Node.js)
- Session list query from local SQLite via adapter
- Basic landing page with session cards
- Deploy to Cloudflare Pages
- **Exit criteria**: Session list visible from phone

### Phase 1: Session View (1 session)

- All 8 tabs (Messages, Governance, Delegations, Missions, State, Feedback, Documents, Git Diffs)
- Message filtering by severity and type
- Delegation duty scores with missing-elements display
- Chain of command visualization
- KPI summary card
- **Exit criteria**: Complete session inspection from any device

### Phase 2: Command Channel (1-2 sessions)

- Directive submission via GraphQL mutation
- Command palette with structured + stream modes
- Directive lifecycle tracking (pending -> acknowledged -> executed)
- Cloudflare Tunnel for local machine connectivity
- Register command-channel-stop.sh in settings.json (closes the Stop hook gap)
- **Exit criteria**: Directive from phone reaches agent within 60 seconds

### Phase 3: KPI Dashboard (1 session)

- Datadog adapter for KPI queries
- KPI trend visualization (delegation quality over time)
- Health indicators on landing page (green/yellow/red)
- Cross-session KPI comparison
- **Exit criteria**: "Is delegation quality improving?" answerable from MC

### Phase 4: Session Viewer (1 session)

- Scratch file browser with file sizes
- Markdown rendering
- Per-file contextual feedback
- Git diff integration
- **Exit criteria**: Session artifacts browsable from any device

### Phase 5: Cross-Session History (1 session)

- Timeline view across all projects and machines
- Machine grouping with collapse
- Session search and filtering
- OL items per session (from RFC 0003)
- **Exit criteria**: "What did I work on last week?" answerable from phone

### Future: Investigation proposals

The command channel investigation (session c0dc2ddc-f) proposed four features beyond the core MC:

1. **Agent orchestration panel**: Live tree view of active agents with per-agent status, commands, and kill buttons. Requires delegation hooks writing to delegation_log — partially in place via delegation-duty-guard.sh.

2. **Session handoff via dashboard**: Banner display of unconsumed handoffs, acceptance tracking. The /handoff skill already produces handoff documents to .aitools/channel/handoffs/. MC surfaces them.

3. **Governance health dashboard**: Cross-session governance metrics from kpi_events. Hook fire rates, rule compliance, incident trends, OL carry-forward rates.

4. **Context-aware command suggestions**: Lightweight classifier on recent messages suggests relevant directives. Agent launched 3+ subagents -> suggest "Show delegation status." Agent wrote a plan -> suggest "Approve/Reject."

These are post-Phase 5 features, informed by operational experience with the core MC.

## 12. Open Questions

1. **Tunnel vs push (Phase 2 blocker)**: Cloudflare Tunnel provides always-on connectivity but requires a daemon. Push-based sync is simpler but adds latency. Decision needed before Phase 2. Evaluate Tunnel daemon resource cost on both macOS and Windows.

2. **Pre-auth directive security (Phase 0-1)**: Directives modify session state. Auth lands in RFC 0001 Phase 2. Before that, how do we prevent unauthorized submissions? Options: Tunnel restricts to local network, shared secret header, or accept single-user risk. Recommendation: accept risk — single user, private infrastructure.

3. **Session DB concurrent access (Phase 2)**: WAL mode handles concurrent readers. The Stop hook writes acknowledged_at while MC reads session data. SQLite WAL is designed for this. Verify with load test during Phase 2.

4. **Git-session association**: How to link commits to sessions for the Git Diffs tab? Options: timestamp overlap (simple, imprecise), session_id in commit message (requires convention), git notes (requires tooling). Recommendation: timestamp overlap initially, convention later.

5. **Mobile command palette**: Cmd+K doesn't exist on phones. Options: floating action button, bottom sheet, long-press. Needs UX design. Stream mode (free text) may be sufficient on mobile — structured mode for desktop.

6. **Real-time updates**: WebSocket vs SSE vs polling from Cloudflare Workers. Workers supports WebSocket with limitations. SSE may be simpler for one-directional updates (server -> client). Polling is always the fallback. Decision during Phase 1.

7. **Schema file gap**: commander_directives and commander_feedback tables need to be added to reference/harness-db-schema.sql. Protected file change. Should be done before Phase 2.

8. **Relay visibility**: The relay at .aitools/channel/relay.md contains cross-agent learning. Should MC surface relay entries? They represent agents helping each other — a unique data type that doesn't fit neatly into session view tabs. Consider a dedicated "Relay" view or integrating with OL graph (RFC 0003).

## 13. References

### Session decisions
- D-F5: Feedback Tables (session f078fb16)
- D-F6: MC Session Scope (session f078fb16)
- D-F7: MC Data Path Constraints (session f078fb16)
- D-F9: MC and OL Definitions Need Redefining (session f078fb16)
- D-F12: Datadog as KPI Source (session f078fb16)
- All 14 decisions: plans/session-f078fb16-ol-and-decisions.md

### Command channel provenance
- Investigation: .scratch/session-c0dc2ddc-f/command-channel-investigation.md (361 lines, 12 systems, 7 domains)
- Build: harvesting/2026-03-26_session-2d439e32-3_command-channel-build.md
- OL: harvesting/2026-03-25_session-c0dc2ddc-f_command-channel-operational-learning.md
- OL-CC1 through OL-CC5: investigation principles

### Monitoring provenance
- /mission-control skill: shared/skills/mission-control/SKILL.md (7 patterns)
- Alpha/Bravo/Charlie operation: session 8236ca9c (where patterns were discovered)

### Existing implementations
- command-channel-stop.sh: shared/hooks/command-channel-stop.sh
- harness-db.py: scripts/harness-db.py (3009 lines)
- session-command-center-v2.py: .scratch/session-c0dc2ddc-f/
- export-snapshot.py: .scratch/session-c0dc2ddc-f/
- generate-dashboard.py: scripts/generate-dashboard.py
- dashboard-serve.sh: shared/hooks/dashboard-serve.sh

### Schema
- harness-db-schema.sql: reference/harness-db-schema.sql
- Schema gap: commander_directives and commander_feedback not in canonical schema

### Commander profile
- Consolidated OL Part 1: .scratch/session-c0dc2ddc-f/consolidated-operational-learning.md
- Commander profile: .aitools/channel/d5b52bf2-2026-03-27T0045Z-commander-profile.md

### Related RFCs
- RFC 0001: nobulai-tools Product Definition (this series)
- RFC 0003: Operational Learning Graph Architecture (this series)
- nobul-ops RFC 0020: Identity, Secrets, Access Management
- nobul-ops RFC 0023: SaaS Contingency Architecture

### Sessions
- 8236ca9c: MC conceptualization, 7 monitoring patterns, identity design
- c0dc2ddc-f: Command channel investigation, telemetry redesign, prototypes
- 2d439e32-3: Command channel build (Stop hook, directive CLI)
- f078fb16: Architectural decisions (this RFC's source)
- 1bc9fd30: Failure mode exit, scope expansion
- fbf7decb: This session
